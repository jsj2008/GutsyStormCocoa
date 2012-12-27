//
//  GSChunkGeometryData.h
//  GutsyStorm
//
//  Created by Andrew Fox on 4/17/12.
//  Copyright 2012 Andrew Fox. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <OpenGL/OpenGL.h>
#import "GSChunkData.h"
#import "GSVertex.h"


@class GSChunkVoxelData;
@class GSNeighborhood;


@interface GSChunkGeometryData : GSChunkData
{
    /* There are two copies of the index buffer so that one can be used for
     * drawing the chunk while geometry generation is in progress. This
     * removes the need to have any locking surrounding access to data
     * related to VBO drawing.
     */
    
    BOOL needsVBORegeneration;
    GLsizei numIndicesForDrawing;
    GLuint vbo;
    
    NSConditionLock *lockGeometry;
    GLsizei numChunkVerts;
    struct vertex *vertsBuffer;
    BOOL dirty;
    int updateInFlight;
    
    NSURL *folder;
    dispatch_group_t groupForSaving;
    NSOpenGLContext *glContext;
    
 @public
    GLKVector3 corners[8];
    BOOL visible; // Used by GSChunkStore to note chunks it has determined are visible.
}

@property (assign) BOOL dirty;

- (id)initWithMinP:(GLKVector3)minP
            folder:(NSURL *)folder
    groupForSaving:(dispatch_group_t)groupForSaving
    chunkTaskQueue:(dispatch_queue_t)chunkTaskQueue
         glContext:(NSOpenGLContext *)_glContext;

/* Try to immediately update geometry using voxel data for the local neighborhood. If it is not possible to immediately take all
 * the locks on necessary resources then this method aborts the update and returns NO. If it is able to complete the update
 * successfully then it returns YES and marks this GSChunkGeometryData as being clean. (dirty=NO)
 */
- (BOOL)tryToUpdateWithVoxelData:(GSNeighborhood *)neighborhood;

- (BOOL)drawGeneratingVBOsIfNecessary:(BOOL)allowVBOGeneration;

@end
