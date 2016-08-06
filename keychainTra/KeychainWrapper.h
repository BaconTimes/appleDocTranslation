//
//  KeychainWrapper.h
//  GAODEMapLearning
//
//  Created by iOSBacon on 16/8/4.
//  Copyright © 2016年 iOSBacon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>


//定义一个OC的封装类来承载keychain服务的代码
@interface KeychainWrapper : NSObject{
    NSMutableDictionary * keychainData;
    NSMutableDictionary * genericPasswordQuery;
}

@property (nonatomic, strong) NSMutableDictionary * keychainData;
@property (nonatomic, strong) NSMutableDictionary *genericPasswordQuery;

- (void)mySetObject:(id)inObject forKey:(id)key;

- (id)myObjectForKey:(id)key;

- (void)resetKeychainItem;


@end
