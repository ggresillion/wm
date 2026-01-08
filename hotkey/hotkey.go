package hotkey

import (
	"log"

	"golang.design/x/hotkey"
)

type Action uint

const (
	ActionLeft Action = iota
	ActionRight
	ActionUp
	ActionDown
	ActionSwapLeft
	ActionSwapRight
	ActionResize
	Debug
)

var KeyBinds = map[Action]*hotkey.Hotkey{
	ActionRight: hotkey.New([]hotkey.Modifier{hotkey.ModCmd}, hotkey.KeyL),
	ActionLeft:  hotkey.New([]hotkey.Modifier{hotkey.ModCmd}, hotkey.KeyH),
	ActionUp:    hotkey.New([]hotkey.Modifier{hotkey.ModCmd}, hotkey.KeyK),
	ActionDown:  hotkey.New([]hotkey.Modifier{hotkey.ModCmd}, hotkey.KeyJ),
	ActionSwapLeft: hotkey.New([]hotkey.Modifier{
		hotkey.ModCmd,
		hotkey.ModShift,
	}, hotkey.KeyH),
	ActionSwapRight: hotkey.New([]hotkey.Modifier{
		hotkey.ModCmd,
		hotkey.ModShift,
	}, hotkey.KeyL),
	ActionResize: hotkey.New([]hotkey.Modifier{
		hotkey.ModCmd,
	}, hotkey.KeyR),
	Debug: hotkey.New([]hotkey.Modifier{hotkey.ModCmd}, hotkey.KeyD),
}

var Callbacks = map[Action]func(){}

func Init() {
	for action, hk := range KeyBinds {
		err := hk.Register()
		if err != nil {
			log.Fatalf("[hotkey] failed to register hotkey: %v", err)
			return
		}
		go func() {
			for range hk.Keydown() {
				log.Printf("[hotkey] hotkey pressed: %s\n", hk)
				Callbacks[action]()
			}
		}()
	}
}

func Stop() {
	for _, hk := range KeyBinds {
		err := hk.Unregister()
		if err != nil {
			log.Fatalf("[hotkey] failed to unregister hotkey: %v", err)
			return
		}
	}
}

func On(action Action, cb func()) {
	Callbacks[action] = cb
}
