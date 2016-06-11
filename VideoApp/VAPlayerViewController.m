//
//  VAPlayerViewController.m
//  VideoApp
//
//  Created by Imran on 3/24/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "VAPlayerViewController.h"
#import "VAPlayerView.h"

static void *ItemStatusContext = &ItemStatusContext;


@interface VAPlayerViewController ()

@property (strong, nonatomic) VAPlayerView *playerView;
@property (strong, nonatomic) AVPlayerItem *playerItem;

@property (strong, nonatomic) UISlider *playSpeedSlider;
@property (strong, nonatomic) UILabel *speedValueLabel;
@property (strong, nonatomic) UILabel *frameRateLabel;

@property (strong, nonatomic) UIButton *playPauseButton;
@property (strong, nonatomic) UISlider *timeSlider;

@property (strong, nonatomic) id timeObserver;
@property (strong, nonatomic) NSLayoutConstraint *topConstraint;
@property (nonatomic) BOOL isPlaying;

@end

@implementation VAPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    
    NSString *name = nil;
    [self.videoURL getResourceValue:&name forKey:NSURLNameKey error:nil];
    if (name) {
        [self setTitle:name];
    }
    
    self.isPlaying = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.playSpeedSlider setValue:1.0];
    [self setupPlayer];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

- (void)updateViewConstraints {
    [self.topConstraint setConstant:[self barHeight]];
    [super updateViewConstraints];
}

- (void)viewDidDisappear:(BOOL)animated {
    if (self.isPlaying) {
        [self pause];
    }
    [self teardownPlayer];
    [super viewDidDisappear:animated];
}

