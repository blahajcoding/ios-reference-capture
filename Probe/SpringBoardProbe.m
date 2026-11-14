#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import <fcntl.h>
#import <unistd.h>

static int output = -1;
static NSObject *lock;
static __thread BOOL recording;

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

__attribute__((constructor)) static void Install(void) {
	@autoreleasepool {
		if (![NSProcessInfo.processInfo.processName isEqualToString:@"SpringBoard"]) return;
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
	}
}
