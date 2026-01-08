package manager

import "fmt"

func dumpPositions(positions []Position) string {
	s := ""
	for _, pos := range positions {
		s += fmt.Sprintf("%s:%d(%d),", pos.Window.App, pos.Rect.X, pos.Rect.W)
	}

	return s
}

func ptr[T any](t T) *T {
	return &t
}
