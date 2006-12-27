//
//  WiiGestures.h
//  Wiidi
//
//  Created by Jinx on 25/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Wiimote.h"

#define SIMILAR(a,b) ((a/b) >= 0.8 || (a/b) <= 1.25)

@interface WiiGestures : NSObject <WiimoteDelegate> {
	NSMutableArray *record;
	NSMutableArray *playback;
}

@end
