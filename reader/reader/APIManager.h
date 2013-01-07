//
//  APIManager.h
//  reader
//
//  Created by Ram Mohan on 07/01/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APIManager : NSObject {
    dispatch_queue_t apiQueue;
}

/**
** Singleton object.
**/
+(id) sharedAPIManager;

/**
** generate URL escaped post data as a string
**/
-(NSString *) urlEscapedPostData:(NSDictionary *) postData;

/**
**  Send POST request Synchronously.
**/
-(id) sendPostRequestTo:(NSString *) targetURL withData:(NSString *) postData;

-(NSDictionary *) defaultServerResponse;

-(void ) signup:(NSDictionary *) userData;
-(void) signin:(NSDictionary *) userData;
-(void) signout:(NSDictionary *) userdata;
-(void) activateAccount:(NSDictionary *) userData;
-(void) getAccountInfo:(NSDictionary *) userData;
-(void) updateAccountInfo:(NSDictionary *) userData;
-(void) changePassword:(NSDictionary *) userData;
-(void) resetPassword:(NSDictionary *) userData;
-(void) updateDeviceName:(NSDictionary *) userData;
-(void) unlinkDevice:(NSDictionary *) userData;
-(void) getCatalogue;
-(void) getCatalogueQuickBooks:(NSDictionary *) userData;
-(void) getCatalogueBooks:(NSDictionary *) userData;
-(void) catalogueSearch:(NSDictionary *) userData;
-(void) bookPurchased:(NSDictionary *) userData;
-(void) getTransactionHistory:(NSDictionary *) userData;
-(void) getMyBooks:(NSDictionary *) userData;
-(void) downloadBook:(NSDictionary *) userData;
-(void) getBookDetails:(NSDictionary *) userData;
-(void) getBookSummary:(NSDictionary *) userData;
-(void) likeBook:(NSDictionary *) userData;
-(void) getMyLikes:(NSDictionary *) userData;
-(void) unlineBook:(NSDictionary *) userData;
-(void) addToWishList:(NSDictionary *) userData;
-(void) getMyWishList:(NSDictionary *) userData;
-(void) removeFromWishList:(NSDictionary *) userData;


@end
