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

        BCVMutablePerson *mutablePerson = [BCVMutablePerson new];

        BVOObserver *observer = [BVOObserver new];

        [mutablePerson addObserver:observer forKeyPath:@"name" options:0 context:NULL];
        [mutablePerson addObserver:observer forKeyPath:@"dateOfBirth" options:0 context:NULL];
        [mutablePerson addObserver:observer forKeyPath:@"arf" options:0 context:NULL];
        [mutablePerson addObserver:observer forKeyPath:@"transform" options:0 context:NULL];
        [mutablePerson addObserver:observer forKeyPath:@"range" options:0 context:NULL];

        mutablePerson.arf = 7;
        mutablePerson.arf = 8;
        mutablePerson.dateOfBirth = [NSDate date];
        mutablePerson.name = @"afsgdf";
        mutablePerson.transform = CATransform3DMakeRotation(M_1_PI, 4, 8, 16);
        mutablePerson.range = NSMakeRange(0, 1234);

        BCVPerson *person = [[BCVPerson alloc] initWithKeysAndValues:
            @"arf", @(mutablePerson.arf),
            @"dateOfBirth", mutablePerson.dateOfBirth,
            @"name", mutablePerson.name,
            @"transform", [mutablePerson valueForKey:@"transform"],
            @"range", [NSValue valueWithRange:NSMakeRange(0, 1234)],
        nil];

        NSLog(@"Equal objects: %i", [mutablePerson isEqual:person]);

        [mutablePerson removeObserver:observer forKeyPath:@"name"];
        [mutablePerson removeObserver:observer forKeyPath:@"dateOfBirth"];
        [mutablePerson removeObserver:observer forKeyPath:@"arf"];
        [mutablePerson removeObserver:observer forKeyPath:@"transform"];
        [mutablePerson removeObserver:observer forKeyPath:@"range"];
    }
    return 0;
}
