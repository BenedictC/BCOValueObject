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



@interface BCOValueObject () <NSCopying, NSMutableCopying>
@property(readonly) NSUInteger bvo_hashValue;
@property(nonatomic) BOOL bvo_allowMutation;
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
        enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property) {

            //Assert that all properties are readonly.
            BOOL isReadOnly = NO;
            unsigned int count = 0;
            objc_property_attribute_t *attribs = property_copyAttributeList(property, &count);
            for (unsigned int i = 0; i < count; i++) {
                objc_property_attribute_t attrib = attribs[i];

                isReadOnly = (strcmp(attrib.name, "R") == 0);
                if (isReadOnly) break;
            }
            free(attribs);

            if (!isReadOnly) {
                [NSException raise:NSInvalidArgumentException format:@"Invalid property for immutable variant of BVOObject. The property <%s> of class <%@> is not readonly.", property_getName(property), NSStringFromClass(immutableClass)];
                return;
            }
        });

    } else if ([self isMutableVariant]) {

        Class immutableClass = self.immutableClass;
        Class mutableClass = self;

        //Assert that no state is being added
        enumeratePropertiesOfClass(mutableClass, ^(objc_property_t property) {
            [NSException raise:NSInvalidArgumentException format:@"Mutable subclass adds state thus preventing copying between mutable and immutable variants"];
            return;
        });

        //Add a setter for each property
#define ADD_SETTER_FOR_NSVALUE_TYPE(TYPE)  \
{\
    IMP setterImp = ({ \
        NSString *name = @(property_getName(property)); \
        imp_implementationWithBlock(^void(id instance, TYPE rawValue) {\
            NSValue *value = [NSNumber valueWithBytes:&rawValue objCType:@encode(TYPE)]; \
            [instance setValue:value forKey:name]; \
        });\
    }); \
    const char *types = [[NSString stringWithFormat:@"v@:%s", @encode(TYPE)] UTF8String]; \
    class_addMethod(mutableClass, setterSelector, setterImp, types); \
}

#define ADD_SETTER_FOR_NSNUMBER_TYPE(TYPE)  \
{\
    IMP setterImp = ({ \
        NSString *name = @(property_getName(property)); \
        imp_implementationWithBlock(^void(id instance, TYPE rawValue) {\
            NSNumber *value = @(rawValue); \
            [instance setValue:value forKey:name]; \
        });\
    }); \
    const char *types = [[NSString stringWithFormat:@"v@:%s", @encode(TYPE)] UTF8String]; \
    class_addMethod(mutableClass, setterSelector, setterImp, types); \
}

#define TYPE_MATCHES_ENCODED_TYPE(TYPE, ENCODED_TYPE) (0 == strcmp(@encode(TYPE), ENCODED_TYPE))
        enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property) {
            SEL setterSelector = setterSelectorForProperty(property); \
            BOOL shouldAddSetter = ![mutableClass instancesRespondToSelector:setterSelector];
            if (!shouldAddSetter) return;

            SEL getterSelector = getterSelectorForProperty(property);
            NSMethodSignature *getterSig = [immutableClass instanceMethodSignatureForSelector:getterSelector];
            const char *returnType = getterSig.methodReturnType;
            BOOL isObject = [@(returnType) hasPrefix:@"@"];
            if (isObject) {
                IMP setterImp = ({
                    NSString *name = @(property_getName(property));
                    imp_implementationWithBlock(^void(id instance, id value) {
                        [instance setValue:value forKey:name];
                    });
                });
                const char *types = [[NSString stringWithFormat:@"v@:%s", @encode(id)] UTF8String];
                class_addMethod(mutableClass, setterSelector, setterImp, types);
            }
            else if (TYPE_MATCHES_ENCODED_TYPE(BOOL, returnType))      ADD_SETTER_FOR_NSNUMBER_TYPE(BOOL)
            else if (TYPE_MATCHES_ENCODED_TYPE(char, returnType))      ADD_SETTER_FOR_NSNUMBER_TYPE(char)
            else if (TYPE_MATCHES_ENCODED_TYPE(short, returnType))     ADD_SETTER_FOR_NSNUMBER_TYPE(short)
            else if (TYPE_MATCHES_ENCODED_TYPE(int, returnType))       ADD_SETTER_FOR_NSNUMBER_TYPE(int)
            else if (TYPE_MATCHES_ENCODED_TYPE(long, returnType))      ADD_SETTER_FOR_NSNUMBER_TYPE(long)
            else if (TYPE_MATCHES_ENCODED_TYPE(long long, returnType)) ADD_SETTER_FOR_NSNUMBER_TYPE(long long)
            else if (TYPE_MATCHES_ENCODED_TYPE(float, returnType))     ADD_SETTER_FOR_NSNUMBER_TYPE(float)
            else if (TYPE_MATCHES_ENCODED_TYPE(double, returnType))    ADD_SETTER_FOR_NSNUMBER_TYPE(double)

#pragma message "TODO: Add all types in the main frameworks"
            else if (TYPE_MATCHES_ENCODED_TYPE(NSRange, returnType))   ADD_SETTER_FOR_NSVALUE_TYPE(NSRange)
            else if (TYPE_MATCHES_ENCODED_TYPE(NSSize, returnType))    ADD_SETTER_FOR_NSVALUE_TYPE(NSSize)
            else if (TYPE_MATCHES_ENCODED_TYPE(NSPoint, returnType))   ADD_SETTER_FOR_NSVALUE_TYPE(NSPoint)
            else if (TYPE_MATCHES_ENCODED_TYPE(NSRect, returnType))    ADD_SETTER_FOR_NSVALUE_TYPE(NSRect)
            else if (TYPE_MATCHES_ENCODED_TYPE(CGSize, returnType))    ADD_SETTER_FOR_NSVALUE_TYPE(CGSize)
            else if (TYPE_MATCHES_ENCODED_TYPE(CGPoint, returnType))   ADD_SETTER_FOR_NSVALUE_TYPE(CGPoint)
            else if (TYPE_MATCHES_ENCODED_TYPE(CGRect, returnType))    ADD_SETTER_FOR_NSVALUE_TYPE(CGRect)
            else {
                [NSException raise:NSInvalidArgumentException format:@"Unable to add setter for property <%s> of class <%@>. A setter must be added manually.", property_getName(property), NSStringFromClass(mutableClass)];
                return;
            }
        });
