# BCOValueObject
BCOValueObject is an Objective-C class designed to remove the boiler plate code required for creating immutable value objects. It's currently an experiment and may never evolve into a full project.


BCOValueObject provides equality and uniquing of immutable object. BCOValueObject subclasses can also be subclassed to create mutable variants. The mutable and immutable variants follow the Cocoa patterns for copy and mutable copy. Mutable variants supports KVO.
