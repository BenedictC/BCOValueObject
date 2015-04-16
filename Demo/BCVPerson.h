//
//  BCVPerson.h
//  ValueObjects
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import "BCOValueObject.h"
#import <QuartzCore/QuartzCore.h>



@interface BCVPerson : BCOValueObject
@property(nonatomic, readonly, copy) NSString *name;
@property(nonatomic, readonly) NSDate *dateOfBirth;
@property(nonatomic, readonly) NSInteger arf;
@property(nonatomic, readonly) CATransform3D transform;
@property(nonatomic, readonly) NSRange range;
@end



#pragma mark - Mutable subclass
@interface BCVMutablePerson : BCVPerson
@end



//These methods are dynamically created at runtime by BVOObject. They are declared in a category to avoid unimplemented method warnings.
@interface BCVMutablePerson (Setters)

-(void)setName:(NSString *)name;
-(void)setDateOfBirth:(NSDate *)dateOfBirth;
-(void)setArf:(NSInteger)arf;

-(void)setTransform:(CATransform3D)transform;
-(void)setRange:(NSRange)range;

@end



BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT(BCVMutablePerson);
