//
//  VideoPacket.m
//  decodeTest
//
//  Created by joynices on 2018/5/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import "VideoPacket.h"

@implementation VideoPacket
- (instancetype)initWithSize:(NSInteger)size
{
    self = [super init];
    self.buffer = malloc(size);
    self.size = size;
    
    return self;
}

-(void)dealloc
{
    free(self.buffer);
}
@end
