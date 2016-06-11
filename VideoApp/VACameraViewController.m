//
//  VACameraViewController.m
//  VideoApp
//
//  Created by Imran on 3/9/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "VACameraViewController.h"
#import "VAPreviewView.h"
#import "VAFrameRatePickerDelegate.h"

NSString *const NewRecordingNotification = @"NewRecordingNotification";
NSString *const NewRecordingFileURLKey = @"NewRecordingFileURLKey";

static void *SessionRunningContext = &SessionRunningContext;

static dispatch_once_t oneceToken;
//static NSDateFormatter *movieFilenameDateTimeFormater;
static NSDateComponentsFormatter *recordTimeFormatter;

@interface VACameraViewController () <AVCaptureFileOutputRecordingDelegate>

@property (weak, nonatomic) IBOutlet VAPreviewView *previewView;
@property (weak, nonatomic) IBOutlet UILabel *recordTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;

@property (weak, nonatomic) IBOutlet UIPickerView *frameRatePicker;
@property (strong, nonatomic) VAFrameRatePickerDelegate *frameRatePickerDelegate;

@property (strong, nonatomic) AVCaptureSession *session;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureDeviceInput *cameraInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;

@property (nonatomic, weak) NSTimer *recordtimer;
@property (nonatomic) NSTimeInterval recordTimeElapsed; //will be <= 0

@property (nonatomic) BOOL canRecord;

@end

@implementation VACameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Video Recorder";
    
    dispatch_once(&oneceToken, ^{
        //movieFilenameDateTimeFormater = [[NSDateFormatter alloc] init];
        //movieFilenameDateTimeFormater.dateFormat = @"yyMMddHHmmssSSS";
        
        recordTimeFormatter = [[NSDateComponentsFormatter alloc] init];
        recordTimeFormatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        recordTimeFormatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        recordTimeFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
    });
    
    self.recordTimeElapsed = 0;
    
    self.switchCameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    
    UIImage *switchImage = [self.switchCameraButton.imageView image];
    self.switchCameraButton.imageView.image = [switchImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.switchCameraButton.imageView setTintColor:[UIColor whiteColor]];
    
    
    [self.recordButton.layer setCornerRadius:20.0];
    [self.recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
    
    self.frameRatePickerDelegate  = [[VAFrameRatePickerDelegate alloc] initWithPickerView:self.frameRatePicker];
    
    [self setupCaptureSession];
    [self getAuthorization];
    [self setupCaptureDevices];    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.recordTimeLabel.text = @"";
    
    dispatch_async(self.sessionQueue, ^{
        if (self.canRecord) {
            [self addObservers];
            [self.session startRunning];
        }
        else {
            NSLog(@"Cannot run");
        }
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    dispatch_async(self.sessionQueue, ^{
        if (self.canRecord) {
            [self.session stopRunning];
            [self removeObservers];
        }
    });
    
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK: AVCapture methods
// AVCaptureSession manages flow of data from input devices (cameras and microphone)
// to output objects (movie files and still images.
- (void)setupCaptureSession {
    self.sessionQueue = dispatch_queue_create("SessionQueue", DISPATCH_QUEUE_SERIAL);
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    self.session = session;
    self.previewView.session = session;
}

// Check if user has given authorization to use the camera
// If not ask user for authorization to use the camera to record.
- (void)getAuthorization {
    self.canRecord = YES;
    NSString *mediaType = AVMediaTypeVideo;
    
    NSUInteger authorization = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    
    switch(authorization) {
        case AVAuthorizationStatusNotDetermined: {
            dispatch_suspend(self.sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
                self.canRecord = granted;
                dispatch_resume(self.sessionQueue);
            }];
        }
        case AVAuthorizationStatusAuthorized: {
            break;
        }
        default: {
            self.canRecord = NO;
            break;
        }
    }
}

// Setup the video and audio devices
- (void)setupCaptureDevices {
    dispatch_async(self.sessionQueue, ^{
        if (!self.canRecord) {
            return;
        }
        
        // Configure devices
        [self.session beginConfiguration];
        
        // Setup video device and its input
        self.canRecord = [self createCameraInput];
        
        // Setup audio device and its input
        [self createMicrophoneInput];
        
        // Setup movie file output
        self.canRecord = self.canRecord && [self createMovieFileOutput];
        
        // set the video layer of view's orientation to the orientation of the device
        dispatch_async(dispatch_get_main_queue(), ^{
            UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
            
            AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
            if (statusBarOrientation != UIInterfaceOrientationUnknown) {
                initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
            }
            
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            //[previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            previewLayer.connection.videoOrientation = initialVideoOrientation;
            
        });
        
        [self.session commitConfiguration];
    });
}

// Create Camera Capture Input
- (BOOL)createCameraInput {
    BOOL success = YES;
    
    AVCaptureDevice *camera = [VACameraViewController cameraOfPosition:AVCaptureDevicePositionBack];
    
    NSError *error;
    AVCaptureDeviceInput *cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (cameraInput && [self.session canAddInput:cameraInput]) {
        [self.session addInput:cameraInput];
        self.cameraInput = cameraInput;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.frameRatePickerDelegate setFrameRatesForDevice:camera];
            [self.frameRatePickerDelegate selectFrameRateForFormat:[camera activeFormat]];
        });
    }
    else {
        NSLog(@"Cannot create camera input: %@", error.localizedDescription);
        success = NO;
    }
    
    return success;
}

