"""Build a self-contained Roblox XML place and Rojo arena, using Python only."""
from pathlib import Path
import argparse
import math
import xml.etree.ElementTree as ET
from manor_layout import layout

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
            ax,ay,az=map(math.radians,angle)
            cx,sx,cy,sy,cz,sz=math.cos(ax),math.sin(ax),math.cos(ay),math.sin(ay),math.cos(az),math.sin(az)
            matrix=(cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy)
            for key,v in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),(*pos,*matrix)):
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

def make_manor(doc,parent):
    model,_=doc.item(parent,'Model','Manor')
    parts,lights,signs,markers=layout();lookup={}
    for spec in parts:
        node,p=doc.item(model,'SpawnLocation' if spec.get('spawn') else 'Part',spec['name'])
        lookup[spec['name']]=node
        for kind,name,value in [
            ('Vector3','size',spec['size']),('CoordinateFrame','CFrame',(spec['pos'],spec.get('rotation',(0,0,0)))),
            ('Color3','Color',spec['color']),('bool','Anchored',True),('bool','CanCollide',spec.get('collide',True)),
            ('bool','CastShadow',spec.get('collide',True)),('token','Material',spec.get('material',256)),
            ('token','TopSurface',0),('token','BottomSurface',0),
            ('float','Transparency',spec.get('transparency',0)),
        ]:doc.prop(p,kind,name,value)
        if spec.get('shape'):doc.prop(p,'token','shape',{'Ball':0,'Cylinder':2}[spec['shape']])
        if spec.get('spawn'):
            doc.prop(p,'bool','Neutral',True);doc.prop(p,'int','Duration',0)
    for spec in lights:
        _,p=doc.item(lookup[spec['part']],'PointLight','HouseLight')
        for kind,name,value in [('Color3','Color',spec['color']),('float','Brightness',spec['brightness']),
            ('float','Range',spec['range']),('bool','Shadows',spec['shadows'])]:
            doc.prop(p,kind,name,value)
    for spec in signs:
        surface,p=doc.item(lookup[spec['part']],'SurfaceGui','Lettering')
        doc.prop(p,'token','Face',2);doc.prop(p,'float','PixelsPerStud',45);doc.prop(p,'token','SizingMode',1)
        _,p=doc.item(surface,'TextLabel','Text')
        for kind,name,value in [('UDim2','Size',(1,0,1,0)),('float','BackgroundTransparency',1),
            ('string','Text',spec['text']),('Color3','TextColor3',spec['color']),
            ('bool','TextScaled',True),('token','Font',11)]:
            doc.prop(p,kind,name,value)
    folder,_=doc.item(model,'Folder','Markers')
    for spec in markers:
        _,p=doc.item(folder,'Part',spec['name'])
        for kind,name,value in [('Vector3','size',(1,1,1)),('CoordinateFrame','CFrame',(spec['pos'],(0,0,0))),
            ('bool','Anchored',True),('bool','CanCollide',False),('bool','CanQuery',False),
            ('float','Transparency',1)]:
            doc.prop(p,kind,name,value)
    return model

def build(output):
    doc=Document()
    ws,p=doc.item(doc.root,'Workspace','Workspace')
    doc.prop(p,'bool','StreamingEnabled',False)
    doc.prop(p,'float','Gravity',196.2)
    make_manor(doc,ws)
    lighting,p=doc.item(doc.root,'Lighting','Lighting')
    for kind,name,value in [('token','LightingStyle',0),('bool','PrioritizeLightingQuality',True),('float','ClockTime',.4),('float','Brightness',1),('bool','GlobalShadows',True),
        ('Color3','Ambient',(19,23,28)),('Color3','OutdoorAmbient',(33,42,53)),('float','ExposureCompensation',-.15)]:
        doc.prop(p,kind,name,value)
    _,fx=doc.item(lighting,'ColorCorrectionEffect','EmberGrade')
    for kind,name,value in [('float','Brightness',-.025),('float','Contrast',.18),('float','Saturation',-.25),
        ('Color3','TintColor',(217,226,235))]:doc.prop(fx,kind,name,value)
    _,fx=doc.item(lighting,'BloomEffect','EmberBloom')
    for name,value in [('Intensity',.25),('Size',22),('Threshold',1.2)]:doc.prop(fx,'float',name,value)
    _,fx=doc.item(lighting,'Atmosphere','EmberMist')
    doc.prop(fx,'float','Density',.32);doc.prop(fx,'float','Offset',.05)
    doc.prop(fx,'Color3','Color',(145,158,170));doc.prop(fx,'Color3','Decay',(50,59,68))
    _,p=doc.item(doc.root,'Players','Players');doc.prop(p,'float','RespawnTime',3)
    for service in ('ReplicatedStorage','ServerScriptService','StarterPlayer'):
        node,p=doc.item(doc.root,service,service)
        if service=='StarterPlayer':
            doc.prop(p,'bool','EnableMouseLockOption',False)
            for name,value in [('CharacterWalkSpeed',12),('CharacterJumpPower',0),('CameraMinZoomDistance',5),('CameraMaxZoomDistance',10)]:
                doc.prop(p,'float',name,value)
        def folder(parent,path):
            for entry in sorted(path.iterdir()):
                if entry.is_dir():
                    cls='StarterPlayerScripts' if entry.name=='StarterPlayerScripts' else 'Folder'
                    child,_=doc.item(parent,cls,entry.name);folder(child,entry)
                elif entry.suffix=='.lua':
                    cls='Script' if entry.name.endswith('.server.lua') else 'LocalScript' if entry.name.endswith('.client.lua') else 'ModuleScript'
                    _,props=doc.item(parent,cls,entry.name.split('.')[0]);doc.prop(props,'ProtectedString','Source',entry.read_text())
        folder(node,ROOT/'src'/service)
    doc.write(output)
    model=Document();make_manor(model,model.root);model.write(ROOT/'assets'/'Manor.rbxmx')
    print(f'Built {output.name}: {len(list((ROOT/"src").rglob("*.lua")))} scripts, {len(layout()[0])} architecture parts')
    return output
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT.parent/'dist'/'last-ember'/'TheLastEmber.rbxlx')
    build(parser.parse_args().output)
