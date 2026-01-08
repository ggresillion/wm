package manager

import (
	"sync"
	"time"
)

type debounce struct {
	interval time.Duration
	mu       sync.Mutex
	timer    *time.Timer
	lastFn   func()
}

func newDebounce(interval time.Duration) *debounce {
	return &debounce{interval: interval}
}

func (d *debounce) Call(f func()) {
	d.mu.Lock()
	defer d.mu.Unlock()

	d.lastFn = f

	if d.timer != nil {
		d.timer.Stop()
	}

	d.timer = time.AfterFunc(d.interval, func() {
		d.mu.Lock()
		defer d.mu.Unlock()
		if d.lastFn != nil {
			d.lastFn()
			d.lastFn = nil
		}
	})
}
