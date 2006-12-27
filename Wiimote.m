//
//  Wiimote.m
//  Wiidi
//
//  Created by Jinx on 22/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Wiimote.h"


@implementation Wiimote

- (id) initWithDelegate:(id)del
{
	if ([self init]) 
	{
		[self setDelegate:del];
	}
	return self;
}

- (id) init
{
	if ([super init])
	{
		device = nil;
		delegate = nil;
		inquiry = nil;
		inChannel = nil;
		outChannel = nil;
		initialized = NO;
		nunchuckAvailable = NO;
		ledValues = 0;
		memset(&nunchuckData, 0, sizeof(NunchuckData));
		memset(&wiimoteData, 0, sizeof(WiimoteData));
		memset(&lastNunchuckData, 0, sizeof(NunchuckData));
		memset(&lastWiimoteData, 0, sizeof(WiimoteData));
		readerIdentifier = 0;
		
		[self calibrateDevices];
	}
	return self;
}

- (void) dealloc
{
	if ([self isConnected]) [self stopDevice];
	if (inquiry) [inquiry stop];
	[delegate release];
	[super dealloc];
}

- (void) calibrateDevices
{
	// Manually calibrate the remote for now (REFACTOR THIS)
	
	// Wiimote
	// Default values are: 
	//   => 0 force: 82 82 82
	//   => gravity: 9C 9C 9E 
	// - wiili.org
	wiimoteData.calibration[X]   = 135;
	wiimoteData.calibration[Y]   = 136;
	wiimoteData.calibration[Z]   = 132;
	wiimoteData.calibration[Gx]  = 164;
	wiimoteData.calibration[Gy]  = 164;
	wiimoteData.calibration[Gz]  = 160;
	wiimoteData.calibration[Gnx] = 108;
	wiimoteData.calibration[Gny] = 108;
	wiimoteData.calibration[Gnz] = 105;

	// Nunchuck
	// Default values are: 
	//   => 0 force: 7D 7A 7E
	//   => gravity: B0 AF B1 
	// - wiili.org
	nunchuckData.calibration[X]   = 95;
	nunchuckData.calibration[Y]   = 87;
	nunchuckData.calibration[Z]   = 92;
	nunchuckData.calibration[Gx]  = 175;
	nunchuckData.calibration[Gy]  = 191;
	nunchuckData.calibration[Gz]  = 191;
	nunchuckData.calibration[Gnx] = 8;
	nunchuckData.calibration[Gny] = 0;
	nunchuckData.calibration[Gnz] = 0;
	
	// Calibrate the joypad for nunchuck
	nunchuckData.joypadCalibration[X]	= 103;
	nunchuckData.joypadCalibration[Y]	= 108;
	nunchuckData.joypadCalibration[Z]   = 202;
	nunchuckData.joypadCalibration[Gx]  = 205;
	nunchuckData.joypadCalibration[Gy]  = 5;
	nunchuckData.joypadCalibration[Gz]  = 10;
}

- (void) transformRawDevicePositions
{
	int i;
	WiimoteData  *w = &wiimoteData;
	NunchuckData *n = &nunchuckData;

	// Fix some of the values
	// Wiimote X and Y axes is too sensitive at 0-1, treat 1 as 0
	if (w->rawForce[X] == wiimoteData.calibration[X] + 1) w->rawForce[X] -= 1;
	if (w->rawForce[Y] == wiimoteData.calibration[Y] + 1) w->rawForce[Y] -= 1;
	
	for (i = X; i < Z+1; i++) 
	{
		double comp = (double)(w->rawForce[i] - w->calibration[i]);
		double grav = (double)(comp >= 0 ? w->calibration[i+3] - w->calibration[i] 
										 : w->calibration[i]   - w->calibration[i+6]);
		w->force[i] =  comp / grav;
					  
		if (nunchuckAvailable) { // do the nunchuck
			comp = (double)(n->rawForce[i] - n->calibration[i]);
			grav = (double)(comp >= 0 ? n->calibration[i+3] - n->calibration[i] 
									  : n->calibration[i]   - n->calibration[i+6]);
			n->force[i] = comp / grav;
			
			// Also do the joypad, but not for Z
			if (i < Z) {
				comp = (double)(n->rawJoypad[i] - n->joypadCalibration[i]);
				grav = (double)(comp >= 0 ? n->joypadCalibration[i+2] - n->joypadCalibration[i] 
									      : n->joypadCalibration[i]   - n->joypadCalibration[i+4]);
				
				n->joypad[i] = comp / grav;
			}
		}
	}
	
	// Magnitudes
	w->magnitude = sqrt(w->force[X] * w->force[X] + w->force[Y] * 
						w->force[Y] + w->force[Z] * w->force[Z]);

	if (nunchuckAvailable)
	{
		n->magnitude = sqrt(n->force[X] * n->force[X] + n->force[Y] * 
							n->force[Y] + n->force[Z] * n->force[Z]);
	}
}

