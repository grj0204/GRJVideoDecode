//
//  DecodeH264.h
//  decodeTest
//
//  Created by joynices on 2018/5/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVSampleBufferDisplayLayer.h>
#import "VideoPacket.h"
#import <UIKit/UIKit.h>

@protocol DecodeH264Delegate <NSObject>

- (void)displayDecodedFrame:(CVImageBufferRef )imageBuffer;

- (void)displayDecodedSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)displayTimeInterval:(double)timeI;

- (void)displayFrameSize:(NSInteger)size;

- (void)displayImage:(UIImage *)image;

- (void)decodeBuffer:(uint8_t *)buffer bufferSize:(NSInteger)bufferSize;

- (void)displayPacket:(VideoPacket *)packet;


@end

@interface DecodeH264 : NSObject
@property (weak, nonatomic) id<DecodeH264Delegate> delegate;

-(BOOL)initH264Decoder;
-(void)decodeNalu:(VideoPacket *)vp;
- (VideoPacket *)deteachBuffer;
@end
