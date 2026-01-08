#include <ApplicationServices/ApplicationServices.h>
#include <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>

// Window list
CFArrayRef copyWindowList(void);
int getWindowPID(CFDictionaryRef dict);
uint32_t getWindowID(CFDictionaryRef dict);
CFStringRef getWindowTitle(CFDictionaryRef dict);
CFStringRef getWindowOwner(CFDictionaryRef dict);

// Move / Resize windows
bool setWindowFrame(int pid, double x, double y, double width, double height);
bool getWindowFrame(int pid, double *x, double *y, double *width,
                    double *height);
int hideWindow(int pid, bool hide);

// Focus window
int focusWindow(int pid);

double screenWidth(void);
double screenHeight(void);

void showFocusBorder(int pid, double thickness, double r, double g, double b,
                     double a);

int setWindowFrameFastPrivate(int pid, double x, double y, double width,
                              double height);
