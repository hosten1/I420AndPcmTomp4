//
//  DataForH264.m
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/26.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import "RTCDataForSampleBuffer.h"
#import <CoreMedia/CoreMedia.h>

const int32_t TIME_SCALE = 1000000000l;    // 1s = 1e10^9 ns

#ifndef WEAKSELF
#define WEAKSELF __weak __typeof(&*self)weakSelf = self;
#endif
#ifndef STRONGSELF
#define STRONGSELF __strong __typeof(&*weakSelf)strongSelf = weakSelf;
#endif

@interface RTCDataForSampleBuffer ()

@property (nonatomic) CMFormatDescriptionRef formatRef ;
@property (nonatomic, assign) NSUInteger videoDataIndex;  //!<

@property (nonatomic, assign) NSUInteger audioDataIndex;  //!<

@property(nonatomic,assign)int audioSampleRate;

@property(nonatomic,assign)int audioChannels;

@property(nonatomic,assign)int bitsPerChannel;

@property(nonatomic,strong)NSMutableData* temPCMData;

@end

@implementation RTCDataForSampleBuffer
-(instancetype)init{
    if (self = [super init]) {
        self.videoDataIndex = 0;
        self.audioDataIndex = 0;
    }
    return self;
}
-(NSData *)createVideoDataWithVideoSampleBuffer:(CMSampleBufferRef)sample
{
    if (sample == nil) {
        return nil ;
    }
    const char bytes[] = {0,0,0,1} ;
    
    CFDictionaryRef dicRef = (CFDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sample, true), 0) ;
    BOOL keyFrame = !CFDictionaryContainsKey(dicRef, kCMSampleAttachmentKey_NotSync) ;
    NSMutableData *fullData = [NSMutableData data] ;
    
    
    if (keyFrame) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sample) ;
        size_t sparameterSetSize ,sparameterSetCount ;
        const uint8_t *sparameterSet ;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, nil) ;
        if (statusCode == noErr) {
            size_t pparameterSetSize ,pparameterSetCount ;
            const uint8_t *pparameterSet ;
            statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, nil) ;
            if (statusCode == noErr) {
                [fullData  appendBytes:bytes length:4];
                [fullData appendBytes:sparameterSet length:sparameterSetSize];
                [fullData  appendBytes:bytes length:4];
                [fullData appendBytes:pparameterSet length:pparameterSetSize];
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sample) ;
    size_t totalLength ;
    char *dataPointer ;
    OSStatus statusCode = CMBlockBufferGetDataPointer(dataBuffer, 0, NULL, &totalLength, &dataPointer) ;
    if (statusCode == noErr) {
        size_t bufferOffset = 0 ;
        static const int AVCCHeaderLength = 4 ;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0 ;
            memcpy(&NALUnitLength, dataPointer+bufferOffset, AVCCHeaderLength) ;
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength) ;
            
            [fullData appendBytes:bytes length:4];
            [fullData appendBytes:dataPointer+bufferOffset+AVCCHeaderLength length:NALUnitLength] ;
            bufferOffset += AVCCHeaderLength +NALUnitLength ;
        }
    }
    
    NSMutableData *allData = [NSMutableData dataWithBytes:bytes length:4] ;
    uint8_t type = 100 ;
    [allData appendBytes:&type length:1];
    uint32_t lengh = (uint32_t)fullData.length ;
    lengh = CFSwapInt32BigToHost(lengh) ;
    [allData appendBytes:&lengh length:4];
    [allData appendData:fullData];
    return [allData copy];
}

