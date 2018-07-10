//
//  DecodeH264.m
//  decodeTest
//
//  Created by joynices on 2018/5/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import "DecodeH264.h"
#import "JNFIFO.h"

const uint8_t KStartCode[4] = {0, 0, 0, 1};

@interface DecodeH264 ()
{
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    
    uint8_t *_buffer;
    NSInteger _bufferSize;
    NSInteger _bufferCap;
    NSDate *startDate;
    NSDate *endDate;
}
@end

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
//    CIImage *cilmage = [CIImage imageWithCVPixelBuffer:*outputPixelBuffer];
//    UIImage *uiImage = [UIImage imageWithCIImage:cilmage];
//    DecodeH264 *decoder = (__bridge DecodeH264 *)decompressionOutputRefCon;
//    if (decoder.delegate != nil) {
////        [decoder.delegate displayDecodedFrame:pixelBuffer];
//        [decoder.delegate displayImage:uiImage];
//    }
    
}

@implementation DecodeH264

- (instancetype)init {
    if (self = [super init]) {
        _bufferSize = 0;
        _bufferCap = 4 * 1024 * 1024;
        _buffer = malloc(_bufferCap);
    }
    return self;
}

-(BOOL)initH264Decoder {
    if(_deocderSession) {
        return YES;
    }
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey, kCVPixelBufferOpenGLCompatibilityKey};
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) , CFNumberCreate(NULL, kCFNumberSInt32Type, kCFBooleanTrue) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);

        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;

        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &_deocderSession);
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:20]);
        VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);

        CFRelease(attrs);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
    }
    
    return YES;
}



-(CVPixelBufferRef)decode:(VideoPacket *)vp {
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)vp.buffer, vp.size,
                                                          kCFAllocatorNull,
                                                          NULL, 0, vp.size,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {vp.size};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);

        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
            }
   
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    return outputPixelBuffer;
}


- (void)decodeNalu:(VideoPacket *)vp {
    NSDate *sta = [NSDate date];
    startDate = [NSDate date];
    CVPixelBufferRef pixelBuffer = NULL;
    uint32_t nalSize = (uint32_t)(vp.size - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    vp.buffer[0] = *(pNalSize + 3);
    vp.buffer[1] = *(pNalSize + 2);
    vp.buffer[2] = *(pNalSize + 1);
    vp.buffer[3] = *(pNalSize);
    
    int nalType = vp.buffer[4] & 0x1F;
    switch (nalType) {
        case 0x05:
        {
            
            if([self initH264Decoder]) {
                pixelBuffer = [self decode:vp];
            }
        }
            break;
        case 0x07:
        {
            
            _spsSize = vp.size - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, vp.buffer + 4, _spsSize);
        }
            break;
        case 0x08:
        {
            
            _ppsSize = vp.size - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, vp.buffer + 4, _ppsSize);
        }
            break;
            
        default:
        {
            
            if ([self initH264Decoder]) {
                pixelBuffer = [self decode:vp];
            }
            
        }
            break;
    }

        if (pixelBuffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(displayDecodedFrame:)]) {
                    [self.delegate displayDecodedFrame:pixelBuffer];
                }
            });

        }
    

    
}

- (VideoPacket *)deteachBuffer {
    startDate = [NSDate date];
    
    JNFIFO *fifo = [JNFIFO sharedFIFO];
    
    if ([fifo getActualSize] && _bufferSize < _bufferCap) {
        int readBytes = [fifo fifoRead:_buffer + _bufferSize length:_bufferCap - _bufferSize];
        _bufferSize += readBytes;
    
    
    if (memcmp(_buffer, KStartCode, 4) != 0) {
        uint8_t *bufferBegin = _buffer + 4;
        uint8_t *bufferEnd = _buffer + _bufferSize;
        while (bufferBegin != bufferEnd) {
            if (*bufferBegin == 0x01) {
                if(memcmp(bufferBegin - 3, KStartCode, 4) == 0 && ((*(bufferBegin + 1)) & 0x1F) == 0x07) {
                    NSInteger packetSize = bufferBegin - _buffer - 3;
                    memmove(_buffer, _buffer + packetSize, _bufferSize - packetSize);
                    _bufferSize -= packetSize;
                    break;
                }
            }
            ++bufferBegin;
            if (bufferBegin == bufferEnd) {
                memmove(_buffer, _buffer + _bufferSize, 0);
                _bufferSize = 0;
            }
        }
        
    }
    
    if (_bufferSize >= 19) {
        
        uint8_t *bufferBegin = _buffer + 4;
        uint8_t *bufferEnd = _buffer + _bufferSize;
        while (bufferBegin != bufferEnd) {
            if (*bufferBegin == 0x01) {
                if(memcmp(bufferBegin - 3, KStartCode, 4) == 0) {
                    NSInteger packetSize = bufferBegin - _buffer - 3;
                    VideoPacket *vp = [[VideoPacket alloc] initWithSize:packetSize];
                    memcpy(vp.buffer, _buffer, packetSize);

                    memmove(_buffer, _buffer + packetSize, _bufferSize - packetSize);
                    _bufferSize -= packetSize;
                    return vp;
                }
            }
            ++bufferBegin;
            
        }
                           
    }
        
    }
    
    return nil;
}

- (void)dealloc {
    free(_buffer);
}

@end
