#import "window_monitor.h"
#import <string.h>

// ============================================================
// Configuration - Edit these lists to change what you monitor
// ============================================================

// Events to monitor at the APPLICATION level
static CFStringRef APP_EVENTS[] = {
    kAXFocusedUIElementChangedNotification,
    kAXApplicationActivatedNotification,
    kAXApplicationDeactivatedNotification,
    kAXCreatedNotification,
};
static const int APP_EVENTS_COUNT = 4;

// Events to monitor at the WINDOW level
static CFStringRef WINDOW_EVENTS[] = {
    kAXUIElementDestroyedNotification,
    kAXResizedNotification,
    kAXMovedNotification,
};
static const int WINDOW_EVENTS_COUNT = 3;

// ============================================================
// Storage
// ============================================================

static NSMutableDictionary *observedWindows = nil;
static NSMutableDictionary *observedApps = nil;
static dispatch_queue_t observerQueue = nil;
static id workspaceObserver = nil;

// ============================================================
// Helper: Get window information
// ============================================================

static void getWindowInfo(AXUIElementRef windowRef, int *windowID, pid_t *pid,
                          NSString **title, int *x, int *y, int *width,
                          int *height) {
  *windowID = (int)(uintptr_t)windowRef;

  if (AXUIElementGetPid(windowRef, pid) != kAXErrorSuccess) {
    *pid = -1;
  }

  CFTypeRef titleRef = NULL;
  if (AXUIElementCopyAttributeValue(windowRef, kAXTitleAttribute, &titleRef) ==
          kAXErrorSuccess &&
      titleRef) {
    *title = [NSString stringWithString:(__bridge NSString *)titleRef];
    CFRelease(titleRef);
  } else {
    *title = @"";
  }

  CFTypeRef posRef = NULL;
  if (AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, &posRef) ==
          kAXErrorSuccess &&
      posRef) {
    CGPoint pos;
    AXValueGetValue(posRef, kAXValueCGPointType, &pos);
    *x = (int)pos.x;
    *y = (int)pos.y;
    CFRelease(posRef);
  }

  CFTypeRef sizeRef = NULL;
  if (AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, &sizeRef) ==
          kAXErrorSuccess &&
      sizeRef) {
    CGSize size;
    AXValueGetValue(sizeRef, kAXValueCGSizeType, &size);
    *width = (int)size.width;
    *height = (int)size.height;
    CFRelease(sizeRef);
  }
}

// ============================================================
// Helper: Find window from focused element
// ============================================================

static AXUIElementRef getWindowFromElement(AXUIElementRef element) {
  AXUIElementRef windowElement = NULL;
  CFTypeRef windowRef = NULL;

  // Try to get the window attribute
  if (AXUIElementCopyAttributeValue(element, kAXWindowAttribute, &windowRef) ==
          kAXErrorSuccess &&
      windowRef) {
    windowElement = (AXUIElementRef)windowRef;
  } else {
    // Check if the element itself is a window
    CFTypeRef roleRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &roleRef) ==
            kAXErrorSuccess &&
        roleRef) {
      NSString *role = (__bridge NSString *)roleRef;
      if ([role isEqualToString:(__bridge NSString *)kAXWindowRole]) {
        windowElement = element;
        CFRetain(windowElement);
      }
      CFRelease(roleRef);
    }
  }

  return windowElement;
}

// ============================================================
// Callbacks
// ============================================================

// Callback for window-level events
static void windowEventCallback(AXObserverRef observer, AXUIElementRef element,
                                CFStringRef notification, void *refcon) {
  NSRunningApplication *app = (__bridge NSRunningApplication *)refcon;
  NSString *eventName = (__bridge NSString *)notification;

  int windowID, x = 0, y = 0, width = 0, height = 0;
  NSString *title;
  pid_t pid;

  getWindowInfo(element, &windowID, &pid, &title, &x, &y, &width, &height);

  char *appName = strdup(app.localizedName.UTF8String);
  char *titleStr = strdup(title.UTF8String);
  char *eventStr = strdup(eventName.UTF8String);

  goWindowEventCallback(eventStr, windowID, pid, appName, titleStr, x, y, width,
                        height);

  // Clean up if window was destroyed
  if ([eventName isEqualToString:(__bridge NSString *)
                                     kAXUIElementDestroyedNotification]) {
    NSString *key =
        [NSString stringWithFormat:@"%d-%p", app.processIdentifier, element];
    NSValue *observerValue = observedWindows[key];
    if (observerValue) {
      AXObserverRef obs = (AXObserverRef)[observerValue pointerValue];
      for (int i = 0; i < WINDOW_EVENTS_COUNT; i++) {
        AXObserverRemoveNotification(obs, element, WINDOW_EVENTS[i]);
      }
      CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs),
                            kCFRunLoopDefaultMode);
      CFRelease(obs);
      CFRelease(refcon);
      [observedWindows removeObjectForKey:key];
    }
  }
}

