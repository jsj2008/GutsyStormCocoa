//
//  GSLightingBuffer.m
//  GutsyStorm
//
//  Created by Andrew Fox on 9/18/12.
//  Copyright (c) 2012 Andrew Fox. All rights reserved.
//

#import "GSLightingBuffer.h"
#import "GSChunkVoxelData.h"

@implementation GSLightingBuffer

@synthesize lockLightingBuffer;
@synthesize lightingBuffer;

- (id)init
{
    self = [super init];
    if (self) {
        lightingBuffer = calloc(CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z, sizeof(int8_t));
        if(!lightingBuffer) {
            [NSException raise:@"Out of Memory" format:@"Failed to allocate memory for lighting buffer."];
        }
    }
    
    return self;
}

- (void)dealloc
{
    free(lightingBuffer);
    [lockLightingBuffer release];
    [super dealloc];
}

- (uint8_t)lightAtPoint:(GSIntegerVector3)p
{
    return *[self pointerToLightAtPoint:p];
}


- (uint8_t *)pointerToLightAtPoint:(GSIntegerVector3)p
{
    assert(SAMPLE);
    assert(p.x >= 0 && p.x < CHUNK_SIZE_X);
    assert(p.y >= 0 && p.y < CHUNK_SIZE_Y);
    assert(p.z >= 0 && p.z < CHUNK_SIZE_Z);
    
    size_t idx = INDEX(p.x, p.y, p.z);
    assert(idx >= 0 && idx < (CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z));
    
    return &lightingBuffer[idx];
}

