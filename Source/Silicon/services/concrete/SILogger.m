//
//  SILogger.m
//  WodRandomizer
//
//  Created by malczak on 30/08/14.
//  Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import "SILogger.h"

@interface SILogger () {
    SILoggerLevel level;
}

@end

@implementation SILogger

-(instancetype) setLogLevel:(SILoggerLevel) value
{
    level = value;
    return self;
}

-(instancetype) log:(NSString*) message withLevel:(SILoggerLevel) inLevel
{
    if(inLevel < level) {
        return self;
    }
    
    NSString *levelStr = nil;
    switch (inLevel) {
        case siLevelCustom:
            levelStr = @"CUSTOM";
            break;
        case siLevelDebug:
            levelStr = @"DEBUG";
            break;
        case siLevelInfo:
            levelStr = @"INFO";
            break;
        case siLevelNotice:
            levelStr = @"NOTICE";
            break;
        case siLevelWarning:
            levelStr = @"WARNING";
            break;
        case siLevelError:
            levelStr = @"ERROR";
            break;
        case siLevelAlert:
            levelStr = @"ALERT";
            break;
        case siLevelCritical:
            levelStr = @"CRITICAL";
            break;
    };
    
    NSLog(@"[%@] %@", levelStr, message);
    
    return self;
}

-(instancetype) debug:(NSString*) message
{
    return [self log:message withLevel:siLevelDebug];
}

-(instancetype) info:(NSString*) message
{
    return [self log:message withLevel:siLevelInfo];
}

-(instancetype) notice:(NSString*) message
{
    return [self log:message withLevel:siLevelNotice];
}

-(instancetype) warning:(NSString*) message
{
    return [self log:message withLevel:siLevelWarning];
}

-(instancetype) error:(NSString*) message
{
    return [self log:message withLevel:siLevelError];
}

-(instancetype) alert:(NSString*) message
{
    return [self log:message withLevel:siLevelAlert];
}

-(instancetype) critical:(NSString*) message
{
    return [self log:message withLevel:siLevelCritical];
}

@end
