#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <assert.h>

@interface NSObject (SimulatorOrientation)
+ (id)sharedServiceContextForDeveloperDir:(NSString *)directory error:(NSError **)error;
- (id)defaultDeviceSetWithError:(NSError **)error;
- (NSArray *)availableDevices;
- (NSUUID *)UDID;
- (mach_port_t)lookup:(NSString *)name error:(NSError **)error;
@end

static void Message(uint32_t *words, mach_port_t port, uint32_t orientation) {
	memset(words, 0, 112);
	words[0] = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
	words[1] = 108;
	words[2] = port;
	words[5] = 0x7b;
	words[6] = 50 | 0x20000;
	words[18] = 4;
	words[19] = orientation;
}

int main(int argc, const char **argv) {
	@autoreleasepool {
		uint32_t words[28];
		if (argc == 2 && strcmp(argv[1], "--self-test") == 0) {
			Message(words, 123, 3);
			assert(sizeof(words) == 112 && words[1] == 108 && words[2] == 123);
			assert(words[5] == 0x7b && words[6] == (50 | 0x20000));
			assert(words[18] == 4 && words[19] == 3 && words[27] == 0);
			return 0;
		}
		if (argc != 3 || (strcmp(argv[2], "1") != 0 && strcmp(argv[2], "3") != 0)) return 2;
		NSError *error = nil;
		NSBundle *framework = [NSBundle bundleWithPath:@"/Library/Developer/PrivateFrameworks/CoreSimulator.framework"];
		if (![framework loadAndReturnError:&error]) {
			NSLog(@"CoreSimulator load failed: %@", error);
			return 1;
		}
		id context = [NSClassFromString(@"SimServiceContext") sharedServiceContextForDeveloperDir:nil error:&error];
		id deviceSet = [context defaultDeviceSetWithError:&error];
		NSString *udid = [NSString stringWithUTF8String:argv[1]];
		for (id device in [deviceSet availableDevices]) {
			if (![[[device UDID] UUIDString] isEqualToString:udid]) continue;
			mach_port_t port = [device lookup:@"PurpleWorkspacePort" error:&error];
			if (!MACH_PORT_VALID(port)) break;
			// Send the device-orientation event used by Simulator.app, not an app-only geometry request.
			Message(words, port, (uint32_t)atoi(argv[2]));
			kern_return_t result = mach_msg_send((mach_msg_header_t *)words);
			mach_port_deallocate(mach_task_self(), port);
			if (result == KERN_SUCCESS) return 0;
			NSLog(@"Orientation send failed: %s", mach_error_string(result));
			return 1;
		}
		NSLog(@"Simulator orientation port unavailable for %@: %@", udid, error);
		return 1;
	}
}
