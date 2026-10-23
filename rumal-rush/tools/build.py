"""Build a self-contained Roblox XML place and Rojo arena, using Python only."""
from pathlib import Path
import argparse
import math
import xml.etree.ElementTree as ET
from arena_layout import arena

ROOT = Path(__file__).resolve().parents[1]
class Document:
    def __init__(self):
        self.root = ET.Element('roblox', version='4')
        self.count = 0
    def item(self, parent, cls, name):
        self.count += 1
        node = ET.SubElement(parent, 'Item', {'class': cls, 'referent': f'RBX{self.count}'})
        props = ET.SubElement(node, 'Properties')
        self.prop(props, 'string', 'Name', name)
        return node, props
    def prop(self, props, kind, name, value):
        node = ET.SubElement(props, kind, name=name)
        if kind in ('Vector3','Color3'):
            for axis,v in zip(('X','Y','Z') if kind=='Vector3' else ('R','G','B'),value):
                ET.SubElement(node,axis).text = str(v if kind=='Vector3' else v/255)
        elif kind=='CoordinateFrame':
            pos, angle = value
            # Only Z rotations are used by the layout (horizontal cylinders).
            a=math.radians(angle[2]);c,s=math.cos(a),math.sin(a)
            for key,v in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),(*pos,c,-s,0,s,c,0,0,0,1)):
                ET.SubElement(node,key).text=str(v)
        elif kind=='UDim2':
            for key,v in zip(('XS','XO','YS','YO'),value): ET.SubElement(node,key).text=str(v)
        elif kind=='bool': node.text='true' if value else 'false'
        else: node.text=str(value)
        return node
    def write(self,path):
        path.parent.mkdir(parents=True,exist_ok=True)
        ET.indent(self.root)
        ET.ElementTree(self.root).write(path,encoding='utf-8',xml_declaration=True)

def make_arena(doc,parent):
    model,_=doc.item(parent,'Model','Arena')
    parts,signs=arena(); lookup={}
    for spec in parts:
        cls='SpawnLocation' if spec.get('spawn') else 'Part'
        node,p=doc.item(model,cls,spec['name']);lookup[spec['name']]=node
        for kind,name,value in [
            ('Vector3','size',spec['size']),('CoordinateFrame','CFrame',(spec['pos'],spec.get('rotation',(0,0,0)))),
            ('Color3','Color',spec['color']),('bool','Anchored',True),('bool','CanCollide',spec.get('collide',True)),
            ('bool','CastShadow',False),('token','Material',256),('token','TopSurface',0),('token','BottomSurface',0),
        ]: doc.prop(p,kind,name,value)
        if spec.get('shape'): doc.prop(p,'token','shape',{'Ball':0,'Cylinder':2}[spec['shape']])
        if spec.get('spawn'):
            doc.prop(p,'bool','Neutral',True);doc.prop(p,'int','Duration',0)
    for spec in signs:
        surface,p=doc.item(lookup[spec['part']],'SurfaceGui','Lettering')
        doc.prop(p,'token','Face',5) # Front (-Z); use Back below to face toward the court.
        # All signs sit at negative Z and face positive Z toward the player camera.
        p.find("token[@name='Face']").text='2'
        doc.prop(p,'float','PixelsPerStud',35)
        doc.prop(p,'token','SizingMode',1)
        label,p=doc.item(surface,'TextLabel','Text')
        doc.prop(p,'UDim2','Size',(1,0,1,0));doc.prop(p,'float','BackgroundTransparency',1)
        doc.prop(p,'string','Text',spec['text']);doc.prop(p,'Color3','TextColor3',spec['color'])
        doc.prop(p,'bool','TextScaled',True);doc.prop(p,'bool','TextWrapped',True)
        doc.prop(p,'token','Font',20)
    return model

def build(output):
    doc=Document()
    ws,p=doc.item(doc.root,'Workspace','Workspace')
    doc.prop(p,'bool','StreamingEnabled',False) # One compact arena, needed for the fixed overview camera.
    doc.prop(p,'float','Gravity',196.2)
    make_arena(doc,ws)
    camera,cp=doc.item(ws,'Camera','Camera')
    eye=(92,100,124)
    length=math.sqrt(sum(v*v for v in eye))
    back=tuple(v/length for v in eye)
    right=(back[2],0,-back[0])
    length=math.sqrt(sum(v*v for v in right))
    right=tuple(v/length for v in right)
    up=(back[1]*right[2]-back[2]*right[1],
        back[2]*right[0]-back[0]*right[2],
        back[0]*right[1]-back[1]*right[0])
    cf=doc.prop(cp,'CoordinateFrame','CFrame',(eye,(0,0,0)))
    for row in range(3):
        for col,basis in enumerate((right,up,back)):
            cf.find(f'R{row}{col}').text=str(basis[row])
    doc.prop(cp,'CoordinateFrame','Focus',((0,0,0),(0,0,0)))
    doc.prop(cp,'float','FieldOfView',55)
    doc.prop(p,'Ref','CurrentCamera',camera.get('referent'))
    lighting,p=doc.item(doc.root,'Lighting','Lighting')
    for kind,name,value in [('float','ClockTime',15),('float','Brightness',2),('bool','GlobalShadows',False),('Color3','Ambient',(160,163,175)),('Color3','OutdoorAmbient',(180,182,193))]:doc.prop(p,kind,name,value)
    players,p=doc.item(doc.root,'Players','Players')
    doc.prop(p,'float','RespawnTime',2)
    for service in ('ReplicatedStorage','ServerScriptService','StarterPlayer'):
        node,p=doc.item(doc.root,service,service)
        if service=='StarterPlayer':
            doc.prop(p,'float','CharacterWalkSpeed',19)
            doc.prop(p,'float','CharacterJumpPower',0)
        def add_folder(parent,path):
            for entry in sorted(path.iterdir()):
                if entry.is_dir():
                    cls='StarterPlayerScripts' if entry.name=='StarterPlayerScripts' else 'Folder'
                    child,_=doc.item(parent,cls,entry.name);add_folder(child,entry)
                elif entry.suffix=='.lua':
                    cls='Script' if entry.name.endswith('.server.lua') else 'LocalScript' if entry.name.endswith('.client.lua') else 'ModuleScript'
                    _,props=doc.item(parent,cls,entry.name.split('.')[0])
                    doc.prop(props,'ProtectedString','Source',entry.read_text())
        add_folder(node,ROOT/'src'/service)
    doc.write(output)
    model=Document();make_arena(model,model.root);model.write(ROOT/'assets'/'Arena.rbxmx')
    scripts=ET.parse(output).findall('.//ProtectedString')
    assert len(scripts)==len(list((ROOT/'src').rglob('*.lua')))
    print(f'Built {output.name}: {len(scripts)} scripts, {len(arena()[0])} static parts, {output.stat().st_size:,} bytes')
    return output

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT.parent/'dist'/'RumalRush.rbxlx')
    build(parser.parse_args().output)
