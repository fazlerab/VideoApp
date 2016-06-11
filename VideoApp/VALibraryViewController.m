//
//  VideoLibraryCollectionViewController.m
//  VideoApp
//
//  Created by Imran on 3/9/16.
//  Copyright © 2016 Fazle Rab. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "VALibraryViewController.h"
#import "VAThumbnailViewCell.h"
#import "VACameraViewController.h"
#import "VAPlayerViewController.h"

static NSString *const PlayVideoSegue = @"PlayVideoSegue";


@interface VALibraryViewController () {
    dispatch_queue_t _serialQueue;
}

@property (nonatomic, strong) NSMutableArray<NSURL *> *videoURLs;

@end

@implementation VALibraryViewController

static NSString * const reuseIdentifier = @"ThumbnailViewCell";


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _serialQueue = dispatch_queue_create("serialQueue", NULL);
    
    // Uncomment the following line to preserve selection between presentations
    self.clearsSelectionOnViewWillAppear = NO;
    
    //Add Edit/Done button item to Navagation bar. setEditing called as action
    self.navigationItem.rightBarButtonItems = @[self.editButtonItem];
    
    
    // Register cell classes
    //[self.collectionView registerClass:[VAThumbnailViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    
    // Do any additional setup after loading the view.
    NSNotificationCenter *notificatonCenter = [NSNotificationCenter defaultCenter];
    [notificatonCenter addObserver:self selector:@selector(handleNewRecording:) name:NewRecordingNotification object:nil];
    [notificatonCenter addObserver:self selector:@selector(handleDeleteRecording:) name:DeleteRecordingNotification object:nil];
    
    [self loadVideoURLs];
}

// Method invoked when Edit/Done button tapped on Navigation bar
- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (VAThumbnailViewCell *cell in visibleCells) {
        [cell setEditing:editing];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:PlayVideoSegue]) {
        UINavigationController *navController = (UINavigationController *)[segue destinationViewController];
        VAPlayerViewController *playerController = (VAPlayerViewController *)[navController topViewController];
        playerController.videoURL = (NSURL *)sender;
    }
}

- (IBAction)unwindFromPlayerViewController:(UIStoryboardSegue *)unwindSegue {
}


#pragma mark <UICollectionViewDataSource>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.videoURLs count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    return [self configureCollectionViewCell:cell atIndex:indexPath.row];
}

- (UICollectionViewCell *)configureCollectionViewCell:(UICollectionViewCell *)cell atIndex:(NSInteger)index {
    NSURL *videoURL = self.videoURLs[index];
    NSURL *thumbnailURL = [self.class thumbnailURLForVideoURL:videoURL];
    
    NSError *error = nil;
    NSData *imageData = [NSData dataWithContentsOfURL:thumbnailURL options:0 error:&error];
    if (!imageData) {
        NSLog(@"configureCollectionViewCell: %@", error.localizedDescription);;
        [self saveThumbnailForVideoURL:videoURL completion:^{
            [self.collectionView reloadData];
        }];
    }
    
    UIImage *image = [UIImage imageWithData:imageData];
    
    NSString *name;
    [videoURL getResourceValue:&name forKey:NSURLNameKey error:&error];
    if (error) {
        NSLog(@"Error getting NSURLNameKey resourse. %@", error.localizedDescription);
        name = [videoURL lastPathComponent];
    }
    name = [name stringByDeletingPathExtension];
    
    VAThumbnailViewCell *thumbnailViewCell = (VAThumbnailViewCell*)cell;
    thumbnailViewCell.name = name;
    thumbnailViewCell.image = image;
    [thumbnailViewCell setEditing:self.isEditing];
    
    return thumbnailViewCell;
}

#pragma mark <UICollectionViewDelegate>
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return !self.isEditing;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSURL *videoURL = self.videoURLs[indexPath.row];
    [self performSegueWithIdentifier:PlayVideoSegue sender:videoURL];
}


// MARK: NotificationCenter observer methods
- (void)handleNewRecording:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSURL *videoURL = (NSURL *)userInfo[NewRecordingFileURLKey];
    NSLog(@"LibraryView.NewRecording: %@", [videoURL lastPathComponent]);
    
    [self saveThumbnailForVideoURL:videoURL completion:^{
        [self.videoURLs addObject:videoURL];
        [self.collectionView reloadData];
    }];
}

- (void)handleDeleteRecording:(NSNotification *)notification {
    VAThumbnailViewCell *cell = (VAThumbnailViewCell *)notification.object;
    NSIndexPath *indexPath =  [self.collectionView indexPathForCell:cell];
    
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deleteRecording:indexPath.row];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    NSString *title = @"Are you sure?";
    NSString *message = [NSString stringWithFormat:@"Delete '%@'?", cell.name];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:deleteAction];
    [alertController addAction:cancelAction];
    
    [self showDetailViewController:alertController sender:self];
}

