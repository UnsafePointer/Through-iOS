//
//  THRFeedsViewController.m
//  Through
//
//  Created by Renzo Crisóstomo on 01/06/14.
//  Copyright (c) 2014 Renzo Crisóstomo. All rights reserved.
//

#import "THRFeedViewController.h"
#import "THRMediaCollectionViewCell.h"
#import "THRSettingsViewController.h"
#import "THRConnectViewController.h"

@interface THRFeedViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, assign) BOOL shouldRefreshOlder;

- (void)refresh:(id)sender;
- (void)refreshOlder;
- (void)goToSettings:(id)sender;
- (void)insertMedia:(NSArray *)media;
- (NSString *)serviceNameForMediaType:(THRMediaType)type;
- (void)onUserDidDisconnectedServices:(NSNotification *)notification;
- (void)onUserDidConnectedServices:(NSNotification *)notification;

@end

@implementation THRFeedViewController

static NSString *cellIdentifier = @"THRMediaCollectionViewCell";

#pragma mark - Controller Life Cycle

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Feed";
        self.feed = [NSMutableArray array];
        self.shouldRefreshOlder = YES;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    @weakify(self);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserDidDisconnectedServices:)
                                                 name:THRUserDidDisconnectedServicesNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserDidConnectedServices:)
                                                 name:THRUserDidConnectedServicesNotification
                                               object:nil];
    UIBarButtonItem *btnSettings = [[UIBarButtonItem alloc]
                                    initWithImage:[UIImage imageNamed:@"Settings"]
                                    style:UIBarButtonItemStyleBordered
                                    target:self
                                    action:@selector(goToSettings:)];
    self.navigationItem.leftBarButtonItem = btnSettings;
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl setTintColor:[UIColor colorWithHexString:@"#C644FC"]];
    [refreshControl addTarget:self
                       action:@selector(refresh:)
             forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:refreshControl];
    [self.collectionView registerClass:[THRMediaCollectionViewCell class]
            forCellWithReuseIdentifier:cellIdentifier];
    self.collectionView.delegate = self;
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.collectionView setContentInset:UIEdgeInsetsMake(20 + 44.0f, 0, 20 + 20 + 44.0f, 0)];
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(cellSelected:)];
    [self.collectionView addGestureRecognizer:gestureRecognizer];
    if ([self.feed count] == 0) {
        PFQuery *query = [PFQuery queryWithClassName:@"Media"];
        [query whereKey:@"user" equalTo:[PFUser currentUser]];
        [query orderByDescending:@"mediaDate"];
        [query setLimit:50];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            
            @strongify(self);
            
            if (error) {
                [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
            } else {
                [self insertMedia:objects];
            }
        }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.screenName = @"Feed Screen";
}

#pragma mark - Private Methods

- (void)onUserDidDisconnectedServices:(NSNotification *)notification
{
    @weakify(self);
    
    [self.feed removeAllObjects];
    [self.collectionView reloadData];
    PFQuery *query = [PFQuery queryWithClassName:@"Media"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query orderByDescending:@"mediaDate"];
    [query setLimit:50];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        @strongify(self);
        
        if (error) {
            [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
        } else {
            [self.feed addObjectsFromArray:objects];
            [self.collectionView reloadData];
        }
    }];
}

- (void)onUserDidConnectedServices:(NSNotification *)notification
{
    @weakify(self);
    
    [self.feed removeAllObjects];
    [self.collectionView reloadData];
    PFUser *user = [PFUser currentUser];
    [PFCloud
     callFunctionInBackground:@"generateFeedsForUser"
     withParameters:@{@"username": [user objectForKey:@"username"]}
     block:^(NSArray *results, NSError *error) {
         
         @strongify(self);
         
         if (error) {
             [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
         } else {
             [self.feed addObjectsFromArray:results];
             [self.collectionView reloadData];
         }
     }];
}

- (void)cellSelected:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint point = [gestureRecognizer locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (indexPath == nil){
        NSLog(@"couldn't find index path");
    } else {
        THRMediaCollectionViewCell *cell = (THRMediaCollectionViewCell *)[self.collectionView
                                                                          cellForItemAtIndexPath:indexPath];
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.image = cell.imgViewMedia.image;
        imageInfo.referenceRect = cell.frame;
        imageInfo.referenceView = cell.superview;
        JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                               initWithImageInfo:imageInfo
                                               mode:JTSImageViewControllerMode_Image
                                               backgroundStyle:JTSImageViewControllerBackgroundStyle_ScaledDimmedBlurred];
        [imageViewer
         showFromViewController:self
         transition:JTSImageViewControllerTransition_FromOriginalPosition];
    }
}

