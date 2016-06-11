//
//  MMAThumbnailViewCellCollectionViewCell.m
//  MyMovieApp
//
//  Created by Imran on 3/16/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import "VAThumbnailViewCell.h"

NSString *const DeleteRecordingNotification = @"DeleteRecordingNotification";

@interface VAThumbnailViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *imageLabel;
@property (nonatomic, weak) IBOutlet UIButton *deleteButton;

@end

@implementation VAThumbnailViewCell

- (void) awakeFromNib {
    [super awakeFromNib];
    
    [self.deleteButton.layer setCornerRadius:16.0];
    [self.deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [[self.deleteButton titleLabel] setFont:[UIFont boldSystemFontOfSize:22.0]];
    [self.deleteButton setHidden:YES];
    [self.deleteButton addTarget:self action:@selector(handleDelete) forControlEvents:UIControlEventTouchUpInside];
    [self.deleteButton setTitle:@"X" forState:UIControlStateNormal];
    
}

- (void)setName:(NSString *)name {
    self.imageLabel.text = name;
}

- (NSString *)name {
    return self.imageLabel.text;
}

- (void)setImage:(UIImage *)image {
    self.imageView.image = image;
}

- (UIImage *)image {
    return self.imageView.image;
}

- (void)setEditing:(BOOL)editing {
    _editing = editing;
    [self revealEditingView:editing];
}

- (void)revealEditingView:(BOOL)editing {
    if (self.deleteButton.isHidden) {
        [self.deleteButton setAlpha:0.0];
        [self.deleteButton setHidden:NO];
    }
    
    [UIView animateWithDuration:0.4
                     animations:^{
                         [self.deleteButton setAlpha:editing ? 1.0 : 0.0];
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             if (self.deleteButton.alpha == 0.0) {
                                 [self.deleteButton setHidden:YES];
                             }
                         }
                     }];
}

- (void)handleDelete {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter postNotificationName:DeleteRecordingNotification object:self];
}

@end