// Create Microphone Capture Input
- (BOOL)createMicrophoneInput {
    BOOL success = YES;
    AVCaptureDevice *microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    NSError *error;
    AVCaptureDeviceInput *microphoneInput = [AVCaptureDeviceInput deviceInputWithDevice:microphone error:&error];
    if (microphoneInput && [self.session canAddInput:microphoneInput]) {
        [self.session addInput:microphoneInput];
    }
    else {
        NSLog(@"Cannot add audio microphone input to the capture session: %@", error.localizedDescription);
        success = NO;
    }
    
    return success;
}

// Create Movie File Capture Output
- (BOOL)createMovieFileOutput {
    BOOL success = YES;
    
    AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ( [self.session canAddOutput:movieFileOutput] ) {
        [self.session addOutput:movieFileOutput];
        
        // Configure Stabilization mode
        AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoStabilizationSupported) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        self.movieFileOutput = movieFileOutput;
    }
    else {
        NSLog(@"Error: Cannot add movie file output to session.");
        success = NO;
    }
    
    return success;
}

// Create Still Image Capture Output
- (BOOL)createStillImageOutput {
    BOOL success = YES;
    
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    if ([self.session canAddOutput:stillImageOutput]) {
        [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        [self.session addOutput:stillImageOutput];
        self.stillImageOutput = stillImageOutput;
    }
    else {
        NSLog(@"Error: Cannot add still image outupt to session.");
        success = NO;
    }
    
    return success;
}


// MARK: KVOs and Notifications
- (void)addObservers {
    // Capture session KVO
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:&SessionRunningContext];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // Capture session notifications
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:)
                               name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    [notificationCenter addObserver:self selector:@selector(sessionWasInterrupted:)
                               name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [notificationCenter addObserver:self selector:@selector(sessionInterruptionEnded:)
                               name:AVCaptureSessionInterruptionEndedNotification object:self.session ];
}

- (void)removeObservers {
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (context == SessionRunningContext) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        NSLog(@"isSessionRunning=%d", isSessionRunning);
        
        self.switchCameraButton.enabled = isSessionRunning;
        self.recordButton.enabled = isSessionRunning;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)sessionRuntimeError:(NSNotification *)notification {
    NSLog(@"sessionRuntimeError: %@", notification);
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
    NSLog(@"sessionWasInterrupted: %@", notification);
}

- (void) sessionInterruptionEnded:(NSNotification *)notification {
    NSLog(@"sessionInterruptionEnded: %@", notification);
}

// MARK: Orientation change
- (BOOL)shouldAutorotate {
    return !self.movieFileOutput.isRecording;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Note that the app delegate controls the device orientation notifications required to use the device orientation.
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsPortrait(deviceOrientation) || UIDeviceOrientationIsLandscape(deviceOrientation)) {
        AVCaptureVideoPreviewLayer *previewView = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        previewView.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

// MARK: File output recording delegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    [self startRecordTime];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordTimeLabel.text = @"0:00:00";
        
        [UIView animateWithDuration:0.5 animations:^{
            [self.recordButton setTitle:@"Stop" forState:UIControlStateNormal];
            [self.recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self.recordButton setBackgroundColor:[UIColor redColor]];

        } completion:^(BOOL finished) {
            if (finished) {
                self.recordButton.enabled = YES;
            }
        }];
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    [self stopRecordTime];
    
    BOOL success = YES;
    if (error) {
        NSLog(@"Movie recording finished with Error: %@", error.localizedDescription);
        success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    if (success) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter postNotificationName:NewRecordingNotification
                                          object:self
                                        userInfo:@{NewRecordingFileURLKey:outputFileURL}];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{
            [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
            [self.recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            [self.recordButton setBackgroundColor:[UIColor whiteColor]];
        } completion:^(BOOL finished) {
            if (finished) {
                self.recordButton.enabled = YES;
                self.switchCameraButton.enabled = YES;
                self.frameRatePicker.userInteractionEnabled = YES;
            }
        }];
    });
}

