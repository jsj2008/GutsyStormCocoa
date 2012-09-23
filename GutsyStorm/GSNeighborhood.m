//
//  GSGridNeighbors.m
//  GutsyStorm
//
//  Created by Andrew Fox on 9/11/12.
//  Copyright (c) 2012 Andrew Fox. All rights reserved.
//

#import "GSNeighborhood.h"
#import "Voxel.h"
#import "GSChunkVoxelData.h"
#import "GSChunkStore.h"


@implementation GSNeighborhood

+ (NSLock *)_sharedVoxelDataLock
{
    static dispatch_once_t onceToken;
    static NSLock *a = nil;
    
    dispatch_once(&onceToken, ^{
        a = [[NSLock alloc] init];
        [a setName:@"GSNeighborhood._sharedVoxelDataLock"];
    });
    
    return a;
}


+ (GSVector3)offsetForNeighborIndex:(neighbor_index_t)idx
{
    switch(idx)
    {
        case CHUNK_NEIGHBOR_POS_X_NEG_Z:
            return GSVector3_Make(+CHUNK_SIZE_X, 0, -CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_POS_X_ZER_Z:
            return GSVector3_Make(+CHUNK_SIZE_X, 0, 0);
            
        case CHUNK_NEIGHBOR_POS_X_POS_Z:
            return GSVector3_Make(+CHUNK_SIZE_X, 0, +CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_NEG_X_NEG_Z:
            return GSVector3_Make(-CHUNK_SIZE_X, 0, -CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_NEG_X_ZER_Z:
            return GSVector3_Make(-CHUNK_SIZE_X, 0, 0);
            
        case CHUNK_NEIGHBOR_NEG_X_POS_Z:
            return GSVector3_Make(-CHUNK_SIZE_X, 0, +CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_ZER_X_NEG_Z:
            return GSVector3_Make(0, 0, -CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_ZER_X_POS_Z:
            return GSVector3_Make(0, 0, +CHUNK_SIZE_Z);
            
        case CHUNK_NEIGHBOR_CENTER:
            return GSVector3_Make(0, 0, 0);
            
        case CHUNK_NUM_NEIGHBORS:
            [NSException raise:NSInvalidArgumentException format:@"\"idx\" must not be CHUNK_NUM_NEIGHBORS."];
    }
    
    NSAssert(NO, @"shouldn't get here");
    return GSVector3_Make(0, 0, 0);
}


- (id)init
{
    self = [super init];
    if (self) {
        for(size_t i = 0; i < CHUNK_NUM_NEIGHBORS; ++i)
        {
            neighbors[i] = nil;
        }
    }
    
    return self;
}


- (void)dealloc
{
    for(neighbor_index_t i = 0; i < CHUNK_NUM_NEIGHBORS; ++i)
    {
        [neighbors[i] release];
    }
    
    [super dealloc];
}


- (GSChunkVoxelData *)neighborAtIndex:(neighbor_index_t)idx
{
    NSAssert(idx < CHUNK_NUM_NEIGHBORS, @"idx is out of range");
    return neighbors[idx];
}


- (void)setNeighborAtIndex:(neighbor_index_t)idx neighbor:(GSChunkVoxelData *)neighbor
{
    NSAssert(idx < CHUNK_NUM_NEIGHBORS, @"idx is out of range");
    [neighbors[idx] release];
    neighbors[idx] = neighbor;
    [neighbors[idx] retain];
}


- (void)enumerateNeighborsWithBlock:(void (^)(GSChunkVoxelData*))block
{
    for(neighbor_index_t i = 0; i < CHUNK_NUM_NEIGHBORS; ++i)
    {
        block(neighbors[i]);
    }
}


- (BOOL)tryReaderAccessToVoxelDataUsingBlock:(void (^)(void))block
{
    NSMutableArray *locksTaken = [[NSMutableArray alloc] initWithCapacity:CHUNK_NUM_NEIGHBORS];
    
    for(neighbor_index_t i = 0; i < CHUNK_NUM_NEIGHBORS; ++i)
    {
        if([neighbors[i].lockVoxelData tryLockForReading]) {
            [locksTaken addObject:neighbors[i].lockVoxelData];
        } else {
            // It was not possible to lock all neighbors, so unwind and bail out.
            for(GSReaderWriterLock *lock in locksTaken)
            {
                [lock unlockForReading];
            }
            
            [locksTaken release];
            
            return NO;
        }
    }
    [locksTaken release];
    
    block();
    
    [self enumerateNeighborsWithBlock:^(GSChunkVoxelData *neighbor) {
        [neighbor.lockVoxelData unlockForReading];
    }];
    
    return YES;
}


- (void)readerAccessToVoxelDataUsingBlock:(void (^)(void))block
{
    [[GSNeighborhood _sharedVoxelDataLock] lock];
    [self enumerateNeighborsWithBlock:^(GSChunkVoxelData *neighbor) {
        [neighbor.lockVoxelData lockForReading];
    }];
    [[GSNeighborhood _sharedVoxelDataLock] unlock];
    
    block();
    
    [self enumerateNeighborsWithBlock:^(GSChunkVoxelData *neighbor) {
        [neighbor.lockVoxelData unlockForReading];
    }];
}


- (GSChunkVoxelData *)neighborVoxelAtPoint:(GSIntegerVector3 *)chunkLocalP
{
    if(chunkLocalP->x >= CHUNK_SIZE_X) {
        chunkLocalP->x -= CHUNK_SIZE_X;
        
        if(chunkLocalP->z < 0) {
            chunkLocalP->z += CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_POS_X_NEG_Z];
        } else if(chunkLocalP->z >= CHUNK_SIZE_Z) {
            chunkLocalP->z -= CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_POS_X_POS_Z];
        } else {
            return [self neighborAtIndex:CHUNK_NEIGHBOR_POS_X_ZER_Z];
        }
    } else if(chunkLocalP->x < 0) {
        chunkLocalP->x += CHUNK_SIZE_X;
        
        if(chunkLocalP->z < 0) {
            chunkLocalP->z += CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_NEG_X_NEG_Z];
        } else if(chunkLocalP->z >= CHUNK_SIZE_Z) {
            chunkLocalP->z -= CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_NEG_X_POS_Z];
        } else {
            return [self neighborAtIndex:CHUNK_NEIGHBOR_NEG_X_ZER_Z];
        }
    } else {
        if(chunkLocalP->z < 0) {
            chunkLocalP->z += CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_ZER_X_NEG_Z];
        } else if(chunkLocalP->z >= CHUNK_SIZE_Z) {
            chunkLocalP->z -= CHUNK_SIZE_Z;
            return [self neighborAtIndex:CHUNK_NEIGHBOR_ZER_X_POS_Z];
        } else {
            return [self neighborAtIndex:CHUNK_NEIGHBOR_CENTER];
        }
    }
}


