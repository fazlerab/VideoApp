//
//  PreviewView.h
//  VideoApp
//
//  Created by Imran on 3/9/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VAPreviewView : UIView

@property (nonatomic, strong) AVCaptureSession *session;

@end
