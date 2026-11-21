import bpy, math
from mathutils import Vector, Matrix
from math import pi, cos, sin
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,h,metal,rough,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 rgb=tuple(((v/255+.055)/1.055)**2.4 if v/255>.04045 else v/255/12.92 for v in bytes.fromhex(h))
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 if emission:bs.inputs['Emission Color'].default_value=(*rgb,1);bs.inputs['Emission Strength'].default_value=emission
 m.diffuse_color=(*rgb,1);return m
gold=material('Saffron enamel','e49935',.36,.35); lip=material('Golden trim','ffd17b',.52,.34)
red=material('Oxide red','953d43',.48,.38); maroon=material('Dark lacquer','713b40',.55,.34)
dark=material('Carbon steel','363c40',.73,.31); black=material('Recess','1a2127',.56,.42); steel=material('Titanium','79818a',.66,.37)
grey=material('Slate housing','626b79',.48,.39); lightgrey=material('Chamfered armor','818b96',.52,.41)
light=material('Amber arc','ffb83f',.24,.28,1.2)
groups={}; role='base'
def finish(o,m,bevel=0,smooth=False):
 o.data.materials.append(m)
 if smooth:
  for f in o.data.polygons:f.use_smooth=True
 if bevel:
  mod=o.modifiers.new('Cast edge','BEVEL');mod.width=bevel;mod.segments=5;mod.limit_method='ANGLE';mod.harden_normals=True
 if bevel or smooth:
  mod=o.modifiers.new('Normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 groups.setdefault((role,m),[]).append(o);return o
def mesh(name,vs,faces,m,bevel=0,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,m,bevel,smooth)
def box(n,pos,dims,m,b=.014,angle=0):
 x,y,z=[v*.5 for v in dims];v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 o=mesh(n,v,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m,b);o.location=pos;o.rotation_euler.z=angle;return o
def lathe(n,pos,profile,m,axis='z',seg=72):
 # profile runs around the section, including the back of recessed rings
 vs=[];fs=[]
 for u,r in profile:
  for j in range(seg):
   a=2*pi*j/seg;v=(r*cos(a),r*sin(a),u)
   if axis=='x':v=(v[2],v[1],-v[0])
   if axis=='y':v=(v[0],v[2],-v[1])
   vs.append(v)
 for i in range(len(profile)):
  ni=(i+1)%len(profile)
  for j in range(seg):
   jj=(j+1)%seg;fs.append((i*seg+j,i*seg+jj,ni*seg+jj,ni*seg+j))
 o=mesh(n,vs,fs,m,smooth=True);o.location=pos;return o
def disk(n,pos,r,h,m,axis='z',seg=80):
 b=min(h*.2,r*.05);return lathe(n,pos,[(-h/2,.001),(-h/2,r-b),(-h/2+b,r),(h/2-b,r),(h/2,r-b),(h/2,.001)],m,axis,seg)
def ring(n,pos,r,t,h,m,axis='z',seg=80):
 b=min(t*.24,h*.23);return lathe(n,pos,[(-h/2,r-t+b),(-h/2,r-b),(-h/2+b,r),(h/2-b,r),(h/2,r-b),(h/2,r-t+b),(h/2-b,r-t),(-h/2+b,r-t)],m,axis,seg)
def sector(n,lo,hi,ri,ro,z0,z1,m,steps=10,b=.01):
 vs=[]
 for j in range(steps+1):
  a=lo+(hi-lo)*j/steps
  for r,z in [(ri,z0),(ro,z0),(ro,z1),(ri,z1)]:vs.append((r*cos(a),r*sin(a),z))
 fs=[(3,2,1,0),(steps*4,steps*4+1,steps*4+2,steps*4+3)]
 for j in range(steps):
  for k in range(4):fs.append((4*j+k,4*j+(k+1)%4,4*j+4+(k+1)%4,4*j+4+k))
 return mesh(n,vs,fs,m,b)
def rod(n,a,b,r,m,seg=24):
 a,b=Vector(a),Vector(b);d=b-a;o=disk(n,(a+b)/2,r,d.length,m,seg=seg);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def arch(n,x0,x1,path,m,b=.012):
 # A sheet with an octagonal cross section spanning the chassis.
 vs=[];th=.038
 for x in [x0,x1]:
  for y,z in path:vs.extend([(x,y,z),(x,y*.968,z-th)])
 fs=[]
 for i in range(len(path)-1):
  a=i*2;k=len(path)*2;fs.extend([(a,a+2,k+a+2,k+a),(a+1,k+a+1,k+a+3,a+3),(a,a+1,a+3,a+2),(k+a,k+a+2,k+a+3,k+a+1)])
 k=len(path)*2
 for j in [0,k-2]:fs.append((j,k+j,k+j+1,j+1))
 return mesh(n,vs,fs,m,b)
def outline(n,x0,x1,path,m,b=.02):
 vs=[(x,y,z) for x in (x0,x1) for y,z in path];k=len(path)
 fs=[tuple(reversed(range(k))),tuple(range(k,2*k))]+[(j,(j+1)%k,(j+1)%k+k,j+k) for j in range(k)]
 return mesh(n,vs,fs,m,b)
def glyph(n,text,pos,size,m,rot=(0,0,0)):
 c=bpy.data.curves.new(n,'FONT');c.body=text;c.size=size;c.align_x='CENTER';c.align_y='CENTER';c.extrude=.0008
 o=bpy.data.objects.new(n,c);bpy.context.collection.objects.link(o);o.location=pos;o.rotation_euler=rot
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False);return finish(o,m)
def bolt(p,axis='z',rad=.044):
 disk('Bolt collar',p,rad*1.25,.018,black,axis,seg=16)
 d={'x':(.013,0,0),'y':(0,.013,0),'z':(0,0,.013)}[axis];disk('Bolt',Vector(p)+Vector(d),rad,.021,steel,axis,seg=6)
