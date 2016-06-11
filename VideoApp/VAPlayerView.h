//
//  VAPlayerView.h
//  VideoApp
//
//  Created by Imran on 3/24/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VAPlayerView : UIView

@property (nonatomic, strong) AVPlayer *player;

- (float)nominalFrameRate;
@end
