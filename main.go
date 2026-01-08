package main

import (
	"fmt"
	"macwm/hotkey"
	"macwm/manager"
	"os"
	"os/signal"
	"syscall"

	"golang.design/x/hotkey/mainthread"
)

func main() {
	mainthread.Init(fn)
}

func fn() {
	hotkey.Init()

	hotkey.On(hotkey.ActionRight, func() {
		manager.FocusRight()
	})
	hotkey.On(hotkey.ActionLeft, func() {
		manager.FocusLeft()
	})
	hotkey.On(hotkey.ActionSwapLeft, func() {
		manager.SwapLeft()
	})
	hotkey.On(hotkey.ActionSwapRight, func() {
		manager.SwapRight()
	})
	hotkey.On(hotkey.Debug, func() {
	})
	hotkey.On(hotkey.ActionResize, func() {
		manager.Resize()
	})

	manager.Start()

	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)
	fmt.Println("Blocking, press ctrl+c to continue...")
	<-done

	hotkey.Stop()
}