- (void) decryptNunchuckData:(Byte *)data
{
	int i;
	for (i = 0; i < 6; i ++)
	{
		if (i == 3) // Y-axis has special encoding (why?)
		{
			data[i] = (data[i] & 201) + 6 - (data[i] & 6) + 48 - (data[i] & 48) - 100;
		}
		else
		{
			data[i] = (data[i] & 232) + 7 - (data[i] & 7) + 16 - (data[i] & 16);
		}
	}
	
	// Button data is inverted except for bit 1
	data[5] = data[5] ^ 0x01;
}

- (bool) isConnected
{
	// Device exists, device is connected and both L2CAP channels are active (in/out)
	return (device && [device isConnected] && initialized);
}

- (bool)nunchuckAvailable
{
	return nunchuckAvailable;
}

- (void) connectDevice:(NSTimer *)timer
{
	if ([self isConnected] || inquiry) return;
	inquiry = [[IOBluetoothDeviceInquiry alloc] initWithDelegate:self];
	[inquiry start];

#ifdef DEBUG
	NSLog(@"Searching for device...");
#endif 
}

- (void) deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry*)sender device:(IOBluetoothDevice*)foundDevice
{
	if ([[foundDevice getName] isEqualToString:kWiimoteDeviceName]) 
	{
#ifdef DEBUG
		NSLog(@"Found Wii device, initializing...");
#endif

		// Found device, retain it in memory and end the search
		[self initializeDevice:foundDevice];
		[sender stop];
	}
}

- (void) deviceInquiryComplete:(IOBluetoothDeviceInquiry*)sender error:(IOReturn)error aborted:(BOOL)aborted
{
#ifdef DEBUG
	NSLog(@"Device inquiry completed.");
#endif

	[inquiry release];
	inquiry = nil;
}

- (void) l2capChannelData:(IOBluetoothL2CAPChannel*)l2capChannel data:(void *)packet length:(size_t)packetLength
{
	Byte *packetData = (Byte *)packet;
	Byte reportType = packetData[1];
	Byte *data = (Byte *)(packet + 2);
	int length = packetLength - 2;
	int i; // use this counter later
	
	switch (reportType)
	{
		case kExpansionPortReport:
		{
			if (data[2] & 2) // 0x02 bit is set when nunchuck connects
				[self enableNunchuck]; 
			else
				nunchuckAvailable = NO;

			[self registerForReport:kFullReport]; // Register for full report

			break;
		}
		case kReadDataReport:
		{
			if (readerIdentifier == kNunchuckReading)
			{
#ifdef DEBUG
				NSLog(@"Received nunchuck reading");
#endif 
				if (data[2] == 0xF0) // Nunchuck is available
					[self enableNunchuck]; 
				else 
					nunchuckAvailable = NO;
			}
			if (readerIdentifier == kWiimoteCalibrationReading) // NOT USED!
			{
				// Get calibration data
				// Data is segmented on the controller as:
				// X  Y  Z | Gx Gy Gz, "|" being an empty byte
				for (i = 0; i < 3; i++) wiimoteData.calibration[i]  = data[i];
				for (i = 4; i < 7; i++) wiimoteData.calibration[i-1] = data[i];
				
#ifdef DEBUG
				NSLog(@"Got calibration data: 0x=%d 0y=%d 0z=%d / Gx=%d Gy=%d Gz=%d",
						wiimoteData.calibration[X],	wiimoteData.calibration[Y], wiimoteData.calibration[Z],
						wiimoteData.calibration[Gx], wiimoteData.calibration[Gy], wiimoteData.calibration[Gz]);
#endif
			}
			break;
		}
		case kFullReport:
		{
			if (nunchuckAvailable) // Grab nunchuck info
			{
				// Decrypt nunchuck data
				[self decryptNunchuckData:(data+15)];

				// Set values
				for (i = 15; i < 17; i++) nunchuckData.rawJoypad[i-15] = data[i];
				for (i = 17; i < 20; i++) nunchuckData.rawForce[i-17]  = data[i];
				nunchuckData.buttonData = data[20]; 
			}
			
			// Do wiimote stuff
			wiimoteData.buttonData = ((UInt16)data[0] << 8) + data[1];
			for (i = 2; i < 5; i++) wiimoteData.rawForce[i-2] = data[i];
			
			[self transformRawDevicePositions];
			[self informDelegate];
			
			// Save last values
			memcpy(&lastNunchuckData, &nunchuckData, sizeof(NunchuckData));
			memcpy(&lastWiimoteData, &wiimoteData, sizeof(WiimoteData));
		
			break;
		}
	}

#ifdef DEBUG
	if (reportType != kFullReport)
	{
		int i;
		printf("READ DATA: (Report type = 0x%02X) ", reportType);
		for (i = 0; i < length; i++) {
			printf("0x%02X ", data[i]);
		}
		printf("\n");
	}
#endif

}

