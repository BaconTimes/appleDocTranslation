//
//  KeychainWrapper.m
//  GAODEMapLearning
//
//  Created by iOSBacon on 16/8/4.
//  Copyright © 2016年 iOSBacon. All rights reserved.
//

#import "KeychainWrapper.h"

//作为唯一的字符串来识别keychain的条目
static const UInt8 kKeychainItemIdentifier[] = "com.apple.dts.KeychainUI\0";

@interface KeychainWrapper(PrivateMethods)

//接下来的两个方法用来转换VC使用的(NSStirng *)的格式和keychain服务的API
- (NSMutableDictionary *)secItemFormateToDictionary:(NSDictionary *)dictionaryToConvert;

- (NSMutableDictionary *)dictionaryToSecItemFormate:(NSDictionary *)dictionaryToConvert;
//写数据到keychain的方法
- (void)writeToKeychain;

@end

@implementation KeychainWrapper

@synthesize keychainData, genericPasswordQuery;

- (instancetype)init
{
    self = [super init];
    if (self) {
        OSStatus keychainErr = noErr;
        //建立keychain搜寻的字典
        genericPasswordQuery = [[NSMutableDictionary alloc]init];
        //这个keychain条目 是一个普通密码
        [genericPasswordQuery setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        //kSecAttrGeneric attribut 用来存储一个唯一的字符串，该字符串能轻易地识别并找到对应的keychain条目
        //该字符串 首先被转换成NSData对象
        NSData * keychainItemID = [NSData dataWithBytes:kKeychainItemIdentifier length:strlen((const char *)kKeychainItemIdentifier)];
        [genericPasswordQuery setObject:keychainItemID forKey:(__bridge id)kSecAttrGeneric];
        //仅返回第一个匹配上的属性
        [genericPasswordQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
        //返回keychain条目的属性（在方法secItemFormatToDictionary:中密码是必要的）
        [genericPasswordQuery setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
        
        //初始化用于持有返回自keychain数据的字典
        CFMutableDictionaryRef outDictionary = nil;
        //如果keychain条目已经存在，则返回这个条目的各个属性
        keychainErr = SecItemCopyMatching((__bridge CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&outDictionary);
        
        if (keychainErr == noErr) {
            //转化dataDictionary成vc使用的格式
            self.keychainData = [self secItemFormateToDictionary:(__bridge_transfer NSMutableDictionary *)outDictionary];
        }else if (keychainErr == errSecItemNotFound){
            //如果没有匹配上，则将默认值放到keychain中
            [self resetKeychainItem];
            if (outDictionary) {
                CFRelease(outDictionary);
            }
        }else{
            //其他未意料到的错误
            NSAssert(NO, @"Serious error.\n");
            if (outDictionary) {
                CFRelease(outDictionary);
            }
        }
    }
    return self;
}

//执行mySetObject:forKey:方法，存储属性到keychain中
- (void)mySetObject:(id)inObject forKey:(id)key{
    if (inObject == nil) return;
    id currentObject = [keychainData objectForKey:key];
    if (![currentObject isEqual:inObject]) {
        [keychainData setObject:inObject forKey:key];
        [self writeToKeychain];
    }
}

//从字典中读取属性对应的值
- (id)myObjectForKey:(id)key{
    return [keychainData objectForKey:key];
}

//重置keychain条目中的值，或者创建一个新的条目如果它之前不存在
- (void)resetKeychainItem{
    if (!keychainData) {//创建keychainData
        self.keychainData = [[NSMutableDictionary alloc] init];
    }else if (keychainData){
        //格式化在keychainData字典中的数据，转换用于查询的格式，并放入tmpDictionary
        NSMutableDictionary * tmpDictionary = [self dictionaryToSecItemFormate:keychainData];
        OSStatus errorcode = SecItemDelete((__bridge CFDictionaryRef)tmpDictionary);
        NSAssert(errorcode == noErr, @"Problem deleting current keychain item");
    }
    //将默认的数据放入keychain条目中
    [keychainData setObject:@"Item label" forKey:(__bridge id)kSecAttrLabel];
    [keychainData setObject:@"Item desciption" forKey:(__bridge id)kSecAttrDescription];
    [keychainData setObject:@"Account" forKey:(__bridge id)kSecAttrAccount];
    [keychainData setObject:@"Service" forKey:(__bridge id)kSecAttrService];
    [keychainData setObject:@"Your comment here" forKey:(__bridge id)kSecAttrComment];
    [keychainData setObject:@"password" forKey:(__bridge id)kSecValueData];
}

/*!
 执行dictionaryToSecItemFormat:方法，你想要加入到keychain条目中并且建立keychain服务所需要的格式的字典
 */
- (NSMutableDictionary *)dictionaryToSecItemFormate:(NSDictionary *)dictionaryToConvert{
    //调用该方法必须要有一个配置好的字典
    //包含所有正确的键值对，用于keychain条目的搜寻
    NSMutableDictionary * returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    //添加keychain的条目类和普通属性
    NSData * keychainItemID = [NSData dataWithBytes:kKeychainItemIdentifier length:strlen((const char *)kKeychainItemIdentifier)];
    [returnDictionary setObject:keychainItemID forKey:(__bridge id)kSecAttrGeneric];
    [returnDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    //将密码字符串转换成NSData来适应API范例
    NSString * passwordString = [dictionaryToConvert objectForKey:(__bridge id)kSecValueData];
    [returnDictionary setObject:[passwordString dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    return returnDictionary;
}

/*!
 取出keychain条目中的attribute字典，需要来自keychain的密码，并且把它到attribute字典中
 */
- (NSMutableDictionary *)secItemFormateToDictionary:(NSDictionary *)dictionaryToConvert{
    //调用该方法必须要有一个配置好的字典
    //包含所有正确的键值对，用于keychain条目
    
    //创建一个配置好的返回字典
    NSMutableDictionary * returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    //需要来自keychain条目的密码的data
    //首先添加搜寻关键字和类属性，这些是获取密码必不可少的
    [returnDictionary setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [returnDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    //调用keychain服务来获得密码
    CFDataRef passwordData = NULL;
    OSStatus keychainError = noErr;
    keychainError = SecItemCopyMatching((__bridge CFDictionaryRef)returnDictionary, (CFTypeRef *)&passwordData);
    if (keychainError == noErr) {
        //移除kSecReturnData 键，我们不再需要它
        [returnDictionary removeObjectForKey:(__bridge id)kSecReturnData];
        //转换密码成NSString 并且加入到返回字典中
        NSString * password = [[NSString alloc] initWithBytes:[(__bridge_transfer NSData *)passwordData bytes] length:[(__bridge NSData *)passwordData length] encoding:NSUTF8StringEncoding];
        [returnDictionary setObject:password forKey:(__bridge id)kSecValueData];
    }
    //没有找到，什么都不做
    else if (keychainError == errSecItemNotFound){
        NSAssert(NO, @"Nothing was found in the keychain.\n");
        if (passwordData) {
            CFRelease(passwordData);
        }
    }
    //意外情况
    else{
        NSAssert(NO, @"Serious error.\n");
        if (passwordData) {
            CFRelease(passwordData);
        }
    }
    return returnDictionary;
}

/*!
 该方法被mySetObject中调用，该方法反过来会被UI调用当有新的数据需要在keychain中更新
 这个方法修改已存在的keychain 条目，或者不存在条目就会创建一个新的keychain条目，该条目的值是默认的
 */
- (void)writeToKeychain{
    CFDictionaryRef attributes = nil;
    NSMutableDictionary * updateItem = nil;
    //如果keychain条目早就存在，就修改它
    if (SecItemCopyMatching((__bridge CFDictionaryRef)genericPasswordQuery, (CFTypeRef *)&attributes) == noErr) {
        //首先获得返回来自keychain的属性，并把他们添加到控制更新的字典中
        updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attributes];
        [updateItem setObject:[genericPasswordQuery objectForKey:(__bridge id)kSecClass] forKey:(__bridge id)kSecClass];
        
        //其次，建立包含新的值的键值对字典
        NSMutableDictionary * tempCheck = [self dictionaryToSecItemFormate:keychainData];
        //移除类，因为它不是keychain的属性
        [tempCheck removeObjectForKey:(__bridge id)kSecClass];
        
        //你只能一次更新一个keychain条目
        OSStatus errcode = SecItemUpdate((__bridge CFDictionaryRef)updateItem, (__bridge CFDictionaryRef)tempCheck);
        NSAssert(errcode == noErr, @"Couldn't update the Keychain Item.");
        
    }else{
        //之前的条目没找到，添加新的条目
        //新的值在mySetObject方法中被添加到keychainData字典中
        //并且其他的值之前也被添加到keychainData字典
        //没有新添加的条目，所以第二个参数是NULL
        OSStatus errorcode = SecItemAdd((__bridge CFDictionaryRef)[self dictionaryToSecItemFormate:keychainData], NULL);
        NSAssert(errorcode == noErr, @"Couldn't add the Keychain Item.");
        if (attributes) {
            CFRelease(attributes);
        }
    }
}

@end
