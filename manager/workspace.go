package manager

import (
	"log"
	"macwm/animation"
	"macwm/windows"
	"slices"
	"time"
)

type Rect struct {
	X, Y int
	W, H int
}

type Position struct {
	Window *windows.Window
	Rect   Rect
}

type Workspace struct {
	Viewport   Rect
	Containers []*Container
	Offset     int
	debounce   *debounce
}

// sync animates windows to their computed positions
func (ws *Workspace) sync() {
	positions := ws.compute()
	for _, position := range positions {
		go func(position Position) {
			err := animation.AnimateWindow(position.Window, windows.Rect{
				X: float64(position.Rect.X),
				Y: float64(position.Rect.Y),
				W: float64(position.Rect.W),
				H: float64(position.Rect.H),
			}, animation.Animation{
				Duration: 200 * time.Millisecond,
				Easing:   animation.EaseInOut,
			})
			if err != nil {
				log.Printf("[manager] sync failed: %v", err)
			}
		}(position)
	}
}

// compute returns the positions of windows relative to the viewport
func (ws *Workspace) compute() []Position {
	var positions []Position
	offset := -ws.Offset
	for _, container := range ws.Containers {
		for _, w := range container.Window {
			r := Rect{
				X: ws.Viewport.X + offset,
				Y: ws.Viewport.Y,
				W: container.Size,
				H: ws.Viewport.H,
			}
			offset += container.Size
			positions = append(positions, Position{
				Window: w,
				Rect:   r,
			})
		}
	}

	focused := ws.focused().Name()

	log.Printf("[manager] computed workspace: viewport=%dx%d;position=%d,%d;offset=%d;focused=%s;positions=%s",
		ws.Viewport.W,
		ws.Viewport.H,
		ws.Viewport.X,
		ws.Viewport.Y,
		ws.Offset,
		focused,
		dumpPositions(positions))

	return positions
}

// scrollTo scrolls the workspace to the given container
func (ws *Workspace) scrollTo(container *Container) {
	if !container.visible() {
		if container.workspaceX() < ws.Offset {
			ws.Offset = container.workspaceX()
		}
		if container.workspaceX()+container.Size > ws.Offset+ws.Viewport.W {
			ws.Offset = container.workspaceX() + container.Size - ws.Viewport.W
		}
	}
}

// focused returns the focused container
func (ws *Workspace) focused() *Container {
	for _, container := range ws.Containers {
		if container.Focused {
			return container
		}
	}
	return ws.Containers[0]
}

// subscribe to window events
func (ws *Workspace) subscribe() {
	go func(ws *Workspace) {
		windows.OnWindowCreated(ws.onWindowCreated)
		windows.OnWindowDestroyed(ws.onWindowDestroy)
		windows.OnWindowResized(ws.onWindowResized)
		windows.OnWindowMoved(ws.onWindowMoved)
		windows.OnWindowFocused(ws.onWindowFocused)
		err := windows.StartMonitoring()
		if err != nil {
			log.Fatal(err)
		}
	}(ws)
}

func (ws *Workspace) onWindowMoved(win *windows.Window, x, y int) {
	ws.debounce.Call(func() {
		log.Printf("[workspace] event window moved %s", win)
	})
}

func (ws *Workspace) onWindowResized(win *windows.Window, _, w int) {
	ws.debounce.Call(func() {
		log.Printf("[workspace] event window resized %s: %dpx", win, w)
		for _, container := range ws.Containers {
			if container.Window[0].PID == win.PID {
				container.Size = w
				break
			}
		}
		ws.sync()
	})
}

func (ws *Workspace) onWindowFocused(win *windows.Window) {
	log.Printf("[workspace] event window focused %s", win)
	for _, container := range ws.Containers {
		container.Focused = false
		if container.Window[0].PID == win.PID {
			container.Focused = true
		}
	}
	container := ws.focused()
	ws.scrollTo(container)
	ws.sync()
}

func (ws *Workspace) onWindowDestroy(win *windows.Window) {
	log.Printf("[workspace] event window destroyed %s", win)
	for i, container := range ws.Containers {
		if container.Window[0].PID == win.PID {
			ws.Containers = append(ws.Containers[:i], ws.Containers[i+1:]...)
			break
		}
	}
	ws.sync()
}

func (ws *Workspace) onWindowCreated(win *windows.Window) {
	if slices.ContainsFunc(ws.Containers, func(c *Container) bool {
		return c.Window[0].PID == win.PID
	}) {
		return
	}
	log.Printf("[workspace] event window created %s", win)
	ws.Containers = append(ws.Containers, &Container{
		workspace: ws,
		Window:    []*windows.Window{win},
		Size:      int(float64(ws.Viewport.W) * 0.5),
	})
	if len(ws.Containers) == 1 {
		ws.Containers[0].Focused = true
		err := win.Focus()
		if err != nil {
			log.Printf("[workspace] failed to focus window: %v", err)
		}
	}
	ws.sync()
}
