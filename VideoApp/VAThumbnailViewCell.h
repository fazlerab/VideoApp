//
//  VAThumbnailViewCell.h
//  VideoApp
//
//  Created by Imran on 3/16/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const DeleteRecordingNotification;

@interface VAThumbnailViewCell : UICollectionViewCell

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, getter=isEditing) BOOL editing;

@end
