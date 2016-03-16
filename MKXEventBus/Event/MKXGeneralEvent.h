//
//  MKXGeneralEvent.h
//  MKXEventBus
//
//  Created by MK on 16/3/8.
//  Copyright © 2016年 makeex. All rights reserved.
//

#import <MKXEventBus/MKXEvent.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  通用事件
 */
@interface MKXGeneralEvent : MKXEvent

/**
 *  事件名称
 */
@property (nonatomic, copy) NSString *name;

/**
 *  事件标记
 */
@property (nonatomic, assign) NSUInteger tag;

@end

NS_ASSUME_NONNULL_END