// Callback for app-level events
static void appEventCallback(AXObserverRef observer, AXUIElementRef element,
                             CFStringRef notification, void *refcon) {
  NSRunningApplication *app = (__bridge NSRunningApplication *)refcon;
  NSString *eventName = (__bridge NSString *)notification;

  // Handle focused element change - need to find the window
  if ([eventName isEqualToString:(__bridge NSString *)
                                     kAXFocusedUIElementChangedNotification]) {
    CFTypeRef focusedElementRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute,
                                      &focusedElementRef) == kAXErrorSuccess &&
        focusedElementRef) {
      AXUIElementRef focusedElement = (AXUIElementRef)focusedElementRef;
      AXUIElementRef windowElement = getWindowFromElement(focusedElement);

      if (windowElement) {
        int windowID, x = 0, y = 0, width = 0, height = 0;
        NSString *title;
        pid_t pid;

        getWindowInfo(windowElement, &windowID, &pid, &title, &x, &y, &width,
                      &height);

        char *appName = strdup(app.localizedName.UTF8String);
        char *titleStr = strdup(title.UTF8String);
        char *eventStr = strdup(eventName.UTF8String);

        goWindowEventCallback(eventStr, windowID, pid, appName, titleStr, x, y,
                              width, height);

        CFRelease(windowElement);
      }
      CFRelease(focusedElementRef);
    }
    return;
  }

  // Handle window creation
  if ([eventName isEqualToString:(__bridge NSString *)kAXCreatedNotification]) {
    CFTypeRef roleRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &roleRef) ==
            kAXErrorSuccess &&
        roleRef) {
      NSString *role = (__bridge NSString *)roleRef;
      if ([role isEqualToString:(__bridge NSString *)kAXWindowRole]) {
        // This is handled by observeWindow function below
        NSString *key = [NSString
            stringWithFormat:@"%d-%p", app.processIdentifier, element];
        if (!observedWindows[key]) {
          // Create window observer
          AXObserverRef windowObserver = NULL;
          if (AXObserverCreate(app.processIdentifier, windowEventCallback,
                               &windowObserver) == kAXErrorSuccess) {
            void *context = CFBridgingRetain(app);

            for (int i = 0; i < WINDOW_EVENTS_COUNT; i++) {
              AXObserverAddNotification(windowObserver, element,
                                        WINDOW_EVENTS[i], context);
            }

            CFRunLoopAddSource(CFRunLoopGetMain(),
                               AXObserverGetRunLoopSource(windowObserver),
                               kCFRunLoopDefaultMode);

            observedWindows[key] = [NSValue valueWithPointer:windowObserver];

            // Send created event
            int windowID, x = 0, y = 0, width = 0, height = 0;
            NSString *title;
            pid_t pid;
            getWindowInfo(element, &windowID, &pid, &title, &x, &y, &width,
                          &height);

            char *appName = strdup(app.localizedName.UTF8String);
            char *titleStr = strdup(title.UTF8String);
            char *eventStr = strdup(eventName.UTF8String);

            goWindowEventCallback(eventStr, windowID, pid, appName, titleStr, x,
                                  y, width, height);
          }
        }
      }
      CFRelease(roleRef);
    }
    return;
  }

  // For other app events (activated, deactivated, etc.)
  char *appName = strdup(app.localizedName.UTF8String);
  char *eventStr = strdup(eventName.UTF8String);

  // Use -1 for windowID when it's an app-level event without a specific window
  goWindowEventCallback(eventStr, -1, app.processIdentifier, appName, "", 0, 0,
                        0, 0);
}

