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
 - Direct subclasses can only include readonly properties. These properties should only be set by the designated initalizer. Direct subclasses are refered to as 'immutable variants'.
 - Immutable variants are thread safe.
 - Immutable variants may be subclassed to create 'mutable variants'. Mutable variants have the following restrictions:
    - Mutable variants must not add properties or ivars.
    - Mutable variants should not be subclassed.
    - Mutable variants should declare setter methods in an named category (these methods will be dynamically added at runtime by BVOObject.)
    - Setter declarations for mutable variants must be listed in a category. Setters will be automatically generated for most types. If a setter cannot be generated then an exception will be raised when the class is initalized. Setters which cannot be generated must be implemented as like so:
        -(void)setTransform:(CATransform3D)transform
        {
            [self setValue:[NSValue valueWithCATransform3D:transform] forKey:@"transform"];
        }
      BCOValueObject overrides setValue:forKey: so that it will not cause an infinte loop when being called from within a setter providing that the class hierarchy requirements listed above are adhered to.
  - Mutable variants must be registed so that immutable variant can make mutable copies. The simplest way to do this is to call BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT from the header file where the mutable variant is declared.
 */



@interface BCOValueObject : NSObject <NSCopying, NSMutableCopying>
-(instancetype)initWithKeysAndValues:(id)firstKey,... __attribute__((objc_designated_initializer));
@end



void BCOValueObjectRegisterMutableVariantWithClassName(NSString *mutableVariantClassName);



#define BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT(MUTABLE) \
extern NSMutableSet *__BVOObjectMutableSubclassNames; \
__attribute__((constructor)) static inline void register##MUTABLE(void) { \
    MUTABLE *dummyVar = nil;  /* This gives us compile time checking that the class actually exists. */ \
    [dummyVar self]; /*dummy call to avoid an unused variable warning. */ \
    BCOValueObjectRegisterMutableVariantWithClassName(@"" #MUTABLE ); \
}