-(CMSampleBufferRef)createVideoSampleBufferWithdata:(NSData *)data  frameRate:(CGFloat)frameRate
{
    if (data == nil ) {
        return nil;
    }
    self.videoDataIndex++;

    char *h264Pointer = (char *)data.bytes ;
    NSUInteger h264Length = data.length ;
    
    int nalu_type = (h264Pointer[4] & 0x1F);
    int spsLocal = 0 ;
    int ppsLocal = 0 ;
    int frameLocal = 0 ;
    OSStatus status = noErr ;
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;
    NSUInteger frameLength = 0 ;
    //SPS
    if (nalu_type == 7) {
        spsLocal = [self naluLocal:h264Pointer start:0 total:h264Length] ;
        if (spsLocal == -1) {
            return sampleBuffer;
        }
        nalu_type = (h264Pointer[spsLocal + 4] & 0x1F);
    }
    //PPS
    if (nalu_type == 8) {
        ppsLocal = [self naluLocal:h264Pointer start:spsLocal total:h264Length] ;
        if (ppsLocal == -1) {
            return sampleBuffer;
        }
        nalu_type = (h264Pointer[ppsLocal + 4] & 0x1F);
        
        int  spsSize = spsLocal - 4 ;
        int  ppsSize = ppsLocal - spsLocal - 4 ;
        uint8_t *sps ,*pps ;
        sps = malloc(spsSize) ;
        pps = malloc(ppsSize) ;
        
        memcpy(sps, &h264Pointer[4], spsSize) ;
        memcpy(pps, &h264Pointer[spsLocal+4], ppsSize) ;
        
        uint8_t * parameterSetPointers[2] = {sps,pps} ;
        size_t parameterSetSizes[2] = {spsSize,ppsSize} ;
        
        CMVideoFormatDescriptionRef format ;
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                     2,
                                                                     (const uint8_t *const*)parameterSetPointers,
                                                                     parameterSetSizes,
                                                                     4,
                                                                     &format) ;
        if (self.formatRef) {
            CFRelease(self.formatRef) ;
        }
        self.formatRef = format ;
        free(sps) ;
        free(pps) ;
        if (status != noErr) {
            NSLog(@"create format error");
        }
        
    }
    
    if (nalu_type == 6) {
//        int otherLocal = [self naluLocal:h264Pointer start:ppsLocal total:h264Length] ;
//        NSData *data = [NSData dataWithBytes:&h264Pointer[ppsLocal + 4] length:otherLocal - ppsLocal - 4] ;
//        NSLog(@"data:%@",data);
        
    }
    
    frameLocal = ppsLocal ;
    if (nalu_type != 5 && nalu_type != 1) {
        while (nalu_type != 5 && nalu_type != 1 && frameLocal < h264Length) {
            frameLocal = [self naluLocal:h264Pointer start:frameLocal total:h264Length] ;
            nalu_type = (h264Pointer[frameLocal + 4] & 0x1F);
        }
    }
    
    //Keyframe (IDR) or non-IDR
    if (nalu_type == 5 || nalu_type == 1 ) {
        if (nalu_type == 5) {
            NSLog(@"key frame");
        }
        frameLength = h264Length - frameLocal ;
        uint32_t dataLength = htonl(frameLength - 4) ;
        
        //        uint8_t *data = malloc(frameLength) ;
        //        memcpy(data, &h264Pointer[frameLocal], frameLength) ;
        //        memcpy(data, &dataLength, sizeof(uint32_t)) ;
        //        NSData *muData = [NSData dataWithBytes:data length:frameLength] ;
        //        free(data) ;
        
        NSMutableData *muData = [NSMutableData dataWithBytes:&h264Pointer[frameLocal] length:frameLength] ;
        [muData  replaceBytesInRange:NSMakeRange(0, sizeof(uint32_t)) withBytes:&dataLength] ;
        
        status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                    (void *)muData.bytes,
                                                    frameLength,
                                                    kCFAllocatorNull,
                                                    NULL,
                                                    0,
                                                    frameLength,
                                                    0,
                                                    &blockBuffer) ;
        if (status != noErr) {
            NSLog(@"create block buffer error");
        }
    }
    
    //
    if (status == noErr) {
        int64_t ptss = (_videoDataIndex * (1000.0 / frameRate)) *(TIME_SCALE/1000);
        //    DLog(@"pts:%lld",pts);
        CMTime pts = CMTimeMake(ptss, TIME_SCALE);
        
        
        CMSampleTimingInfo timeInfoArray[1] = { {
            .duration = CMTimeMake(1, frameRate),
            .presentationTimeStamp = pts,
            .decodeTimeStamp = pts,
        } };
        CMFormatDescriptionRef format = self.formatRef ;
        const size_t sampleSize = frameLength ;
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer,
                                      true,
                                      NULL, NULL,
                                      format,
                                      1, 0, timeInfoArray, 1,
                                      &sampleSize,
                                      &sampleBuffer) ;
        if (status != noErr) {
            NSLog(@"create sample buffer error");
        }
    }
    if (status == noErr) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES) ;
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef) CFArrayGetValueAtIndex(attachments, 0) ;
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue) ;
    }
    CFAutorelease(blockBuffer) ;
    CFAutorelease(sampleBuffer) ;
    return sampleBuffer ;
}

