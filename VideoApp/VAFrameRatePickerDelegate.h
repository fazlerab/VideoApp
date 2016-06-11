//
//  VideoFormatPickerDelegateDataSource.h
//  VideoApp
//
//  Created by Imran on 3/31/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface VAFrameRatePickerDelegate : NSObject <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, weak) UIPickerView *pickerView;
@property (nonatomic, weak) NSNumber *selectedFrameRate;
//@property (nonatomic, weak) NSArray<AVCaptureDeviceFormat *> *formats;

- (instancetype) initWithPickerView:(UIPickerView *)pickerView;
- (void)setFrameRatesForDevice:(AVCaptureDevice *)device;
- (void)selectFrameRateForFormat:(AVCaptureDeviceFormat *)format;

@end