- (float)barHeight {
    float barHeight = self.navigationController.navigationBar.bounds.size.height;
    
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (statusBarOrientation == UIInterfaceOrientationPortrait) {
        barHeight += [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    
    return barHeight;
}

- (void)setupUI {
    NSDictionary *views;
    NSArray *constraints;
    UIColor *backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
    
    // PlayerView
    VAPlayerView *playerView = [[VAPlayerView alloc] init];
    [self.view addSubview:playerView];
    self.playerView = playerView;
    
    playerView.translatesAutoresizingMaskIntoConstraints = NO;
    views = NSDictionaryOfVariableBindings(playerView);
    
    // playerView.top = 1.0 * superView.top + navigationBar.height + statusBar.height
    self.topConstraint =  [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTopMargin multiplier:1.0 constant:[self barHeight]];
    self.topConstraint.active = YES;
    
    // playerView.bottom = 1.0 * superView.bottom + 0.0
    [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0].active = YES;
    
    // playerView.leading = 1.0 * superView.leading + 0.0
    // playerView.trailing = 1.0 * superView.trailing + 0.0
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[playerView]|"
                                                          options:0 metrics:nil views:views];
    [NSLayoutConstraint activateConstraints:constraints];
    //-------------------------------------------------------------------------------------------------------------//
    
    
    // Play/Pause button
    UIButton *playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    playPauseButton.backgroundColor = backgroundColor;
    [playPauseButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    [playPauseButton addTarget:self action:@selector(handlePlayPause:) forControlEvents:UIControlEventTouchUpInside];
    self.playPauseButton = playPauseButton;
    
    // Time UISlider
    UISlider *timeSlider = [[UISlider alloc] init];
    timeSlider.backgroundColor = backgroundColor;
    timeSlider.minimumTrackTintColor = [UIColor yellowColor];
    timeSlider.maximumTrackTintColor = [UIColor grayColor];
    [timeSlider setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [timeSlider setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    timeSlider.continuous = NO;
    [timeSlider addTarget:self action:@selector(handleTimeSlider:) forControlEvents:UIControlEventValueChanged];
    self.timeSlider = timeSlider;
    
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[playPauseButton, timeSlider]];
    [stackView setAxis:UILayoutConstraintAxisHorizontal];
    [stackView setDistribution:UIStackViewDistributionFill];
    [stackView setSpacing:2.0];
    [self.view addSubview:stackView];
    
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    views = NSDictionaryOfVariableBindings(stackView);
    
    // stackView.bottom = 1.0 * superView.bottom + standardSpacing
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[stackView]|"
                                                          options:0 metrics:nil views:views];
    // stackView.leading = 1.0 * superView.leading + standardSpacing
    // stackView.trailing = 1.0 * superViwe.trailing + standardSpacing
    [NSLayoutConstraint activateConstraints:constraints];
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[stackView]|"
                                                          options:0 metrics:nil views:views];
    [NSLayoutConstraint activateConstraints:constraints];
    
    //------------------------------------------------------------------------------------------------------------//
    
    // Play speed slider
    UISlider *playSpeedSlider = [[UISlider alloc] init];
    [playSpeedSlider setBackgroundColor:backgroundColor];
    [playSpeedSlider setMinimumValue:0.0];
    [playSpeedSlider setMaximumValue:2.0];
    [playSpeedSlider addTarget:self action:@selector(handlePlaySpeedChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:playSpeedSlider];
    self.playSpeedSlider = playSpeedSlider;
    
    UIFont *labelFont = [UIFont fontWithName:@"Helvetica Neue" size:15.0];
    
    UILabel *speedLabel = [[UILabel alloc] init];
    [speedLabel setFont:labelFont];
    [speedLabel setBackgroundColor:backgroundColor];
    [speedLabel setText:@" Play Speed:"];
    [self.view addSubview:speedLabel];
    
    UILabel *speedValueLabel = [[UILabel alloc] init];
    [speedValueLabel setFont:labelFont];
    [speedValueLabel setBackgroundColor:backgroundColor];
    [speedValueLabel setText:@"1.0x "];
    [self.view addSubview:speedValueLabel];
    self.speedValueLabel = speedValueLabel;
    
    playSpeedSlider.translatesAutoresizingMaskIntoConstraints = NO;
    speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    speedValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    views = NSDictionaryOfVariableBindings(playSpeedSlider, speedLabel, speedValueLabel);
    
    // speedStackView.top = 1.0 * playerView.top + 0.0
    [NSLayoutConstraint constraintWithItem:playSpeedSlider attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:playerView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0].active = YES;
    
    // speedStackView.leading = 1.0 * superView.leading + standardSpacing
    // speedStackView.trailing = 1.0 * superView.trailing + standardSpacing
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[speedLabel]-(2)-[playSpeedSlider]-(2)-[speedValueLabel]|" options:NSLayoutFormatAlignAllTop metrics:nil views:views];
    [NSLayoutConstraint activateConstraints:constraints];
    
    [NSLayoutConstraint constraintWithItem:speedLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:playSpeedSlider attribute:NSLayoutAttributeHeight multiplier:1.0 constant:1.0].active = YES;
    
    [NSLayoutConstraint constraintWithItem:speedValueLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:playSpeedSlider attribute:NSLayoutAttributeHeight multiplier:1.0 constant:1.0].active = YES;
    //------------------------------------------------------------------------------------------------------------//
    
    UILabel *frameRateLabel = [[UILabel alloc] init];
    //[frameRateLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size:15.0]];
    [frameRateLabel setBackgroundColor:backgroundColor];
    [frameRateLabel setTextColor:[UIColor yellowColor]];
    [self.view addSubview:frameRateLabel];
    self.frameRateLabel = frameRateLabel;
    
    frameRateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    [NSLayoutConstraint constraintWithItem:frameRateLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.playSpeedSlider attribute:NSLayoutAttributeBottom multiplier:1.0 constant:8.0].active = YES;
    
    [NSLayoutConstraint constraintWithItem:frameRateLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0].active = YES;

}

- (void)setupPlayer {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.videoURL options:nil];
    
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
            
            if (status == AVKeyValueStatusLoaded) {
                
                self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
                
                [self.playerItem addObserver:self
                                  forKeyPath:@"status"
                                     options:NSKeyValueObservingOptionInitial
                                     context:ItemStatusContext];
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                       selector:@selector(playerItemDidReachEnd:)
                                                           name:AVPlayerItemDidPlayToEndTimeNotification
                                                         object:self.playerItem];
                
                AVPlayer *player = [AVPlayer playerWithPlayerItem:self.playerItem];
                
                self.timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(600, 600)
                                                     queue:dispatch_get_main_queue()
                                                usingBlock:^(CMTime time) {
                                                    [self updateTimeUI:time];
                                                }];
                
                [self.playerView setPlayer:player];
                [self play];
           }
            else {
                NSLog(@"The asset's tracks were not loaded. %@", error.localizedDescription);
            }
        });
    }];
}