// ============================================================
// Observe a single window
// ============================================================

static void observeWindow(AXUIElementRef windowRef, NSRunningApplication *app) {
  NSString *key =
      [NSString stringWithFormat:@"%d-%p", app.processIdentifier, windowRef];

  if (observedWindows[key]) {
    return; // Already observing
  }

  AXObserverRef observer = NULL;
  if (AXObserverCreate(app.processIdentifier, windowEventCallback, &observer) !=
      kAXErrorSuccess) {
    return;
  }

  void *context = CFBridgingRetain(app);

  // Add all window event notifications
  for (int i = 0; i < WINDOW_EVENTS_COUNT; i++) {
    AXObserverAddNotification(observer, windowRef, WINDOW_EVENTS[i], context);
  }

  CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer),
                     kCFRunLoopDefaultMode);

  observedWindows[key] = [NSValue valueWithPointer:observer];

  // Send created event for existing window
  int windowID, x = 0, y = 0, width = 0, height = 0;
  NSString *title;
  pid_t pid;
  getWindowInfo(windowRef, &windowID, &pid, &title, &x, &y, &width, &height);

  // ignore if the window has no title (hidden)
  if (title.length == 0) {
    return;
  }

  // NSLog(@"app = %s", app.localizedName.UTF8String);
  // NSLog(@"pid = %d", pid);
  // NSLog(@"windowID = %d", windowID);
  // NSLog(@"title = %s", title.UTF8String);
  // NSLog(@"x = %d", x);
  // NSLog(@"y = %d", y);
  // NSLog(@"width = %d", width);
  // NSLog(@"height = %d", height);

  char *appName = strdup(app.localizedName.UTF8String);
  char *titleStr = strdup(title.UTF8String);
  char *eventStr = strdup("AXCreated");

  goWindowEventCallback(eventStr, windowID, pid, appName, titleStr, x, y, width,
                        height);
}

// ============================================================
// Observe a single application
// ============================================================

static void observeApplication(NSRunningApplication *app) {
  NSNumber *pidKey = @(app.processIdentifier);

  // Set up app-level observer if not already done
  if (!observedApps[pidKey]) {
    AXUIElementRef appRef = AXUIElementCreateApplication(app.processIdentifier);
    if (!appRef)
      return;

    AXObserverRef appObserver = NULL;
    if (AXObserverCreate(app.processIdentifier, appEventCallback,
                         &appObserver) != kAXErrorSuccess) {
      CFRelease(appRef);
      return;
    }

    void *context = CFBridgingRetain(app);

    // Add all app event notifications
    for (int i = 0; i < APP_EVENTS_COUNT; i++) {
      AXObserverAddNotification(appObserver, appRef, APP_EVENTS[i], context);
    }

    CFRunLoopAddSource(CFRunLoopGetMain(),
                       AXObserverGetRunLoopSource(appObserver),
                       kCFRunLoopDefaultMode);

    NSMutableDictionary *appData = [NSMutableDictionary dictionary];
    appData[@"observer"] = [NSValue valueWithPointer:appObserver];
    appData[@"appElement"] = [NSValue valueWithPointer:appRef];
    appData[@"context"] = [NSValue valueWithPointer:context];

    observedApps[pidKey] = appData;
  }

  // Observe existing windows
  AXUIElementRef appRef = AXUIElementCreateApplication(app.processIdentifier);
  if (!appRef)
    return;

  CFTypeRef windowsRef = NULL;
  if (AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, &windowsRef) ==
      kAXErrorSuccess) {
    CFArrayRef windows = (CFArrayRef)windowsRef;
    CFIndex count = CFArrayGetCount(windows);

    for (CFIndex i = 0; i < count; i++) {
      AXUIElementRef window =
          (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
      observeWindow(window, app);
    }

    CFRelease(windowsRef);
  }

  CFRelease(appRef);
}

// ============================================================
// Workspace notification handlers
// ============================================================

static void handleAppActivated(NSNotification *notification) {
  NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
  dispatch_async(observerQueue, ^{
    observeApplication(app);
  });
}

