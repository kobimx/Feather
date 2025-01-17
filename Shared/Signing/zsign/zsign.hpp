//
//  zsign.hpp
//  feather
//
//  Created by HAHALOSAH on 5/22/24.
//

#ifndef zsign_hpp
#define zsign_hpp

#include <stdio.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool InjectDyLib(NSString *filePath,
				 NSString *dylibPath,
				 bool weakInject,
				 bool bCreate);

bool ChangeDylibPath(NSString *filePath,
					 NSString *oldPath,
					 NSString *newPath);

int zsign(NSString *app,
		  NSString *prov,
		  NSString *key,
		  NSString *pass,
		  NSString *bundleid,
		  NSString *displayname,
		  NSString *bundleversion
		  );

#ifdef __cplusplus
}
#endif

#endif /* zsign_hpp */
