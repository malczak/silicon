//
// Created by malczak on 22/06/14.
// Copyright (c) 2014 segfaultsoft. All rights reserved.
//

#import "UIViewController+Silicon.h"
#import "Silicon.h"


@implementation UIViewController (Silicon)

-(Silicon *) silicon {
    return [Silicon sharedInstance];
}

@end