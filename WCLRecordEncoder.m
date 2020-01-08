//
//  WCLRecordEncoder.m
//  WCL
//
// **************************************************
// *                                  _____         *
// *         __  _  __     ___        \   /         *
// *         \ \/ \/ /    / __\       /  /          *
// *          \  _  /    | (__       /  /           *
// *           \/ \/      \___/     /  /__          *
// *                               /_____/          *
// *                                                *
// **************************************************
//  Github  :https://github.com/631106979
//  HomePage:https://imwcl.com
//  CSDN    :http://blog.csdn.net/wang631106979
//
//  Created by 王崇磊 on 16/9/14.
//  Copyright © 2016年 王崇磊. All rights reserved.
//
// @class WCLRecordEncoder
// @abstract 视频编码类
// @discussion 应用的相关扩展
//
// 博客地址：http://blog.csdn.net/wang631106979/article/details/51498009

#import "WCLRecordEncoder.h"

@interface WCLRecordEncoder ()

@property (nonatomic, strong) AVAssetWriter *asseetWriter;//媒体写入对象
@property (nonatomic, strong) AVAssetWriterInput *videoInput;//视频写入
@property (nonatomic, strong) AVAssetWriterInput *audioInput;//音频写入
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, strong) NSString *path;//写入路径
@property (nonatomic, assign) NSInteger i;//帧数

@property (nonatomic, assign) BOOL videoAllWriter;//帧数
@end

@implementation WCLRecordEncoder

- (void)dealloc {
    _asseetWriter = nil;
    _videoInput = nil;
    _audioInput = nil;
    _path = nil;
    _i = 0;
}

//WCLRecordEncoder遍历构造器的
+ (WCLRecordEncoder*)encoderForPath:(NSString*) path Height:(NSInteger) cy width:(NSInteger) cx channels: (int) ch samples:(Float64) rate {
    WCLRecordEncoder* enc = [WCLRecordEncoder alloc];
    return [enc initPath:path Height:cy width:cx channels:ch samples:rate];
}

//初始化方法
- (instancetype)initPath:(NSString*)path Height:(NSInteger)cy width:(NSInteger)cx channels:(int)ch samples:(Float64) rate {
    self = [super init];
    if (self) {
        self.i = 0;
        self.path = path;
        self.videoAllWriter = NO;
        //先把路径下的文件给删除掉，保证录制的文件是最新的
        [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
        NSURL* url = [NSURL fileURLWithPath:self.path];
        //初始化写入媒体类型为MP4类型
        NSError *error;
        AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        if (error) {
            NSLog(@"%@",error);
            return nil;
        }
        self.asseetWriter = writer;
        [self initVideoInputHeight:cy width:cx];
        //确保采集到rate和ch
        if (rate != 0 && ch != 0) {
            //初始化音频输出
            [self initAudioInputChannels:ch samples:rate];
        }
        //开始写入
        [self.asseetWriter startWriting];
    }
    return self;
}

//初始化视频输入
- (void)initVideoInputHeight:(NSInteger)height width:(NSInteger)width {
    //录制视频的一些配置，分辨率，编码方式等等
    NSInteger frameRate = 15;
    //写入视频大小
    NSInteger numPixels = width * height;
    //每像素比特
    CGFloat bitsPerPixel = 6.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(frameRate),
                                             AVVideoMaxKeyFrameIntervalKey : @(frameRate),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    
    NSDictionary *setting = @{ AVVideoCodecKey : AVVideoCodecH264,
                               AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                               AVVideoWidthKey : @(width),
                               AVVideoHeightKey : @(height),
                               AVVideoCompressionPropertiesKey : compressionProperties };
    
    
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:setting];
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoInput sourcePixelBufferAttributes:nil];

    //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
    self.videoInput.expectsMediaDataInRealTime = YES;
    if ([self.asseetWriter canAddInput:videoInput]) {
        [self.asseetWriter addInput:videoInput];
        self.videoInput = videoInput;
//        self.videoAssetWriterInput.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    }else {
        NSLog(@"can't add video input!");
        return;
    }
    
   
}

