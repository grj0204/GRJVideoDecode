//
//  VideoPacket.h
//  decodeTest
//
//  Created by joynices on 2018/5/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoPacket : NSObject
@property uint8_t* buffer;
@property NSInteger size;

- (instancetype)initWithSize:(NSInteger)size;

@end
