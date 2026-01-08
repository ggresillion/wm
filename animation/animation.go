package animation

import (
	"macwm/windows"
	"time"
)

type Easing func(float64) float64

func EaseInOut(t float64) float64 {
	return t * t * (3 - 2*t)
}

type Animation struct {
	Duration time.Duration
	Easing   Easing
}

func Lerp(a, b, t float64) float64 {
	return a + (b-a)*t
}

func AnimateWindow(win *windows.Window, to windows.Rect, anim Animation) error {
	from, err := win.GetFrame()
	if err != nil {
		return err
	}
	if equalPosition(from, to) {
		return nil
	}
	if anim.Easing == nil {
		anim.Easing = EaseInOut
	}

	startTime := time.Now()
	ticker := time.NewTicker(time.Second / 120) // Hz poll rate
	defer ticker.Stop()

	for {
		elapsed := time.Since(startTime)
		t := elapsed.Seconds() / anim.Duration.Seconds()

		if t >= 1.0 {
			return win.SetFrame(to)
		}

		t = anim.Easing(t)
		r := windows.Rect{
			X: Lerp(from.X, to.X, t),
			Y: Lerp(from.Y, to.Y, t),
			W: Lerp(from.W, to.W, t),
			H: Lerp(from.H, to.H, t),
		}

		_ = win.SetFrame(r)

		<-ticker.C
	}
}

func equalPosition(from, to windows.Rect) bool {
	return from.X == to.X && from.Y == to.Y && from.W == to.W && from.H == to.H
}
