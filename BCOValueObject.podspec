#
#  Be sure to run `pod spec lint BCOValueObject.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "BCOValueObject"
  s.version      = "0.3"
  s.summary      = " BCOValueObject is an abstract Objective-C class for implementing value objects."

  s.description  = <<-DESC
 BCOValueObject is an abstract class for implementing value objects. BCOValueObject provides equality checking and uniquing and optionally support for mutable variants.

 BCOValueObject places the following restrictions on its subclasses:
 - Direct subclasses can only include readonly properties. These properties should only be set by the designated initializer. Direct subclasses are referred to as 'immutable variants'.
 - Immutable variants are thread safe.
 - Immutable variants may be subclassed to create 'mutable variants'. Mutable variants have the following restrictions:
    - Mutable variants must not add properties (direct ivars can be added but this is strongly discouraged).
    - Mutable variants should not be subclassed.
    - Setter declarations for mutable variants must be listed in a category. Implementations for setters will be automatically generated for most types. If a setter cannot be generated then an exception will be raised when the class is initialized. Setters which cannot be generated must be implemented like so:
        -(void)setTransform:(CATransform3D)transform
        {
            [self setValue:[NSValue valueWithCATransform3D:transform] forKey:@"transform"];
        }
      BCOValueObject overrides setValue:forKey: so that it will not cause an infinite loop when being called from within a setter providing that the class hierarchy requirements listed above are adhered to.
  - Mutable variants must be registered so that immutable variant can make mutable copies. The simplest way to do this is to call BCO_VALUE_OBJECT_REGISTER_MUTABLE_VARIANT from within the header file where the mutable variant is declared.
 
 Due to the subclassing restrictions protocols should be used to implement polymorphism.
                   DESC

  s.homepage     = "https://github.com/BenedictC/BCOValueObject"



  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Licensing your code is important. See http://choosealicense.com for more info.
  #  CocoaPods will detect a license file if there is a named LICENSE*
  #  Popular ones are 'MIT', 'BSD' and 'Apache License, Version 2.0'.
  #

  s.license      = { :type => "MIT", :file => "LICENSE" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the authors of the library, with email addresses. Email addresses
  #  of the authors are extracted from the SCM log. E.g. $ git log. CocoaPods also
  #  accepts just a name if you'd rather not provide an email address.
  #
  #  Specify a social_media_url where others can refer to, for example a twitter
  #  profile URL.
  #

  s.author             = { "Benedict Cohen" => "ben@benedictcohen.co.uk" }
  s.social_media_url   = "http://twitter.com/BenedictC"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

  # s.platform     = :ios
  # s.platform     = :ios, "5.0"

  #  When using multiple platforms
  # s.ios.deployment_target = "5.0"
  # s.osx.deployment_target = "10.7"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  s.source       = { :git => "https://github.com/BenedictC/BCOValueObject.git", :tag => "0.3" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any h, m, mm, c & cpp files. For header
  #  files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  s.source_files  = "BCOValueObject", "BCOValueObject/*.{h,m}"
  # s.exclude_files = "Classes/Exclude"

  s.public_header_files = "BCOValueObject/BCOValueObject.h"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }

end
