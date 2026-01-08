#ifndef WINDOW_MONITOR_H
#define WINDOW_MONITOR_H

#import <Cocoa/Cocoa.h>
#include <sys/types.h>

// Start monitoring window events for all applications
// Returns 0 on success, -1 if accessibility permissions are not granted
int startWindowObserver(void);

// Stop monitoring and clean up all observers
void stopWindowObserver(void);

// Callback function that must be implemented in Go
// eventName: The accessibility notification name (e.g., "AXCreated", "AXMoved")
// windowID: Unique identifier for the window
// pid: Process ID of the application
// appName: Name of the application (must be freed by caller)
// title: Window title (must be freed by caller)
// x, y: Window position
// width, height: Window dimensions
extern void goWindowEventCallback(char *eventName, int windowID, pid_t pid,
                                  char *appName, char *title, int x, int y,
                                  int width, int height);

#endif // WINDOW_MONITOR_H
