//
//  THRAPIManager.h
//  Through
//
//  Created by Renzo Crisóstomo on 30/05/14.
//  Copyright (c) 2014 Renzo Crisóstomo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface THRAPIManager : NSObject

+ (THRAPIManager *)sharedManager;
- (void)reverseAuthTwitterForAccount:(ACAccount *)account
                 withCompletionBlock:(ObjectCompletionBlock)completionBlock;

@end