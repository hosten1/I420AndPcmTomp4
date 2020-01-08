//
//  ViewController.m
//  LYMI420AndPcmToMp4
//
//  Created by ymluo on 2020/1/8.
//  Copyright © 2020 ymluo. All rights reserved.
//

#import "ViewController.h"
#import "ESCMp4v2RecordTool.h"
#import "WCLRecordEncoder.h"

@interface ViewController ()
@property (nonatomic, strong) ESCMp4v2RecordTool *mp4v2RecordTool;  //!<
@property (nonatomic, strong) WCLRecordEncoder *fileWriter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
/*
- (void)appClient:(RTCSDKClientPeer *)client didReciveMixAudioStreamPcm:(char *)pcm len:(int)len_ channels:(const size_t)channels bit_per_sample:(const size_t)bit_per_sample sample_rate:(const size_t)sample_rat{
    
    if (self.haveRecoring) {
        if (!self.fileWriter) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [NSLocale systemLocale];
            formatter.dateFormat = @"yyyy_MM_dd_HH_mm_ss";
            NSString *date = [formatter stringFromDate:[NSDate date]];
            NSString* fileName = [NSString stringWithFormat:@"record_video_%@.mp4",date];
            NSString *mp4Path = [self.params.recordSavePath stringByAppendingPathComponent:fileName];
            self.fileWriter =  [[WCLRecordEncoder alloc]initPath:mp4Path Height:480 width:640 channels:channels samples:sample_rat];
            
            if (!_dataForSam) {
                self.dataForSam = [[RTCDataForSampleBuffer alloc]init];
            }
        }
        
        NSData *pcmData = [NSData dataWithBytes:pcm length:len_];
        [self.fileWriter encodeAudioPcmFrame:pcmData channels:channels bit_per_sample:bit_per_sample sample_rate:sample_rat];
        pcmData = nil;
    }
}
 */
-(void)appClient:(RTCSDKClientPeer *)client didOutputMixVideoSampleBufferRef:(CMSampleBufferRef)sampleBufferRef width:(CGFloat)width height:(CGFloat)height{
    if (_fileWriter) {
        [self.fileWriter encodeFrame:sampleBufferRef isVideo:YES];
    }
}
#pragma mark - map4v2 使用
- (void)didReciveMixVideoStreamI420:(char *)yuv width:(int)width height:(int)height yuv_size:(size_t)yuv_size h264Data:(NSData *)data{
    if (_mp4v2RecordTool) {
        [_mp4v2RecordTool addVideoData:data];
        NSLog(@"=====================pushH264DataContentSpsAndPpsData()===========================");
    }
    
}
- (void)didReciveMixAudioStreamPcm:(char *)pcm len:(int)len_ channels:(const size_t)channels bit_per_sample:(const size_t)bit_per_sample sample_rate:(const size_t)sample_rat{
    
    if (!_mp4v2RecordTool) {
        NSLog(@"=====================didReciveMixAudioStreamPcm(init )===========================");
        
        self.mp4v2RecordTool = [[ESCMp4v2RecordTool alloc]init];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale systemLocale];
        formatter.dateFormat = @"yyyy_MM_dd_HH_mm_ss";
        NSString *date = [formatter stringFromDate:[NSDate date]];
        NSString *path =  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString* fileName = [NSString stringWithFormat:@"record_video_%@.mp4",date];
        NSString *mp4Path = [path stringByAppendingPathComponent:fileName];
        [_mp4v2RecordTool startRecordWithFilePath:mp4Path Width:640 height:480 frameRate:20 audioFormat:0 audioSampleRate:sample_rat audioChannel:(int)channels audioBitsPerSample:(int)16];
    }else{
        @autoreleasepool {
            NSData *pcmData = [NSData dataWithBytes:pcm length:len_];
            [_mp4v2RecordTool addAudioData:pcmData isPcm:YES];
            pcmData = nil;
        }
        
        
    }
}
@end
