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
#import "RTCDataForSampleBuffer.h"

@interface WCLRecordEncoder ()

@property (nonatomic, strong) AVAssetWriter *asseetWriter;//媒体写入对象
@property (nonatomic, strong) AVAssetWriterInput *videoInput;//视频写入
@property (nonatomic, strong) AVAssetWriterInput *audioInput;//音频写入
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, strong) NSString *path;//写入路径
@property (nonatomic, assign) NSInteger i;//帧数

@property (nonatomic, assign) BOOL videoAllWriter;//
@property (nonatomic, assign) BOOL audioAllWriter;//

@property (nonatomic, strong) RTCDataForSampleBuffer *dataForSam;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL isClose;  //!<
@property (nonatomic, assign) CMTime currentFrameTime;  //!<
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
+ (WCLRecordEncoder*)encoderForPath:(NSString*) path Height:(NSInteger) cy width:(NSInteger) cx channels: (int) ch samples:(Float64) rate VideoFrameRate:(NSInteger)frameRate{
    WCLRecordEncoder* enc = [WCLRecordEncoder alloc];
    return [enc initPath:path Height:cy width:cx channels:ch samples:rate VideoFrameRate:frameRate];
}

//初始化方法
- (instancetype)initPath:(NSString*)path Height:(NSInteger)cy width:(NSInteger)cx channels:(int)ch samples:(Float64) rate VideoFrameRate:(NSInteger)frameRate{
    self = [super init];
    if (self) {
        self.i = 0;
        self.path = path;
        self.videoAllWriter = NO;
        self.isClose = NO;
        self.currentFrameTime = kCMTimeZero;
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
        [self initVideoInputHeight:cy width:cx VideoFrameRate:frameRate];
        //确保采集到rate和ch
        if (rate != 0 && ch != 0) {
            //初始化音频输出
            [self initAudioInputChannels:ch samples:rate];
        }
        //开始写入
        if ([self.asseetWriter startWriting]) {
            [self.asseetWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
        }

        self.lock = [[NSLock alloc]init];
    }
    return self;
}

//初始化视频输入
- (void)initVideoInputHeight:(NSInteger)height width:(NSInteger)width VideoFrameRate:(NSInteger)VideoFrameRate{
    //录制视频的一些配置，分辨率，编码方式等等
    NSInteger frameRate = (VideoFrameRate > 0) ? VideoFrameRate : 20;
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
                               AVVideoCompressionPropertiesKey : compressionProperties
                               };
    
    
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:setting];
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoInput sourcePixelBufferAttributes:nil];

    //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
    self.videoInput.expectsMediaDataInRealTime = YES;

    if ([self.asseetWriter canAddInput:videoInput]) {
        [self.asseetWriter addInput:videoInput];
        self.videoInput = videoInput;
//        self.videoAssetWriterInput.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    } else {
        NSLog(@"can't add video input!");
        return;
    }
    
   
}

//初始化音频输入
- (void)initAudioInputChannels:(int)ch samples:(Float64)rate {
    
    //音频的一些配置包括音频各种这里为AAC,音频通道、采样率和音频的比特率
    // Configure the channel layout as stereo.
//    AudioChannelLayout stereoChannelLayout = {
//        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
//        .mChannelBitmap = 0,
//        .mNumberChannelDescriptions = 0
//    };
//
    // Convert the channel layout object to an NSData object.
//    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
    
    // Get the compression settings for 128 kbps AAC.
    NSDictionary *compressionAudioSettings = @{
                                               AVFormatIDKey         : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
//                                               AVEncoderBitRateKey   : [NSNumber numberWithInteger:128000],
                                               AVSampleRateKey       : [NSNumber numberWithInteger:rate],
//                                               AVChannelLayoutKey    : channelLayoutAsData,
                                               AVNumberOfChannelsKey : [NSNumber numberWithUnsignedInteger:2],
//                                               AVEncoderBitRateStrategyKey:AVAudioBitRateStrategy_LongTermAverage,
                                               };
//    初始化音频写入类
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:compressionAudioSettings];
    //表明输入是否应该调整其处理为实时数据源的数据
    _audioInput.expectsMediaDataInRealTime = YES;
    //将音频输入源加入
    if ([self.asseetWriter canAddInput:_audioInput]) {
        [self.asseetWriter addInput:_audioInput];
    }else {
        NSLog(@"can't add audio input!");
        return;
    }
    if (!_dataForSam) {
        self.dataForSam = [[RTCDataForSampleBuffer alloc]init];
    }
}

