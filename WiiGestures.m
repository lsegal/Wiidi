//
//  WiiGestures.m
//  Wiidi
//
//  Created by Jinx on 25/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "WiiGestures.h"


@implementation WiiGestures

- (id) init
{
	if ([super init])
	{
		playback = nil;
		record = nil;
	}
	return self;
}

- (bool) playbackMatchesRecording
{
	// First check that the sizes are close, define "close" as 80% similarity
//	double sizeCheck = (double)[playback count] / (double)[record count];
//	if ([playback count] < 10 || sizeCheck < 0.8 || sizeCheck > 1.2) return NO;
	
	// Check that 80% or more of the component vectors match in direction
	int rCount = [record count], pCount = [playback count], diff = rCount - pCount;
	int numMatch = 0, i = 0, total = (diff < 0 ? rCount : pCount);
	float p[3] = {0}, r[3] = {0};
	
	if (total == 0) return NO;
	
	
	for (i = 0; i < total; i++) 
	{
		int pIndex = i, rIndex = i;
		if (total == rCount) pIndex = (int)(((float)i/(float)total) * pCount);
		else				 rIndex = (int)(((float)i/(float)total) * rCount);

		NSArray *pArr = [playback objectAtIndex:pIndex];
		NSArray *rArr = [record   objectAtIndex:rIndex];
		float p[] = { p[X] + [[pArr objectAtIndex:X] floatValue], 
					  p[Y] + [[pArr objectAtIndex:Y] floatValue], 
					  p[Z] + [[pArr objectAtIndex:Z] floatValue] };
		float r[] = { r[X] + [[rArr objectAtIndex:X] floatValue], 
					  r[Y] + [[rArr objectAtIndex:Y] floatValue], 
					  r[Y] + [[rArr objectAtIndex:Z] floatValue] };
		float vp[] = { lp[X] - p[X], lp[Y] - p[Y], lp[Z] - p[Z] };
		float vr[] = { lr[X] - r[X], lr[Y] - r[Y], lr[Z] - r[Z] };
		
		float pp[] = { lvp[X] - vp[X], lvp[Y] - vp[Y], lvp[Z] - vp[Z] };
		float pr[] = { lvr[X] - vr[X], lvr[Y] - vr[Y], lvr[Z] - vr[Z] };
		
		if (i > 1) 
		{
			
			if (SIMILAR(pr[X], pp[X]) && SIMILAR(pr[Y], pp[Y]) && SIMILAR(pr[Z], pp[Z]))
			{
			NSLog(@"%2.2f <=> %2.2f \t %2.2f <=> %2.2f \t %2.2f <=> %2.2f (MATCH)", pp[X], pr[X], pp[Y], pr[Y], pp[Z], pr[Z]);
				numMatch++; 
				//NSLog(@"Match number %d (%2.2f <=> %2.2f)", numMatch, pRatioXY, rRatioXY);
			} 
			else 
				NSLog(@"%2.2f <=> %2.2f \t %2.2f <=> %2.2f \t %2.2f <=> %2.2f", pp[X], pr[X], pp[Y], pr[Y], pp[Z], pr[Z]);
		}
		
		// old values
		memcpy(lp, p, sizeof(float) * 3);
		memcpy(lr, r, sizeof(float) * 3);
		memcpy(lvp, vp, sizeof(float) * 3);
		memcpy(lvr, vr, sizeof(float) * 3);
	}
	
	if (numMatch / total >= 0.8) return YES;
	
	return NO;
}

- (void) wiimoteData:(WiimoteData *)data lastData:(WiimoteData *)lastData
{
	bool aButton = data->buttonData & kWiimoteAButton, lastAButton = lastData->buttonData & kWiimoteAButton;
	bool bButton = data->buttonData & kWiimoteBButton, lastBButton = lastData->buttonData & kWiimoteBButton;
	
	if (aButton && bButton) // RECORD
	{
		if (!lastAButton || !lastBButton) // START RECORD
		{
			NSLog(@"Start record");
			[record release];
			record = [[NSMutableArray alloc] init];
		}
		
		NSArray *arr = [NSArray arrayWithObjects:[NSNumber numberWithFloat:data->force[X]],
												 [NSNumber numberWithFloat:data->force[Y]],
												 [NSNumber numberWithFloat:data->force[Z]], nil];

		[record addObject:arr];
		return;
	}
	else if (lastAButton && lastBButton) // STOP RECORD
	{
		NSLog(@"Stop record");
		return;
	}
	
	if (bButton) // PLAYBACK
	{
		if (!lastBButton) // START PLAYBACK
		{
			NSLog(@"Start playback");
			[playback release];
			playback = [[NSMutableArray alloc] init];
		}
		NSArray *arr = [NSArray arrayWithObjects:[NSNumber numberWithFloat:data->force[X]],
												 [NSNumber numberWithFloat:data->force[Y]],
												 [NSNumber numberWithFloat:data->force[Z]], nil];

		[playback addObject:arr];
		return;
	}
	else if (lastBButton) // END PLAYBACK
	{
		NSLog(@"Stop playback");
		if ([self playbackMatchesRecording])
		{
			NSLog(@"MATCH!");
		}
		else
		{
			NSLog(@"No match");
		}
	}
}

- (void) nunchuckData:(NunchuckData *)data lastData:(NunchuckData *)lastData
{
}


@end
