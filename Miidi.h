//
//  Miidi.h
//  Wiidi
//
//  Created by Jinx on 23/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>
#import <CoreMIDIServer/CoreMIDIServer.h>
#import "Wiimote.h"

#define kMiidiInterfaceName CFSTR("Miidi Wii Remote Interface")
#define kMiidiPortName		CFSTR("Miidi_outPort")

typedef enum {
	kMIDIControlChangeEvent 	= 0xB0,
	kMIDIProgramChangeEvent 	= 0xC0,
	kMIDIBankMSBControlEvent 	= 0x00,
	kMIDIBankLSBControlEvent	= 0x20,
	kMIDINoteOnEvent 			= 0x90
} MIDIEvent;

@interface Miidi : NSObject <WiimoteDelegate> {
	MIDIClientRef		client;
	MIDIEndpointRef		endpoint;
	MIDIPortRef			port;

	Byte				__listHolder[1024];
	MIDIPacketList		*list;
	MIDIPacket			*packet;
}
- (void)  initializeMIDI;
- (void)  initializePacketList;
- (UInt8) MIDINoteForWiimoteButton:(WiimoteButtonType)button;
- (UInt8) MIDINoteForNunchuckButton:(NunchuckButtonType)button;
- (void)  MIDIEventAdd:(MIDIEvent)type note:(UInt8)note velocity:(UInt8)velocity;
- (void)  MIDIFlush;
@end
