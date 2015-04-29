//
//  BCOValueObject.m
//  BCOValueObject
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import "BCOValueObject.h"
#import <objc/runtime.h>
#import "BCOPropertyHelpers.h"



#pragma mark - Hash Cache values
typedef NS_ENUM(NSInteger, BCOHashState) {
    BCOHashStateUnitialized = 0,
    BCOHashStateNotCacheableMutable,
    BCOHashStateNotCacheableWeakProperties,
    BCOHashStateCached,
};



typedef struct {
    BCOHashState state;
    NSUInteger value;
} BCOHash;



#pragma mark - Mutable Variant Registation
static NSMutableSet *__BCOValueObjectMutableSubclassNames = nil;



void BCOValueObjectRegisterMutableVariantWithClassName(NSString *className) {
    @synchronized(__BCOValueObjectMutableSubclassNames) {
        if (__BCOValueObjectMutableSubclassNames == nil) __BCOValueObjectMutableSubclassNames = [NSMutableSet new];

        [__BCOValueObjectMutableSubclassNames addObject:className];
    }
}



static void BCOValueObjectIntializeMutableVariants() {
    @synchronized(__BCOValueObjectMutableSubclassNames) {
        for (NSString *className in [__BCOValueObjectMutableSubclassNames copy]) {
            Class mutableClass = NSClassFromString(className);
            [mutableClass self]; //This implicitly causes +initalized to be called on the mutableClass.
            [__BCOValueObjectMutableSubclassNames removeObject:className];
        }
    }
}



#pragma mark - Associated objects keys
static const void * const __cannonicalInstancesQueueKey = &__cannonicalInstancesQueueKey;
static const void * const __cannonicalInstancesCacheKey = &__cannonicalInstancesCacheKey;



@interface BCOValueObject () <NSCopying, NSMutableCopying>
-(instancetype)initWithValues:(NSDictionary *)valuesByPropertyName andReturnCanonicalInstance:(BOOL)shouldReturnCanonicalInstance __attribute__((objc_designated_initializer));
@property(atomic) BCOHash bvo_hash;
@end



@implementation BCOValueObject

#pragma mark - class life cycle

+(void)initialize
{
    if ([self isEqual:BCOValueObject.class]) {
        //Nothing to do for the base class
        return;
    }

    if ([self isImmutableVariant]) {

        Class immutableClass = self;
        enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {

            //Assert that all properties are readonly.
            __block BOOL isReadOnly = NO;
            enumerateAttributesOfProperty(property, ^(objc_property_attribute_t attribute, BOOL *stop) {
                isReadOnly = (strcmp(attribute.name, "R") == 0);
                *stop = isReadOnly;
            });
            if (!isReadOnly) {
                [NSException raise:NSInvalidArgumentException format:@"Invalid property for immutable variant of BVOObject. The property <%s> of class <%@> is not readonly.", property_getName(property), NSStringFromClass(immutableClass)];
                return;
            }

            //Create a queue for creating canonical instances
            const char *queueLabel = [@"BCOValueObject.canonicalInstance." stringByAppendingString:NSStringFromClass(immutableClass)].UTF8String;
            dispatch_queue_t queue = dispatch_queue_create(queueLabel, DISPATCH_QUEUE_CONCURRENT);
#if defined(OS_OBJECT_USE_OBJC) && OS_OBJECT_USE_OBJC != 0
            objc_setAssociatedObject(self, __cannonicalInstancesQueueKey, queue, OBJC_ASSOCIATION_RETAIN);
#else
            objc_setAssociatedObject(self, __cannonicalInstancesQueueKey, (__bridge id)(queue), OBJC_ASSOCIATION_RETAIN);
#endif

            //Create the instance cache if instances are cachable
            if ([self immutableInstanceHasStableHash]) {
                NSMapTable *cache = [NSMapTable strongToWeakObjectsMapTable];
                objc_setAssociatedObject(self, __cannonicalInstancesCacheKey, cache, OBJC_ASSOCIATION_RETAIN);
            }
        });

        return;
    }

    //Assert that no state is being added after ontop of the immutable variant
    enumeratePropertiesOfClass(self, ^(objc_property_t property, BOOL *stop) {
        [NSException raise:NSInvalidArgumentException format:@"Mutable subclass adds state thus preventing copying between mutable and immutable variants"];
    });

    if ([self isMutableVariant]) {
        Class immutableClass = self.immutableClass;
        Class mutableClass = self;

        //Add a setter for each property
        enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
            BOOL didSucceed = addSetterToClassForPropertyFromClass(mutableClass, property, immutableClass);
            if (!didSucceed) {
                [NSException raise:NSInvalidArgumentException format:@"Unable to add setter for property <%s> of class <%@>. A setter must be added manually.", property_getName(property), NSStringFromClass(mutableClass)];
            }
        });

        //Register the mutable variant
        [self setMutableClass:self forImmutableClass:self.immutableClass];

        return;
    }

    //Possibly an invalid class hierarchy but we can't do anything because it *may* be a legitmate class, eg a KVO subclass.
}



