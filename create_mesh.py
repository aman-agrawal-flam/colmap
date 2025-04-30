import sys
import subprocess

# Install required packages
print("Installing required packages...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "open3d", "numpy"])

import open3d as o3d
import numpy as np
import os

# Rest of your script remains the same...
# Path to the sparse reconstruction
sparse_path = "input/south-building/sparse"
output_mesh_path = "input/south-building/sparse/mesh.ply"

# Load points from COLMAP's points3D.txt
points = []
colors = []
print("Reading points from COLMAP reconstruction...")
with open(os.path.join(sparse_path, "points3D.txt"), "r") as f:
    for line in f:
        if line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) >= 7:
            points.append([float(parts[1]), float(parts[2]), float(parts[3])])
            colors.append([int(parts[4])/255, int(parts[5])/255, int(parts[6])/255])

# Create point cloud
pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(np.array(points))
pcd.colors = o3d.utility.Vector3dVector(np.array(colors))

# Estimate normals
print("Estimating normals...")
pcd.estimate_normals(search_param=o3d.geometry.KDTreeSearchParamHybrid(radius=0.1, max_nn=30))
pcd.orient_normals_consistent_tangent_plane(k=20)

# Create mesh using Poisson reconstruction
print("Creating mesh using Poisson reconstruction...")
mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
    pcd, depth=9, width=0, scale=1.1, linear_fit=False)

# Optional: Remove low-density vertices
print("Cleaning mesh...")
vertices_to_remove = densities < np.quantile(densities, 0.01)
mesh.remove_vertices_by_mask(vertices_to_remove)

# Optional: Transfer colors from point cloud to mesh
print("Transferring colors...")
mesh.paint_uniform_color([0.7, 0.7, 0.7])  # Default color

# Save the mesh
print(f"Saving mesh to {output_mesh_path}...")
o3d.io.write_triangle_mesh(output_mesh_path, mesh)

print("Mesh created and saved successfully")

# Optionally, visualize the mesh
print("Would you like to visualize the mesh? (y/n)")
answer = input()
if answer.lower() == 'y':
    o3d.visualization.draw_geometries([mesh])