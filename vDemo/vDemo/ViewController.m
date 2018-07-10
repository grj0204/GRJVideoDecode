//
//  ViewController.m
//  vDemo
//
//  Created by joynices on 2018/5/28.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import "ViewController.h"
#import "AAPLEAGLLayer.h"
#import "JNCVideoCopter.h"
#import <mach/mach.h>
#import "MonitorIOS.h"

@interface ViewController ()<JNCVideoCopterDelegate>
@property (strong, nonatomic) UILabel *label;
@property (nonatomic, strong) NSMutableArray *accessoryList;
@property (nonatomic, strong) EAAccessory *linkAccessory;
@property (nonatomic, strong) AAPLEAGLLayer *glLayer;
@property (nonatomic, strong) JNCVideoCopter *copter;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, assign) int count;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _glLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
    [self.view.layer addSublayer:_glLayer];
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 200, 30)];
    self.label.text = @"hello world";
    [self.view addSubview:self.label];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    self.copter = [JNCVideoCopter sharedInstance];
    self.copter.delegate = self;
    self.accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    if (self.accessoryList.count == 0) {
        
    }else {
        self.linkAccessory = [self.accessoryList firstObject];
        self.label.text = [self.linkAccessory name];
        [self.copter setupControllerForAccessory:self.linkAccessory];
        [self.copter videoStart];
    }
    
    [self.copter listenData];
    self.count = 0;
    
}

#pragma mark - 外设连接通知
- (void)accessoryDidConnect:(NSNotification *)noti {
    self.startDate = [NSDate date];
    self.linkAccessory = [[noti userInfo] objectForKey:EAAccessoryKey];
    self.label.text = [self.linkAccessory name];
    [self.copter setupControllerForAccessory:self.linkAccessory];
    [self.copter videoStart];
}

- (void)accessoryDidDisconnect:(NSNotification *)noti {
    self.label.text = @"断开了";
    [self.copter videoStop];
}

- (void)videoCopterDisplayFrame:(CVImageBufferRef)imageBuffer {
    _glLayer.pixelBuffer = imageBuffer;
    CVPixelBufferRelease(imageBuffer);
    
    MonitorIOS *mon = [[MonitorIOS alloc] init];
    self.label.text = [NSString stringWithFormat:@"cpu: %g",[mon GetCpuUsage]];
}

- (void)updateStatus:(JNCVideoStatus)status {
    switch (status) {
        case JNCVideoStatusVideoSessionOpen:
            self.label.text = @"视频通道打开";
            break;
        case JNCVideoStatusVideoSessionClose:
            self.label.text = @"视频通道未打开";
            break;
            
        default:
            break;
    }
    
}

- (void)cpuUseg:(float)cpu {
    self.label.text = [NSString stringWithFormat:@"cpu: %g",cpu];
}

@end