# Squat, scalloped plinth and ten projecting grounding lugs.
disk('Foundation',(0,0,.23),1.42,.39,grey,seg=16)
disk('Lower rim',(0,0,.16),1.46,.16,dark,seg=20)
disk('Crown',(0,0,.39),1.40,.25,lightgrey,seg=20)
for j in range(10):
 a=2*pi*j/10
 sector('Stepped rim',a-.117,a+.117,1.17,1.51,.09,.40,grey,6,.027)
 sector('Raised tooth',a-.091,a+.091,1.18,1.47,.34,.53,lightgrey,6,.021)
 def radial(r,z):return (r*cos(a),r*sin(a),z)
 p,q,t=radial(1.45,.24),radial(1.65,.19),radial(1.72,.054)
 rod('Socket',radial(1.43,.24),radial(1.49,.23),.095,black,8)
 rod('Outrigger',p,q,.049,steel);rod('Toe',q,t,.049,steel);disk('Foot',t,.078,.074,dark,seg=12)
ring('Outer race',(0,0,.53),1.21,.24,.12,steel)
disk('Turntable',(0,0,.59),1.16,.105,dark)
ring('Index dial',(0,0,.64),1.16,.23,.03,grey)
for j in range(38):
 a=j*2*pi/38;sector('Index tick',a-.032,a+.032,.96,1.146,.65,.661,gold,4,.001)
role='head'
lathe('Swivel dome',(0,0,.63),[(0,.01),(0,.92),(.05,.93),(.17,.89),(.32,.77),(.48,.6),(.51,.02)],black)
for side in [-1,1]:
 y=side*.51
 disk('Elevation cheek',(0,y,1.05),.42,.19,grey,'y')
 ring('Illuminated bearing',(0,side*.615,1.05),.37,.077,.057,light,'y')
 disk('Bearing cap',(0,side*.636,1.05),.284,.028,dark,'y')
 box('Carrier saddle',(0,y,1.29),(.76,.22,.37),dark,.09)
role='pitch'
cross=[(-.48,1.40),(-.63,1.53),(-.63,1.84),(-.47,1.99),(.47,1.99),(.63,1.84),(.63,1.53),(.48,1.40)]
outline('Internal frame',-1.46,1.08,cross,black,.045)
upper=[(-.688,1.74),(-.688,1.88),(-.516,2.094),(.516,2.094),(.688,1.88),(.688,1.74)]
lower=[(-.667,1.60),(-.667,1.46),(-.516,1.32),(.516,1.32),(.667,1.46),(.667,1.60)]
arch('Lower keel',-1.49,1.14,lower,gold,.025)
for x0,x1,h in [(-1.53,-1.28,.09),(-.75,-.10,0),(.91,1.14,.035)]:
 arch('Folded cover',x0,x1,[(y,z+h) for y,z in upper],gold,.026)
for end in [-1.43,1.04]:
 outline('Endplate',end-.04,end+.04,cross,dark,.022)
for s in [-1,1]:
 y=s*.572
 disk('Cooling core',(-.15,y,1.70),.155,2.49,dark,'x')
 for j in range(35):
  x=-1.34+j*.0702
  ring('Heat exchanger rib',(x,y,1.70),.169,.044,.036,black if j%5 else dark,'x',seg=96)
 box('Window sill',(-.17,s*.689,1.630),(2.49,.044,.036),lip,.012)
 for x in [-1.37,1.045]:
  for z in [1.55,1.84]:bolt((x,s*.696,z),'y',.026)
