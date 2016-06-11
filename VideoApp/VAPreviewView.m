//
//  PreviewView.m
//  VideoApp
//
//  Created by Imran on 3/9/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import "VAPreviewView.h"

@implementation VAPreviewView

+ (Class) layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *) session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    return previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    previewLayer.session = session;
}

@end
