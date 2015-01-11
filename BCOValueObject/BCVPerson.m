//
//  BCVPerson.m
//  ValueObjects
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import "BCVPerson.h"



@implementation BCVPerson

@end



@implementation BCVMutablePerson

-(void)setName:(NSString *)name
{
    [self setValue:name forKey:@"name"];
}



-(void)setTransform:(CATransform3D)transform
{
    [self setValue:[NSValue valueWithCATransform3D:transform] forKey:@"transform"];
}


@end
