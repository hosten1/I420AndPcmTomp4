# ESCAssetWriterToMp4Tool
 NV12 stream and pcm stream to mp4 file

* 从WebRTC 获取视频流：通过回调接口生成RTCVideoFrame

```objectivec
void  PeerConnectionDelegateAdapter::OnMixVideoStreamI420(char* videoFrame, int width, int height, int yuv_size) {
    RTCPeerConnection *peer_connection = peer_connection_;
    if (peer_connection.isRecord) {
        int stride_y = width;
        int stride_uv = (width + 1) / 2;
        int target_width = width;
        int target_height = abs(height);
        // Setting absolute height (in case it was negative).
        // In Windows, the image starts bottom left, instead of top left.
        // Setting a negative source height, inverts the image (within LibYuv).
        
        // TODO(nisse): Use a pool?
        rtc::scoped_refptr<I420Buffer> buffer = I420Buffer::Create(
                                                                   target_width, target_height, stride_y, stride_uv, stride_uv);
        
        libyuv::RotationMode rotation_mode = libyuv::kRotate0;
        const int conversionResult = libyuv::ConvertToI420(
                                                           (const uint8_t *)videoFrame, yuv_size, buffer.get()->MutableDataY(),
                                                           buffer.get()->StrideY(), buffer.get()->MutableDataU(),
                                                           buffer.get()->StrideU(), buffer.get()->MutableDataV(),
                                                           buffer.get()->StrideV(), 0, 0,  // No Cropping
                                                           width, height, target_width, target_height, rotation_mode,
                                                           libyuv::FOURCC_I420);
        if (conversionResult < 0) {
            RTC_LOG(LS_ERROR) << "Failed to convert capture frame from type "
            << static_cast<int>(libyuv::FOURCC_I420) << "to I420.";
            return ;
        }
        VideoFrame captureFrame =
        VideoFrame::Builder()
        .set_video_frame_buffer(buffer)
        .set_timestamp_rtp(0)
        .set_timestamp_ms(rtc::TimeMillis())
        .set_rotation(kVideoRotation_0)
        .build();
        captureFrame.set_ntp_time_ms(0);
       
        
        if ([peer_connection.delegate
             respondsToSelector:@selector(peerConnection:didReciveMixVideoStreamI420:width:height:yuv_size:rtcvideoFrame:)]) {
            @autoreleasepool {
                id<RTCVideoFrameBuffer> frameBuffer = ToObjCVideoFrameBuffer(captureFrame.video_frame_buffer());

                RTCVideoFrame *rtcvideoFrame = [[RTCVideoFrame alloc] initWithBuffer:frameBuffer rotation:RTCVideoRotation(captureFrame.rotation()) timeStampNs:captureFrame.timestamp_us() * rtc::kNumNanosecsPerMicrosec];
                rtcvideoFrame.timeStamp = captureFrame.timestamp();
                [peer_connection.delegate peerConnection:peer_connection didReciveMixVideoStreamI420:videoFrame width:width height:height yuv_size:yuv_size rtcvideoFrame:rtcvideoFrame];
            };
            
        }else{
            if ([peer_connection.delegate
                 respondsToSelector:@selector(peerConnection:didReciveMixVideoStreamI420:width:height:yuv_size:Buffer:rotation:timeStampNs:)]) {
                @autoreleasepool {
                    id<RTCVideoFrameBuffer> frameBuffer = ToObjCVideoFrameBuffer(captureFrame.video_frame_buffer());
                    [peer_connection.delegate peerConnection:peer_connection didReciveMixVideoStreamI420:videoFrame width:width height:height yuv_size:yuv_size Buffer:frameBuffer rotation:RTCVideoRotation(captureFrame.rotation())timeStampNs:captureFrame.timestamp_us() * rtc::kNumNanosecsPerMicrosec];
                    frameBuffer = nil;
                };
                
            }
        }
       
        //        rtcvideoFrame = nil
    }

    
}
```

* 然后使用WebRTC的`RTCVideoDecoderH264`文件编码成h264文件：获取编码后的文件利用libmp4v2库生成MP4;

