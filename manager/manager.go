package manager

import (
	"log"
	"macwm/windows"
	"time"
)

var workspace *Workspace

func Start() {
	screenWidth := windows.ScreenWidth()
	screenHeight := windows.ScreenHeight()

	workspace = &Workspace{
		Viewport: Rect{
			X: 0,
			Y: 0,
			W: screenWidth,
			H: screenHeight,
		},
		Containers: []*Container{},
		debounce:   newDebounce(time.Millisecond * 100),
	}

	workspace.subscribe()
	log.Printf("[manager] started")
}

// FocusLeft moves focus left and scrolls viewport if needed
func FocusLeft() {
	i := workspace.focused().index()
	if i == 0 {
		return
	}
	workspace.Containers[i-1].Focus()
	log.Printf("[manager] focus left: container %s", workspace.focused().Name())
}

// FocusRight moves focus right and scrolls viewport if needed
func FocusRight() {
	i := workspace.focused().index()
	if i == len(workspace.Containers)-1 {
		return
	}
	workspace.Containers[i+1].Focus()
	log.Printf("[manager] focus right: container %s", workspace.focused().Name())
}

// SwapLeft swaps focused container with the one on its left
func SwapLeft() {
	focused := workspace.focused().index()
	if focused <= 0 {
		return
	}
	workspace.Containers[focused], workspace.Containers[focused-1] = workspace.Containers[focused-1], workspace.Containers[focused]
	workspace.scrollTo(workspace.Containers[focused-1])
	workspace.sync()
}

// SwapRight swaps focused container with the one on its right
func SwapRight() {
	focused := workspace.focused().index()
	if focused >= len(workspace.Containers)-1 {
		return
	}
	workspace.Containers[focused], workspace.Containers[focused+1] = workspace.Containers[focused+1], workspace.Containers[focused]
	workspace.scrollTo(workspace.Containers[focused+1])
	workspace.sync()
}

// Resize resizes the focused container
func Resize() {
	focus := workspace.focused()
	focus.Resize()
}
