//
//  main.m
//  ValueObjects
//
//  Created by Benedict Cohen on 30/12/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BCVPerson.h"



@interface BVOObserver : NSObject
@end

@implementation BVOObserver
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"transform"]) {
        CATransform3D expectedTransform = CATransform3DMakeRotation(M_1_PI, 4, 8, 16);
        CATransform3D actualTransform = [[object valueForKey:keyPath] CATransform3DValue];
        NSLog(@"%@ is equal: %@", keyPath, @(CATransform3DEqualToTransform(expectedTransform, actualTransform)));
    } else if ([keyPath isEqual:@"range"]) {
        NSLog(@"%@", NSStringFromRange([[object valueForKey:keyPath] rangeValue]));
    } else {
        NSLog(@"%@: %@", keyPath, [object valueForKey:keyPath]);
    }
}
@end



int main(int argc, const char * argv[]) {
    @autoreleasepool {

        BCVPerson *person = [BCVPerson new];
        BCVMutablePerson *anotherPerson = [person mutableCopy];

        BVOObserver *observer = [BVOObserver new];

        [anotherPerson addObserver:observer forKeyPath:@"name" options:0 context:NULL];
        [anotherPerson addObserver:observer forKeyPath:@"dateOfBirth" options:0 context:NULL];
        [anotherPerson addObserver:observer forKeyPath:@"arf" options:0 context:NULL];
        [anotherPerson addObserver:observer forKeyPath:@"transform" options:0 context:NULL];
        [anotherPerson addObserver:observer forKeyPath:@"range" options:0 context:NULL];

        anotherPerson.arf = 7;
        anotherPerson.arf = 8;
        anotherPerson.dateOfBirth = [NSDate date];
        anotherPerson.name = @"afsgdf";
        anotherPerson.transform = CATransform3DMakeRotation(M_1_PI, 4, 8, 16);
        anotherPerson.range = NSMakeRange(0, 1234);

        [anotherPerson removeObserver:observer forKeyPath:@"name"];
        [anotherPerson removeObserver:observer forKeyPath:@"dateOfBirth"];
        [anotherPerson removeObserver:observer forKeyPath:@"arf"];
        [anotherPerson removeObserver:observer forKeyPath:@"transform"];
        [anotherPerson removeObserver:observer forKeyPath:@"range"];
    }
    return 0;
}
