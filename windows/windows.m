#import "bindings.h"
#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>

CFArrayRef copyWindowList(void) {
  return CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly |
                                        kCGWindowListExcludeDesktopElements,
                                    kCGNullWindowID);
}

int getWindowPID(CFDictionaryRef dict) {
  CFNumberRef num = CFDictionaryGetValue(dict, kCGWindowOwnerPID);
  int pid = 0;
  if (num)
    CFNumberGetValue(num, kCFNumberIntType, &pid);
  return pid;
}

uint32_t getWindowID(CFDictionaryRef dict) {
  CFNumberRef num = CFDictionaryGetValue(dict, kCGWindowNumber);
  uint32_t id = 0;
  if (num)
    CFNumberGetValue(num, kCFNumberIntType, &id);
  return id;
}

CFStringRef getWindowTitle(CFDictionaryRef dict) {
  return CFDictionaryGetValue(dict, kCGWindowName);
}

CFStringRef getWindowOwner(CFDictionaryRef dict) {
  return CFDictionaryGetValue(dict, kCGWindowOwnerName);
}
