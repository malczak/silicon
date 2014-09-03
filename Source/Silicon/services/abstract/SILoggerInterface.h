//
//  SILoggerInterface.h
//  WodRandomizer
//
//  Created by malczak on 30/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SILoggerLevel) {
    siLevelCustom,
    siLevelDebug,
    siLevelInfo,
    siLevelNotice,
    siLevelWarning,
    siLevelError,
    siLevelAlert,
    siLevelCritical
};

@protocol SILoggerInterface <NSObject>

@required

-(instancetype) setLogLevel:(SILoggerLevel) level;

-(instancetype) log:(NSString*) message withLevel:(SILoggerLevel) level;

-(instancetype) debug:(NSString*) message;

-(instancetype) info:(NSString*) message;

-(instancetype) notice:(NSString*) message;

-(instancetype) warning:(NSString*) message;

-(instancetype) error:(NSString*) message;

-(instancetype) alert:(NSString*) message;

-(instancetype) critical:(NSString*) message;

@end
