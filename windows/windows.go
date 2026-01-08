package windows

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework CoreGraphics -framework ApplicationServices
#include "bindings.h"
*/
import "C"

import (
	"errors"
	"fmt"
	"log"
	"slices"
	"strings"
)

var ErrWindowNotFound = errors.New("window not found")

var blacklist = []string{
	"Window Server",
	"Finder",
}

type Window struct {
	ID    uint32
	PID   uint32
	App   string
	Title string
}

func (w *Window) String() string {
	return fmt.Sprintf("%s (%d)", w.App, w.PID)
}

type Rect struct {
	X, Y float64
	W, H float64
}

// List all on-screen windows
func ListAllWindows() []*Window {
	list := C.copyWindowList()
	if list == 0 {
		return nil
	}
	defer C.CFRelease(C.CFTypeRef(list))

	count := C.CFArrayGetCount(list)
	windows := make([]*Window, 0, count)

	for i := range count {
		dict := C.CFDictionaryRef(C.CFArrayGetValueAtIndex(list, i))

		ownerCF := C.getWindowOwner(dict)
		titleCF := C.getWindowTitle(dict)

		owner := CFStringToGo(ownerCF)
		owner = strings.TrimRight(owner, "\x00")

		if slices.Contains(blacklist, owner) {
			continue
		}

		windows = append(windows, &Window{
			ID:    uint32(C.getWindowID(dict)),
			App:   owner,
			Title: CFStringToGo(titleCF),
		})

	}
	return windows
}

// Return a window by app name
func GetWindowByApp(owner string) (*Window, error) {
	windows := ListAllWindows()
	for _, win := range windows {
		if strings.Contains(win.App, owner) {
			return win, nil
		}
	}
	return nil, ErrWindowNotFound
}

// Return a window by PID
func GetWindowByPID(pid int) (*Window, error) {
	list := C.copyWindowList()
	if list == 0 {
		return nil, ErrWindowNotFound
	}
	defer C.CFRelease(C.CFTypeRef(list))

	count := C.CFArrayGetCount(list)
	for i := range count {
		dict := C.CFDictionaryRef(C.CFArrayGetValueAtIndex(list, i))
		wpid := int(C.getWindowPID(dict))
		if wpid != pid {
			continue
		}

		return &Window{
			ID:    uint32(C.getWindowID(dict)),
			App:   CFStringToGo(C.getWindowOwner(dict)),
			Title: CFStringToGo(C.getWindowTitle(dict)),
		}, nil
	}

	return nil, ErrWindowNotFound
}

// Set window frame (instant)
func (win *Window) SetFrame(r Rect) error {
	ok := bool(C.setWindowFrame(C.int(win.PID), C.double(r.X), C.double(r.Y), C.double(r.W), C.double(r.H)))
	if !ok {
		return fmt.Errorf("failed to set window frame for %s", win.App)
	}
	return nil
}

func (win *Window) GetFrame() (Rect, error) {
	var x, y, w, h C.double

	ok := bool(C.getWindowFrame(
		C.int(win.PID),
		&x,
		&y,
		&w,
		&h,
	))
	if !ok {
		return Rect{}, errors.New("failed to get window frame")
	}

	return Rect{
		X: float64(x),
		Y: float64(y),
		W: float64(w),
		H: float64(h),
	}, nil
}

// FocusWindow brings a window to the foreground and gives it focus
func (win *Window) Focus() error {
	err := C.focusWindow(C.int(win.PID))
	if err != C.kAXErrorSuccess {
		return fmt.Errorf("failed to focus window: %d", int(err))
	}
	log.Printf("[windows] window %s focused", win.App)
	return nil
}

func ScreenWidth() int {
	return int(C.screenWidth())
}

func ScreenHeight() int {
	return int(C.screenHeight())
}

func HideWindow(pid int) error {
	err := int(C.hideWindow(C.int(pid), C.bool(true)))
	if err != 0 {
		return fmt.Errorf("failed to hide window: %d", err)
	}
	return nil
}

func ShowWindow(pid int) error {
	err := int(C.hideWindow(C.int(pid), C.bool(false)))
	if err != 0 {
		return fmt.Errorf("failed to hide window: %d", err)
	}
	return nil
}
