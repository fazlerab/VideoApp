//
//  VideoFormatPickerDelegateDataSource.m
//  VideoApp
//
//  Created by Imran on 3/31/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import "VAFrameRatePickerDelegate.h"

@interface VAFrameRatePickerDelegate()
    
@property (nonatomic, strong) NSArray<NSNumber *> *frameRates;

@end
@implementation VAFrameRatePickerDelegate

- (instancetype) initWithPickerView:(UIPickerView *)pickerView {
    self = [super init];
    if (self) {
        pickerView.delegate = self;
        pickerView.dataSource = self;
        pickerView.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
        pickerView.layer.cornerRadius = 10.0;
        
        _pickerView = pickerView;
        _frameRates = [NSArray array];
    }
    return self;
}


// MARK: UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return  1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSInteger rows = [self.frameRates count];
    return rows;
}


// MARK: UIPickerViewDelegate
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel *label = (UILabel *)view;
    if (!label) {
        label = [[UILabel alloc] init];
        label.textColor = [UIColor yellowColor];
        label.font = [UIFont fontWithName:@"Helvetica" size:18.0];
        label.textAlignment = NSTextAlignmentCenter;
    }
    
    label.text = [self titleForRow:row];
    //[label sizeToFit];
    return label;
}


/*
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [self titleForRow:row];
}
*/

- (NSString *)titleForRow:(NSInteger)row {
    NSString *title = @"";
    
    /*
    AVCaptureDeviceFormat *format = [self.formats objectAtIndex:row];
    
    CMFormatDescriptionRef formatDesc = format.formatDescription;
    CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(formatDesc);
    int32_t subType = CMFormatDescriptionGetMediaSubType(formatDesc);
    
    AVFrameRateRange *frameRateRange = [[format videoSupportedFrameRateRanges] firstObject];
    
    title = [NSString stringWithFormat:@"%c%c%c%c %dx%d %dFPS", subType>>24, subType>>16, subType>>8, subType>>0, dim.width, dim.height, (int)frameRateRange.maxFrameRate];
    */
    
    NSNumber *frameRate = [self.frameRates objectAtIndex:row];
    title = [NSString stringWithFormat:@"%.0f fps", [frameRate floatValue]];
    
    return title;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSNumber *frameRate = [self.frameRates objectAtIndex:row];
    _selectedFrameRate = frameRate;
}

/*
- (void)setFormats:(NSArray<AVCaptureDeviceFormat *> *)formats {
    _formats = formats;
    [self.pickerView reloadAllComponents];
}

- (void)setSelectedFormat:(AVCaptureDeviceFormat *)selectedFormat {
    NSInteger row = -1;;
    for(NSInteger i = 0; i < self.formats.count; i++) {
        if (self.formats[i] == selectedFormat) {
            row = i;
            break;
        }
    }
    
    if (row >= 0) {
        _selectedFormat = selectedFormat;
        [self.pickerView selectRow:row inComponent:0 animated:NO];
    }
}
*/

- (void)setFrameRatesForDevice:(AVCaptureDevice *)device {
    NSMutableSet<NSNumber *> *frameRateSet = [NSMutableSet set];
    
    NSArray<AVCaptureDeviceFormat *> *formats = [device formats];
    for(AVCaptureDeviceFormat *format in formats) {
        if (![format.mediaType isEqualToString:AVMediaTypeVideo]) {
            continue;
        }
        NSLog(@"%@",format);
        
        AVFrameRateRange *frameRateRange = [[format videoSupportedFrameRateRanges] firstObject];
        [frameRateSet addObject:[NSNumber numberWithFloat:frameRateRange.maxFrameRate]];
    }
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"floatValue" ascending:YES];
    self.frameRates = [frameRateSet sortedArrayUsingDescriptors:@[sortDescriptor]];
    [self.pickerView reloadAllComponents];
}

- (void)selectFrameRateForFormat:(AVCaptureDeviceFormat *)format {
    AVFrameRateRange *frameRateRange = [[format videoSupportedFrameRateRanges] firstObject];
    
    NSInteger row = -1;
    for(int i = 0; i < self.frameRates.count; i++) {
        if ( self.frameRates[i].floatValue == [frameRateRange maxFrameRate] ) {
            row = i;
            break;
        }
    }
    
    if (row >= 0) {
        _selectedFrameRate = self.frameRates[row];
        [self.pickerView selectRow:row inComponent:0 animated:YES];
    }
}


@end
