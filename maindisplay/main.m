//
//  main.m
//  maindisplay
//
//  Created by Damien DeVille on 12/15/14.
//  Copyright (c) 2014 Damien DeVille. All rights reserved.
//

#import <AppKit/AppKit.h>

static pid_t pid_for_frontmost_application(void) {
    return [[[NSWorkspace sharedWorkspace] frontmostApplication] processIdentifier];
}

static CFArrayRef CF_RETURNS_RETAINED windows_for_process(pid_t pid) {
    CFMutableArrayRef process_windows = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);

    CFArrayRef all_windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    for (CFIndex idx = 0; idx < CFArrayGetCount(all_windows); idx++) {
        CFDictionaryRef window_info = CFArrayGetValueAtIndex(all_windows, idx);

        int32_t window_process_pid = 0;
        CFNumberGetValue(CFDictionaryGetValue(window_info, kCGWindowOwnerPID), kCFNumberSInt32Type, &window_process_pid);

        if (window_process_pid == pid) {
            CFArrayAppendValue(process_windows, window_info);
        }
    }
    CFRelease(all_windows);

    return process_windows;
}

static CGDirectDisplayID display_id_for_window(CFDictionaryRef window_info) {
    CGRect window_bounds = CGRectZero;
    CGRectMakeWithDictionaryRepresentation(CFDictionaryGetValue(window_info, kCGWindowBounds), &window_bounds);

    CGDisplayCount display_count;
    CGDirectDisplayID displays[32];
    CGGetActiveDisplayList(32, displays, &display_count);

    CGDirectDisplayID display_id = 0;
    for (uint32_t idx = 0; idx < display_count; idx++) {
        CGDirectDisplayID current_display_id = displays[idx];
        CGRect intersection_rect = CGRectIntersection(window_bounds, CGDisplayBounds(current_display_id));
        if (!CGRectIsNull(intersection_rect)) {
            if (CGRectGetWidth(intersection_rect) != 0.0 && CGRectGetHeight(intersection_rect) != 0.0) {
                display_id = current_display_id;
                break;
            }
        }
    }

    return display_id;
}

static void write_frame_to_output(CGRect frame) {
    fprintf(stdout, "%f, %f, %f, %f\n", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
}

typedef enum {
    ArgumentMain = 0,
    ArgumentKey = 1,
} Argument;

/*
    Parameters:
        --main - retrieve the main display frame
        --key  - retrieve the frame of the display that has the frontmost window
 */
int main(int argc, const char **argv) {
    Argument argument = ArgumentMain;
    if (argc > 1) {
        if (strcmp(argv[1], "--main") == 0) {
            argument = ArgumentMain;
        } else if (strcmp(argv[1], "--key") == 0) {
            argument = ArgumentKey;
        } else {
            printf("Use maindisplay [--main] [--key]");
            return -1;
        }
    }

    if (argument == ArgumentMain) {
        CGRect main_display_frame = CGDisplayBounds(CGMainDisplayID());
        write_frame_to_output(main_display_frame);
        return 0;
    }

    pid_t current_process = pid_for_frontmost_application();
    CFArrayRef current_process_windows = windows_for_process(current_process);

    CGRect display_frame = CGRectZero;

    if (CFArrayGetCount(current_process_windows) != 0) {
        CFDictionaryRef current_process_main_window = CFArrayGetValueAtIndex(current_process_windows, 0);
        CGDirectDisplayID display_id = display_id_for_window(current_process_main_window);
        display_frame = CGDisplayBounds(display_id);
    }

    CFRelease(current_process_windows);

    write_frame_to_output(display_frame);
    return 0;
}
