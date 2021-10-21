//
//  BeatPluginWindow.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.5.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPluginWindow.h"

@interface BeatPluginWindow ()
@property (weak) BeatPluginParser *host;
@end

@implementation BeatPluginWindow 

-(instancetype)initWithHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(BeatPluginParser*)host {
	NSRect frame = NSMakeRect((NSScreen.mainScreen.frame.size.width - width) / 2, (NSScreen.mainScreen.frame.size.height - height) / 2, width, height);
	
	self = [super initWithContentRect:frame styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskResizable | NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	self.level = NSModalPanelWindowLevel;
	self.delegate = host;
	
	self.releasedWhenClosed = NO;
	
	_host = host;
	self.title = host.pluginName;

	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
	
	[config.userContentController addScriptMessageHandler:self.host name:@"sendData"];
	[config.userContentController addScriptMessageHandler:self.host name:@"call"];
	[config.userContentController addScriptMessageHandler:self.host name:@"callAndLog"];
	[config.userContentController addScriptMessageHandler:self.host name:@"log"];

	_webview = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, height) configuration:config];
	_webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

	[self setHTML:html];
	[self.contentView addSubview:_webview];
	
	return self;
}

+ (BeatPluginWindow*)withHTML:(NSString*)html width:(CGFloat)width height:(CGFloat)height host:(id)host {
	return [[BeatPluginWindow alloc] initWithHTML:html width:width height:height host:(BeatPluginParser*)host];
}

- (void)setTitle:(NSString *)title {
	[super setTitle:title];
}
- (void)setHTML:(NSString*)html {
	// Load template
	NSURL *templateURL = [NSBundle.mainBundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	[_webview loadHTMLString:template baseURL:nil];
}

- (void)runJS:(nonnull NSString *)js callback:(nullable JSValue *)callback {
	if (callback && !callback.isUndefined) {
		[_webview evaluateJavaScript:js completionHandler:^(id _Nullable data, NSError * _Nullable error) {
			// Make sure we are on the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				[callback callWithArguments:data];
			});
		}];
	} else {
		[self.webview evaluateJavaScript:js completionHandler:nil];
	}
}

- (void)focus {
	[self makeFirstResponder:self.contentView];
}

- (void)setPositionX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
	NSRect screen = self.screen.frame;
	// Don't allow moving the windows out of view
	if (x > screen.size.width) x = screen.size.width - 100;
	if (y > screen.size.height) x = screen.size.height - height;
	
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	
	NSRect frame = NSMakeRect(x, y, width, height);
	[self setFrame:frame display:YES];
}

- (NSRect)getFrame {
	//NSRect rect = self.frame;
	return self.frame;
}
- (NSSize)screenSize {
	return self.screen.frame.size;
	//return @[ @(self.screen.frame.size.width), @(self.screen.frame.size.height) ];
}
-(BOOL)canBecomeKeyWindow {
	return  YES;
}
-(void)cancelOperation:(id)sender {
	[super cancelOperation:sender];
}
-(void)close {
	[self.host closePluginWindow:self];
}
-(void)closeWindow {
	[super close];
}


@end
