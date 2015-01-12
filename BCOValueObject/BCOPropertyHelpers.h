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

#endif
