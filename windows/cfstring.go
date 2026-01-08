package windows

/*
#include "bindings.h"
*/
import "C"
import "unsafe"

func CFStringToGo(cf C.CFStringRef) string {
	if cf == 0 {
		return ""
	}
	length := C.CFStringGetLength(cf)
	if length == 0 {
		return ""
	}
	max := C.CFStringGetMaximumSizeForEncoding(length, C.kCFStringEncodingUTF8)
	buf := make([]byte, max+1)
	if C.CFStringGetCString(cf, (*C.char)(unsafe.Pointer(&buf[0])), max+1, C.kCFStringEncodingUTF8) == 0 {
		return ""
	}
	return string(buf[:len(buf)-1])
}
