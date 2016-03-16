//
//  MKXEvent.m
//  MKXEventBus
//
//  Created by MK on 16/3/2.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import <libkern/OSAtomic.h>

#import "MKXEvent.h"

static int64_t sEventIdSeed = 0;

@implementation MKXEvent

- (instancetype)init {
    if (self = [super init]) {
        _eventId = OSAtomicIncrement64(&sEventIdSeed);
    }
    return self;
}

@end
