//
//  ESCAACEncoder.m
//  ESCAACCoderDemo
//
//  Created by xiang on 2018/10/9.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAACEncoder.h"
#import "faac/include/faac.h"


@interface ESCAACEncoder ()

@property(nonatomic,assign)faacEncHandle encoder;

@property(nonatomic,assign)    faacEncConfigurationPtr pConfiguration;//aac设置指针

@property(nonatomic,assign)int inputSamples;

@property(nonatomic,assign)int inputBytes;

@property(nonatomic,assign)int maxOutputBytes;

@property(nonatomic,strong)NSMutableData* temPCMData;

@end

@implementation ESCAACEncoder

- (void)setupEncoderWithSampleRate:(int)sampleRate channels:(int)channels sampleBit:(int)sampleBit{
    unsigned long inputSamples;
    unsigned long maxOutputBytes;
    //初始化aac句柄，同时获取最大输入样本，及编码所需最小字节
    faacEncHandle encoder = faacEncOpen(sampleRate, channels, &inputSamples, &maxOutputBytes);
    self.encoder = encoder;
    
    self.inputSamples = (int)inputSamples;
    self.maxOutputBytes = (int)maxOutputBytes;
    
    int nMaxInputBytes = (int)inputSamples * sampleBit / 8;
    self.inputBytes = nMaxInputBytes;
    
    // (2.1) Get current encoding configuration
    self.pConfiguration = faacEncGetCurrentConfiguration(self.encoder);//获取配置结构指针
    self.pConfiguration->inputFormat = FAAC_INPUT_16BIT;
    self.pConfiguration->outputFormat=1;
    self.pConfiguration->useTns=true;
    self.pConfiguration->useLfe=false;
    self.pConfiguration->aacObjectType=LOW;
    self.pConfiguration->shortctl=SHORTCTL_NORMAL;
    self.pConfiguration->quantqual=100;
    self.pConfiguration->bandWidth=0;
    self.pConfiguration->bitRate=0;
    // (2.2) Set encoding configuration
    int nRet = faacEncSetConfiguration(self.encoder, self.pConfiguration);//设置配置，根据不同设置，耗时不一样

    if (nRet < 0) {
        NSLog(@"set failed!");
    }
    

}

- (NSData *)encodePCMDataWithPCMData:(NSData *)pcmData {
    if (self.temPCMData == nil) {
        self.temPCMData = [NSMutableData data];
    }
    NSData *temData = pcmData;
    if (self.temPCMData.length > 0) {
        [self.temPCMData appendData:pcmData];
        temData = self.temPCMData;
        self.temPCMData = nil;
    }
    
    //首先判断pcmData的长度
    int pcmLength = (int)temData.length;
    int i = 0;
    
    int writeLength = _inputBytes;
    
    while (i + writeLength <= pcmLength && pcmLength >= writeLength) {
        NSData *pcmSubData = [temData subdataWithRange:NSMakeRange(i, writeLength)];
        i += writeLength;
        return  [self __encodePCMDataWithPCMData:pcmSubData];
    }
    if (i < pcmLength) {
        NSData *pcmSubData = [temData subdataWithRange:NSMakeRange(i, pcmLength - i)];
        self.temPCMData = [pcmSubData mutableCopy];
    }else{
        return nil;
    }
    
    return nil;
//    return temData;
}
- (NSData *) __encodePCMDataWithPCMData:(NSData *)pcmData {
    int32_t *pPcmData = (int32_t *)[pcmData bytes];
    
    unsigned char *outputBuffer[self.maxOutputBytes];
    
    NSMutableData *temData = [NSMutableData data];
    //编码
    int outLength = faacEncEncode(self.encoder, pPcmData, self.inputSamples, outputBuffer, self.maxOutputBytes);
    //组装数据
    if (outLength > 0) {
        [temData appendBytes:outputBuffer length:outLength];
    }else {
        NSLog(@"__encodePCMDataWithPCMData:no data");
    }
     return temData;
}
- (void)closeEncoder {
    faacEncClose(self.encoder);
}

@end
