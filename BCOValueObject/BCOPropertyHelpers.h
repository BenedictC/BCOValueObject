//
//  BCOPropertyHelpers.h
//  ValueObjects
//
//  Created by Benedict Cohen on 11/01/2015.
//  Copyright (c) 2015 Benedict Cohen. All rights reserved.
//

#ifndef ValueObjects_BCOPropertyHelpers_h
#define ValueObjects_BCOPropertyHelpers_h

#import <objc/runtime.h>



static void enumeratePropertiesOfClass(Class class, void(^enumerator)(objc_property_t property, BOOL *stop)) {
    uint count = 0;
    objc_property_t *properties = class_copyPropertyList(class, &count);
    BOOL stop = NO;
    for (uint i = 0; i < count; i++) {
        //Get the value for the property
        objc_property_t property = properties[i];
        enumerator(property, &stop);
        if (stop) break;
    }
    //Tidy up
    free(properties);
}



static void enumerateAttributesOfProperty(objc_property_t property, void(^enumerator)(objc_property_attribute_t attribute, BOOL *stop)) {
    unsigned int count = 0;
    objc_property_attribute_t *attribs = property_copyAttributeList(property, &count);
    BOOL stop = NO;
    for (unsigned int i = 0; i < count; i++) {
        objc_property_attribute_t attrib = attribs[i];

        enumerator(attrib, &stop);
        if (stop) break;
    }
    free(attribs);
}



static SEL setterSelectorForProperty(objc_property_t property) {

    SEL setterSelector = NULL;

    unsigned int count = 0;
    objc_property_attribute_t *attribs = property_copyAttributeList(property, &count);
    for (unsigned int i = 0; i < count; i++) {
        objc_property_attribute_t attrib = attribs[i];

        BOOL isSetterAttribute = (strcmp(attrib.name, "S") == 0);
        if (isSetterAttribute) {
            setterSelector = NSSelectorFromString(@(attrib.value));
            break;
        }
    }
    free(attribs);

    if (setterSelector != NULL) return setterSelector;

    NSString *name = @(property_getName(property));
    NSString *head = [[name substringWithRange:NSMakeRange(0, 1)] uppercaseString];
    NSString *body = [name substringWithRange:NSMakeRange(1, name.length-1)];
    NSString *setterString = [NSString stringWithFormat:@"set%@%@:", head, body];

    return NSSelectorFromString(setterString);
}



static SEL getterSelectorForProperty(objc_property_t property) {

    SEL getterSelector = NULL;

    unsigned int count = 0;
    objc_property_attribute_t *attribs = property_copyAttributeList(property, &count);
    for (unsigned int i = 0; i < count; i++) {
        objc_property_attribute_t attrib = attribs[i];

        BOOL isGetterAttribute = (strcmp(attrib.name, "G") == 0);
        if (isGetterAttribute) {
            getterSelector = NSSelectorFromString(@(attrib.value));
            break;
        }
    }
    free(attribs);

    if (getterSelector != NULL) return getterSelector;

    NSString *name = @(property_getName(property));
    return NSSelectorFromString(name);
}



