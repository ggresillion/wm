#import "bindings.h"
#include <AppKit/AppKit.h>

int focusWindow(int pid) {
  @autoreleasepool {
    NSRunningApplication *app =
        [NSRunningApplication runningApplicationWithProcessIdentifier:pid];

    if (!app)
      return -1;

    BOOL activated =
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps |
                                 NSApplicationActivateAllWindows];

    if (!activated)
      return -2;

    AXUIElementRef axApp = AXUIElementCreateApplication(pid);
    if (!axApp)
      return -3;

    CFArrayRef windows = NULL;
    if (AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute,
                                      (CFTypeRef *)&windows) !=
        kAXErrorSuccess) {
      CFRelease(axApp);
      return -4;
    }

    if (CFArrayGetCount(windows) == 0) {
      CFRelease(windows);
      CFRelease(axApp);
      return -5;
    }

    AXUIElementRef win = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);

    AXUIElementPerformAction(win, kAXRaiseAction);

    CFRelease(windows);
    CFRelease(axApp);

    return 0;
  }
}
