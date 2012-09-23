//
//  GSChunkVoxelData.h
//  GutsyStorm
//
//  Created by Andrew Fox on 4/17/12.
//  Copyright 2012 Andrew Fox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GSChunkData.h"
#import "GSIntegerVector3.h"
#import "GSReaderWriterLock.h"
#import "Voxel.h"
#import "GSNeighborhood.h"
#import "GSLightingBuffer.h"


typedef void (^terrain_generator_t)(GSVector3, voxel_t*);


@interface GSChunkVoxelData : GSChunkData
{
    NSURL *folder;
    dispatch_group_t groupForSaving;
    dispatch_queue_t chunkTaskQueue;
    
    GSReaderWriterLock *lockVoxelData;
    voxel_t *voxelData; // the voxels that make up the chunk
    
    GSLightingBuffer *sunlight; // lighting contributions from sunlight
}

@property (readonly, nonatomic) voxel_t *voxelData;
@property (readonly, nonatomic) GSLightingBuffer *sunlight;

/* There are circumstances when it is necessary to use this lock directly, but in most cases the reader/writer accessor methods
 * here and in GSNeighborhood should be preferred.
 */
@property (readonly, nonatomic) GSReaderWriterLock *lockVoxelData;

+ (NSString *)fileNameForVoxelDataFromMinP:(GSVector3)minP;

- (id)initWithMinP:(GSVector3)minP
            folder:(NSURL *)folder
    groupForSaving:(dispatch_group_t)groupForSaving
    chunkTaskQueue:(dispatch_queue_t)chunkTaskQueue
         generator:(terrain_generator_t)callback;

// Must call after modifying voxel data and while still holding the lock on "lockVoxelData".
- (void)voxelDataWasModified;

// Obtains a reader lock on the voxel data and allows the caller to access it in the specified block.
- (void)readerAccessToVoxelDataUsingBlock:(void (^)(void))block;

/* Obtains a writer lock on the voxel data and allows the caller to access it in the specified block. Calls -voxelDataWasModified
 * after the block returns.
 */
- (void)writerAccessToVoxelDataUsingBlock:(void (^)(void))block;

// Assumes the caller is already holding "lockVoxelData".
- (voxel_t)voxelAtLocalPosition:(GSIntegerVector3)chunkLocalP;
- (voxel_t *)pointerToVoxelAtLocalPosition:(GSIntegerVector3)chunkLocalP;

// Rebuilds sunlight for this chunk and then calls the completion handler block.
- (void)rebuildSunlightWithNeighborhood:(GSNeighborhood *)neighborhood completionHandler:(void (^)(void))completionHandler;

@end