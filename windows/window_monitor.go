package windows

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa -framework ApplicationServices -lobjc
#include "window_monitor.h"
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"unsafe"
)

//export goWindowEventCallback
func goWindowEventCallback(eventName *C.char, windowID C.int, pid C.pid_t,
	appName *C.char, title *C.char, x C.int, y C.int, width C.int, height C.int,
) {
	// Convert C strings to Go strings
	goEventName := C.GoString(eventName)
	goAppName := C.GoString(appName)
	goTitle := C.GoString(title)
	// Free the C strings
	C.free(unsafe.Pointer(eventName))
	C.free(unsafe.Pointer(appName))
	// TODO: Free title string
	// C.free(unsafe.Pointer(title))
	onEvent(goEventName, goAppName, uint32(pid), uint32(windowID), goTitle, int(x), int(y), int(width), int(height))
}

func StartMonitoring() error {
	result := C.startWindowObserver()
	if result != 0 {
		return fmt.Errorf("failed to start window observer: accessibility permissions not granted")
	}
	return nil
}

func StopMonitoring() {
	C.stopWindowObserver()
}

var (
	onWindowCreated   func(win *Window)
	onWindowDestroyed func(win *Window)
	onWindowResized   func(win *Window, h, w int)
	onWindowMoved     func(win *Window, x, y int)
	onWindowFocused   func(win *Window)
)

func OnWindowCreated(cb func(win *Window)) {
	onWindowCreated = cb
}

func OnWindowDestroyed(cb func(win *Window)) {
	onWindowDestroyed = cb
}

func OnWindowResized(cb func(win *Window, h, w int)) {
	onWindowResized = cb
}

func OnWindowMoved(cb func(win *Window, x, y int)) {
	onWindowMoved = cb
}

func OnWindowFocused(cb func(win *Window)) {
	onWindowFocused = cb
}

func onEvent(
	eventName string,
	appName string,
	pid uint32,
	winID uint32,
	title string,
	x, y, width, height int,
) {
	switch eventName {
	case "AXApplicationActivated":
		onWindowFocused(&Window{
			PID:   pid,
			App:   appName,
			Title: title,
		})
	case "AXMoved":
		onWindowMoved(&Window{
			PID:   pid,
			App:   appName,
			Title: title,
		}, x, y)
	case "AXResized":
		onWindowResized(&Window{
			PID:   pid,
			App:   appName,
			Title: title,
		}, width, height)
	case "AXCreated":
		onWindowCreated(&Window{
			PID:   pid,
			App:   appName,
			Title: title,
		})
	case "AXDestroyed":
		onWindowDestroyed(&Window{
			PID:   pid,
			App:   appName,
			Title: title,
		})
	}
}