//完成视频录制时调用
- (void)finishWithCompletionHandler:(void (^)(void))handler {
    __weak typeof(self) weakSelf = self;
    [_dataForSam closeWithCompleHandler:^(int dataLength) {
        __strong typeof(weakSelf) stongSelf = weakSelf;
        NSLog(@"=============dataLength:%@===============",@(dataLength));
        [stongSelf.lock lock];
        if (stongSelf.isClose) {
            return;
        }
        
        stongSelf.isClose = YES;
        [stongSelf.lock unlock];
        if (stongSelf.asseetWriter.status == AVAssetWriterStatusWriting) {
            //        CMTime frameTime = _frameTime;
            //        CMTimeMake(_i, 1);
            [stongSelf.asseetWriter endSessionAtSourceTime:stongSelf.currentFrameTime];
        }
        
        //Finish the session:
        if (stongSelf.videoInput) {
            [stongSelf.videoInput markAsFinished];
        }
        if (stongSelf.audioInput) {
            [stongSelf.audioInput markAsFinished];
        }
        if (stongSelf.asseetWriter.status != AVAssetWriterStatusCompleted) {
            [stongSelf.asseetWriter finishWritingWithCompletionHandler: handler];
        }
    }];//告诉已经停止录制，开始处理缓存数据
    
    
   
}

- (void)encodeFrameWithPixelBuff:(CVPixelBufferRef) pixelBuffer isVideo:(BOOL)isVideo fps:(int32_t)fps {
    CMTime presentTime = CMTimeMake(0, fps);
//    if (_asseetWriter.status == AVAssetWriterStatusUnknown && isVideo) {
//        //开始写入
//        [_asseetWriter startWriting];
//        [_asseetWriter startSessionAtSourceTime:kCMTimeZero];
//    }
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
    if (!_videoAllWriter) {
        self.videoAllWriter = YES;
        //         [self.asseetWriter startSessionAtSourceTime:timestamp];
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
-(BOOL)encodeAudioPcmFrame:(NSData *)pcmData channels:(const size_t)channels bit_per_sample:(const size_t)bit_per_sample sample_rate:(const size_t)sample_rat{
//    [_lock lock];
//    if (_isClose) {
//        [_lock unlock];
//        return NO;
//    }
//    [_lock unlock];
//    CMSampleBufferRef sampleBuffer =  [self.dataForSam createAudioAACSampleBufferWithPcmdata:pcmData audioSampleRate:(int)sample_rat audioChannels:(int)channels bitsPerChannel:16];
    __weak typeof(self) weakSelf = self;
    [self.dataForSam createAudioAACSampleBufferWithPcmdata:pcmData audioSampleRate:(int)sample_rat audioChannels:(int)channels bitsPerChannel:16 handler:^(CMSampleBufferRef  _Nonnull sampleBufferRef) {
        if (weakSelf && sampleBufferRef) {
//                    NSLog(@"=====================didReciveMixAudioStreamPcm(sample_rat:%@ )===========================",@(sample_rat));
            [weakSelf encodeFrame:sampleBufferRef isVideo:NO];
            CFRelease(sampleBufferRef);
            //         return true;
        }else{
                    NSLog(@"-======================== err");
            //         return false;
        }
    }];
   
    return NO;
}
//通过这个方法写入数据
- (BOOL)encodeFrame:(CMSampleBufferRef) sampleBuffer isVideo:(BOOL)isVideo {
    //数据是否准备写入
    CFRetain(sampleBuffer);
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        //写入失败
        if (_asseetWriter && _asseetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _asseetWriter.error.localizedDescription);
            CFRelease(sampleBuffer);
            return NO;
        }
        //判断是否是视频
        if (isVideo) {
            //视频输入是否准备接受更多的媒体数据
            [self addVideoFrame:sampleBuffer];
            CFRelease(sampleBuffer);
        }else {
            [self addAudioFrame:sampleBuffer];
            CFRelease(sampleBuffer);
        }
        
    }
    
    return NO;
}
- (void)addAudioFrame:(CMSampleBufferRef)sampleBufferRef {
    if (!_videoAllWriter) {
        return;
    }
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBufferRef);
    CMTime duration   = CMSampleBufferGetDuration(sampleBufferRef);
    if (duration.value > 0) {
        timestamp = CMTimeAdd(timestamp, duration);
    }
    if (!_audioAllWriter) {
//        [self.asseetWriter startSessionAtSourceTime:timestamp];
        self.audioAllWriter = YES;
    }
    if (self.audioInput.readyForMoreMediaData) {
        [self.audioInput appendSampleBuffer:sampleBufferRef];
    }
   
   
}

- (void)addVideoFrame:(CMSampleBufferRef)sampleBufferRef {
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBufferRef);
    CMTime duration   = CMSampleBufferGetDuration(sampleBufferRef);
    if (duration.value > 0) {
        timestamp = CMTimeAdd(timestamp, duration);
    }
    if (!_videoAllWriter) {
        self.videoAllWriter = YES;
//         [self.asseetWriter startSessionAtSourceTime:timestamp];
    }
    if (self.videoInput.readyForMoreMediaData) {
        [self.videoInput appendSampleBuffer:sampleBufferRef];
    }
    self.currentFrameTime = timestamp;
}

@end
