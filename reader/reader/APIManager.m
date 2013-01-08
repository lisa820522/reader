//
//  APIManager.m
//  reader
//
//  Created by Ram Mohan on 07/01/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "APIManager.h"

#import "SBJson.h"
#import "Utils.h"
#import "CovenantNotification.h"
#import "NSNotificationCenterAdditions.h"

NSString *NAPI_SERVER = @"http://54.235.196.12/japi";

@implementation APIManager

+(id) sharedAPIManager {
    // http://www.galloway.me.uk/tutorials/singleton-classes/
    static APIManager *mySharedAPIManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mySharedAPIManager = [[self alloc] init];
    });
    return mySharedAPIManager;
}

-(id) init {
    self = [super init];
    if (self) {
        apiQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    }
    return self;
}


-(NSString *) urlEscapedPostData:(NSDictionary *) postData {
    NSMutableString *sb = [[NSMutableString alloc] init];
    for(NSString *k in [postData allKeys] ) {
        ([sb length] != 0) ? [sb appendString:@"&"] : nil;
        
        [sb appendString:k];
        [sb appendString:@"="];
        if ([[postData objectForKey:k] isKindOfClass:[NSDictionary class]] || 
            [[postData objectForKey:k] isKindOfClass:[NSArray class] ] ) {
            
            SBJsonWriter *jsonWriter = [[SBJsonWriter alloc] init];
            NSString *jsonString = [jsonWriter stringWithObject:[postData objectForKey:k] ];
            if(jsonString != nil)
                [sb appendString:[Utils urlEscapedString:jsonString] ];
        } else {
            [sb appendString:[Utils urlEscapedString:[postData objectForKey:k]]];
        }
    } 
    
    return (NSString *) sb;
}

-(id) sendPostRequestTo:(NSString *) targetURL withData:(NSString *) postData {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:targetURL] 
                                                    cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
                                                    timeoutInterval:30];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLResponse *resp;
    NSError *err;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    
    if ((data != nil) && ([data length] != 0) ) {
        NSString *status = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        SBJsonParser *jsonParser = [[SBJsonParser alloc] init];
        id dataResponse = [jsonParser objectWithString:status];
        return dataResponse;
    } else {
        NSLog(@"Request failed...");
        NSLog(@"Error : %@", [err userInfo]);
        return nil;
    }
}

-(NSDictionary *) defaultServerResponse {
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"ec", @"internal server error", @"em",nil];
}

