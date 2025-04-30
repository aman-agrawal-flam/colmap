import open3d as o3d
import numpy as np

# Load point cloud
print("Loading point cloud...")
pcd = o3d.io.read_point_cloud("input/coke/sparse/sparse.ply")

# Estimate normals if they don't exist
if not pcd.has_normals():
    print("Estimating normals...")
    pcd.estimate_normals(search_param=o3d.geometry.KDTreeSearchParamHybrid(radius=0.1, max_nn=30))
    pcd.orient_normals_consistent_tangent_plane(k=15)

# Perform Poisson surface reconstruction
print("Running Poisson surface reconstruction...")
mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
    pcd, depth=9, scale=1.1, linear_fit=False)

# Filter out low density vertices
print("Filtering mesh...")
vertices_to_remove = densities < np.quantile(densities, 0.1)
mesh.remove_vertices_by_mask(vertices_to_remove)

# Optimize mesh
print("Optimizing mesh...")
mesh = mesh.filter_smooth_simple(number_of_iterations=5)
mesh.compute_vertex_normals()

# Save the mesh
print("Saving mesh...")
o3d.io.write_triangle_mesh("input/coke/sparse/mesh_open3d.ply", mesh)
print("Done!")