- (BOOL)emptyAtPoint:(GSIntegerVector3)p
{
    // Assumes each chunk spans the entire vertical extent of the world.
    
    if(p.y < 0) {
        return NO; // Space below the world is always full.
    }
    
    if(p.y >= CHUNK_SIZE_Y) {
        return YES; // Space above the world is always empty.
    }
    
    return isVoxelEmpty([[self neighborVoxelAtPoint:&p] voxelAtLocalPosition:p]);
}


- (uint8_t)lightAtPoint:(GSIntegerVector3)p getter:(GSLightingBuffer* (^)(GSChunkVoxelData *c))getter
{
    // Assumes each chunk spans the entire vertical extent of the world.
    
    if(p.y < 0) {
        return 0; // Space below the world is always dark.
    }
    
    if(p.y >= CHUNK_SIZE_Y) {
        return CHUNK_LIGHTING_MAX; // Space above the world is always bright.
    }
    
    GSChunkVoxelData *chunk = [self neighborVoxelAtPoint:&p];
    GSLightingBuffer *lightingBuffer = getter(chunk);
    
    uint8_t lightLevel = [lightingBuffer lightAtPoint:p];

    assert(lightLevel >= 0 && lightLevel <= CHUNK_LIGHTING_MAX);
    
    return lightLevel;
}

@end
