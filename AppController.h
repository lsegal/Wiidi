/* AppController */

#import <Cocoa/Cocoa.h>
#import "Wiimote.h"
#import "Miidi.h"
#import "WiiGestures.h"

@interface AppController : NSObject <WiimoteDelegate>
{
    IBOutlet NSButton *nunchuckButton;
    IBOutlet NSButton *wiimoteButton;
	
	Wiimote *wiimote;
	Miidi *miidi;
	WiiGestures *gestures;
}
@end