-(int)naluLocal:(char *)h264Pointer start:(int)start total:(NSUInteger)totallength
{
    for (int i = start + 4; i < totallength ; i++) {
        if (h264Pointer[i] == 0x00 &&
            h264Pointer[i+1] == 0x00 &&
            h264Pointer[i+2] == 0x00 &&
            h264Pointer[i+3] == 0x01)
        {
            return i ;
        }
    }
    return -1 ;
}
-(CMSampleBufferRef)createAudioAACSampleBufferWithPcmdata:(NSData *)audioData audioSampleRate:(int)audioSampleRate audioChannels:(int)audioChannels bitsPerChannel:(int)bitsPerChannel{
    self.audioChannels = audioChannels;
    self.audioSampleRate = audioSampleRate;
    self.bitsPerChannel = bitsPerChannel;
    if (self.temPCMData == nil) {
        self.temPCMData = [NSMutableData data];
    }
    NSData *temData = audioData;
    if (self.temPCMData.length > 0) {
        [self.temPCMData appendData:audioData];
        temData = self.temPCMData;
        self.temPCMData = nil;
    }
    
    //首先判断pcmData的长度
    int pcmLength = (int)temData.length;
    int i = 0;
    
    int writeLength = 1024 * self.bitsPerChannel * self.audioChannels / 8;
    
    while (i + writeLength <= pcmLength && pcmLength >= writeLength) {
        NSData *pcmSubData = [temData subdataWithRange:NSMakeRange(i, writeLength)];
        i += writeLength;
        return [self __createAudioSampleBufferWithdata:pcmSubData audioSampleRate:audioSampleRate audioChannels:audioChannels bitsPerChannel:bitsPerChannel];
    }
    if (i < pcmLength) {
        NSData *pcmSubData = [temData subdataWithRange:NSMakeRange(i, pcmLength - i)];
        self.temPCMData = [pcmSubData mutableCopy];
    }
    return nil;
}
-(CMSampleBufferRef)__createAudioSampleBufferWithdata:(NSData *)data audioSampleRate:(int)audioSampleRate audioChannels:(int)audioChannels bitsPerChannel:(int)bitsPerChannel{
    self.audioDataIndex++;
    OSStatus result;
    
    AudioStreamBasicDescription audioDescription;
    audioDescription.mSampleRate = self.audioSampleRate;
    audioDescription.mChannelsPerFrame = self.audioChannels;
    audioDescription.mBitsPerChannel = self.bitsPerChannel;
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mFramesPerPacket = 1;
    audioDescription.mBytesPerFrame = audioDescription.mBitsPerChannel / 8 * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame * audioDescription.mFramesPerPacket;
    audioDescription.mReserved = 0;
    
    CMAudioFormatDescriptionRef cmAudioFormatDescriptionRef;
    CMAudioFormatDescriptionCreate(NULL, &audioDescription, 0, NULL, 0, NULL, NULL, &cmAudioFormatDescriptionRef);
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    size_t data_len = data.length;
    
    // _blockBuffer is a CMBlockBufferRef instance variable
    
    size_t blockLength = data.length;
    result = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                NULL,
                                                blockLength,
                                                NULL,
                                                NULL,
                                                0,
                                                data_len,
                                                kCMBlockBufferAssureMemoryNowFlag,
                                                &blockBuffer);
    
    if (result != noErr) {
        NSLog(@"create block buffer failed! result:%@  data_len:%@",@(result),@(data_len));
        return NULL;
    }
    
    result = CMBlockBufferReplaceDataBytes([data bytes], blockBuffer, 0, [data length]);
    
    // check error
    if (result != noErr) {
        NSLog(@"replace block buffer failed! result:%@",@(result));
        return NULL;
    }
    
    int64_t ptst = (_audioDataIndex * (1000.0 / audioSampleRate)) *(TIME_SCALE/1000);
    //    DLog(@"pts:%lld",pts);
    CMTime pts = CMTimeMake(ptst, TIME_SCALE);
    
    
    CMSampleTimingInfo timeInfoArray[1] = { {
        .duration = CMTimeMake(1024, audioSampleRate),
        .presentationTimeStamp = pts,
        .decodeTimeStamp = pts,
    } };
    size_t samplesizesarray[1024] = {2};
    for (int i = 0; i < 1024; i++) {
        samplesizesarray[i] = 2;
    }
    
    result = CMSampleBufferCreate(kCFAllocatorDefault,//
                                  blockBuffer,//dataBuffer
                                  YES,//dataReady
                                  NULL,//makeDataReadyCallback
                                  NULL,//makeDataReadyRefcon
                                  cmAudioFormatDescriptionRef,
                                  1024,//numSamples
                                  1,//numSampleTimingEntries
                                  timeInfoArray,//
                                  1,
                                  samplesizesarray,//sampleSizeArray
                                  &sampleBuffer);
    if (result != noErr) {
        NSLog(@"CMSampleBufferCreate result:%@",@(result));
        return NULL;
    }
    if (result == noErr) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES) ;
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef) CFArrayGetValueAtIndex(attachments, 0) ;
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue) ;
    }
    CFAutorelease(blockBuffer) ;
    CFAutorelease(sampleBuffer) ;
    // check error
    return sampleBuffer;
}
@end
