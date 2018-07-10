//
//  JNEADSessionModel.m
//  flying(new)
//
//  Created by joynices on 2018/4/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "JNCVideoCopter.h"
#import "JNFIFO.h"
#import "VideoPacket.h"
#import "DecodeH264.h"

#define WeakSelf __weak typeof(self) weakSelf = self
#define kVideoImageNotification  @"videoImageNotification"

#define USB_INPUT_BUFFER_SIZE  8 * 1024 * 1024
#define BUFFER_SIZE 32 * 1024
static uint8_t videoBuf[USB_INPUT_BUFFER_SIZE];

@interface JNCVideoCopter ()<DecodeH264Delegate>
@property (nonatomic, strong) EASession *videoSession;

@property (nonatomic, assign) NSInteger onceCode;
/*
 读取连接到设备的附件
 */
@property (nonatomic) EAAccessory *accessory;

/*
 读取附件视频通道协议
 */
@property (nonatomic, copy) NSString *videoProtocol;

/*
 读取附件自定义通道协议
 */
@property (nonatomic, copy) NSString *customerProtocol;
@property (nonatomic, assign) BOOL control;
@property (nonatomic, strong) DecodeH264 *decoderH264;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, assign) BOOL decode;

@end


@implementation JNCVideoCopter

+ (JNCVideoCopter *)sharedInstance {
    static JNCVideoCopter *sharedModel = nil;
    if (sharedModel == nil) {
        sharedModel = [[JNCVideoCopter alloc] init];
    }
    return sharedModel;
}

- (void)add_video_cb:(id)observer selector:(SEL)aSelector{
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:aSelector
                                                 name:kVideoImageNotification
                                               object:nil];
}

- (void)setupControllerForAccessory:(EAAccessory *)accessory withVideoProtocol:(NSString *)videoProtocol withCustomerProtocol:(NSString *)customerProtocol {
    _accessory = accessory;
    _videoProtocol = videoProtocol;
    _customerProtocol = customerProtocol;
}

- (void)setupControllerForAccessory:(EAAccessory *)accessory {
    _accessory = accessory;
    NSArray *protocolsArray = [_accessory protocolStrings];
    for (NSString *item in protocolsArray) {
        if ([item isEqualToString:@"com.joynice.video"]) {
            _videoProtocol = item;
        }
    }
}

- (BOOL)videoStart {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *deadDate = [NSDate date];
    deadDate = [formatter dateFromString:@"2018-12-31 23:00:00"];
    NSComparisonResult result = [currentDate compare:deadDate];
    
    [_accessory setDelegate:self];
    _videoSession = [[EASession alloc] initWithAccessory:_accessory forProtocol:_videoProtocol];
    if (_videoSession && (result == NSOrderedAscending)) {
        [[_videoSession inputStream] setDelegate:self];
        [[_videoSession inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_videoSession inputStream] open];
        
        [[_videoSession outputStream] setDelegate:self];
        [[_videoSession outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_videoSession outputStream] open];
        
        if ([self.delegate respondsToSelector:@selector(updateStatus:)]) {
            [self.delegate updateStatus:JNCVideoStatusVideoSessionOpen];
        }
    }else {
        if ([self.delegate respondsToSelector:@selector(updateStatus:)]) {
            [self.delegate updateStatus:JNCVideoStatusVideoSessionClose];
        }
    }
    return (_videoSession != nil);
}

- (void)videoStop {
    [[_videoSession inputStream] close];
    [[_videoSession inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_videoSession inputStream] setDelegate:nil];
    
    [[_videoSession outputStream] close];
    [[_videoSession outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_videoSession outputStream] setDelegate:nil];
    _videoSession = nil;
    self.onceCode = 0;
    self.decode = NO;
}

- (void)listenData {
    WeakSelf;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [weakSelf decodePacket];
    });
}

#pragma mark - usb读数据
- (void)readVideoData {
    
    int bytesRead = [[self.videoSession inputStream] read:videoBuf maxLength:USB_INPUT_BUFFER_SIZE];
    [self writeReadBytes:bytesRead len:0];
    
}

- (void)decodePacket {
    self.decoderH264 = [[DecodeH264 alloc] init];
    self.decoderH264.delegate = self;
    while (1) {
        VideoPacket *vp = [self.decoderH264 deteachBuffer];
        if (vp == nil) {
            continue;
        }else {
            [self.decoderH264 decodeNalu:vp];
        }
        usleep(1000 * 13.6);
    }
}

#pragma mark - 写缓存数据
- (int)writeReadBytes:(int)writeLen len:(int)clen {
    int len = -1;
    JNFIFO *fifo = [JNFIFO sharedFIFO];
    len = [fifo fifoWrite:videoBuf+clen length:writeLen];
    if (len == writeLen) {
        return len;
    }
    clen += len;
    writeLen -= len;
    return [self writeReadBytes:writeLen len:clen];
}

#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventNone:
            break;
        case NSStreamEventOpenCompleted:
            break;
        case NSStreamEventHasBytesAvailable:
            [self readVideoData];
            break;
        case NSStreamEventHasSpaceAvailable:
            break;
        case NSStreamEventErrorOccurred:
            break;
        case NSStreamEventEndEncountered:
           
            break;
        default:
            break;
    }
}

#pragma mark - DecodeH264Delegate
- (void)displayDecodedFrame:(CVImageBufferRef)imageBuffer {
    if ([self.delegate respondsToSelector:@selector(videoCopterDisplayFrame:)]) {
        [self.delegate videoCopterDisplayFrame:imageBuffer];
    }
    
}

- (void)decodeBuffer:(uint8_t *)buffer bufferSize:(NSInteger)bufferSize {
    if ([self.delegate respondsToSelector:@selector(frameBuffer:bufferSize:)]) {
        [self.delegate frameBuffer:buffer bufferSize:bufferSize];
    }
}

- (void)displayFrameSize:(NSInteger)size {
    if ([self.delegate respondsToSelector:@selector(frameSize:)]) {
        [self.delegate frameSize:size];
    }
}

- (void)displayTimeInterval:(double)timeI {
    if ([self.delegate respondsToSelector:@selector(cpuUseg:)]) {
        [self.delegate cpuUseg:timeI];
    }
}

#pragma mark - 解码初始化 & 释放资源


- (int)logConsole:(bool)uselog {
    self.control = uselog;
    return 0;
}

- (int)controlLocal:(float)climbRate yr:(float)yr fb:(float)fb rl:(float)rl {
    if (self.control) {
        NSLog(@"爬升率：%.2f,航向速率：%.2f,前后速率：%.2f,左右平移速率：%.2f",climbRate,yr,fb,rl);
    }
    return 0;
}

- (void)accessoryDidDisconnect:(EAAccessory *)accessory {
    [self videoStop];
   
}

- (void)dealloc {
    [self videoStop];
    [self setupControllerForAccessory:nil withVideoProtocol:nil withCustomerProtocol:nil];
}
@end