#pragma mark - Class hierarchy methods
+(Class)immutableClass
{
    if ([self.superclass isEqual:BCOValueObject.class]) return self;
    if ([self.superclass.superclass isEqual:BCOValueObject.class]) return self.superclass;

    return Nil;
}



+(Class)mutableClass
{
    if ([self.superclass.superclass isEqual:BCOValueObject.class]) return self;

    __block Class mutableClass = Nil;
    [self getMutableClassesByImmutableClasses:^(NSMutableDictionary *mutableClassesByImmutableClasses) {
        Class immutableClass = [self immutableClass];
        mutableClass = mutableClassesByImmutableClasses[immutableClass];
    }];

    return mutableClass;
}



+(BOOL)isMutableVariant
{
    return [self.superclass.superclass isEqual:BCOValueObject.class];
}



+(BOOL)isImmutableVariant
{
    return [self.superclass isEqual:BCOValueObject.class];
}



#pragma mark - Mutable class registery
+(void)getMutableClassesByImmutableClasses:(void(^)(NSMutableDictionary *mutableClassesByImmutableClasses))getter
{
    @synchronized(BCOValueObject.class) {
        static NSMutableDictionary *dict = nil;
        if (dict == nil) dict = [NSMutableDictionary new];

        getter(dict);
    }
}



+(void)setMutableClass:(Class)mutableClass forImmutableClass:(Class)immutableClass
{
    [BCOValueObject getMutableClassesByImmutableClasses:^(NSMutableDictionary *mutableClassesByImmutableClasses) {
        NSString *key = NSStringFromClass(immutableClass);

        Class existingMutableClass = mutableClassesByImmutableClasses[key];
        if (existingMutableClass != nil && ![existingMutableClass isEqual:mutableClass]) {
            [NSException raise:NSInvalidArgumentException format:@"Attempting to re-set mutable class for immutable class."];
            return;
        }
        mutableClassesByImmutableClasses[key] = mutableClass;
    }];
}



+(Class)mutableClassForImmutableClass:(Class)immutableClass
{
    __block Class mutableClass = nil;
    [BCOValueObject getMutableClassesByImmutableClasses:^(NSMutableDictionary *mutableClassesByImmutableClasses) {
        NSString *key = NSStringFromClass(immutableClass);
        mutableClass = mutableClassesByImmutableClasses[key];
    }];

    return mutableClass;
}



#pragma mark - instance life cycle
-(instancetype)initWithValues:(NSDictionary *)valuesByPropertyName
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
    //We lied! This isn't the designated initalizer - it's the *public* designated initalizer.
    return [self initWithValues:valuesByPropertyName andReturnCanonicalInstance:YES];
#pragma clang diagnostic pop
}



