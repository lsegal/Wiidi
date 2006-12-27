//
//  Wiimote.h
//  Wiidi
//
//  Created by Jinx on 22/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>
#import <IOBluetooth/objc/IOBluetoothL2CAPChannel.h>
#pragma pack(0)

@protocol WiimoteDelegate;

enum { X, Y, Z, Gx, Gy, Gz, Gnx, Gny, Gnz } Directions;

typedef enum {
	kLEDAndFeedback		= 0x11,
	kReportType			= 0x12,
	kIRSensorEnable		= 0x13,
	kSpeakerEnable		= 0x14,
	kControllerStatus	= 0x15,
	kWriteData			= 0x16,
	kReadData			= 0x17,
	kSpeakerData		= 0x18,
	kMuteSpeaker		= 0x19,
	kIRSensorEnable2	= 0x1A
} WiimoteCommand;

typedef enum {
	kInitializeReport	 = 0x00,
	kExpansionPortReport = 0x20,
	kReadDataReport		 = 0x21,
	kWriteDataReport	 = 0x22,
	kButtonOnlyReport	 = 0x30,
	kFullReport			 = 0x37
} WiimoteReport;

typedef enum {
	kNunchuckReading			= 0x1,
	kWiimoteCalibrationReading	= 0x2,
} WiimoteReadings;

enum {
	kZeroPointX = 0x00,
	kZeroPointY = 0x01,
	kZeroPointZ = 0x02,
	kGravPointX = 0x04,
	kGravPointY = 0x05,
	kGravPointZ = 0x06
} WiimoteCalibrationData;

typedef enum {
	kWiimoteTwoButton	= 0x0001,
	kWiimoteOneButton	= 0x0002,
	kWiimoteBButton		= 0x0004,
	kWiimoteAButton		= 0x0008,
	kWiimoteMinusButton	= 0x0010,
	kWiimoteHomeButton	= 0x0080,
	kWiimoteLeftButton	= 0x0100,
	kWiimoteRightButton	= 0x0200,
	kWiimoteDownButton	= 0x0400,
	kWiimoteUpButton	= 0x0800,
	kWiimotePlusButton	= 0x1000,
} WiimoteButtonType;

const UInt16 WiimoteButtons[] = {
	kWiimoteTwoButton,
	kWiimoteOneButton,
	kWiimoteBButton,
	kWiimoteAButton,
	kWiimoteMinusButton,
	kWiimoteHomeButton,
	kWiimoteLeftButton,
	kWiimoteRightButton,
	kWiimoteDownButton,	
	kWiimoteUpButton,	
	kWiimotePlusButton
};

typedef enum {
	kNunchuckCButton = 0x01,
	kNunchuckZButton = 0x02
} NunchuckButtonType;

const UInt8 NunchuckButtons[] = {
	kNunchuckCButton,
	kNunchuckZButton
};

typedef struct {
	UInt32	address;
	UInt16	length;
} WiimoteReadAddress;

typedef struct {
	UInt8  buttonData;
	UInt8  rawJoypad[2];
	UInt8  rawForce[3];
	UInt8  calibration[9];
	UInt8  joypadCalibration[6];

	double force[3];
	double joypad[2];
	double magnitude;
} NunchuckData;

typedef struct {
	UInt16 buttonData;
	UInt8  rawForce[3];
	UInt8  calibration[9];

	double force[3];
	double magnitude;
} WiimoteData;

#define kWiimoteDeviceName		@"Nintendo RVL-CNT-01"
#define kBluetoothWrite			0x52
#define kNunchukDecryptionValue 0x17

@interface Wiimote : NSObject {
	IOBluetoothDevice			*device;
	IOBluetoothDeviceInquiry	*inquiry;
	IOBluetoothL2CAPChannel		*inChannel;
	IOBluetoothL2CAPChannel		*outChannel;

	id		delegate;
	bool	nunchuckAvailable;
	UInt8	ledValues;
	UInt8	readerIdentifier;
	BOOL	initialized;

	NunchuckData	nunchuckData;
	NunchuckData	lastNunchuckData;
	WiimoteData		wiimoteData;
	WiimoteData		lastWiimoteData;
}
- (id) initWithDelegate:(id)del;
- (id) delegate;
- (void) setDelegate:(id)newDelegate;
- (void) informDelegate;

- (void) connectDevice:(NSTimer *)timer;
- (bool) isConnected;
- (bool) nunchuckAvailable;

- (void) setLED:(UInt8)number enabled:(BOOL)onOrOff;
- (void) toggleLED:(UInt8)number;
- (bool) isLEDenabled:(UInt8)number;
- (void) disableAllLEDs;
- (void) enableAllLEDs;

- (void) enableNunchuck;

- (bool) initializeDevice:(IOBluetoothDevice *)newDevice;
- (void) stopDevice;

- (void) setLED:(UInt8)newLEDValues;
- (void) sendLEDValues;

- (void) registerForReport:(WiimoteReport)type;
- (void) sendCommand:(WiimoteCommand)command withData:(void *)data length:(UInt16)length;
- (void) readDataFromAddress:(UInt32)address length:(UInt16)length identifier:(UInt8)identifier;

- (void) calibrateDevices;
- (void) transformRawDevicePositions;
@end

@protocol WiimoteDelegate
- (void) nunchuckData:(NunchuckData *)data lastData:(NunchuckData *)lastData;
- (void)  wiimoteData: (WiimoteData *)data lastData: (WiimoteData *)lastData;
@end