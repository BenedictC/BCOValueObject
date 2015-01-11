//
//  BCOValueObject.h
//  BCOValueObject
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 
 BCOValueObject is an abstract class for implementing value objects. BCOValueObject provides equality checking and uniquing.
 BCOValueObject places the following restrictions on its subclasses:
 - Direct subclasses must only include readonly properties. These properties should only be set by the designated initalizer. Direct subclasses are refered to as 'immutable variants'.
 - Immutable variants may be subclassed to create 'mutable variants'. Mutable vairants have the following restrictions:
    - Mutable variants must not add properties or ivars.
    - Mutable variants should not be subclassed.
    - Mutable variants should declare setter methods in an named category (these methods will be dynamically added at runtime by BVOObject.)

 */



@interface BCOValueObject : NSObject <NSCopying, NSMutableCopying>
@end



void BCOValueObjectRegisterMutableVariantWithClassName(NSString *mutableVariantClassName);



#define BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT(MUTABLE) \
extern NSMutableSet *__BVOObjectMutableSubclassNames; \
__attribute__((constructor)) static inline void register##MUTABLE(void) { \
    MUTABLE *dummyVar = nil;  /* This gives us compile time checking that the class actually exists. */ \
    [dummyVar self];\
    BCOValueObjectRegisterMutableVariantWithClassName(@"" #MUTABLE ); \
}
