import bpy, math, json, sys
from mathutils import Vector, Quaternion
from pathlib import Path
from math import radians
root=Path(__file__).resolve().parents[2]
models=json.loads((root/'core/models.json').read_text())
def clean():
 bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,h,metal=0,rough=.44,glow=False):
 m=bpy.data.materials.get(name)
 if m:return m
 c=tuple(int(h[k:k+2],16)/255 for k in (1,3,5))
 c=tuple(((q+.055)/1.055)**2.4 if q>.04045 else q/12.92 for q in c)+(1,)
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=c;bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 if glow:bs.inputs['Emission Color'].default_value=c;bs.inputs['Emission Strength'].default_value=2.5
 m.diffuse_color=c;return m
def empty(n,p=None,pos=(0,0,0)):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.parent=p;o.location=pos;return o
def transform(coords):return Vector((coords[0],-coords[2],coords[1]))
def make_model(k):
 data=models[k];base=empty(k);yaw=empty('Yaw',base);pivot=empty('Pitch',yaw,(0,0,1.68));sled=empty('Recoil',pivot)
 for i,p in enumerate(data['parts']):
  kind=p['shape'];size=p['size'];pos=transform(p['pos']);role=p.get('role','')
  if role in ('pitch','slide'):pos.z-=1.68
  if kind=='box':bpy.ops.mesh.primitive_cube_add(size=1)
  else:bpy.ops.mesh.primitive_cylinder_add(vertices=p.get('seg',24),radius=.5,depth=1)
  o=bpy.context.object;o.name='%s_%02d'%(role or ('Chassis' if k=='turret' else 'Frame'),i);o.parent={'head':yaw,'pitch':pivot,'slide':sled}.get(role,base);o.location=pos;o.scale=(size[0],size[2],size[1])
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  angles=p.get('rot',[0,0,0]);o.rotation_euler=tuple(radians(v) for v in (angles[0],-angles[2],angles[1]))
  m=p.get('mat','paint');color=p['color']
  o.data.materials.append(mat(m+color,color,.67 if m in ('metal','dark') else .22,.58 if m=='belt' else .37,m=='glow'))
  bevel=o.modifiers.new('Edge fillets','BEVEL');bevel.width=min(size)*p.get('bevel',.055);bevel.segments=3;bevel.limit_method='ANGLE';bevel.harden_normals=True
  normal=o.modifiers.new('Panel normals','WEIGHTED_NORMAL')
  if k=='belt' and m=='belt':
   for j in range(14):
    bpy.ops.mesh.primitive_cube_add(size=1);r=bpy.context.object;r.name='Tread_%02d'%j;r.parent=base;r.location=((j+.5)*2/14-1,0,.2605);r.dimensions=(.022,1.23,.008);r.data.materials.append(mat('Graphite tread','#202a30',.18,.68))
 return base,yaw,pivot,sled
def render(path,focus,offset,zoom,quality=20):
 sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=quality;sc.cycles.use_denoising=False
 sc.world=bpy.data.worlds.new('Studio');sc.world.use_nodes=True;sc.world.node_tree.nodes.get('Background').inputs[0].default_value=(.26,.32,.41,1);sc.world.node_tree.nodes.get('Background').inputs[1].default_value=.65
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));bpy.context.object.data.materials.append(mat('Backdrop','#5d6c75',.06,.68))
 for p,power,sz,c in [((2,-4,7),650,5,(1,.88,.75)),((-4,1,4),520,5,(.71,.88,1)),((3,4,6),850,3,(1,.91,.78))]:
  bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=sz;o.data.color=c;o.rotation_euler=(Vector(focus)-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=Vector(focus)+Vector(offset));cam=bpy.context.object;cam.rotation_euler=(Vector(focus)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=zoom;sc.camera=cam
 sc.render.resolution_x=960;sc.render.resolution_y=720;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='JPEG';sc.render.image_settings.quality=94;sc.render.filepath=str(path);bpy.ops.render.render(write_still=True)
clean()
k = "belt"
base, yaw, pitch, sled = make_model(k)
for obj in (sled, pitch, yaw):
 bpy.data.objects.remove(obj, do_unlink=True)
bpy.context.scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(root / 'art/designed/belt.glb'), export_apply=True)
for offset in [-2, 2]:
 for obj in list(base.children):
  instance = obj.copy()
  instance.data = obj.data
  bpy.context.collection.objects.link(instance)
  instance.parent = None
  instance.location = obj.location + Vector((offset, 0, 0))
render(root / 'previews/belt.jpg', (0, 0, .13), (5, -7, 4.3), 6.9)
