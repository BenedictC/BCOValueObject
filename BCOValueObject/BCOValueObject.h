//
//  BCOValueObject.h
//  BCOValueObject
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 
 BCOValueObject is an abstract class for implementing value objects. BCOValueObject provides equality checking and uniquing and optionally support for mutable variants.

 BCOValueObject places the following restrictions on its subclasses:
 - Direct subclasses can only include readonly properties. These properties should only be set by the designated initalizer. Direct subclasses are refered to as 'immutable variants'.
 - Immutable variants are thread safe.
 - Immutable variants may be subclassed to create 'mutable variants'. Mutable variants have the following restrictions:
    - Mutable variants must not add properties (direct ivars can be added but this is strongly discouraged).
    - Mutable variants should not be subclassed.
    - Setter declarations for mutable variants must be listed in a category. Implementations for setters will be automatically generated for most types. If a setter cannot be generated then an exception will be raised when the class is initalized. Setters which cannot be generated must be implemented like so:
        -(void)setTransform:(CATransform3D)transform
        {
            [self setValue:[NSValue valueWithCATransform3D:transform] forKey:@"transform"];
        }
      BCOValueObject overrides setValue:forKey: so that it will not cause an infinte loop when being called from within a setter providing that the class hierarchy requirements listed above are adhered to.
  - Mutable variants must be registered so that immutable variant can make mutable copies. The simplest way to do this is to call BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT from within the header file where the mutable variant is declared.
 
 Due to the subclassing restrictions protocols should be used to implement polymorphism.

 */
@interface BCOValueObject : NSObject <NSCopying, NSMutableCopying>
/**
 Subclasses should override this method if there hash value may change once the object is created. The default implementation is returns YES unless the object contains a property that is use weak storage. If this method returns NO then uniquing and hash caching are not performed.

 @return YES if the hash value of instances will not change once created.
 */
+(BOOL)immutableInstanceHasStableHash;

/**
 Initalize an instance using the values in valuesByPropertyName. The keys of valuesByPropertyName should be the name property name. Keys which do not relate to the a property name are ignored.

 @param valuesByPropertyName An NSDictionary where keys are property names and values are the property's value.

 @return an initalized instance.
 */
-(instancetype)initWithValues:(NSDictionary *)valuesByPropertyName __attribute__((objc_designated_initializer));
/**
 Initalized an instance using the value

 @param firstKey A list of alternating keys and values. keys must be NSString instances and values must be objects or nil. The list is terminated by a nil in a key position. Due to the fact that this method can accept nil values it may be prefereable to initWithValues:.

 @return an initalized instance.
 */
-(instancetype)initWithKeysAndValues:(id)keysAndValues,...;
@end



void BCOValueObjectRegisterMutableVariantWithClassName(NSString *mutableVariantClassName);



#define BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT(MUTABLE) \
extern NSMutableSet *__BVOObjectMutableSubclassNames; \
__attribute__((constructor)) static inline void register##MUTABLE(void) { \
    MUTABLE *dummyVar = nil;  /* This gives us compile time checking that the class actually exists. */ \
    [dummyVar self]; /*dummy call to avoid an unused variable warning. */ \
    BCOValueObjectRegisterMutableVariantWithClassName(@"" #MUTABLE ); \
}
