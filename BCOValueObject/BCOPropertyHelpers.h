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



//# The structs where found using the following Ruby script:
//
// #!/usr/bin/ruby
//
// paths = Array.new
//
// #OS X
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/System/Library/Frameworks/Foundation.framework/Headers/*.h')
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/System/Library/Frameworks/AppKit.framework/Headers/*.h')
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/System/Library/Frameworks/CoreGraphics.framework/Headers/*.h')
//
// #iOS
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.1.sdk/System/Library/Frameworks/Foundation.framework/Headers/*.h')
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.1.sdk/System/Library/Frameworks/UIKit.framework/Headers/*.h')
// paths.push('/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.1.sdk/System/Library/Frameworks/CoreGraphics.framework/Headers/*.h')
//
//
// paths.each do |path|
//
//    sdk = path.scan(/([a-zA-Z0-9\.]*)\.sdk/)[0][0]
//    framework = path.scan(/([a-zA-Z0-9]*)\.frame/)[0][0]
//    title = sdk + ': ' + framework
//    puts title
//    puts '-' * title.length #Ruby is lolz
//
//	Dir[path].each do |filename|
//        s = IO.read(filename)
//        regex = /typedef\s+struct\s+[_A-Za-z0-9]*(?:\s*\{[\s\S]*?\})?\s([a-zA-Z][a-zA-Z0-9_]*);/
//        matches = s.scan(regex)
//        if matches
//            puts matches
//        end
//	end
//    puts '
// '
// end



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

#define ELSE_IF_MATCHES_STRUCT(STRUCT, RETURN_TYPE)  else if (TYPE_MATCHES_ENCODED_TYPE(STRUCT, RETURN_TYPE))   {ADD_SETTER_FOR_NSVALUE_TYPE(STRUCT)}

static BOOL addSetterToClassForPropertyFromClass(Class mutableClass, objc_property_t property, Class immutableClass) {
    SEL setterSelector = setterSelectorForProperty(property); \
    BOOL shouldAddSetter = ![mutableClass instancesRespondToSelector:setterSelector];
    if (!shouldAddSetter) return YES;

    SEL getterSelector = getterSelectorForProperty(property);
    NSMethodSignature *getterSig = [immutableClass instanceMethodSignatureForSelector:getterSelector];
    const char *returnType = getterSig.methodReturnType;
    BOOL isObject = [@(returnType) hasPrefix:@"@"];
    //Objects
    if      (isObject)                                         {ADD_SETTER_FOR_OBJECT_TYPE(id)}

    //Scalars
    else if (TYPE_MATCHES_ENCODED_TYPE(BOOL, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(BOOL)}
    else if (TYPE_MATCHES_ENCODED_TYPE(char, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(char)}
    else if (TYPE_MATCHES_ENCODED_TYPE(short, returnType))     {ADD_SETTER_FOR_NSNUMBER_TYPE(short)}
    else if (TYPE_MATCHES_ENCODED_TYPE(int, returnType))       {ADD_SETTER_FOR_NSNUMBER_TYPE(int)}
    else if (TYPE_MATCHES_ENCODED_TYPE(long, returnType))      {ADD_SETTER_FOR_NSNUMBER_TYPE(long)}
    else if (TYPE_MATCHES_ENCODED_TYPE(long long, returnType)) {ADD_SETTER_FOR_NSNUMBER_TYPE(long long)}
    else if (TYPE_MATCHES_ENCODED_TYPE(float, returnType))     {ADD_SETTER_FOR_NSNUMBER_TYPE(float)}
    else if (TYPE_MATCHES_ENCODED_TYPE(double, returnType))    {ADD_SETTER_FOR_NSNUMBER_TYPE(double)}

    //Structs
#if __MAC_OS_X_VERSION_MIN_ALLOWED >= 1000
    //MacOSX10.10: Foundation
    //-----------------------
    adsgfd
    ELSE_IF_MATCHES_STRUCT(NSAffineTransformStruct, returnType)
    ELSE_IF_MATCHES_STRUCT(NSSwappedFloat, returnType)
    ELSE_IF_MATCHES_STRUCT(NSSwappedDouble, returnType)
    ELSE_IF_MATCHES_STRUCT(NSDecimal, returnType)
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
    ELSE_IF_MATCHES_STRUCT(NSFastEnumerationState, returnType) //10.5
#endif
    ELSE_IF_MATCHES_STRUCT(NSPoint, returnType)
    ELSE_IF_MATCHES_STRUCT(NSSize, returnType)
    ELSE_IF_MATCHES_STRUCT(NSRect, returnType)
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    ELSE_IF_MATCHES_STRUCT(NSEdgeInsets, returnType) //10.7
#endif
    ELSE_IF_MATCHES_STRUCT(NSHashEnumerator, returnType)
    ELSE_IF_MATCHES_STRUCT(NSHashTableCallBacks, returnType)
    ELSE_IF_MATCHES_STRUCT(NSMapEnumerator, returnType)
    ELSE_IF_MATCHES_STRUCT(NSMapTableKeyCallBacks, returnType)
    ELSE_IF_MATCHES_STRUCT(NSMapTableValueCallBacks, returnType)
    ELSE_IF_MATCHES_STRUCT(NSOperatingSystemVersion, returnType)
    ELSE_IF_MATCHES_STRUCT(NSRange, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSZone, returnType)

    //MacOSX10.10: AppKit
    //-------------------
    //    ELSE_IF_MATCHES_STRUCT(NSEdgeInsets, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSOpenGLContextAuxiliary, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSScreenAuxiliaryOpaque, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSTypesetterGlyphInfo, returnType)

    //MacOSX10.10: CoreGraphics
    //-------------------------
    ELSE_IF_MATCHES_STRUCT(CGAffineTransform, returnType)
    ELSE_IF_MATCHES_STRUCT(CGDataConsumerCallbacks, returnType)
    ELSE_IF_MATCHES_STRUCT(CGPoint, returnType)
    ELSE_IF_MATCHES_STRUCT(CGSize, returnType)
    ELSE_IF_MATCHES_STRUCT(CGRect, returnType)

    ELSE_IF_MATCHES_STRUCT(CGPatternCallbacks, returnType) //10.1
    ELSE_IF_MATCHES_STRUCT(CGFunctionCallbacks, returnType) //10.2
    ELSE_IF_MATCHES_STRUCT(CGPathElement, returnType) //10.2
    ELSE_IF_MATCHES_STRUCT(CGPSConverterCallbacks, returnType) //10.3
    ELSE_IF_MATCHES_STRUCT(CGScreenUpdateMoveDelta, returnType) //10.3
    ELSE_IF_MATCHES_STRUCT(CGEventTapInformation, returnType) //10.4

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
    ELSE_IF_MATCHES_STRUCT(CGDataProviderDirectCallbacks, returnType) //10.5
#endif
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090
    ELSE_IF_MATCHES_STRUCT(CGVector, returnType) ///10.9
#endif
    //    ELSE_IF_MATCHES_STRUCT(CGDeviceColor, returnType) //???
#endif

#if __IPHONE_OS_VERSION_MIN_ALLOWED >= 20000
    //iPhoneOS8.1: Foundation
    //-----------------------
    ELSE_IF_MATCHES_STRUCT(NSSwappedFloat, returnType)
    ELSE_IF_MATCHES_STRUCT(NSSwappedDouble, returnType)
    ELSE_IF_MATCHES_STRUCT(NSDecimal, returnType)
    ELSE_IF_MATCHES_STRUCT(NSFastEnumerationState, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSHashEnumerator, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSHashTableCallBacks, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSMapEnumerator, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSMapTableKeyCallBacks, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSMapTableValueCallBacks, returnType)
#if __IPHONE_OS_VERSION_MIN_ALLOWED >= 80000
    ELSE_IF_MATCHES_STRUCT(NSOperatingSystemVersion, returnType)
#endif
    ELSE_IF_MATCHES_STRUCT(NSRange, returnType)
    //    ELSE_IF_MATCHES_STRUCT(NSZone, returnType)

    //iPhoneOS8.1: UIKit
    //------------------
    ELSE_IF_MATCHES_STRUCT(UIEdgeInsets, returnType)
#if __IPHONE_OS_VERSION_MIN_ALLOWED >= 50000
    ELSE_IF_MATCHES_STRUCT(UIOffset, returnType)
#endif

    //iPhoneOS8.1: CoreGraphics
    //-------------------------
    ELSE_IF_MATCHES_STRUCT(CGAffineTransform, returnType)
    ELSE_IF_MATCHES_STRUCT(CGDataConsumerCallbacks, returnType)
    ELSE_IF_MATCHES_STRUCT(CGDataProviderDirectCallbacks, returnType)
    ELSE_IF_MATCHES_STRUCT(CGFunctionCallbacks, returnType)
    ELSE_IF_MATCHES_STRUCT(CGPoint, returnType)
    ELSE_IF_MATCHES_STRUCT(CGSize, returnType)
#if __IPHONE_OS_VERSION_MIN_ALLOWED >= 70000
    ELSE_IF_MATCHES_STRUCT(CGVector, returnType)
#endif
    ELSE_IF_MATCHES_STRUCT(CGRect, returnType)
    ELSE_IF_MATCHES_STRUCT(CGPathElement, returnType)
    ELSE_IF_MATCHES_STRUCT(CGPatternCallbacks, returnType)
#endif

    else return NO;

    return YES;
#undef ADD_SETTER_FOR_TYPE
#undef ADD_SETTER_FOR_OBJECT_TYPE
#undef ADD_SETTER_FOR_NSNUMBER_TYPE
#undef ADD_SETTER_FOR_NSVALUE_TYPE
#undef TYPE_MATCHES_ENCODED_TYPE
#undef ELSE_IF_MATCHES_STRUCT
}

#endif
