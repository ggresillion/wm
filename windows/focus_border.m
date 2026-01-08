#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

// Global border window (singleton)
NSWindow *borderWindow = nil;

void showFocusBorder(int pid, double thickness, double r, double g, double b, double a) {
    @autoreleasepool {
        AXUIElementRef axApp = AXUIElementCreateApplication(pid);
        if (!axApp) return;

        CFArrayRef windows = NULL;
        if (AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute, (CFTypeRef *)&windows) != kAXErrorSuccess) {
            CFRelease(axApp);
            return;
        }

        if (CFArrayGetCount(windows) == 0) {
            CFRelease(windows);
            CFRelease(axApp);
            return;
        }

        AXUIElementRef win = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);

        // Get window position and size
        CGPoint pos;
        CGSize size;
        AXValueRef posVal, sizeVal;

        if (AXUIElementCopyAttributeValue(win, kAXPositionAttribute, (CFTypeRef *)&posVal) != kAXErrorSuccess ||
            AXUIElementCopyAttributeValue(win, kAXSizeAttribute, (CFTypeRef *)&sizeVal) != kAXErrorSuccess) {
            if (posVal) CFRelease(posVal);
            if (sizeVal) CFRelease(sizeVal);
            CFRelease(windows);
            CFRelease(axApp);
            return;
        }

        AXValueGetValue(posVal, kAXValueCGPointType, &pos);
        AXValueGetValue(sizeVal, kAXValueCGSizeType, &size);
        CFRelease(posVal);
        CFRelease(sizeVal);
        CFRelease(windows);
        CFRelease(axApp);

        // Create border window if needed
        if (!borderWindow) {
            NSRect frame = NSMakeRect(pos.x, pos.y, size.width, size.height);
            borderWindow = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
            [borderWindow setLevel:NSStatusWindowLevel]; // topmost
            [borderWindow setOpaque:NO];
            [borderWindow setBackgroundColor:[NSColor clearColor]];
            [borderWindow setIgnoresMouseEvents:YES];
        }

        // Update border frame
        NSRect frame = NSMakeRect(pos.x, pos.y, size.width, size.height);
        [borderWindow setFrame:frame display:YES];

        // Draw border
        NSView *content = [borderWindow contentView];
        [content setWantsLayer:YES];
        content.layer.borderWidth = thickness;
        content.layer.borderColor = [[NSColor colorWithCalibratedRed:r green:g blue:b alpha:a] CGColor];

        [borderWindow orderFront:nil];
    }
}
