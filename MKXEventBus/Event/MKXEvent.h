//
//  MKXEvent.h
//  MKXEventBus
//
//  Created by MK on 16/3/2.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  一个被分发的事件
 */
@interface MKXEvent : NSObject

/**
 *  事件唯一编号
 */
@property (nonatomic, assign, readonly) UInt64 eventId;

@end

NS_ASSUME_NONNULL_END