static BOOL addSetterToClassForPropertyFromClass(Class mutableClass, objc_property_t property, Class immutableClass) {
#define ADD_SETTER_FOR_TYPE(TYPE, OBJECT_GENERATOR)  \
{\
    IMP setterImp = ({ \
        NSString *name = @(property_getName(property)); \
        imp_implementationWithBlock(^void(id instance, TYPE rawValue) {\
        id value = (OBJECT_GENERATOR); \
        [instance setValue:value forKey:name]; \
    });\
}); \
const char *types = [[NSString stringWithFormat:@"v@:%s", @encode(TYPE)] UTF8String]; \
class_addMethod(mutableClass, setterSelector, setterImp, types); \
}

#define ADD_SETTER_FOR_OBJECT_TYPE(TYPE) ADD_SETTER_FOR_TYPE(TYPE, {rawValue;})
#define ADD_SETTER_FOR_NSVALUE_TYPE(TYPE) ADD_SETTER_FOR_TYPE(TYPE, {[NSValue valueWithBytes:&rawValue objCType:@encode(TYPE)];})
#define ADD_SETTER_FOR_NSNUMBER_TYPE(TYPE) ADD_SETTER_FOR_TYPE(TYPE, {@(rawValue);})

#define TYPE_MATCHES_ENCODED_TYPE(TYPE, ENCODED_TYPE) (0 == strcmp(@encode(TYPE), ENCODED_TYPE))

    SEL setterSelector = setterSelectorForProperty(property); \
    BOOL shouldAddSetter = ![mutableClass instancesRespondToSelector:setterSelector];
    if (!shouldAddSetter) return YES;

    SEL getterSelector = getterSelectorForProperty(property);
    NSMethodSignature *getterSig = [immutableClass instanceMethodSignatureForSelector:getterSelector];
    const char *returnType = getterSig.methodReturnType;
    BOOL isObject = [@(returnType) hasPrefix:@"@"];
    if      (isObject)                                         {ADD_SETTER_FOR_OBJECT_TYPE(id)}
    else if (TYPE_MATCHES_ENCODED_TYPE(BOOL, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(BOOL)}
    else if (TYPE_MATCHES_ENCODED_TYPE(char, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(char)}
    else if (TYPE_MATCHES_ENCODED_TYPE(short, returnType))     {ADD_SETTER_FOR_NSNUMBER_TYPE(short)}
    else if (TYPE_MATCHES_ENCODED_TYPE(int, returnType))       {ADD_SETTER_FOR_NSNUMBER_TYPE(int)}
    else if (TYPE_MATCHES_ENCODED_TYPE(long, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(long)}
    else if (TYPE_MATCHES_ENCODED_TYPE(long long, returnType)) {ADD_SETTER_FOR_NSNUMBER_TYPE(long long)}
    else if (TYPE_MATCHES_ENCODED_TYPE(float, returnType))     {ADD_SETTER_FOR_NSNUMBER_TYPE(float)}
    else if (TYPE_MATCHES_ENCODED_TYPE(double, returnType))    {ADD_SETTER_FOR_NSNUMBER_TYPE(double)}

#pragma message "TODO: Add all types in the main frameworks"
    else if (TYPE_MATCHES_ENCODED_TYPE(NSRange, returnType))   {ADD_SETTER_FOR_NSVALUE_TYPE(NSRange)}
    else if (TYPE_MATCHES_ENCODED_TYPE(NSSize, returnType))    {ADD_SETTER_FOR_NSVALUE_TYPE(NSSize)}
    else if (TYPE_MATCHES_ENCODED_TYPE(NSPoint, returnType))   {ADD_SETTER_FOR_NSVALUE_TYPE(NSPoint)}
    else if (TYPE_MATCHES_ENCODED_TYPE(NSRect, returnType))    {ADD_SETTER_FOR_NSVALUE_TYPE(NSRect)}
    else if (TYPE_MATCHES_ENCODED_TYPE(CGSize, returnType))    {ADD_SETTER_FOR_NSVALUE_TYPE(CGSize)}
    else if (TYPE_MATCHES_ENCODED_TYPE(CGPoint, returnType))   {ADD_SETTER_FOR_NSVALUE_TYPE(CGPoint)}
    else if (TYPE_MATCHES_ENCODED_TYPE(CGRect, returnType))    {ADD_SETTER_FOR_NSVALUE_TYPE(CGRect)}
    else return NO;

    return YES;
#undef ADD_SETTER_FOR_TYPE
#undef ADD_SETTER_FOR_OBJECT_TYPE
#undef ADD_SETTER_FOR_NSNUMBER_TYPE
#undef ADD_SETTER_FOR_NSVALUE_TYPE
#undef TYPE_MATCHES_ENCODED_TYPE
}

#endif
