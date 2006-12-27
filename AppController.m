#import "AppController.h"

@implementation AppController

- (void)awakeFromNib
{
//	miidi = [[Miidi alloc] init];
//	[miidi initializeMIDI];


	gestures = [[WiiGestures alloc] init];

	wiimote = [[Wiimote alloc] initWithDelegate:self];

	// Start to search for the device and keep looking every 5 seconds
	[wiimote connectDevice:nil];
	[NSTimer scheduledTimerWithTimeInterval:5 
									 target:wiimote 
								   selector:@selector(connectDevice:) 
								   userInfo:nil
									repeats:YES];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
#ifdef DEBUG
	NSLog(@"Application is terminating! Clean up");
#endif
	[wiimote stopDevice];
	return NSTerminateNow;
}

- (void) wiimoteData:(WiimoteData *)data lastData:(WiimoteData *)lastData
{
	[gestures wiimoteData:data lastData:lastData];
}

- (void) nunchuckData:(NunchuckData *)data lastData:(NunchuckData *)lastData
{
	[gestures nunchuckData:data lastData:lastData];
}

@end