-(void ) signup:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/signup", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"email",@"name",@"pwd", @"did",nil];
        for(NSString *field in fields) {
            if ( ![userData objectForKey:field]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         field,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_SIGNUP_RESULT_FAILED 
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSMutableDictionary *data =  [NSMutableDictionary dictionaryWithDictionary:userData]; 
        [data addEntriesFromDictionary:[Utils getDeviceDetails] ];
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:data] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNUP_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNUP_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNUP_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
        
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) signin:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/signin", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"repeat",@"email",@"pwd",@"did", nil];
        for(NSString *field in fields) {
            if (![userData objectForKey:field]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         field,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_SIGNIN_RESULT_FAILED 
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSMutableDictionary *data =  [NSMutableDictionary dictionaryWithDictionary:userData]; 
        [data addEntriesFromDictionary:[Utils getDeviceDetails] ];
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:data] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNIN_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNIN_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNIN_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) signout:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/signout", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_SIGNOUT_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNOUT_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNOUT_RESULT_FAILED
                                                                             object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_SIGNOUT_RESULT_OK
                                                                             object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
        
    };

    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) activateAccount:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/activate", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did",@"act_code", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_ACCOUNT_ACTIVATE_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_ACCOUNT_ACTIVATE_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_ACCOUNT_ACTIVATE_RESULT_FAILED
                                                                             object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_ACCOUNT_ACTIVATE_RESULT_OK 
                                                                             object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };

    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getAccountInfo:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/profile", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"email",@"did", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_ACCOUNT_INFO_RESULT_FAILED 
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_ACCOUNT_INFO_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_ACCOUNT_INFO_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_ACCOUNT_INFO_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) updateAccountInfo:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implementation
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) changePassword:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/profile/change_password", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"email",@"did",@"oldpwd",@"newpwd", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_CHANGE_PASSWORD_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_CHANGE_PASSWORD_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_CHANGE_PASSWORD_RESULT_FAILED
                                                                             object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_CHANGE_PASSWORD_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) resetPassword:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implementation
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) updateDeviceName:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implementation
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) unlinkDevice:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implementation
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getCatalogue {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/catalog/all", NAPI_SERVER];
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:nil];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_RESULT_FAILED 
                                                                        object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getCatalogueQuickBooks:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/catalog/quick_books", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"cat_ids",@"counts", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_QUICK_BOOKS_RESULT_FAILED 
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return;
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_QUICK_BOOKS_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_QUICK_BOOKS_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_QUICK_BOOKS_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getCatalogueBooks:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/catalog/books", NAPI_SERVER];
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_BOOKS_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_BOOKS_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_BOOKS_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) catalogueSearch:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/catalog/search", NAPI_SERVER];
        NSArray *fields = [NSArray arrayWithObjects:@"qry", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_SEARCH_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_SEARCH_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_SEARCH_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_CATALOGUE_SEARCH_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) bookPurchased:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/book/purchase", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did",@"pid", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_BOOK_PURCHASED_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_BOOK_PURCHASED_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_BOOK_PURCHASED_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_BOOK_PURCHASED_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) getTransactionHistory:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/txn/history", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_TRANSACTION_HISTORY_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_TRANSACTION_HISTORY_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_TRANSACTION_HISTORY_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_TRANSACTION_HISTORY_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if (dispatch_get_current_queue() == apiQueue) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getMyBooks:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/user/profile/books", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_TRANSACTION_HISTORY_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_MY_BOOKS_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_MY_BOOKS_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_MY_BOOKS_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };

    if (dispatch_get_current_queue() == apiQueue) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) downloadBook:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/book/download", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did",@"bid", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_DOWNLOAD_BOOK_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_DOWNLOAD_BOOK_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_DOWNLOAD_BOOK_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_DOWNLOAD_BOOK_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if (dispatch_get_current_queue() == apiQueue) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

-(void) getBookDetails:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/book/details", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"pid", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                         fld,@"em", nil];
                NSNotification *notificaiton = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOK_DETAILS_RESULT_FAILED
                                                                             object:nil
                                                                           userInfo:errResp];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notificaiton waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOK_DETAILS_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOK_DETAILS_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOK_DETAILS_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if (dispatch_get_current_queue() == apiQueue) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) getBookSummary:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        NSString *url = [NSString stringWithFormat:@"%@/books/summary", NAPI_SERVER];
        
        NSArray *fields = [NSArray arrayWithObjects:@"src",@"sid",@"did",@"pids",@"fields", nil];
        for(NSString *fld in fields) {
            if (![userData objectForKey:fld]) {
                NSDictionary *errResp = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"ec",
                                            fld,@"em", nil];
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOKS_SUMMARY_RESULT_FAILED object:nil userInfo:errResp];    
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
                return; 
            }
        }
        
        NSDictionary *result = (NSDictionary *)[self sendPostRequestTo:url withData:[self urlEscapedPostData:userData] ];
        if (!result) {
            NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOKS_SUMMARY_RESULT_FAILED
                                                                         object:nil userInfo:[self defaultServerResponse]];
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
        } else {
            if ([[result objectForKey:@"s"] intValue] == 0) {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOKS_SUMMARY_RESULT_FAILED object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            } else {
                NSNotification *notification = [NSNotification notificationWithName:COVNOTIFICATION_GET_BOOKS_SUMMARY_RESULT_OK object:nil userInfo:[result objectForKey:@"d"]];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThread:notification waitUntilDone:NO];
            }
        }
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) likeBook:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) getMyLikes:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) unlineBook:(NSDictionary *) userData {
    dispatch_block_t block = ^{
        // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) addToWishList:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) getMyWishList:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

/**/
-(void) removeFromWishList:(NSDictionary *) userData {
    dispatch_block_t block = ^{
            // TODO: implement
        ;
    };
    
    if ( dispatch_get_current_queue() == apiQueue ) {
        block();
    } else {
        dispatch_async(apiQueue, block);
    }
}

@end
