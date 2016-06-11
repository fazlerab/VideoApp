//
//  VAPlayerView.m
//  VideoApp
//
//  Created by Imran on 3/24/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import "VAPlayerView.h"

@implementation VAPlayerView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (instancetype) init {
    self = [super init];
    if (self) {
        [self setBackgroundColor:[UIColor darkGrayColor]];
    }
    return self;
}

- (void)setPlayer:(AVPlayer *)player {
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)[self layer];
    [playerLayer setPlayer:player];
}

- (AVPlayer *)player {
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)[self layer];
    return [playerLayer player];
}

- (float)nominalFrameRate {
    float fps = 0.0;
    AVPlayerItem *playerItem = [self.player  currentItem];
    
    AVAsset *asset = [playerItem asset];
    NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    
    for(AVAssetTrack *track in tracks) {
        fps = track.nominalFrameRate;
    }
    
    return fps;
}

@end
