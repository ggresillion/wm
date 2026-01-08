#import "bindings.h"

bool setWindowFrame(int pid, double x, double y, double width, double height) {
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  if (!app)
    return false;
  CFArrayRef windows = NULL;
  if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute,
                                    (CFTypeRef *)&windows) != kAXErrorSuccess) {
    CFRelease(app);
    return false;
  }
  bool success = false;
  if (CFArrayGetCount(windows) > 0) {
    AXUIElementRef win = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);
    CGPoint pos = CGPointMake(x, y);
    CGSize size = CGSizeMake(width, height);
    AXValueRef posVal = AXValueCreate(kAXValueCGPointType, &pos);
    AXValueRef sizeVal = AXValueCreate(kAXValueCGSizeType, &size);

    // Set both attributes together
    CFStringRef attrs[2] = {kAXPositionAttribute, kAXSizeAttribute};
    CFTypeRef values[2] = {posVal, sizeVal};

    // Try multiple attributes at once first
    AXError err =
        AXUIElementSetAttributeValue(win, kAXPositionAttribute, posVal);
    if (err == kAXErrorSuccess) {
      err = AXUIElementSetAttributeValue(win, kAXSizeAttribute, sizeVal);
      success = (err == kAXErrorSuccess);
    }

    CFRelease(posVal);
    CFRelease(sizeVal);
  }
  CFRelease(windows);
  CFRelease(app);
  return success;
}

bool getWindowFrame(int pid, double *x, double *y, double *width,
                    double *height) {
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  if (!app)
    return false;

  CFArrayRef windows = NULL;
  if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute,
                                    (CFTypeRef *)&windows) != kAXErrorSuccess) {
    CFRelease(app);
    return false;
  }

  bool success = false;

  if (CFArrayGetCount(windows) > 0) {
    AXUIElementRef win = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);

    AXValueRef posVal = NULL;
    AXValueRef sizeVal = NULL;

    if (AXUIElementCopyAttributeValue(win, kAXPositionAttribute,
                                      (CFTypeRef *)&posVal) ==
            kAXErrorSuccess &&
        AXUIElementCopyAttributeValue(
            win, kAXSizeAttribute, (CFTypeRef *)&sizeVal) == kAXErrorSuccess) {

      CGPoint pos;
      CGSize size;

      AXValueGetValue(posVal, kAXValueCGPointType, &pos);
      AXValueGetValue(sizeVal, kAXValueCGSizeType, &size);

      *x = pos.x;
      *y = pos.y;
      *width = size.width;
      *height = size.height;

      success = true;
    }

    if (posVal)
      CFRelease(posVal);
    if (sizeVal)
      CFRelease(sizeVal);
  }

  CFRelease(windows);
  CFRelease(app);
  return success;
}

int hideWindow(int pid, bool hide) {
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  if (!app)
    return false;

  CFArrayRef windows = NULL;
  if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute,
                                    (CFTypeRef *)&windows) != kAXErrorSuccess) {
    CFRelease(app);
    return false;
  }

  if (CFArrayGetCount(windows) == 0) {
    CFRelease(windows);
    CFRelease(app);
    return false;
  }

  AXUIElementRef win = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);
  CFBooleanRef value = hide ? kCFBooleanTrue : kCFBooleanFalse;

  AXError err = AXUIElementSetAttributeValue(win, kAXHiddenAttribute, value);

  if (err != kAXErrorSuccess) {
    err = AXUIElementSetAttributeValue(win, kAXMinimizedAttribute, value);
  }

  CFRelease(windows);
  CFRelease(app);
  return err;
}
