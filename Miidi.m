//
//  Miidi.m
//  Wiidi
//
//  Created by Jinx on 23/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Miidi.h"


@implementation Miidi

- (void) initializeMIDI
{
	MIDIClientCreate(kMiidiInterfaceName, nil, nil, &client);
	MIDISourceCreate(client, kMiidiInterfaceName, &endpoint);
	MIDIOutputPortCreate(client, kMiidiPortName, &port);

	[self initializePacketList];
}

- (void) initializePacketList
{
	list = (MIDIPacketList *)__listHolder;
	list->numPackets = 0;
	packet = MIDIPacketListInit(list);
}

- (void) wiimoteData:(WiimoteData *)data lastData:(WiimoteData *)lastData
{
	int i;

	// Button data (there are currently 11 buttons)
	for (i = 0; i < 11; i++)
	{
		UInt8 button = WiimoteButtons[i];
		UInt8 note = [self MIDINoteForWiimoteButton:button];
		if (button & data->buttonData && !(button & lastData->buttonData))
		{
			[self MIDIEventAdd:(button == kWiimoteBButton ? kMIDIControlChangeEvent : kMIDINoteOnEvent) note:note velocity:127];
		}
		else if (button & lastData->buttonData && !(button & data->buttonData))
		{
			[self MIDIEventAdd:(button == kWiimoteBButton ? kMIDIControlChangeEvent : kMIDINoteOnEvent) note:note velocity:0];
		}
	}
	
	// Wiimote X-Y axis MIDI controlling
	// Only send it if A and B is pushed??
	if (data->buttonData & kWiimoteBButton && data->buttonData & kWiimoteAButton)
	{
		for (i = 0; i < 2; i++)
		{
			double *f = data->force;
			double Fc = f[Z] >= 0 ? f[X] : nearbyint(f[X]);
			UInt8 velocity = (UInt8)(Fc * 63) + 64;
			[self MIDIEventAdd:kMIDIControlChangeEvent note:i+1 velocity:velocity];
		}
	}
	
	if (data->magnitude > 2.2 && data->magnitude < lastData->magnitude && lastData->force[Z] > 1 && lastData->force[Y] > -0.5)
	{
		NSLog(@"Snare HIT!");
		[self MIDIEventAdd:kMIDINoteOnEvent note:62 velocity:(UInt8)((data->magnitude - 2.2) * 127 / 3)];
	}
	
	[self MIDIFlush];
}

- (void) nunchuckData:(NunchuckData *)data lastData:(NunchuckData *)lastData
{
	// Button data (there are currently 11 buttons)
	int i;
	for (i = 0; i < 2; i++)
	{
		UInt8 button = NunchuckButtons[i];
		UInt8 note = [self MIDINoteForNunchuckButton:button];
		if (button & data->buttonData && !(button & lastData->buttonData))
		{
			[self MIDIEventAdd:kMIDINoteOnEvent note:note velocity:127];
		}
		else if (button & lastData->buttonData && !(button & data->buttonData))
		{
			[self MIDIEventAdd:kMIDINoteOnEvent note:note velocity:0];
		}
	}	
	
	// Joypad
	for (i = X; i < Z; i++)
	{
		if (data->joypad[i] != lastData->joypad[i])
		{
			UInt8 velocity = data->joypad[i] * 64 + 63;
			[self MIDIEventAdd:kMIDIControlChangeEvent note:(i+100) velocity:velocity];
		}
	}
	
	if (data->magnitude >= 1 && data->magnitude < lastData->magnitude && lastData->force[Z] > 0.9)
	{
		NSLog(@"NUNCHUCK Snare HIT!");
		[self MIDIEventAdd:kMIDINoteOnEvent note:71 velocity:(UInt8)(abs(data->magnitude - 0.5) * 127)];
	}
	[self MIDIFlush];
}

- (void) MIDIEventAdd:(MIDIEvent)type note:(UInt8)note velocity:(UInt8)velocity
{
	UInt64 time = 0;
	if (velocity > 127) velocity = 127;
	Byte data[] = { type, note, velocity };
	list->numPackets++;
	packet = MIDIPacketListAdd(list, 1024, packet, time, 3, data);
}

- (void) MIDIFlush
{
	MIDIReceived(endpoint, list);
	[self initializePacketList];
}

- (UInt8) MIDINoteForWiimoteButton:(WiimoteButtonType)button
{
	switch (button)
	{
		case kWiimoteAButton:		return 74;
		case kWiimoteBButton:		return 73;
		case kWiimoteLeftButton:	return 76;
		case kWiimoteRightButton:	return 77;
		case kWiimoteUpButton:		return 78;
		case kWiimoteDownButton:	return 79;
		case kWiimoteTwoButton:		return 80;
		case kWiimoteOneButton:		return 81;
		case kWiimoteMinusButton:	return 82;
		case kWiimoteHomeButton:	return 83;
		case kWiimotePlusButton:	return 84;
	}
	return 0;
}

- (UInt8) MIDINoteForNunchuckButton:(NunchuckButtonType)button
{
	switch (button)
	{
		case kNunchuckZButton:	return 72;
		case kNunchuckCButton:	return 60;
	}
	return 0;
}

@end