static void handleAppTerminated(NSNotification *notification) {
  NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];

  dispatch_async(observerQueue, ^{
    NSNumber *pidKey = @(app.processIdentifier);
    NSDictionary *appData = observedApps[pidKey];

    if (appData) {
      AXObserverRef observer =
          (AXObserverRef)[appData[@"observer"] pointerValue];
      AXUIElementRef appElement =
          (AXUIElementRef)[appData[@"appElement"] pointerValue];
      void *context = (void *)[appData[@"context"] pointerValue];

      for (int i = 0; i < APP_EVENTS_COUNT; i++) {
        AXObserverRemoveNotification(observer, appElement, APP_EVENTS[i]);
      }

      CFRunLoopRemoveSource(CFRunLoopGetMain(),
                            AXObserverGetRunLoopSource(observer),
                            kCFRunLoopDefaultMode);

      CFRelease(observer);
      CFRelease(appElement);
      CFRelease(context);

      [observedApps removeObjectForKey:pidKey];
    }

    // Clean up windows for this app
    NSMutableArray *keysToRemove = [NSMutableArray array];
    NSString *pidPrefix =
        [NSString stringWithFormat:@"%d-", app.processIdentifier];

    for (NSString *key in observedWindows) {
      if ([key hasPrefix:pidPrefix]) {
        [keysToRemove addObject:key];
      }
    }

    for (NSString *key in keysToRemove) {
      NSValue *observerValue = observedWindows[key];
      if (observerValue) {
        AXObserverRef obs = (AXObserverRef)[observerValue pointerValue];
        CFRunLoopRemoveSource(CFRunLoopGetMain(),
                              AXObserverGetRunLoopSource(obs),
                              kCFRunLoopDefaultMode);
        CFRelease(obs);
      }
      [observedWindows removeObjectForKey:key];
    }
  });
}

// ============================================================
// Public API
// ============================================================

int startWindowObserver(void) {
  @autoreleasepool {
    // Check accessibility permissions
    NSDictionary *opts = @{(__bridge id)kAXTrustedCheckOptionPrompt : @YES};
    if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts)) {
      return -1;
    }

    // Initialize storage
    observedWindows = [[NSMutableDictionary alloc] init];
    observedApps = [[NSMutableDictionary alloc] init];
    observerQueue =
        dispatch_queue_create("com.windowmonitor.queue", DISPATCH_QUEUE_SERIAL);

    // Set up workspace notifications
    NSNotificationCenter *center =
        [[NSWorkspace sharedWorkspace] notificationCenter];

    workspaceObserver = [[NSObject alloc] init];

    [center addObserverForName:NSWorkspaceDidActivateApplicationNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                      handleAppActivated(note);
                    }];

    [center addObserverForName:NSWorkspaceDidTerminateApplicationNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                      handleAppTerminated(note);
                    }];

    // Observe all currently running applications
    for (NSRunningApplication *app in
         [[NSWorkspace sharedWorkspace] runningApplications]) {
      if (app.activationPolicy == NSApplicationActivationPolicyRegular) {
        observeApplication(app);
      }
    }

    return 0;
  }
}

void stopWindowObserver(void) {
  @autoreleasepool {
    // Remove workspace notifications
    NSNotificationCenter *center =
        [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:workspaceObserver];
    [workspaceObserver release];
    workspaceObserver = nil;

    // Clean up all app observers
    for (NSDictionary *appData in [observedApps allValues]) {
      AXObserverRef observer =
          (AXObserverRef)[appData[@"observer"] pointerValue];
      AXUIElementRef appElement =
          (AXUIElementRef)[appData[@"appElement"] pointerValue];
      void *context = (void *)[appData[@"context"] pointerValue];

      CFRunLoopRemoveSource(CFRunLoopGetMain(),
                            AXObserverGetRunLoopSource(observer),
                            kCFRunLoopDefaultMode);

      CFRelease(observer);
      CFRelease(appElement);
      CFRelease(context);
    }

    // Clean up all window observers
    for (NSValue *observerValue in [observedWindows allValues]) {
      AXObserverRef observer = (AXObserverRef)[observerValue pointerValue];
      CFRunLoopRemoveSource(CFRunLoopGetMain(),
                            AXObserverGetRunLoopSource(observer),
                            kCFRunLoopDefaultMode);
      CFRelease(observer);
    }

    [observedWindows release];
    observedWindows = nil;

    [observedApps release];
    observedApps = nil;
  }
}
