//
//  JNEADSessionModel.h
//  flying(new)
//
//  Created by joynices on 2018/4/10.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>

typedef NS_ENUM(NSInteger, JNCVideoStatus)
{
    JNCVideoStatusVideoSessionOpen,        //视频数据通道打开
    JNCVideoStatusVideoSessionClose,       //视频数据通道未打开
};

@protocol JNCVideoCopterDelegate <NSObject>


/**
 监听状态  包括：连接状态、协议通道状态、解码器状态
 
 @param status 状态信息
 */
- (void)updateStatus:(JNCVideoStatus)status;


/**
 接收到帧率时可以获得帧率
 
 @param fps 帧率
 */
//- (void)fps:(NSString *)fps;
//
//- (void)frameData:(uint8_t *)frame frameSize:(int)size;

- (void)videoCopterDisplayFrame:(CVImageBufferRef)imageBuffer;


@end

@interface JNCVideoCopter : NSObject <EAAccessoryDelegate, NSStreamDelegate>

/**
 协议代理属性
 */
@property (nonatomic, weak) id<JNCVideoCopterDelegate> delegate;

/*
 创建 JNCVideoCopter 对象
 */
+ (JNCVideoCopter *)sharedInstance;

/*
 设置附件和附件支持的协议
 * accessory : 连接到设备的附件
 * videoProtocol : 附件中视频通道协议
 * customerProtocol : 附件自定义通道协议
 */
- (void)setupControllerForAccessory:(EAAccessory *)accessory withVideoProtocol:(NSString *)videoProtocol withCustomerProtocol:(NSString *)customerProtocol;

- (void)setupControllerForAccessory:(EAAccessory *)accessory;
- (void)listenData;

/*
 打开数据通道
 */
- (BOOL)videoStart;

/*
 关闭数据通道
 */
- (void)videoStop;

/**
 注册接收到图传数据后执行的方法
 
 @param observer 监听通知的对象
 @param aSelector 监听到通知后执行的方法
 */
- (void)add_video_cb:(id)observer selector:(SEL)aSelector;

/**
 在local坐标系的控制接口，优先级最低，会被物理按键覆盖并失效。
 
 @param climbRate 爬升率，0表示定高。单位 cm/s
 @param yr 航向速率。正右负左（转向），0不变。单位 °/s
 @param fb 前后速率。正前负后，0不动。单位 cm/s
 @param rl 左右平移速率。正右负左，0不动。单位 cm/s
 @return 0成功，其它：拒绝
 */
- (int)controlLocal:(float)climbRate yr:(float)yr fb:(float)fb rl:(float)rl;


/**
 在屏幕显示飞机状态
 
 @param uselog 是否显示飞机状态
 @return  0成功，其它：拒绝
 */
- (int)logConsole:(bool)uselog;

- (void)resourceForFile:(NSString *)filename;
@end
