//
//  WYKSocketManager.m
//  CocoaSyncSocket
//
//  Created by 王永康 on 18/03/28.
//  Copyright © 2018年 王永康. All rights reserved.
//

#import "WYKSocketManager.h"
#import "GCDAsyncSocket.h" // for TCP

static NSString *Khost = @"127.0.0.1";
static uint16_t  Kport = 6969;
static NSInteger KPingPongOutTime  = 3;
static NSInteger KPingPongInterval = 5;

@interface WYKSocketManager()<GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *gcdSocket;
@property (nonatomic, assign) NSTimeInterval reConnectTime;
@property (nonatomic, assign) NSTimeInterval heartBeatSecond;
@property (nonatomic, strong) NSTimer *heartBeatTimer;
@property (nonatomic, assign) BOOL socketOfflineByUser;  //!< 主动关闭
@property (nonatomic, retain) NSTimer *connectTimer; // 计时器

@end

@implementation WYKSocketManager

- (void)dealloc
{
    [self destoryHeartBeat];
}

+ (instancetype)share
{
    static dispatch_once_t onceToken;
    static WYKSocketManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance initSocket];
    });
    return instance;
}

- (void)initSocket
{
    self.gcdSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                delegateQueue:dispatch_get_main_queue()];
}

#pragma mark - 对外的一些接口
//建立连接
- (BOOL)connect
{
    self.reConnectTime = 0;
    return [self autoConnect];
}
//断开连接
- (void)disConnect
{
    self.socketOfflineByUser = YES;
    [self autoDisConnect];
}

//发送消息
- (void)sendMsg:(NSString *)msg
{
    NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
    //第二个参数，请求超时时间
    [self.gcdSocket writeData:data withTimeout:-1 tag:110];
}

#pragma mark - GCDAsyncSocketDelegate
//连接成功调用
- (void)socket:(GCDAsyncSocket *)sock
didConnectToHost:(NSString *)host
          port:(uint16_t)port
{
    NSLog(@"连接成功,host:%@,port:%d",host,port);
    //pingPong
    [self checkPingPong];
    //心跳写在这...
    [self initHeartBeat];
}

//断开连接的时候调用
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(nullable NSError *)err
{
    NSLog(@"断开连接,host:%@,port:%d",sock.localHost,sock.localPort);
    if (self.delegate && [self.delegate respondsToSelector:@selector(showMessage:)]) {
        NSString *msg = [NSString stringWithFormat:@"断开连接,host:%@,port:%d",sock.localHost,sock.localPort];
        [self.delegate showMessage:msg];
    }

    if (!self.socketOfflineByUser) {
        //断线/失败了就去重连
        [self reConnect];
    }
}

//写的回调
- (void)socket:(GCDAsyncSocket*)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"写的回调,tag:%ld",tag);
    //判断是否成功发送，如果没收到响应，则说明连接断了，则想办法重连
    [self checkPingPong];
}

//收到消息
- (void)socket:(GCDAsyncSocket *)sock
   didReadData:(NSData *)data
       withTag:(long)tag
{
    NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"收到消息：%@",msg);
    if (self.delegate && [self.delegate respondsToSelector:@selector(showMessage:)]) {
        [self.delegate showMessage:[NSString stringWithFormat:@"收到：%@",msg]];
    }
    //去读取当前消息队列中的未读消息 这里不调用这个方法，消息回调的代理是永远不会被触发的
    [self pullTheMsg];
}

//为上一次设置的读取数据代理续时 (如果设置超时为-1，则永远不会调用到)
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock
shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    NSLog(@"pingPong来延时保活，tag:%ld,elapsed:%f,length:%ld",tag,elapsed,length);
    if (self.delegate && [self.delegate respondsToSelector:@selector(showMessage:)]) {
        NSString *msg = [NSString stringWithFormat:@"PingPong延时:,tag:%ld,elapsed:%.1f,length:%ld",tag,elapsed,length];
        [self.delegate showMessage:msg];
    }
    return KPingPongInterval;
}

#pragma mark- Private Methods
- (BOOL)autoConnect
{
    return [self.gcdSocket connectToHost:Khost onPort:Kport error:nil];
}

- (void)autoDisConnect
{
    [self.gcdSocket disconnect];
}

//TODO:监听最新的消息
- (void)pullTheMsg
{
    //监听读数据的代理，只能监听10秒，10秒过后调用代理方法  -1永远监听，不超时，但是只收一次消息，
    //所以每次接受到消息还得调用一次
    [self.gcdSocket readDataWithTimeout:-1 tag:110];
}

//TODO:Pingpong机制
- (void)checkPingPong
{
    //pingpong设置为3秒，如果3秒内没得到反馈就会自动断开连接
    [self.gcdSocket readDataWithTimeout:KPingPongOutTime tag:110];
}

//TODO:重连机制
- (void)reConnect
{
    //如果对一个已经连接的socket对象再次进行连接操作，会抛出异常（不可对已经连接的socket进行连接）程序崩溃
    [self autoDisConnect];
    //重连次数 控制3次
    if (self.reConnectTime >= 5) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(self.reConnectTime * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(showMessage:)]) {
            NSString *msg = [NSString stringWithFormat:@"断开重连中，%f",strongSelf.reConnectTime];
            [strongSelf.delegate showMessage:msg];
        }
        strongSelf.gcdSocket = nil;
        [strongSelf initSocket];
        [strongSelf autoConnect];
    });
    
    //重连时间增长
    if (self.reConnectTime == 0) {
        self.reConnectTime = 1;
    } else {
        self.reConnectTime += 5;
    }
}

//TODO:心跳机制
- (void)initHeartBeat
{
    [self destoryHeartBeat];
    // 每隔5s像服务器发送心跳包
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                         target:self
                                                       selector:@selector(longConnectToSocket)
                                                       userInfo:nil
                                                        repeats:YES];
    // 在longConnectToSocket方法中进行长连接需要向服务器发送的讯息
    [self.connectTimer fire];
}

// 心跳连接
-(void)longConnectToSocket
{
    // 根据服务器要求发送固定格式的数据，但是一般不会是这么简单的指令
    [self sendMsg:@"心跳连接"];
}

//取消心跳
- (void)destoryHeartBeat
{
    if (self.heartBeatTimer && [self.heartBeatTimer isValid]) {
        [self.heartBeatTimer invalidate];
        self.heartBeatTimer = nil;
    }
}

@end
