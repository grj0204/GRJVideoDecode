//
//  FIFO.m
//  decodeTest
//
//  Created by joynices on 2018/3/7.
//  Copyright © 2018年 com.joynices. All rights reserved.
//

#import "JNFIFO.h"
#import <pthread.h>


#define FIFO_SIZE 48 * 1024 * 1024

@interface JNFIFO ()
{
    int front;
    int rear;
    uint8_t buffer[FIFO_SIZE];
    BOOL isEmpty;
    BOOL isFull;
    pthread_mutex_t mutex;
}

@property (nonatomic, strong) NSMutableArray *bytesArray;

@end

static JNFIFO *singletonFIFO;
@implementation JNFIFO

+ (instancetype)sharedFIFO {
    if (singletonFIFO == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            singletonFIFO = [[JNFIFO alloc] init];
        });
    }
    return singletonFIFO;
}

- (instancetype)init {
    if (self = [super init]) {
        front = 0;
        rear = 0;
        _bDestroy = NO;
        isEmpty = YES;
        isFull = NO;
        memset(buffer, 0, FIFO_SIZE);
        pthread_mutex_init(&mutex, NULL);
    }
    return self;
    
}

- (int)fifoRead:(uint8_t *)readBuf length:(int)length {
    pthread_mutex_lock(&mutex);
    int count = 0;
    int bufSize = [self getActualSize];
    if (length < 1 || isEmpty) {
        pthread_mutex_unlock(&mutex);
        return 0;
    }
    if (bufSize > length) {
        count = length;
        isEmpty = NO;
    }else {
        count = bufSize;
        isEmpty = YES;
    }
    
    if (isFull) {
        isFull = NO;
    }
    
    if (rear > front) {
        memcpy(readBuf, buffer + front, count);
        front = front + count;
    }else {
        if (count > FIFO_SIZE - front) {
            memcpy(readBuf, buffer + front, FIFO_SIZE - front);
            memcpy(readBuf + (FIFO_SIZE - front), buffer, count - (FIFO_SIZE - front));
        }else {
            memcpy(readBuf, buffer + front, count);
        }
        front = (front + count) >= FIFO_SIZE ? (front + count - FIFO_SIZE) : (front + count);
    }
    pthread_mutex_unlock(&mutex);
    
    return count;
}

- (int)fifoWrite:(uint8_t *)writeBuf length:(int)length {
    pthread_mutex_lock(&mutex);
    int count = 0;
    int bufSize = [self getActualSize];
    if (length < 1 || isFull) {
        isFull = YES;
        pthread_mutex_unlock(&mutex);
        return 0;
    }
    
    if (FIFO_SIZE - bufSize > length) {
        count = length;
        isFull = NO;
    }else {
        count = FIFO_SIZE - bufSize;
        isFull = YES;
//        return 0;
    }
    
    if (isEmpty) {
        isEmpty = false;
    }
    
    if (rear >= front) {
        if (FIFO_SIZE - rear >= count) {
            memcpy(buffer + rear, writeBuf, count);
            rear = rear + count >= FIFO_SIZE ? 0 : rear + count;
        }else {
            memcpy(buffer + rear, writeBuf, FIFO_SIZE - rear);
            memcpy(buffer, writeBuf + (FIFO_SIZE - rear), count - (FIFO_SIZE - rear));
            rear = rear + count - FIFO_SIZE;
        }
    }else {
        
        memcpy(buffer + rear, writeBuf, count);
        rear = rear + count;

    }
    pthread_mutex_unlock(&mutex);
    
    return count;
}



- (int)getActualSize {
    if (isEmpty) {
        return 0;
    }else {
        if (rear >= front) {
            return (rear - front);
        }else {
            return (FIFO_SIZE - (front - rear));
        }
    }
    return 0;
}

- (void)clearFIFO {
    front = 0;
    rear = 0;
    _bDestroy = NO;
    isEmpty = YES;
    isFull = NO;
    memset(buffer, 0, FIFO_SIZE);
}

- (void)dealloc {
    pthread_mutex_destroy(&mutex);
}

@end
