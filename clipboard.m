// clipboard.m
#import <AppKit/AppKit.h>

const char* getClipboardText() {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
    if (text == nil) return NULL;
    return [text UTF8String];
}

void setClipboardText(const char* cstr) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSString *text = [NSString stringWithUTF8String:cstr];
    [pasteboard setString:text forType:NSPasteboardTypeString];
}
