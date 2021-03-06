//
//  GSVBOHolder.h
//  GutsyStorm
//
//  Created by Andrew Fox on 3/24/13.
//  Copyright (c) 2013 Andrew Fox. All rights reserved.
//

#import <Foundation/Foundation.h>

// Holds an OpenGL vertex buffer object, allowing it to be reference counted.
@interface GSVBOHolder : NSObject

@property (readonly) GLuint handle;

- (id)initWithHandle:(GLuint)handle context:(NSOpenGLContext *)context;

@end