- (void)deleteRecording:(NSInteger)index {
    NSURL *videoURL = self.videoURLs[index];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    BOOL success = [fileManager removeItemAtURL:videoURL error:&error];
    if (success) {
        [self.videoURLs removeObjectAtIndex:index];
        NSURL *thumbURL = [self.class thumbnailURLForVideoURL:videoURL];
        if ([fileManager removeItemAtURL:thumbURL error:&error]) {
            [self.collectionView reloadData];
        }
        else {
            NSLog(@"Cannot delete thumbnail: %@", error.localizedDescription);
        }
    }
    else {
        NSLog(@"Cannot delete video: %@", error.localizedDescription);
        [self showAlertWithTitle:error.localizedFailureReason message:error.localizedDescription];
    }
}

// MARK: Data methods
- (void)saveThumbnailForVideoURL:(NSURL *)videoURL completion:(void(^)(void))completion {
    dispatch_async(_serialQueue, ^{
        NSURL *thumbURL =  [VALibraryViewController thumbnailURLForVideoURL:videoURL];
        
        // Check if thumbnail already exists
        if ([thumbURL checkResourceIsReachableAndReturnError:nil]) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        }
        
        // Generate thumbnail
        BOOL success = YES;
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        imageGenerator.appliesPreferredTrackTransform = YES;
        imageGenerator.maximumSize = CGSizeMake(150.0, 150.0);
        
        NSError *error = nil;
        CGImageRef image = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:nil error:&error];
        if (image) {
            UIImage *thumb = [UIImage imageWithCGImage:image];
            NSData *pngThumb = UIImagePNGRepresentation(thumb);
            
            if (!pngThumb || ![pngThumb writeToURL:thumbURL options:NSDataWritingAtomic error:&error]) {
                success = NO;
                NSLog(@"Error generating and saving thumbnail png to thumbnail directory: %@", error);
            }
        }
        else {
            success = NO;
            NSLog(@"Error generation thumbnail image: %@", error);
        }
        
        if (success && completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
        
        CGImageRelease(image);
    });
}

- (void)loadVideoURLs {
    dispatch_async(_serialQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *error;
        NSArray<NSURL *> *videoURLs = [fileManager contentsOfDirectoryAtURL:[VALibraryViewController videoDirectory]
                                                 includingPropertiesForKeys:@[NSURLNameKey, NSURLCreationDateKey]
                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                      error:&error];
        if (videoURLs) {
            //NSLog(@"%lu videoURLs: %@", (unsigned long)videoURLs.count, videoURLs);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.videoURLs = [videoURLs mutableCopy];
                [self.collectionView reloadData];
            });
        }
        else {
            NSLog(@"%ld: %@: %@", (long)error.code, error.localizedFailureReason, error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlertWithTitle:error.localizedFailureReason message:error.localizedDescription];
            });
        }
    });
}


// MARK: Helper methods
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"Dismiss"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    UIAlertController *alertCntrl = [UIAlertController alertControllerWithTitle:title
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [alertCntrl addAction:alertAction];
    [self presentViewController:alertCntrl animated:YES completion:nil];
}

+ (NSURL *)thumbnailURLForVideoURL:(NSURL *)videoURL {
    NSString *thumbFilename = [[[videoURL lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
    return [[VALibraryViewController thumbnailDirectory] URLByAppendingPathComponent:thumbFilename];
}

+ (NSURL *)thumbnailDirectory {
    NSURL *thumbnailDir = nil;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *possibleDirs = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    NSURL *appSupportDir = possibleDirs.firstObject;
    thumbnailDir = [appSupportDir URLByAppendingPathComponent:@"thumbnails" isDirectory:YES];
        
    NSError *error = nil;
    if (![thumbnailDir checkResourceIsReachableAndReturnError:&error]) {
        
        if (error.code == NSFileReadNoSuchFileError) {
            error = nil;
            [fileManager createDirectoryAtURL:thumbnailDir withIntermediateDirectories:YES
                                   attributes:nil error:&error];
        }
    }
    
    if (error) {
        NSLog(@"Cannot create thumbnail directory: %ld: %@: %@", (long)error.code, error.localizedFailureReason, error.localizedDescription);
    }
    
    return thumbnailDir;
}

+ (NSURL *)videoDirectory {
    NSURL *videoDirectory = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSURL *> *possibleDirs = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    videoDirectory = possibleDirs.firstObject;
    
    NSLog(@"videoDirectory: %@", videoDirectory);
    return videoDirectory;
}

+ (void) removeAllThumbnails {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSArray<NSURL*> *thumbnailURLs = [fileManager contentsOfDirectoryAtURL:[VALibraryViewController thumbnailDirectory]
                                                includingPropertiesForKeys:@[NSURLNameKey, NSURLCreationDateKey]
                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     error:&error];
    if (thumbnailURLs) {
        NSError *removeError = nil;
        for (NSURL *thumbURL in thumbnailURLs) {
            [fileManager removeItemAtURL:thumbURL error:&removeError];
            
            if (removeError) {
                NSLog(@"Thumbnail Remove Error: %@", removeError);
            }
            else {
                NSLog(@"Thumbnail Removed: %@", thumbURL);
            }
        }
    }
    else {
        NSLog(@"Thumbnail Directory Read Error: %@", error);
    }
}

@end