#undef TYPE_MATCHES_ENCODED_TYPE
#undef ADD_SETTER_FOR_NSNUMBER_TYPE
#undef ADD_SETTER_FOR_NSVALUE_TYPE

        //Finally register the mutable variant
        [self setMutableClass:self forImmutableClass:self.immutableClass];

    } else {
        //Possibly an invalid class hierarchy but we can't do anything because it *may* be a legitmate class, eg a KVO subclass.
    }
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
-(instancetype)init
{
    self = [super init];
    if (self == nil) return nil;

    _bvo_allowMutation = [self.class isMutableVariant];

    if ([self.class isImmutableVariant]) {
        return [self.class canonicalImmutableInstance:self];
    }

    return self;
}



+(instancetype)canonicalImmutableInstance:(id)referenceInstance
{
    NSAssert([self isImmutableVariant], @"Only immutable variants may be uniqued.");
    NSAssert([referenceInstance class] == self, @"referenceInstance is of a different class.");

    @synchronized(self.immutableClass) {
        //Fetch/create the cache
        //I feel conflicted about using associated objects to do this. It is perfectly possible to achieve the same
        //result without relying on runtime.h (which should be considered a last resort) but in this case using
        //associated objects results in more succient code that is thus less error prone.
        static const void * const key = &key;
        NSMapTable *cache = objc_getAssociatedObject(self, key) ?: ({
            cache = [NSMapTable strongToWeakObjectsMapTable];
            objc_setAssociatedObject(self, key, cache, OBJC_ASSOCIATION_RETAIN);
            cache;
        });

        //Check the cache
        NSNumber *hash = @([referenceInstance hash]);
        id canonicalInstance = [cache objectForKey:hash];

        BOOL hasCanonicalInstance = canonicalInstance != nil;
        if (hasCanonicalInstance) return canonicalInstance;

        //Update the cache
        [cache setObject:referenceInstance forKey:hash];
        return referenceInstance;
    }
}



#pragma mark - Equality
-(NSUInteger)hash
{
    //Because immutable and mutable variants should compare as equal we use the immutable classes has as the seed for the hash.
    //This isn't really needed because we do an explict class check in isEqual:.
    __block NSUInteger hash = ~[self.class.immutableClass hash];

    //Enumerate each property of the immutable class and incorporate its' values hash into our hash.
    //We only check the immutable class because subclasses are not supposed to add properties.
    enumeratePropertiesOfClass(self.class.immutableClass, ^(objc_property_t property) {
        const char *name = property_getName(property);
        id value = [self valueForKey:@(name)];

        //Incorporate the values hash
        hash ^= [value hash];
    });

#pragma message "TODO: Cache this value if it's an immutable instance and there's no other reason not to."

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
    if (!self.bvo_allowMutation) {
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
    Class immutableClass = [self.class immutableClass];
    BCOValueObject *instance = [immutableClass new];
    instance.bvo_allowMutation = YES;

    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property) {
        NSString *key = @(property_getName(property));
        id value = [self valueForKey:key];
        [instance setValue:value forKey:key];
    });

    instance.bvo_allowMutation = NO;

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
    instance.bvo_allowMutation = YES;

    Class immutableClass = [self.class immutableClass];
    enumeratePropertiesOfClass(immutableClass, ^(objc_property_t property) {
        NSString *key = @(property_getName(property));
        id value = [self valueForKey:key];
        [instance setValue:value forKey:key];
    });

    return instance;
}

@end