//初始化音频输入
- (void)initAudioInputChannels:(int)ch samples:(Float64)rate {
    //音频的一些配置包括音频各种这里为AAC,音频通道、采样率和音频的比特率
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                              [ NSNumber numberWithInt: ch], AVNumberOfChannelsKey,
                              [ NSNumber numberWithFloat: rate], AVSampleRateKey,
                              nil];
//    初始化音频写入类
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
    //表明输入是否应该调整其处理为实时数据源的数据
    _audioInput.expectsMediaDataInRealTime = YES;
    //将音频输入源加入
    if ([self.asseetWriter canAddInput:_audioInput]) {
        [self.asseetWriter addInput:_audioInput];
    }else {
        NSLog(@"can't add audio input!");
        return;
    }
    
}

//完成视频录制时调用
- (void)finishWithCompletionHandler:(void (^)(void))handler {
    if (_asseetWriter.status == AVAssetWriterStatusWriting) {
        sleep(0.01);
        CMTime frameTime = CMTimeMake(_i, 1);
        [_asseetWriter endSessionAtSourceTime:frameTime];
    }
  
    //Finish the session:
    if (_videoInput) {
        [_videoInput markAsFinished];
    }
    if (_audioInput) {
        [_audioInput markAsFinished];
    }
    if (_asseetWriter.status != AVAssetWriterStatusCompleted) {
        [_asseetWriter finishWritingWithCompletionHandler: handler];
    }
   
}
- (void)encodeFrame:(CVPixelBufferRef) pixelBuffer isVideo:(BOOL)isVideo fps:(int32_t)fps {
    CMTime presentTime = CMTimeMake(0, fps);
    if (_asseetWriter.status == AVAssetWriterStatusUnknown && isVideo) {
        //开始写入
        [_asseetWriter startWriting];
        [_asseetWriter startSessionAtSourceTime:kCMTimeZero];
    }
    if(_adaptor.assetWriterInput.readyForMoreMediaData){
        presentTime = CMTimeMake(_i, fps);
        if (pixelBuffer) {
            //append buffer
            BOOL appendSuccess = [self appendToAdapter:_adaptor pixelBuffer:pixelBuffer atTime:presentTime withInput:_videoInput];
            NSAssert(appendSuccess, @"Failed to append");
            if (appendSuccess) {
                NSLog(@"append successed");
            }
            _i++;
        }else{
            //Finish the session:
            [_videoInput markAsFinished];
            [_asseetWriter finishWritingWithCompletionHandler:^{
                
            }];
            NSLog (@"Done");
        }
    }
}
-(BOOL)appendToAdapter:(AVAssetWriterInputPixelBufferAdaptor*)adaptor
           pixelBuffer:(CVPixelBufferRef)buffer
                atTime:(CMTime)presentTime
             withInput:(AVAssetWriterInput*)writerInput
{
    while (!writerInput.readyForMoreMediaData) {
        usleep(1);
    }
    return [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
}
//通过这个方法写入数据
- (BOOL)encodeFrame:(CMSampleBufferRef) sampleBuffer isVideo:(BOOL)isVideo {
    //数据是否准备写入
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        //写入失败
        if (_asseetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _asseetWriter.error.localizedDescription);
            return NO;
        }
        //判断是否是视频
        if (isVideo) {
            //视频输入是否准备接受更多的媒体数据
            [self addVideoFrame:sampleBuffer];
        }else {
            [self addAudioFrame:sampleBuffer];
        }
        
    }
    
    return NO;
}
- (void)addAudioFrame:(CMSampleBufferRef)sampleBufferRef {
    if (!_videoAllWriter) {
        return;
    }
//    [self.asseetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBufferRef)];
    if (self.audioInput.readyForMoreMediaData) {
        [self.audioInput appendSampleBuffer:sampleBufferRef];
        CFRelease(sampleBufferRef);
    }
}

- (void)addVideoFrame:(CMSampleBufferRef)sampleBufferRef {
    [self.asseetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBufferRef)];
    if (self.videoInput.readyForMoreMediaData) {
        [self.videoInput appendSampleBuffer:sampleBufferRef];
    }
    self.videoAllWriter = YES;
}

@end
