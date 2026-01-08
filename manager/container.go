package manager

import (
	"log"
	"macwm/windows"
)

type SizePreset int

const (
	SizePresetSmall SizePreset = iota
	SizePresetMedium
	SizePresetLarge
)

type Container struct {
	workspace  *Workspace
	Window     []*windows.Window
	Size       int
	SizePreset *SizePreset
	Focused    bool
}

// Name of the container
func (c *Container) Name() string {
	name := ""
	for _, window := range c.Window {
		name += window.App
	}
	return name
}

// Resize resizes the container, cycling through presets
func (c *Container) Resize() {
	var preset SizePreset
	switch {
	case c.SizePreset == nil:
		preset = SizePresetSmall
	case *c.SizePreset == SizePresetSmall:
		preset = SizePresetMedium
	case *c.SizePreset == SizePresetMedium:
		preset = SizePresetLarge
	case *c.SizePreset == SizePresetLarge:
		preset = SizePresetSmall
	}
	c.SizePreset = ptr(preset)

	switch preset {
	case SizePresetSmall:
		c.Size = int(float64(c.workspace.Viewport.W) * 0.25)
	case SizePresetMedium:
		c.Size = int(float64(c.workspace.Viewport.W) * 0.5)
	case SizePresetLarge:
		c.Size = int(float64(c.workspace.Viewport.W) * 0.75)
	}

	workspace.sync()
}

// Focus moves focus to the container
func (c *Container) Focus() {
	for _, container := range workspace.Containers {
		container.Focused = false
	}
	c.Focused = true
	err := c.Window[0].Focus()
	if err != nil {
		log.Printf("[manager] failed to focus window: %v", err)
	}
	c.workspace.scrollTo(c)
	c.workspace.sync()
}

// index of this container in the workspace
func (c *Container) index() int {
	for i, container := range workspace.Containers {
		if container == c {
			return i
		}
	}
	return -1
}

// visible returns true if the container is visible in the viewport
func (c *Container) visible() bool {
	ws := c.workspace

	left := c.workspaceX()
	right := left + c.Size

	wsLeft := ws.Offset
	wsRight := wsLeft + ws.Viewport.W

	if left < wsLeft {
		return false
	}
	if right > wsRight {
		return false
	}
	return true
}

// workspaceX position of this container in the workspace
func (c *Container) workspaceX() int {
	if c == nil {
		return 0
	}

	ws := c.workspace
	var x int
	for _, container := range ws.Containers {
		if container == c {
			break
		}
		x += container.Size
	}
	return x
}
