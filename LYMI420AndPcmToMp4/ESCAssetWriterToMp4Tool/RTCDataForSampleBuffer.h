//
//  DataForH264.h
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/26.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreMedia ;

NS_ASSUME_NONNULL_BEGIN

@interface RTCDataForSampleBuffer : NSObject

@property(nonatomic,strong,readonly)NSMutableData* temPCMData;



-(NSData *)createVideoDataWithVideoSampleBuffer:(CMSampleBufferRef)sample ;
-(CMSampleBufferRef)createVideoSampleBufferWithdata:(NSData *)data  frameRate:(CGFloat)frameRate;

-(void)createAudioAACSampleBufferWithPcmdata:(NSData *)audioData audioSampleRate:(int)audioSampleRate audioChannels:(int)audioChannels bitsPerChannel:(int)bitsPerChannel handler:(void(^)(CMSampleBufferRef sampleBufferRef))handler;

- (void) closeWithCompleHandler:(void(^)(int dataLength))CompleteHandler;
@end

NS_ASSUME_NONNULL_END