-(instancetype)initWithValues:(NSDictionary *)valuesByPropertyName andReturnCanonicalInstance:(BOOL)shouldReturnCanonicalInstance
{
    self = [super init];
    if (self == nil) return nil;

    enumeratePropertiesOfClass(self.class.immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *key = @(property_getName(property));
        id value = valuesByPropertyName[key];

        BOOL isIgnorableValue = (value == nil);
        if (isIgnorableValue) return;

        [self setValue:value forKey:key];
    });

    return (shouldReturnCanonicalInstance) ? [self.class canonizeInstance:self] : self;
}



-(instancetype)initWithKeysAndValues:(id)firstKey,...
{
    NSMutableDictionary *values = [NSMutableDictionary new];

    //Convert the va args into a dictionary
    va_list args;
    va_start(args, firstKey);
    id key = firstKey;
    while (key != nil) {
        id value = va_arg(args, id);

        if (value != nil) {
            [values setObject:value forKey:key];
        }

        //Prep for next
        key  = va_arg(args, id);
    }
    va_end(args);


    return [self initWithValues:values];
}



-(instancetype)init
{
    return [self initWithValues:nil];
}



+(BOOL)immutableInstanceHasStableHash
{
    //When a weak property is nil-ed it will result in the objects hash changing therefore we cannot treat cache objects with weak properties.
    __block BOOL hasWeakProperty = NO;
    enumeratePropertiesOfClass(self.immutableClass, ^(objc_property_t property, BOOL *stop) {
        enumerateAttributesOfProperty(property, ^(objc_property_attribute_t attrib, BOOL *stop) {
            if (strcmp(attrib.name, "W") == 0) hasWeakProperty = YES;
            *stop = hasWeakProperty;
        });
        *stop = hasWeakProperty;
    });
    return !hasWeakProperty;
}



+(instancetype)canonizeInstance:(id)referenceInstance
{
    NSAssert([referenceInstance class] == self, @"referenceInstance is of a different class.");

#if defined(OS_OBJECT_USE_OBJC) && OS_OBJECT_USE_OBJC != 0
    dispatch_queue_t queue = objc_getAssociatedObject(self, __cannonicalInstancesQueueKey);
#else
    dispatch_queue_t queue = (__bridge dispatch_queue_t)objc_getAssociatedObject(self, __cannonicalInstancesQueueKey);
#endif

    NSMapTable *cache = objc_getAssociatedObject(self, __cannonicalInstancesCacheKey);
    BOOL isInstanceCachingPermited = cache != nil;
    if (!isInstanceCachingPermited) return referenceInstance;

    //Calling hash implicitly freezes an object
    NSNumber *hash = @([referenceInstance hash]);
    __block id canonicalInstance = nil;
    dispatch_sync(queue, ^{
        canonicalInstance = [cache objectForKey:hash];
    });

    if (canonicalInstance != nil) return canonicalInstance;

    dispatch_barrier_sync(queue, ^{
        //We have to check again because another write may have occured since we read.
        canonicalInstance = [cache objectForKey:hash];
        if (canonicalInstance != nil) return;

        //Update the cache
        [cache setObject:referenceInstance forKey:hash];
        canonicalInstance = referenceInstance;
    });

    return canonicalInstance;
}



#pragma mark - debug
-(NSString *)description
{
    NSMutableString *values = [NSMutableString new];
    enumeratePropertiesOfClass(self.class.immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *name = @(property_getName(property));
        id value = [self valueForKey:name];
        [values appendFormat:@"%@ = %@;\n", name, value];
    });

    NSString *description = [NSString stringWithFormat:@"<%@: %p> (values: {\n%@})", NSStringFromClass(self.class), self, values];

    return description;
}



