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
            [mutableClass self]; //Force +initalized to be called.
            [__BCOValueObjectMutableSubclassNames removeObject:className];
        }
    }
}



#pragma mark - Associated objects keys
static const void * const __cannonicalInstancesQueueKey = &__cannonicalInstancesQueueKey;
static const void * const __cannonicalInstancesCacheKey = &__cannonicalInstancesCacheKey;



@interface BCOValueObject () <NSCopying, NSMutableCopying>
@property(atomic) NSUInteger bvo_hashValue;
@property(nonatomic) BOOL bvo_isImmutable;
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
#define OS_OBJECT_USE_OBJC 0
            objc_setAssociatedObject(self, __cannonicalInstancesQueueKey, (__bridge id)(queue), OBJC_ASSOCIATION_RETAIN);
#undef OS_OBJECT_USE_OBJC

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
    self = [super init];
    if (self == nil) return nil;

    enumeratePropertiesOfClass(self.class.immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *key = @(property_getName(property));
        id value = valuesByPropertyName[key];

        BOOL isIgnorableValue = (value == nil);
        if (isIgnorableValue) return;

        [self setValue:value forKey:key];
    });

    //Freeze!
    _bvo_isImmutable = [self.class isImmutableVariant];

    BOOL shouldReturnCanonicalInstance = [self.class isImmutableVariant];
    return (shouldReturnCanonicalInstance) ? [self.class canonicalImmutableInstance:self] : self;
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
    //If there are weak properties then the hash will change
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



+(instancetype)canonicalImmutableInstance:(id)referenceInstance
{
    NSAssert([self isImmutableVariant], @"Only immutable variants may be uniqued.");
    NSAssert([referenceInstance class] == self, @"referenceInstance is of a different class.");
#define OS_OBJECT_USE_OBJC 0
    dispatch_queue_t queue = (__bridge dispatch_queue_t)objc_getAssociatedObject(self, __cannonicalInstancesQueueKey);
#undef OS_OBJECT_USE_OBJC
    NSMapTable *cache = objc_getAssociatedObject(self, __cannonicalInstancesCacheKey);

    //If the cache is nil then instance cannot be cached
    if (cache == nil) return referenceInstance;

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
    if (self.bvo_hashValue != 0)  return self.bvo_hashValue;

    Class class = self.class;
    Class immutableClass = class.immutableClass;

    //We start with the hash of the class so that a class will always have a non-zero hash value
    //Because immutable and mutable variants should compare as equal we use the immutable classes hash as the seed for the hash.
    __block NSUInteger hash = ~[immutableClass hash];

    //Enumerate each property of the immutable class and incorporate its' values hash into our hash.
    //We only check the immutable class because subclasses are not supposed to add properties.
    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
        const char *name = property_getName(property);
        id value = [self valueForKey:@(name)];

        //Incorporate the values hash
        hash ^= [value hash];
    });

    BOOL isHashCachable = [class isImmutableVariant] && [immutableClass immutableInstanceHasStableHash];
    if (isHashCachable) {
        self.bvo_hashValue = hash;
    }

    return hash;
}



-(BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:self.class.immutableClass]) return NO;

    return self.hash == [object hash];
}



#pragma mark - KVO
-(void)setValue:(id)value forKey:(NSString *)key
{
    if (self.bvo_isImmutable) {
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
    if ([self.class isImmutableVariant]) return self;

    Class immutableClass = [self.class immutableClass];
    BCOValueObject *instance = [immutableClass new];

    instance.bvo_isImmutable = NO;

    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property, BOOL *stop) {
        NSString *key = @(property_getName(property));
        id value = [self valueForKey:key];
        [instance setValue:value forKey:key];
    });

    instance.bvo_isImmutable = YES;

    if ([self.class isImmutableVariant]) {
        return [immutableClass canonicalImmutableInstance:instance];
    }

    return instance;
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