- (void)l2capChannelOpenComplete:(IOBluetoothL2CAPChannel*)l2capChannel status:(IOReturn)error
{
#ifdef DEBUG
		NSLog(@"Wiimote delegate triggered: l2capChannelOpenComplete");
#endif
	if (!initialized)
	{
#ifdef DEBUG
		NSLog(@"Initializing the Wiimote...");
#endif 
		initialized = YES;
		
		// Calibrate the remote
		//[self readDataFromAddress:0x16 length:9 identifier:kWiimoteCalibrationReading];

		// Get the nunchuck read value
		[self readDataFromAddress:0x04A40000 length:0x10 identifier:kNunchuckReading];
		
		[self registerForReport:kFullReport]; // Register for the full report
		[self setLED:1]; // Turn on only led 1
	}
}

- (void)l2capChannelClosed:(IOBluetoothL2CAPChannel*)l2capChannel
{
#ifdef DEBUG
	NSLog(@"Wiimote delegate triggered: l2capChannelClosed");
#endif
	[self stopDevice];
	[self connectDevice:nil];
}

- (void)l2capChannelReconfigured:(IOBluetoothL2CAPChannel*)l2capChannel
{
#ifdef DEBUG
	NSLog(@"Wiimote delegate triggered: l2capChannelReconfigured");
#endif
}

- (void)l2capChannelWriteComplete:(IOBluetoothL2CAPChannel*)l2capChannel refcon:(void*)refcon status:(IOReturn)error
{
#ifdef DEBUG
	NSLog(@"Wiimote delegate triggered: l2capChannelWriteComplete");
#endif
}

- (void)l2capChannelQueueSpaceAvailable:(IOBluetoothL2CAPChannel*)l2capChannel
{
#ifdef DEBUG
	NSLog(@"Wiimote delegate triggered: l2capChannelQueueSpaceAvailable");
#endif
}

- (void) sendLEDValues
{
	Byte msg[] = { ledValues << 4 };
	[self sendCommand:kLEDAndFeedback withData:msg length:sizeof(msg)];
}

- (void) setLED:(UInt8)number enabled:(BOOL)onOrOff
{
	UInt8 value = (UInt8)(1 << number);
	[self setLED:(ledValues + (onOrOff ? value : -value))];
}

- (void) setLED:(UInt8)newLEDValues
{
	ledValues = newLEDValues;
	[self sendLEDValues];
}

- (void) toggleLED:(UInt8)number
{
	[self setLED:(ledValues ^ (UInt8)pow(2, number))];
}

- (void) disableAllLEDs
{
	[self setLED:0x00];
}

- (void) enableAllLEDs
{
	[self setLED:0xF0];
}

- (bool) isLEDenabled:(UInt8)number
{
	return (ledValues & (UInt8)pow(2, number));
}

