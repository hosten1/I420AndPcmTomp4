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

-(NSData *)createVideoDataWithVideoSampleBuffer:(CMSampleBufferRef)sample ;
-(CMSampleBufferRef)createVideoSampleBufferWithdata:(NSData *)data  frameRate:(CGFloat)frameRate;

-(CMSampleBufferRef)createAudioAACSampleBufferWithPcmdata:(NSData *)audioData audioSampleRate:(int)audioSampleRate audioChannels:(int)audioChannels bitsPerChannel:(int)bitsPerChannel;
@end

NS_ASSUME_NONNULL_END