- (void)teardownPlayer {
    if (self.playerView.player) {
        [self.playerView.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.playerItem];
    
    [self.playerItem removeObserver:self forKeyPath:@"status" context:ItemStatusContext];
}

// MARK: Observe 'status' key-value of AVPlayerItem
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (context == ItemStatusContext) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.playerItem && self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
                Float64 totalSeconds = CMTimeGetSeconds([self.playerItem duration]);
                
                [self.timeSlider setMinimumValue:0.0];
                [self.timeSlider setMaximumValue:totalSeconds];
                [self.timeSlider setValue:0.0 animated:YES];
                
                [self updateTimeUI:kCMTimeZero];

                self.playPauseButton.enabled = YES;
                self.timeSlider.enabled = YES;
           }
        });
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)play {
    self.isPlaying = YES;
    [self.playPauseButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
    [self.playerView.player setRate:[self.playSpeedSlider value]];
    [self.playerView.player play];
    self.frameRateLabel.text =[NSString stringWithFormat:@" %02.0f fps ", [self.playerView nominalFrameRate]];
}

- (void)pause {
    self.isPlaying = NO;
    [self.playPauseButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    [self.playerView.player pause];
}

- (void)updateTimeUI:(CMTime)elapsedTime {
     CMTime remainingTime = CMTimeSubtract([self.playerItem duration], elapsedTime);
    
    Float64 elapsedSeconds = CMTimeGetSeconds(elapsedTime);
    Float64 remainingSeconds = CMTimeGetSeconds(remainingTime);
    
    NSString *minText = [NSString stringWithFormat:@" %02i:%02i",  (int)floor(elapsedSeconds/60),   (int)floor(fmod(elapsedSeconds, 60))];
    NSString *maxText = [NSString stringWithFormat:@"-%02i:%02i ", (int)floor(remainingSeconds/60), (int)floor(fmod(remainingSeconds, 60))];
    
    [self.timeSlider setValue:(float)elapsedSeconds animated:YES];
    [self.timeSlider setMinimumValueImage:[self.class imageFromText:minText]];
    [self.timeSlider setMaximumValueImage:[self.class imageFromText:maxText]];
    
    /*
    AVAssetTrack *assetTrack = [self.playerView.player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    NSLog(@"frame-rate: %f", assetTrack.nominalFrameRate);
     */
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.playerView.player seekToTime:kCMTimeZero];
    [self updateTimeUI:kCMTimeZero];
    [self pause];
}

- (void)handlePlayPause:(UIBarButtonItem *)sender {
    if (self.isPlaying) {
        [self pause];
    }
    else {
        [self play];
    }
}

- (void)handleTimeSlider:(UISlider *)sender {
    float selectedSecond = [sender value];
    CMTime selectedTime = CMTimeMakeWithSeconds(selectedSecond, 1);
    [self.playerItem cancelPendingSeeks];
    [self.playerItem seekToTime:selectedTime];
}

- (void)handlePlaySpeedChange:(UISlider *)sender {
    NSString *speedValueText = [NSString stringWithFormat:@" %01.01fx ", [sender value]];
    self.speedValueLabel.text = speedValueText;
    if (self.isPlaying) {
        [self.playerView.player setRate:[sender value]];
    }
}

+ (UIImage *)imageFromText:(NSString *)text {
    UIFont *font = [UIFont fontWithName:@"Helvetica Neue" size:15.0];
    CGSize size = [text sizeWithAttributes:@{NSFontAttributeName:font}];
    
    UIGraphicsBeginImageContext(size);
    [text drawAtPoint:CGPointZero withAttributes:@{NSFontAttributeName:font,
                                                   NSForegroundColorAttributeName:[UIColor blackColor]}];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