// MARK: Record Time Display
- (void) startRecordTime {
    NSDate *startTime = [NSDate dateWithTimeIntervalSinceNow:self.recordTimeElapsed];
    NSTimer *recordTimer = [NSTimer scheduledTimerWithTimeInterval:0.20 target:self
                                                          selector:@selector(updateRecordTime:)
                                                          userInfo:startTime repeats:YES];
    self.recordtimer = recordTimer;
}

int timerCount = 0;
- (void)updateRecordTime:(NSTimer *)timer {
    if (timerCount == 5) {
        timerCount = 0;
        NSDate *startTime = (NSDate *)timer.userInfo;
        // need negative number to adjust the record time when recording resume
        self.recordTimeElapsed = [startTime timeIntervalSinceNow];
        NSString *recordTime = [recordTimeFormatter stringFromTimeInterval:fabs(self.recordTimeElapsed)];
        self.recordTimeLabel.text = recordTime;
    }
    
    timerCount++;
}

- (void) stopRecordTime {
    [self.recordtimer invalidate];
    self.recordTimeElapsed = 0;
}


// MARK: Actions
- (IBAction)handleRecordButton:(UIButton *)sender {
    self.switchCameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    self.frameRatePicker.userInteractionEnabled = NO;
    
    dispatch_async((self.sessionQueue), ^{
        if (!self.movieFileOutput.isRecording) {
            // Update the camera format (frame rate)
            AVCaptureDevice *camera = [self.cameraInput device];
            NSLog(@"activeFormat: %@", [camera activeFormat]);
            
            NSNumber *selectedFrameRate = [self.frameRatePickerDelegate selectedFrameRate];
            AVCaptureDeviceFormat *bestFormat = [self.class bestFormatForFrameRate:selectedFrameRate.floatValue camera:camera];
            CMTime minFrameDuration = ((AVFrameRateRange *)[[bestFormat videoSupportedFrameRateRanges] firstObject]).minFrameDuration;
        
            NSLog(@"Recording frameRate: %f minFrameDuration: (%lli,%i)\nformat: %@", selectedFrameRate.floatValue, minFrameDuration.value, minFrameDuration.timescale, bestFormat);
            
            NSError *error;
            if ([camera lockForConfiguration:&error]) {
                [camera setActiveFormat:bestFormat];
                [camera setActiveVideoMinFrameDuration:minFrameDuration];
                [camera setActiveVideoMaxFrameDuration:minFrameDuration];
                [camera unlockForConfiguration];
            }
            else {
                NSLog(@"Cannot set camera's format: %@", error.localizedDescription);
            }
            
            // Update the orientation of the movieFileOutput connection before starting recording
            AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            
            AVCaptureVideoPreviewLayer *previewView = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            connection.videoOrientation = previewView.connection.videoOrientation;
            
            NSURL *outputFileURL = [VACameraViewController movieFileURL];
            [self.movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
        }
        else {
            [self.movieFileOutput stopRecording];
        }
    });
}

- (IBAction)handleSwitchCameraButton:(UIButton *)sender {
    self.switchCameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *currentCamera = self.cameraInput.device;
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        AVCaptureDevicePosition currentPosition = currentCamera.position;
        
        switch (currentPosition) {
            case AVCaptureDevicePositionUnspecified:
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
                
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                break;
                
            default:
                break;
        }
        
        NSError *error = nil;
        AVCaptureDevice *camera = [VACameraViewController cameraOfPosition:preferredPosition];
        AVCaptureDeviceInput *cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
        
        [self.session beginConfiguration];
        
        // Remove existing device first
        [self.session removeInput:self.cameraInput];
        
        if (cameraInput && [self.session canAddInput:cameraInput]) {
            [self.session addInput:cameraInput];
            self.cameraInput = cameraInput;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.frameRatePickerDelegate setFrameRatesForDevice:camera];
                [self.frameRatePickerDelegate selectFrameRateForFormat:camera.activeFormat ];
            });
        }
        else {
            NSLog(@"Cannot switch camera: %@", error.localizedDescription);
            [self.session addInput:self.cameraInput];
        }
        
        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        [self.session commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.switchCameraButton.enabled = YES;
            self.recordButton.enabled = YES;
        });
    });
}