- (void)insertMedia:(NSArray *)media
{
    if ([media count] == 0) {
        return;
    }
    [self.collectionView performBatchUpdates:^{
        [self.feed insertObjects:media
                       atIndexes:[NSIndexSet
                                  indexSetWithIndexesInRange:
                                  NSMakeRange(0, [media count])]];
        NSMutableArray *paths = [NSMutableArray array];
        for (int i = 0; i < [media count]; i++) {
            [paths addObject:[NSIndexPath indexPathForItem:i
                                                 inSection:0]];
        }
        [self.collectionView insertItemsAtIndexPaths:[paths copy]];
    } completion:^(BOOL finished) {
        if (finished) {
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0
                                                                             inSection:0]
                                        atScrollPosition:UICollectionViewScrollPositionTop
                                                animated:YES];
        }
    }];
}

- (void)goToSettings:(id)sender
{
    THRSettingsViewController *settingsViewController = [[THRSettingsViewController alloc]
                                                         initWithNibName:nil
                                                         bundle:nil];
    [self.navigationController pushViewController:settingsViewController
                                         animated:YES];
}

- (void)refresh:(id)sender
{
    @weakify(self);
    
    UIRefreshControl *refreshControl = (UIRefreshControl *)sender;
    
    PFQuery *query = [PFQuery queryWithClassName:@"Media"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    if ([self.feed count] != 0) {
        PFObject *lastFeed = self.feed[0];
        [query whereKey:@"mediaDate" greaterThan:[lastFeed objectForKey:@"mediaDate"]];
    }
    [query orderByDescending:@"mediaDate"];
    [query setLimit:50];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        @strongify(self);
        
        if (error) {
            [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
            [refreshControl endRefreshing];
        } else if ([objects count] == 0) {
            [PFCloud
             callFunctionInBackground:@"generateFeedsForUser"
             withParameters:@{@"username": [[PFUser currentUser] objectForKey:@"username"]}
             block:^(NSArray *results, NSError *error) {
                 [refreshControl endRefreshing];
                 if (error) {
                     [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
                 } else {
                     [self insertMedia:results];
                 }
             }];
        } else {
            [refreshControl endRefreshing];
            [self insertMedia:objects];
        }
    }];
}

- (void)refreshOlder
{
    @weakify(self);
    
    PFQuery *query = [PFQuery queryWithClassName:@"Media"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    PFObject *oldestFeed = self.feed.lastObject;
    [query whereKey:@"mediaDate" lessThan:[oldestFeed objectForKey:@"mediaDate"]];
    [query orderByDescending:@"mediaDate"];
    [query setLimit:50];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        @strongify(self);
        
        if (error) {
            [SVProgressHUD showErrorWithStatus:@"There was an error with this request, please try again later."];
        } else if ([objects count] == 0) {
            [SVProgressHUD showErrorWithStatus:@"Can't find more items."];
            self.shouldRefreshOlder = NO;
        } else {
            [self.feed addObjectsFromArray:objects];
            [[self collectionView] reloadData];
        }
    }];
}

- (NSString *)serviceNameForMediaType:(THRMediaType)type
{
    switch (type) {
        case THRMediaTypeNone:
            return @"";
        case THRMediaTypeTwitter:
            return @"Twitter";
        case THRMediaTypeFacebook:
            return @"Facebook";
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.feed.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    THRMediaCollectionViewCell *cell = [collectionView
                                        dequeueReusableCellWithReuseIdentifier:cellIdentifier
                                        forIndexPath:indexPath];
    PFObject *media = self.feed[indexPath.row];
    cell.imageURL = [NSURL URLWithString:[media objectForKey:@"url"]];
    NSDate *date = [media objectForKey:@"mediaDate"];
    NSNumber *type = [media objectForKey:@"type"];
    NSString *text = [media objectForKey:@"text"];
    if (text == nil) {
        cell.lblDescription.text = [NSString stringWithFormat:@"%@ on %@ (%@ ago)", [media objectForKey:@"userName"], [self serviceNameForMediaType:[type integerValue]], [date shortTimeAgoSinceNow]];
    } else {
        cell.lblDescription.text = [NSString stringWithFormat:@"%@ on %@ (%@ ago):\n%@", [media objectForKey:@"userName"], [self serviceNameForMediaType:[type integerValue]], [date shortTimeAgoSinceNow], [media objectForKey:@"text"]];
    }
    CGFloat yOffset = ((self.collectionView.contentOffset.y - cell.frame.origin.y) / IMAGE_HEIGHT) * IMAGE_OFFSET_SPEED;
    cell.imageOffset = CGPointMake(0.0f, yOffset);
    if (indexPath.row == self.feed.count - 1 && self.shouldRefreshOlder) {
        [self refreshOlder];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    for(THRMediaCollectionViewCell *view in self.collectionView.visibleCells) {
        CGFloat yOffset = ((self.collectionView.contentOffset.y - view.frame.origin.y) / IMAGE_HEIGHT) * IMAGE_OFFSET_SPEED;
        view.imageOffset = CGPointMake(0.0f, yOffset);
    }
}

@end