// Assumes the caller is already holding "lockSAMPLE" on all neighbors and "lockVoxelData" on the center neighbor, at least.
- (void)interpolateLightAtPoint:(GSIntegerVector3)p
                         neighbors:(GSNeighborhood *)neighbors
                       outLighting:(block_lighting_t *)lighting
{
    /* Front is in the -Z direction and back is the +Z direction.
     * This is a totally arbitrary convention.
     */
    
    GSChunkVoxelData *center = [neighbors getNeighborAtIndex:CHUNK_NEIGHBOR_CENTER];
    voxel_t *voxelData = center.voxelData;
    
    // If the block is empty then bail out early. The point p is always within the chunk.
    if(isVoxelEmpty(voxelData[INDEX(p.x, p.y, p.z)])) {
        block_lighting_vertex_t packed = packBlockLightingValuesForVertex(CHUNK_LIGHTING_MAX,
                                                                          CHUNK_LIGHTING_MAX,
                                                                          CHUNK_LIGHTING_MAX,
                                                                          CHUNK_LIGHTING_MAX);
        
        lighting->top = packed;
        lighting->bottom = packed;
        lighting->left = packed;
        lighting->right = packed;
        lighting->front = packed;
        lighting->back = packed;
        return;
    }
    
#define SAMPLE(x, y, z) (samples[(x+1)*3*3 + (y+1)*3 + (z+1)])
    
    unsigned samples[3*3*3];
    
    for(ssize_t x = -1; x <= 1; ++x)
    {
        for(ssize_t y = -1; y <= 1; ++y)
        {
            for(ssize_t z = -1; z <= 1; ++z)
            {
                SAMPLE(x, y, z) = [neighbors getBlockSkylightAtPoint:GSIntegerVector3_Make(p.x + x, p.y + y, p.z + z)];
            }
        }
    }
    
    lighting->top = packBlockLightingValuesForVertex(averageLightValue(SAMPLE( 0, 1,  0),
                                                                       SAMPLE( 0, 1, -1),
                                                                       SAMPLE(-1, 1,  0),
                                                                       SAMPLE(-1, 1, -1)),
                                                     averageLightValue(SAMPLE( 0, 1,  0),
                                                                       SAMPLE( 0, 1, +1),
                                                                       SAMPLE(-1, 1,  0),
                                                                       SAMPLE(-1, 1, +1)),
                                                     averageLightValue(SAMPLE( 0, 1,  0),
                                                                       SAMPLE( 0, 1, +1),
                                                                       SAMPLE(+1, 1,  0),
                                                                       SAMPLE(+1, 1, +1)),
                                                     averageLightValue(SAMPLE( 0, 1,  0),
                                                                       SAMPLE( 0, 1, -1),
                                                                       SAMPLE(+1, 1,  0),
                                                                       SAMPLE(+1, 1, -1)));
    
    lighting->bottom = packBlockLightingValuesForVertex(averageLightValue(SAMPLE( 0, -1,  0),
                                                                          SAMPLE( 0, -1, -1),
                                                                          SAMPLE(-1, -1,  0),
                                                                          SAMPLE(-1, -1, -1)),
                                                        averageLightValue(SAMPLE( 0, -1,  0),
                                                                          SAMPLE( 0, -1, -1),
                                                                          SAMPLE(+1, -1,  0),
                                                                          SAMPLE(+1, -1, -1)),
                                                        averageLightValue(SAMPLE( 0, -1,  0),
                                                                          SAMPLE( 0, -1, +1),
                                                                          SAMPLE(+1, -1,  0),
                                                                          SAMPLE(+1, -1, +1)),
                                                        averageLightValue(SAMPLE( 0, -1,  0),
                                                                          SAMPLE( 0, -1, +1),
                                                                          SAMPLE(-1, -1,  0),
                                                                          SAMPLE(-1, -1, +1)));
    
    lighting->back = packBlockLightingValuesForVertex(averageLightValue(SAMPLE( 0, -1, 1),
                                                                        SAMPLE( 0,  0, 1),
                                                                        SAMPLE(-1, -1, 1),
                                                                        SAMPLE(-1,  0, 1)),
                                                      averageLightValue(SAMPLE( 0, -1, 1),
                                                                        SAMPLE( 0,  0, 1),
                                                                        SAMPLE(+1, -1, 1),
                                                                        SAMPLE(+1,  0, 1)),
                                                      averageLightValue(SAMPLE( 0, +1, 1),
                                                                        SAMPLE( 0,  0, 1),
                                                                        SAMPLE(+1, +1, 1),
                                                                        SAMPLE(+1,  0, 1)),
                                                      averageLightValue(SAMPLE( 0, +1, 1),
                                                                        SAMPLE( 0,  0, 1),
                                                                        SAMPLE(-1, +1, 1),
                                                                        SAMPLE(-1,  0, 1)));
    
    lighting->front = packBlockLightingValuesForVertex(averageLightValue(SAMPLE( 0, -1, -1),
                                                                         SAMPLE( 0,  0, -1),
                                                                         SAMPLE(-1, -1, -1),
                                                                         SAMPLE(-1,  0, -1)),
                                                       averageLightValue(SAMPLE( 0, +1, -1),
                                                                         SAMPLE( 0,  0, -1),
                                                                         SAMPLE(-1, +1, -1),
                                                                         SAMPLE(-1,  0, -1)),
                                                       averageLightValue(SAMPLE( 0, +1, -1),
                                                                         SAMPLE( 0,  0, -1),
                                                                         SAMPLE(+1, +1, -1),
                                                                         SAMPLE(+1,  0, -1)),
                                                       averageLightValue(SAMPLE( 0, -1, -1),
                                                                         SAMPLE( 0,  0, -1),
                                                                         SAMPLE(+1, -1, -1),
                                                                         SAMPLE(+1,  0, -1)));
    
    lighting->right = packBlockLightingValuesForVertex(averageLightValue(SAMPLE(+1,  0,  0),
                                                                         SAMPLE(+1,  0, -1),
                                                                         SAMPLE(+1, -1,  0),
                                                                         SAMPLE(+1, -1, -1)),
                                                       averageLightValue(SAMPLE(+1,  0,  0),
                                                                         SAMPLE(+1,  0, -1),
                                                                         SAMPLE(+1, +1,  0),
                                                                         SAMPLE(+1, +1, -1)),
                                                       averageLightValue(SAMPLE(+1,  0,  0),
                                                                         SAMPLE(+1,  0, +1),
                                                                         SAMPLE(+1, +1,  0),
                                                                         SAMPLE(+1, +1, +1)),
                                                       averageLightValue(SAMPLE(+1,  0,  0),
                                                                         SAMPLE(+1,  0, +1),
                                                                         SAMPLE(+1, -1,  0),
                                                                         SAMPLE(+1, -1, +1)));
    
    lighting->left = packBlockLightingValuesForVertex(averageLightValue(SAMPLE(-1,  0,  0),
                                                                        SAMPLE(-1,  0, -1),
                                                                        SAMPLE(-1, -1,  0),
                                                                        SAMPLE(-1, -1, -1)),
                                                      averageLightValue(SAMPLE(-1,  0,  0),
                                                                        SAMPLE(-1,  0, +1),
                                                                        SAMPLE(-1, -1,  0),
                                                                        SAMPLE(-1, -1, +1)),
                                                      averageLightValue(SAMPLE(-1,  0,  0),
                                                                        SAMPLE(-1,  0, +1),
                                                                        SAMPLE(-1, +1,  0),
                                                                        SAMPLE(-1, +1, +1)),
                                                      averageLightValue(SAMPLE(-1,  0,  0),
                                                                        SAMPLE(-1,  0, -1),
                                                                        SAMPLE(-1, +1,  0),
                                                                        SAMPLE(-1, +1, -1)));
    
#undef SAMPLE
}

- (void)readerAccessToBufferUsingBlock:(void (^)(void))block
{
    [lockLightingBuffer lockForReading];
    block();
    [lockLightingBuffer unlockForReading];
}


- (void)writerAccessToBufferUsingBlock:(void (^)(void))block
{
    [lockLightingBuffer lockForWriting];
    block();
    [lockLightingBuffer unlockForWriting];
}

@end