// MARK: Helper methods

+ (AVCaptureDeviceFormat *)bestFormatForFrameRate:(float)frameRate camera:(AVCaptureDevice *)camera {
    AVCaptureDeviceFormat *activeFormat = [camera activeFormat];
    AVFrameRateRange *activeFrameRateRange = [[activeFormat videoSupportedFrameRateRanges] firstObject];
    if (activeFrameRateRange.maxFrameRate >= frameRate) {
        return activeFormat;
    }
    
    NSArray<AVCaptureDeviceFormat *> *allFormats = [camera formats];
    AVCaptureDeviceFormat *bestFormat = nil;
    
    for(AVCaptureDeviceFormat *format in allFormats) {
        AVFrameRateRange *frameRateRange = [[format videoSupportedFrameRateRanges] firstObject];
        
        if (frameRateRange.maxFrameRate >= frameRate) {
            if (bestFormat == nil) {
                bestFormat = format;
                continue;
            }
            
            CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            CMVideoDimensions bestDimension = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription);
            
            if (dimension.height > bestDimension.height) {
                bestFormat = format;
            }
        }
    }
    
    return bestFormat;
}

+ (AVCaptureDevice *)cameraOfPosition:(AVCaptureDevicePosition)possition {
    AVCaptureDevice *camera = nil;
    
    NSArray<AVCaptureDevice *> *captureDevices =  [AVCaptureDevice devices];
    for(AVCaptureDevice *captureDevice in captureDevices) {
        if ([captureDevice hasMediaType:AVMediaTypeVideo] &&
            (captureDevice.position == possition)) {
            camera = captureDevice;
        }
    }
    
    return camera;
}


/*
- (NSURL *)outputMovieFileURL {
    NSString *filename = [movieFilenameDateTimeFormater stringFromDate:[NSDate date]];
    filename = [filename stringByAppendingPathExtension:@"mov"];
    
    NSURL *movieDir = [[VAUtil sharedUtil] movieDirectoryPath];
    NSURL *movieFile = [movieDir URLByAppendingPathComponent:filename];
    
    //NSLog(@"Movie file URL = %@", movieFile);
    
    return movieFile;
}
*/

+ (NSURL *)movieFileURL {
    NSURL *movieFileURL = nil;
    
    static NSString *const FileNumberKey = @"VAFileNumber";
    
    NSUserDefaults *userDefaults =  [NSUserDefaults standardUserDefaults];
    NSInteger fileNumber = (NSInteger)[userDefaults integerForKey:FileNumberKey];
    [userDefaults setInteger:++fileNumber forKey:FileNumberKey];
    NSString *fileName = [NSString stringWithFormat:@"VA%04ld.mov", (long)fileNumber];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *possibleDirs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *movieDir = possibleDirs.firstObject;
    
    movieFileURL = [movieDir URLByAppendingPathComponent:fileName];
    
    return movieFileURL;
}

/*
+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType positon:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}
*/

+ (void) removeAllMovies {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *possibleDirs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *movieDir = possibleDirs.firstObject;
    
    NSError *error = nil;
    NSArray<NSURL*> *moveURLs = [fileManager contentsOfDirectoryAtURL:movieDir
                                           includingPropertiesForKeys:@[NSURLNameKey, NSURLCreationDateKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                error:&error];
    
    if (moveURLs) {
        NSError *removeError = nil;
        for (NSURL *moveURL in moveURLs) {
            [fileManager removeItemAtURL:moveURL error:&removeError];
            
            if (removeError) {
                NSLog(@"Movie Remove Error: %@", removeError);
            }
            else {
                NSLog(@"Movie Removed: %@", moveURL);
            }
        }
    }
    else {
        NSLog(@"Movie Directory Read Error: %@", error);
    }
}


@end
