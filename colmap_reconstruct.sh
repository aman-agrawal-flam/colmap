#!/bin/bash

# COLMAP Automation Script (CPU-optimized)
# Usage: ./colmap_reconstruct.sh /path/to/project_directory

# Check if directory argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/project_directory"
    echo "Note: The directory should contain an 'images' subfolder with your images"
    exit 1
fi

# Set the base directory
BASE_DIR="$1"
IMAGES_DIR="$BASE_DIR/images"

# Check if images directory exists
if [ ! -d "$IMAGES_DIR" ]; then
    echo "Error: Images directory not found at $IMAGES_DIR"
    echo "Please create an 'images' subfolder and add your images there"
    exit 1
fi

# Count images to verify
IMAGE_COUNT=$(ls -1 "$IMAGES_DIR" | wc -l)
echo "Found $IMAGE_COUNT images in $IMAGES_DIR"

if [ "$IMAGE_COUNT" -lt 3 ]; then
    echo "Warning: Very few images found. COLMAP typically works best with multiple overlapping images."
fi

# Create required directories, removing them first if they exist
echo "Setting up directory structure..."
rm -rf "$BASE_DIR/database" "$BASE_DIR/sparse" "$BASE_DIR/dense"
mkdir -p "$BASE_DIR/database"
mkdir -p "$BASE_DIR/sparse"
mkdir -p "$BASE_DIR/dense"

# Define paths
DATABASE_PATH="$BASE_DIR/database/database.db"
SPARSE_PATH="$BASE_DIR/sparse"
DENSE_PATH="$BASE_DIR/dense"

# Detect number of CPU cores to use (leave one free)
CPU_CORES=$(( $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) - 1 ))
if [ "$CPU_CORES" -lt 1 ]; then
    CPU_CORES=1
fi
echo "Using $CPU_CORES CPU cores for processing"

echo "Starting COLMAP reconstruction pipeline..."

# 1. Feature extraction
echo "Step 1/5: Extracting features (this may take a while)..."
colmap feature_extractor \
    --database_path "$DATABASE_PATH" \
    --image_path "$IMAGES_DIR" \
    --SiftExtraction.use_gpu 0 \
    --SiftExtraction.num_threads $CPU_CORES

# Check if previous step was successful
if [ $? -ne 0 ]; then
    echo "Error: Feature extraction failed"
    exit 1
fi

# 2. Feature matching
echo "Step 2/5: Matching features (this may take a while)..."
colmap exhaustive_matcher \
    --database_path "$DATABASE_PATH" \
    --SiftMatching.use_gpu 0 \
    --SiftMatching.num_threads $CPU_CORES

if [ $? -ne 0 ]; then
    echo "Error: Feature matching failed"
    exit 1
fi

# 3. Sparse reconstruction
echo "Step 3/5: Performing sparse reconstruction (this may take a while)..."
colmap mapper \
    --database_path "$DATABASE_PATH" \
    --image_path "$IMAGES_DIR" \
    --output_path "$SPARSE_PATH" \
    --Mapper.num_threads $CPU_CORES

if [ $? -ne 0 ]; then
    echo "Error: Sparse reconstruction failed"
    exit 1
fi

# Check if the sparse reconstruction actually produced a model
if [ ! -d "$SPARSE_PATH/0" ]; then
    echo "Error: Sparse reconstruction did not produce a model"
    echo "This typically happens when COLMAP couldn't match enough features between images"
    echo "Suggestion: Try with more images with better overlap or different settings"
    exit 1
fi

# 4. Image undistortion for dense reconstruction
echo "Step 4/5: Undistorting images for dense reconstruction..."
colmap image_undistorter \
    --image_path "$IMAGES_DIR" \
    --input_path "$SPARSE_PATH/0" \
    --output_path "$DENSE_PATH" \
    --max_image_size 2000

if [ $? -ne 0 ]; then
    echo "Error: Image undistortion failed"
    exit 1
fi

# 5. Dense reconstruction with CPU-optimized settings
echo "Step 5/5: Performing dense reconstruction (this may take a long time)..."
echo "          Using CPU-optimized settings with $CPU_CORES threads"

# Use CPU for patch match stereo with optimized settings
colmap patch_match_stereo \
    --workspace_path "$DENSE_PATH" \
    --workspace_format COLMAP \
    --PatchMatchStereo.gpu_index -1 \
    --PatchMatchStereo.num_iterations 5 \
    --PatchMatchStereo.window_radius 5 \
    --PatchMatchStereo.window_step 2 \
    --PatchMatchStereo.num_samples 15 \
    --PatchMatchStereo.num_threads $CPU_CORES

if [ $? -ne 0 ]; then
    echo "Error: Stereo matching failed"
    exit 1
fi

echo "Creating final dense point cloud..."
colmap stereo_fusion \
    --workspace_path "$DENSE_PATH" \
    --workspace_format COLMAP \
    --input_type geometric \
    --output_path "$DENSE_PATH/fused.ply" \
    --StereoFusion.num_threads $CPU_CORES

if [ $? -ne 0 ]; then
    echo "Error: Stereo fusion failed"
    exit 1
fi

# Optional: Create mesh
echo "Creating mesh from point cloud..."
colmap poisson_mesher \
    --input_path "$DENSE_PATH/fused.ply" \
    --output_path "$DENSE_PATH/mesh.ply" \
    --PoissonMeshing.trim 7

# Summarize results
echo ""
echo "==== COLMAP Reconstruction Complete ===="
echo "Input images: $IMAGE_COUNT"
echo "Reconstruction results:"
echo "  - Sparse point cloud: $SPARSE_PATH/0/points3D.bin"
echo "  - Dense point cloud: $DENSE_PATH/fused.ply"
echo "  - Mesh: $DENSE_PATH/mesh.ply"
echo ""
echo "Success! Your 3D reconstruction is complete."
echo "You can view the results using MeshLab or another 3D viewer."