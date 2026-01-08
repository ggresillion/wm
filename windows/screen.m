#import "bindings.h"

double screenWidth(void) {
  return CGDisplayBounds(CGMainDisplayID()).size.width;
}

double screenHeight(void) {
  return CGDisplayBounds(CGMainDisplayID()).size.height;
}
