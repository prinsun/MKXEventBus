//
//  MKXMergeableEvent.h
//  MKXEventBus
//
//  Created by MK on 16/3/2.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MKXEventBus/MKXEvent.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  可合并的事件，旨在高发出量时，合并事件通知
 */
@protocol MKXMergeableEvent <NSObject>

@optional

/**
 *  合并超时时间（默认 1 秒）
 *
 *  @return 超时时间
 */
+ (NSTimeInterval)mergeTimeout;

/**
 *  合并间隔事件（默认 0.25 秒）
 *
 *  @return 间隔事件
 */
+ (NSTimeInterval)mergeInterval;

@required

/**
 *  合并事件
 *
 *  @param event 要合并的时间
 *
 *  @return 是否合并成功
 */
- (BOOL)merge:(__kindof MKXEvent *)event;

@end

NS_ASSUME_NONNULL_END