# One broad red service cap near the front, two smaller at the rear.
for x,y,r in [(.43,0,.385),(-1.055,.245,.202),(-1.055,-.245,.202)]:
 disk('Insulator',(x,y,2.012),r*1.05,.13,black)
 ring('Service flange',(x,y,2.08),r*1.09,.058,.074,maroon)
 disk('Burgundy canister',(x,y,2.145),r,.16,red)
 ring('Inset lip',(x,y,2.224),r*.94,r*.097,.031,maroon)
 disk('Raised inspection cover',(x,y,2.254),r*.72,.057,red)
 for j in range(6):
  a=j*pi/3; disk('Cover pin',(x+cos(a)*r*.865,y+sin(a)*r*.865,2.242),.011,.005,steel,seg=10)
for n,(x,y) in enumerate([(.43,0)]):
 pts=[(x+.098*cos(a),y+.098*sin(a),2.284) for a in (0,2*pi/3,4*pi/3)]
 for a,b in zip(pts,pts[1:]+pts[:1]):rod('Hazard triangle',a,b,.005,lip,12)
 glyph('Inspection mark','!',(x,y,2.286),.102,lip,(0,0,pi/2))
for y in [-.32,.32]:
 for d in [-1,1]:
  rod('Cowl chevron',(1.04,y,2.133),(.977,y+d*.067,2.133),.014,maroon,12)
# Markings printed on the long service panel, in the same run of paint as the casing.
glyph('Service stencil','CAUTION',(-.425,.605,1.999),.081,maroon,(math.radians(48),0,pi))
glyph('Service label','FC  /  03',(-.43,-.608,1.998),.072,maroon,(math.radians(48),0,0))
role='slide'
for j,y in enumerate([-.36,0,.36]):
 x=.01 if j==1 else 0
 disk('Guide ferrule',(1.115,y,1.72),.184,.21,dark,'x')
 disk('Short neck',(1.29+x,y,1.72),.141,.31,black,'x')
 lathe('Tapered muzzle',(1.22+x,y,1.72),[(0,.084),(0,.135),(.04,.148),(.115,.154),(.14,.169),(.335,.169),(.39,.151),(.408,.126),(.408,.091),(.381,.078),(.16,.077)],steel,'x',96)
 ring('Muzzle lining',(1.606+x,y,1.72),.089,.018,.032,black,'x',72)
 disk('Dark bore',(1.50+x,y,1.72),.08,.018,black,'x')
# Fold each material group into a single draw unit and keep the articulated transforms.
def empty(n):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);return o
base=empty('Colony turret');yaw=empty('Yaw');yaw.parent=base;pitch=empty('Elevation');pitch.parent=yaw;pitch.location.z=1.68;sled=empty('Recoil');sled.parent=pitch
for (role,m),parts in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 o=bpy.context.object;o.name='FC_'+role+'_'+m.name.replace(' ','_');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 parent={'base':base,'pitch':pitch,'slide':sled,'head':yaw}[role];o.parent=parent
 if role in ('pitch','slide'):o.location.z=-1.68
for node,path,index,values,clip in [(yaw,'rotation_euler',2,[(1,0),(31,.46),(61,0)],'Survey'),(pitch,'rotation_euler',1,[(1,0),(25,-.27),(50,0)],'Elevation'),(sled,'location',0,[(1,0),(3,-.10),(10,0)],'Recoil')]:
 for frame,v in values:getattr(node,path)[index]=v;node.keyframe_insert(data_path=path,index=index,frame=frame)
 node.animation_data.action.name=clip
sc=bpy.context.scene;sc.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(root/'art/designed/turret.glb'),export_apply=True,export_animation_mode='ACTIONS')
# Studio render, lit from the high left as in the approved reference.
sc.render.engine='CYCLES';sc.cycles.samples=36;sc.cycles.use_denoising=False
sc.world=bpy.data.worlds.new('Ambient softbox');sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.61,.60,.59,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.43
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.003));bpy.context.object.data.materials.append(material('Warm gray background','777575',.03,.65))
focus=Vector((0,0,1.05))
for loc,power,size,col in [((2,2,6),550,5,(1,.88,.76)),((-3,0,5),670,4,(1,.95,.87)),((2,-4,3),410,3,(.79,.88,1)),((1,5,1),145,3,(.81,.9,1))]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=col;o.rotation_euler=(focus-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=focus+Vector((4.5,7.1,4.3)));cam=bpy.context.object;cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.15;sc.camera=cam
sc.render.resolution_x=1280;sc.render.resolution_y=920;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='JPEG';sc.render.image_settings.quality=95
sc.render.filepath=str(root/'previews/turret.jpg');bpy.ops.render.render(write_still=True)
