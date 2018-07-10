//
//  FIFO.h
//  decodeTest
//
//  Created by joynices on 2018/3/7.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JNFIFO : NSObject

@property (nonatomic, assign) BOOL bDestroy;

+ (instancetype)sharedFIFO;

- (int)fifoRead:(uint8_t *)readBuf length:(int)length;

- (int)fifoWrite:(uint8_t *)writeBuf length:(int)length;

- (void)clearFIFO;

- (int)getActualSize;

@end
