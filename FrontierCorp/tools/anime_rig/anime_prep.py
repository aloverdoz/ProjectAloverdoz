"""Imported character GLB -> decimated, triangulated mesh in game coords (x fwd, y up, z lateral), saved as npz."""
import bpy, sys, numpy as np
src, out, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
H = float(sys.argv[4]) if len(sys.argv) > 4 else 1.72
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o; o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
n0 = sum(len(p.vertices) - 2 for p in o.data.polygons)
d = o.modifiers.new("dec", "DECIMATE"); d.ratio = target / n0; d.delimit = {"UV"}
bpy.ops.object.modifier_apply(modifier="dec")
o.modifiers.new("tri", "TRIANGULATE"); bpy.ops.object.modifier_apply(modifier="tri")
for p in o.data.polygons: p.use_smooth = True
me = o.data
me.update()
nv = len(me.vertices); nl = len(me.loops)
co = np.zeros(nv * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
vn = np.zeros(nv * 3, np.float32); me.vertices.foreach_get("normal", vn); vn = vn.reshape(-1, 3)
lv = np.zeros(nl, np.int32); me.loops.foreach_get("vertex_index", lv)
uv = np.zeros(nl * 2, np.float32); me.uv_layers.active.data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
# split vertices on UV seams
key = np.round(uv * 8192).astype(np.int64)
k = lv.astype(np.int64) * (1 << 40) + key[:, 0] * (1 << 20) + key[:, 1]
uk, first, inv = np.unique(k, return_index=True, return_inverse=True)
V = co[lv[first]]; N = vn[lv[first]]; UV = uv[first]; I = inv.astype(np.int32)
# blender (front -Y, up Z) -> game (x fwd, y up, z = -x_blender)
G = np.stack([-V[:, 1], V[:, 2], -V[:, 0]], 1)
GN = np.stack([-N[:, 1], N[:, 2], -N[:, 0]], 1)
s = H / (G[:, 1].max() - G[:, 1].min())
G = (G - [0, G[:, 1].min(), 0]) * s
G[:, 0] -= (G[:, 0].max() + G[:, 0].min()) / 2
G[:, 2] -= (G[:, 2].max() + G[:, 2].min()) / 2
UV[:, 1] = 1.0 - UV[:, 1]
np.savez(out, v=G.astype(np.float32), n=GN.astype(np.float32), uv=UV.astype(np.float32), i=I)
print("PREP tris", len(I) // 3, "verts", len(G), "from", n0)
img = [i for i in bpy.data.images if "basecolor" in i.name.lower()] or list(bpy.data.images)
if img:
    im = img[0]; im.scale(2048, 2048); im.filepath_raw = out.replace(".npz", "_tex.png"); im.file_format = "PNG"; im.save()
    print("PREP tex", im.filepath_raw)
