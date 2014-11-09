//
//  SIEventBus.h
//  WodRandomizer
//
//  Created by malczak on 30/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SIEventBus;

@protocol SIEventBusListener <NSObject>

@required

-(void) eventBus:(SIEventBus*) eventBus didDispatchEvent:(id) event;

@optional

-(void) eventBus:(SIEventBus*) eventBus willDispatchEvent:(id) event;

@end

@protocol SIEventBus <NSObject>


@end
