"""Build the mineral outcrops, basalt buttress and bioluminescent vegetation in Blender."""
from pathlib import Path
import bpy
import random
import math
from mathutils import Vector
from math import sin, cos, pi
root = Path(__file__).resolve().parents[2]
assets = root / "art/designed"
rng = random.Random(7351)

def material(name, color, metal=0., rough=.67, glow=0., texture=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    rgb = [((int(color[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4)] + [1]
    bs.inputs["Base Color"].default_value = rgb
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Emission Color"].default_value = rgb
    bs.inputs["Emission Strength"].default_value = glow
    if texture:
        tex=m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image=bpy.data.images.load(str(root / "textures/frontier" / texture),check_existing=True)
        m.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
    return m

basalt=material("Fractured basalt","62505c",rough=.8,texture="basalt.jpg")
weathered=material("Oxidised ledge","834839",rough=.91,texture="regolith.jpg")
moss=material("Lichen crust","6f6838",rough=.91,texture="moss.jpg")

class Sculpture:
    def __init__(self):
        self.vertices=[]; self.faces=[]; self.materials=[]; self.indices=[]
    def face(self, pts, mat):
        idx=len(self.vertices);self.vertices.extend(pts)
        self.faces.append(tuple(range(idx,idx+len(pts))))
        if mat not in self.materials: self.materials.append(mat)
        self.indices.append(self.materials.index(mat))
    def pillar(self, x,y,z,rx,ry,h, profile, sides, palette, lean=(0,0), twist=0,irregular=.12):
        angle=rng.random()*2*pi
        radius=[rng.uniform(1-irregular,1+irregular) for i in range(sides)]
        rises=[rng.uniform(-.07,.07) for i in range(sides)]
        rings=[]
        for j,(level,rad) in enumerate(profile):
            points=[]
            for i in range(sides):
                a=angle+2*pi*i/sides+twist*level
                points.append((x+rx*rad*radius[i]*cos(a)+lean[0]*level,
                               y+ry*rad*radius[i]*sin(a)+lean[1]*level,
                               z+h*(level+rises[i]*rad)))
            rings.append(points)
        for j in range(len(rings)-1):
            for i in range(sides):
                n=(i+1)%sides
                self.face([rings[j][i],rings[j][n],rings[j+1][n],rings[j+1][i]],palette(j,i))
        self.face(rings[-1],palette(len(rings)-1,0))
        self.face(rings[0][::-1],palette(0,0))
    def rock(self,x,y,z,width,height):
        self.pillar(x,y,z,width,width*rng.uniform(.58,.92),height,[(0,.88),(.24,1),(.66,.82),(.82,.87),(1,.65)],rng.randint(5,8),lambda j,i: moss if j==4 and i%3==0 else weathered if j==2 and i%3==2 else basalt,lean=(width*.16,-width*.10),twist=.19,irregular=.23)
    def export(self,name):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(self.vertices,[],self.faces);mesh.update()
        for m in self.materials: mesh.materials.append(m)
        uv=mesh.uv_layers.new(name="Mineral grain")
        for poly,idx in zip(mesh.polygons,self.indices):
            poly.material_index=idx
            axis=max(range(3),key=lambda v:abs(poly.normal[v]))
            axes=[(1,2),(0,2),(0,1)][axis]
            for k in poly.loop_indices:
                v=mesh.vertices[mesh.loops[k].vertex_index].co
                uv.data[k].uv=(v[axes[0]]*.27,v[axes[1]]*.27)
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT");obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(assets/(name+".glb")),use_selection=True,export_format="GLB")
        bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)

def scatter(x,y,r):
    a=rng.random()*2*pi;k=r*rng.random()**.5
    return x+k*cos(a),y+k*sin(a)

def outcrop(name,tone,glint,form):
    s=Sculpture()
    deep=material(name+" matrix",tone,.38,.28,.25)
    bright=material(name+" luminous core",glint,.16,.22,1.35)
    flank=material(name+" crystal faces",tone,.3,.32,.68)
    for i in range(21):
        x,y=scatter(0,0,.83);s.rock(x,y,-.04,rng.uniform(.13,.36),rng.uniform(.12,.33))
    for i in range(27):
        x,y=scatter(0,0,.76); r=(x*x+y*y)**.5
        h=(1.3-r)*rng.uniform(.51,1.25)
        if form=="crystal":
            radius=h*rng.uniform(.13,.25); profile=[(0,.72),(.13,.95),(.77,1),(.83,.87),(1,.08)]
        elif form=="plate":
            h*=.72;radius=h*rng.uniform(.32,.54);profile=[(0,.7),(.14,1),(.57,.92),(.66,1),(.91,.91),(1,.72)]
        else:
            h*=.80;radius=h*rng.uniform(.29,.51);profile=[(0,.7),(.26,1),(.65,.85),(.84,.77),(1,.40)]
        s.pillar(x,y,.09,radius,radius*.8,h,profile,rng.randint(5,7),lambda j,i: bright if (j==len(profile)-2 and i%3) or (i==1 and j==1) else deep if i%3==0 else flank,lean=(x*h*.40,y*h*.40),twist=.1)
    s.export(name)
outcrop("cobalt_iron","373739","a45f41","crystal")
outcrop("native_copper","783b29","d98e60","nodule")
outcrop("quartz_vein","a6a29a","fff4e5","crystal")
outcrop("ferrous_shale","67566b","b4916f","plate")
s=Sculpture()
for i in range(27):
    x,y=scatter(0,0,1.3);r=(x*x+y*y)**.5
    s.rock(x,y,-.16,rng.uniform(.32,.72),max(.18,(1.65-r))*rng.uniform(.82,2.2))
s.export("basalt_buttress")
s=Sculpture()
stem=material("Plum stalk","63416c");gill=material("Luminous lamellae","ff9aee",rough=.42,glow=.87)
violet=material("Amethyst cuticle","9939c5",rough=.32,glow=.37)
rim=material("Translucent lip","da63fb",rough=.27,glow=.83)
spore=material("Spore freckles","ffdbff",glow=1.7)
leaf=material("Oxalis indigo","643782",rough=.46); vein=material("Oxalis magenta","bc529b",rough=.44)
for x,y,h,r in [(-.16,.09,1.6,.74),(.43,-.36,1.05,.49),(-.63,-.3,.78,.41),(.57,.43,.70,.34),(.14,.62,.45,.23)]:
    dx=.15*h
    s.pillar(x,y,0,.09,.1,h,[(0,1.75),(.13,1.05),(.51,.68),(.89,.80),(1,1.4)],11,lambda j,i:stem,lean=(dx,0),twist=.14)
    cx=x+dx; n=48; rings=[]
    for z,rad in [(-.15,.14),(-.08,.61),(0,1.0),(.055,.96),(.17,.72),(.25,.34),(.26,.015)]:
        layer=[]
        for i in range(n):
            a=2*pi*i/n;rr=r*rad*(1+.04*sin(5*a+h)+.022*cos(3*a));layer.append((cx+cos(a)*rr,y+sin(a)*rr,h+r*(z+.07*cos(2*a)*rad)))
        rings.append(layer)
    for j in range(len(rings)-1):
        for i in range(n):
            nxt=(i+1)%n;s.face([rings[j][i],rings[j][nxt],rings[j+1][nxt],rings[j+1][i]],(gill if i%3 else rim) if j<2 else rim if j==2 else violet)
    for i in range(38):
        px,py=scatter(cx,y,r*.84);t=((px-cx)**2+(py-y)**2)**.5/r
        a=math.atan2(py-y,px-cx);pz=h+r*(.269-.245*t*t+.07*cos(2*a)*t)+.004
        rr=r*rng.uniform(.008,.034)
        s.face([(px+rr*cos(j*pi/3),py+rr*sin(j*pi/3),pz) for j in range(6)],spore)
for i in range(74):
    x,y=scatter(0,0,.97);a=rng.random()*2*pi;l=rng.uniform(.15,.60);w=l*.13
    mid=(x+.45*l*cos(a),y+.45*l*sin(a),l*.64);tip=(x+l*cos(a),y+l*sin(a),l*.73)
    left=(mid[0]-w*sin(a),mid[1]+w*cos(a),mid[2]-.05);right=(mid[0]+w*sin(a),mid[1]-w*cos(a),mid[2]-.05)
    for tri,mat in [([(x,y,.02),mid,left],leaf),([mid,tip,left],vein),([(x,y,.02),right,mid],vein),([mid,right,tip],leaf)]:
        s.face(tri,mat);s.face(tri[::-1],mat)
s.export("amethyst_garden")
s=Sculpture()
plum=material("Burgundy pinnae","7c2858",rough=.62)
rose=material("Coral lamina","bd465e",rough=.53)
russet=material("Amber tips","d56a49",rough=.55)
jade=material("Waxed jade underside","28695c",rough=.62)
rachis=material("Gilded midrib","b49846",rough=.52)
for cluster in range(5):
    cx,cy=scatter(0,0,.61)
    for frond in range(9):
        angle=frond*2*pi/9+cluster*.68+rng.uniform(-.16,.16)
        length=rng.uniform(.58,1.32)*(1.25 if cluster==0 else .81);height=length*rng.uniform(.53,.93)
        d=Vector((cos(angle),sin(angle),0));side=Vector((-sin(angle),cos(angle),0))
        def point(t):
            return Vector((cx,cy,0))+d*(t*length)+Vector((0,0,height*(1.4*sin(t*1.47)-.64*t*t)))
        for j in range(12):
            t=j/12; here=point(t);next_p=point((j+1)/12)
            s.face([here-side*.009,next_p-side*.006,next_p+side*.006,here+side*.009],rachis)
            if j<1:continue
            for sign in [-1,1]:
                width=length*(sin(pi*t)**.62)*.25
                tip=here+sign*side*width+d*length*.18+Vector((0,0,width*.25))
                mid=here.lerp(tip,.5)+Vector((0,0,width*.16));delta=d*(width*.13)
                for tri,mat in [([here,mid-delta,tip],plum if j<8 else rose),([here,tip,mid+delta],rose if j<8 else russet)]:
                    s.face(tri,mat);s.face(tri[::-1],jade)
s.export("coral_fern")