- (void) sendCommand:(WiimoteCommand)command withData:(void *)data length:(UInt16)length
{
	if (outChannel == nil) return;
	IOReturn retValue;
	
	// Build the message
	Byte *msg = (Byte *)malloc(length + 2);
	memset(msg, 0, length + 2);
	msg[0] = kBluetoothWrite;
	msg[1] = command;
	memcpy(msg + 2, data, length);
	
	// Send the message
	retValue = [outChannel writeSync:msg length:(length + 2)];
	
#ifdef DEBUG
	if (retValue != kIOReturnSuccess) NSLog(@"Message failed to send!");
	int i;
	printf("WROTE DATA: ");
	for (i = 0; i < length+2; i++) {
		printf("%02X ", msg[i]);
	}
	printf("\n");			
#endif 

	if (retValue != kIOReturnSuccess)
	{
		// Something is wrong with the connection, re-establish it
		[self stopDevice];
		[self connectDevice:nil];
	}

	free(msg); // free the data
}

/**
  * Not thread safe!
  */
- (void) readDataFromAddress:(UInt32)address length:(UInt16)length identifier:(UInt8)identifier
{
	readerIdentifier = identifier;
	WiimoteReadAddress addr;
	addr.address = htonl(address);
	addr.length = htons(length);
	[self sendCommand:kReadData withData:(void *)&addr length:6];
}

- (void) enableNunchuck
{
#ifdef DEBUG
	NSLog(@"Enabling nunchuck...");
#endif 

	Byte msg[] = {0x04, 0xA4, 0x00, 0x40, 0x09, 0x01, 0x00, 
				  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
				  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
	[self sendCommand:kWriteData withData:msg length:21];
	nunchuckAvailable = YES;
}

- (void) registerForReport:(WiimoteReport)type
{
#ifdef DEBUG
	NSLog(@"Registering for full motion report...");
#endif 

	Byte msg[] = {0x00, type};
	[self sendCommand:kReportType withData:msg length:2];
}

- (bool) initializeDevice:(IOBluetoothDevice*)foundDevice
{
	[self stopDevice];
	
	if ([foundDevice openConnection] != kIOReturnSuccess) 
	{
		NSLog(@"could not open the connection...");
		return NO;
	}
	
	if ([foundDevice performSDPQuery:nil] != kIOReturnSuccess)
	{
		NSLog(@"could not perform SDP Query...");
		return NO;
	}
	
	if ([foundDevice openL2CAPChannelSync:&outChannel withPSM:17 delegate:self] != kIOReturnSuccess)
	{
		NSLog(@"could not open L2CAP channel cchan");
		outChannel = nil;
		[foundDevice closeConnection];
		return NO;
	}	
	
	if ([foundDevice openL2CAPChannelSync:&inChannel withPSM:19 delegate:self] != kIOReturnSuccess){
		NSLog(@"could not open L2CAP channel ichan");
		inChannel = nil;
		[outChannel closeChannel];
		[foundDevice closeConnection];
		return NO;
	}
	
	// Retain the device in memory
	device = [foundDevice retain];
	[outChannel retain];
	[inChannel  retain];
	
	return YES;
}

- (void) stopDevice
{
	if (outChannel) 
	{
		[outChannel closeChannel];
		[outChannel release];
		outChannel = nil;
	}
	
	if (inChannel) 
	{
		[inChannel closeChannel];
		[inChannel release];
		inChannel = nil;
	}
	
	if (device)
	{
		[device closeConnection];;
		[device release];
		device = nil;
	}
	
	initialized = NO;
	nunchuckAvailable = NO;
}

- (void) informDelegate
{
	if (delegate == nil) return;
	
	[delegate wiimoteData:&wiimoteData lastData:&lastWiimoteData];
	
	if (nunchuckAvailable)
	{
		[delegate nunchuckData:&nunchuckData lastData:&lastNunchuckData];
	}
	
//	UInt8 *p = nunchuckData.rawForce;
//	NSLog(@"RAW NUNCHUCK x = %d \t y = %d \t z = %d", p[X], p[Y], p[Z]);
if (nunchuckData.magnitude >= 1) {
	//double *p = nunchuckData.force;
	//NSLog(@"NUNCHUCK x = %2.2f \t y = %2.2f \t z = %2.2f \t mag = %2.2f", p[X], p[Y], p[Z], nunchuckData.magnitude);
	}
}

- (id) delegate
{
	return delegate;
}

- (void) setDelegate:(id)newDelegate
{
	if ([newDelegate conformsToProtocol:@protocol(WiimoteDelegate)])
	{
		[delegate release];
		delegate = [newDelegate retain];
	}
	else
		[NSException raise:@"InvalidWiimoteDelegateException" 
					format:@"The delegate object does not conform to the WiimoteDelegate protocol"];
}

@end
