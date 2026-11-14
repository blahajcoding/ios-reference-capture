#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import <fcntl.h>
#import <unistd.h>

static int output = -1;
static NSObject *lock;
static __thread BOOL recording;
static dispatch_source_t snapshotTimer;

static id Number(double value) {
	return isfinite(value) ? @(value) : NSNull.null;
}

static void Write(NSDictionary *record) {
	if (output < 0 || recording) return;
	recording = YES;
	@try {
		NSMutableDictionary *row = record.mutableCopy;
		row[@"mediaTime"] = Number(CACurrentMediaTime());
		row[@"epoch"] = Number(NSDate.date.timeIntervalSince1970);
		row[@"process"] = NSProcessInfo.processInfo.processName;
		NSData *data = [NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
		if (data) {
			NSMutableData *line = data.mutableCopy;
			[line appendBytes:"\n" length:1];
			@synchronized(lock) {
				const char *bytes = line.bytes;
				NSUInteger remaining = line.length;
				while (remaining) {
					ssize_t count = write(output, bytes, remaining);
					if (count <= 0) break;
					bytes += count;
					remaining -= count;
				}
			}
		}
	} @catch (NSException *exception) {
		NSLog(@"SpringBoardProbe: %@", exception);
	} @finally {
		recording = NO;
	}
}

static NSDictionary *Describe(CAAnimation *animation) {
	NSMutableDictionary *row = [@{
		@"class": NSStringFromClass(animation.class),
		@"duration": Number(animation.duration),
		@"beginTime": Number(animation.beginTime),
		@"speed": Number(animation.speed),
		@"timeOffset": Number(animation.timeOffset),
		@"repeatCount": Number(animation.repeatCount),
		@"autoreverses": @(animation.autoreverses)
	} mutableCopy];
	if ([animation isKindOfClass:CAPropertyAnimation.class]) {
		row[@"keyPath"] = ((CAPropertyAnimation *)animation).keyPath ?: @"";
		row[@"additive"] = @(((CAPropertyAnimation *)animation).additive);
		row[@"cumulative"] = @(((CAPropertyAnimation *)animation).cumulative);
	}
	if ([animation isKindOfClass:CABasicAnimation.class]) {
		CABasicAnimation *basic = (CABasicAnimation *)animation;
		row[@"from"] = [basic.fromValue description] ?: @"nil";
		row[@"to"] = [basic.toValue description] ?: @"nil";
	}
	if ([animation isKindOfClass:CASpringAnimation.class]) {
		CASpringAnimation *spring = (CASpringAnimation *)animation;
		row[@"mass"] = Number(spring.mass);
		row[@"stiffness"] = Number(spring.stiffness);
		row[@"damping"] = Number(spring.damping);
		row[@"initialVelocity"] = Number(spring.initialVelocity);
		row[@"settlingDuration"] = Number(spring.settlingDuration);
	}
	if (animation.timingFunction) {
		NSMutableArray *points = NSMutableArray.array;
		for (size_t index = 0; index < 4; index++) {
			float point[2];
			[animation.timingFunction getControlPointAtIndex:index values:point];
			[points addObject:@[Number(point[0]), Number(point[1])]];
		}
		row[@"timingFunction"] = points;
	}
	if ([animation isKindOfClass:CAAnimationGroup.class]) {
		NSMutableArray *children = NSMutableArray.array;
		for (CAAnimation *child in ((CAAnimationGroup *)animation).animations) {
			[children addObject:Describe(child)];
		}
		row[@"animations"] = children;
	}
	return row;
}

@interface CALayer (SpringBoardProbe)
- (void)sbprobe_addAnimation:(CAAnimation *)animation forKey:(NSString *)key;
@end

@implementation CALayer (SpringBoardProbe)
- (void)sbprobe_addAnimation:(CAAnimation *)animation forKey:(NSString *)key {
	[self sbprobe_addAnimation:animation forKey:key];
	if (!animation || recording) return;
	@try {
		Write(@{
			@"event": @"animation",
			@"layer": NSStringFromClass(self.class),
			@"delegate": self.delegate ? NSStringFromClass([self.delegate class]) : @"",
			@"key": key ?: @"",
			@"animation": Describe(animation)
		});
	} @catch (NSException *exception) {
		NSLog(@"SpringBoardProbe describe: %@", exception);
	}
}
@end

static NSArray *Rect(CGRect rect) {
	return @[Number(rect.origin.x), Number(rect.origin.y), Number(rect.size.width), Number(rect.size.height)];
}

static id Color(UIColor *color, UITraitCollection *traits) {
	if (!color) return NSNull.null;
	CGFloat r, g, b, a;
	if (![[color resolvedColorWithTraitCollection:traits] getRed:&r green:&g blue:&b alpha:&a]) return color.description;
	return @[Number(r), Number(g), Number(b), Number(a)];
}

static NSDictionary *View(UIView *view) {
	NSMutableDictionary *row = [@{
		@"class": NSStringFromClass(view.class),
		@"frameInWindow": Rect([view convertRect:view.bounds toView:view.window]),
		@"bounds": Rect(view.bounds),
		@"alpha": Number(view.alpha),
		@"hidden": @(view.hidden),
		@"cornerRadius": Number(view.layer.cornerRadius),
		@"clipsToBounds": @(view.clipsToBounds),
		@"backgroundColor": Color(view.backgroundColor, view.traitCollection),
		@"accessibilityIdentifier": view.accessibilityIdentifier ?: @"",
		@"accessibilityLabel": view.accessibilityLabel ?: @""
	} mutableCopy];
	if ([view isKindOfClass:UILabel.class]) {
		UILabel *label = (UILabel *)view;
		row[@"text"] = label.text ?: @"";
		row[@"font"] = @{@"name": label.font.fontName, @"size": Number(label.font.pointSize),
			@"lineHeight": Number(label.font.lineHeight)};
		row[@"textColor"] = Color(label.textColor, view.traitCollection);
	}
	if ([view isKindOfClass:UIScrollView.class]) {
		UIScrollView *scroll = (UIScrollView *)view;
		row[@"contentOffset"] = @[Number(scroll.contentOffset.x), Number(scroll.contentOffset.y)];
		row[@"contentSize"] = @[Number(scroll.contentSize.width), Number(scroll.contentSize.height)];
	}
	NSMutableArray *children = NSMutableArray.array;
	for (UIView *child in view.subviews) [children addObject:View(child)];
	row[@"children"] = children;
	return row;
}

static void StartSnapshots(void) {
	NSString *root = NSProcessInfo.processInfo.environment[@"SB_PROBE_ROOT"];
	if (!root) return;
	NSString *requestPath = [root stringByAppendingPathComponent:@"request.json"];
	__block NSString *lastLabel = nil;
	snapshotTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	dispatch_source_set_timer(snapshotTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 5, NSEC_PER_SEC / 20);
	dispatch_source_set_event_handler(snapshotTimer, ^{
		@try {
			NSData *request = [NSData dataWithContentsOfFile:requestPath];
			if (!request) return;
			NSDictionary *command = [NSJSONSerialization JSONObjectWithData:request options:0 error:nil];
			NSString *label = command[@"label"];
			if (!label || [label isEqualToString:lastLabel]) return;
			lastLabel = label;
			NSMutableArray *windows = NSMutableArray.array;
			for (UIWindow *window in UIApplication.sharedApplication.windows) {
				[windows addObject:View(window)];
			}
			NSDictionary *snapshot = @{@"label": label, @"systemVersion": UIDevice.currentDevice.systemVersion,
				@"process": NSProcessInfo.processInfo.processName, @"scale": Number(UIScreen.mainScreen.scale),
				@"screenBounds": Rect(UIScreen.mainScreen.bounds), @"epoch": Number(NSDate.date.timeIntervalSince1970),
				@"windows": windows};
			NSString *directory = [[root stringByAppendingPathComponent:@"views"]
				stringByAppendingPathComponent:NSProcessInfo.processInfo.processName];
			[NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
			NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
			[data writeToFile:[directory stringByAppendingPathComponent:[label stringByAppendingString:@".json"]] atomically:YES];
		} @catch (NSException *exception) {
			NSLog(@"SpringBoardProbe snapshot: %@", exception);
		}
	});
	dispatch_resume(snapshotTimer);
}

__attribute__((constructor)) static void Install(void) {
	@autoreleasepool {
		NSString *process = NSProcessInfo.processInfo.processName;
		if (![process isEqualToString:@"SpringBoard"] && ![process isEqualToString:@"Preferences"]) return;
		const char *path = getenv("SB_PROBE_OUTPUT");
		if (!path) return;
		output = open(path, O_WRONLY | O_CREAT | O_APPEND, 0600);
		if (output < 0) return;
		lock = NSObject.new;
		Method original = class_getInstanceMethod(CALayer.class, @selector(addAnimation:forKey:));
		Method replacement = class_getInstanceMethod(CALayer.class, @selector(sbprobe_addAnimation:forKey:));
		if (!original || !replacement) return;
		method_exchangeImplementations(original, replacement);
		Write(@{@"event": @"ready", @"pid": @(getpid()),
			@"process": NSProcessInfo.processInfo.processName,
			@"systemVersion": UIDevice.currentDevice.systemVersion});
		dispatch_async(dispatch_get_main_queue(), ^{ StartSnapshots(); });
	}
}