#pragma mark - Equality
-(NSUInteger)hash
{
    //If the hash is cached then we're done.
    BCOHash hash = self.bvo_hash;
    if (self.bvo_hash.state == BCOHashStateCached) {
        return hash.value;
    }

    Class class = self.class;
    Class immutableClass = class.immutableClass;

    //We start with the hash of the class so that a class will always have a non-zero hash value
    //Because immutable and mutable variants should compare as equal we use the immutable classes hash as the seed for the hash.
    __block NSUInteger hashValue = ~[immutableClass hash];

    //Enumerate each property of the immutable class and incorporate its' values hash into our hash.
    //We only check the immutable class because subclasses are not supposed to add properties.
    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
        const char *name = property_getName(property);
        id value = [self valueForKey:@(name)];

        //Incorporate the values hash
        hashValue ^= [value hash];
    });

    //Update self.hash
    if (hash.state == BCOHashStateUnitialized) {
        if ([class isMutableVariant]) {
            hash.state = BCOHashStateNotCacheableMutable;
        } else if (![immutableClass immutableInstanceHasStableHash]) {
            hash.state = BCOHashStateNotCacheableWeakProperties;
        } else {
            hash.state = BCOHashStateCached;
            hash.value = hashValue;
            self.bvo_hash = hash;
        }
    }

    return hashValue;
}



-(BOOL)isEqual:(id)object
{
    BOOL isMutableOrImmutableClass = [object isKindOfClass:self.class.immutableClass];
    if (!isMutableOrImmutableClass) return NO;

    return [self hash] == [object hash];
}



#pragma mark - KVO
-(void)setValue:(id)value forKey:(NSString *)key
{
    BCOHash hash = self.bvo_hash;
    BOOL isWritable = hash.state == BCOHashStateNotCacheableMutable || hash.state == BCOHashStateUnitialized;
    if (!isWritable) {
        [NSException raise:NSInvalidArgumentException format:@"Attempted to set a value of an immutable object."];
        return;
    }

    static void (*setValueForKey)(id, SEL, id, NSString *) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method method = class_getInstanceMethod(NSObject.class, @selector(setValue:forKey:));
        setValueForKey = (void (*)(id, SEL, id, NSString *))method_getImplementation(method);
    });

    //Temporarily change self.class to the immutable variant so that NSObject's setValue:forKey: will not find any setters.
    Class originalClass = object_getClass(self); //we use object_getClass() because [self class] is overriden by dynamic KVO subclasses to hide their existance.
    Class immutableClass = self.class.immutableClass;
    NSAssert(({
        objc_property_t property = class_getProperty(immutableClass, key.UTF8String);
        SEL setter = setterSelectorForProperty(property);
        BOOL hasSetter = [immutableClass instancesRespondToSelector:setter];
        !hasSetter;
    }), @"Setter found on immutable class!");

    object_setClass(self, immutableClass);
    setValueForKey(self, _cmd, value, key);

    object_setClass(self, originalClass);
}



#pragma mark - copying
-(id)copyWithZone:(NSZone *)zone
{
    //Immutable objects can just return themselves
    if ([self.class isImmutableVariant]) return self;

    Class immutableClass = [self.class immutableClass];
    BCOValueObject *instance = [[immutableClass alloc] initWithValues:nil andReturnCanonicalInstance:NO];

    NSAssert(instance.bvo_hash.state == BCOHashStateUnitialized, @"Attempting to modifiy a uniquied instance.");
    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *key = @(property_getName(property));
        id value = [self valueForKey:key];
        [instance setValue:value forKey:key];
    });

    //Canonize
    return [instance.class canonizeInstance:instance];
}



-(id)mutableCopyWithZone:(NSZone *)zone
{
    //Ensure that the mutable variant has been initalized
    BCOValueObjectIntializeMutableVariants();

    Class mutableClass = [BCOValueObject mutableClassForImmutableClass:[self.class immutableClass]];
    if (mutableClass == Nil) {
        [NSException raise:NSInvalidArgumentException format:@"Attempted to make a mutable copy of an immutable class which does not have registered mutable variant."];
        return nil;
    }

    BCOValueObject *instance = [mutableClass new];

    Class immutableClass = [self.class immutableClass];
    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *key = @(property_getName(property));
        id value = [self valueForKey:key];
        [instance setValue:value forKey:key];
    });

    return instance;
}

@end
