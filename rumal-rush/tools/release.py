"""Build and validate a binary .rbxl and XML .rbxlx using pinned Rojo."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from build import build
ROOT=Path(__file__).resolve().parents[1]
def release(destination,rojo):
    destination.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        tmp=Path(temporary)
        raw=build(tmp/'RumalRush-raw.rbxlx')
        # Rojo imports .rbxmx models, not .rbxlx places. Wrap the services in
        # a DataModel root to preserve the exact complete place hierarchy.
        tree=ET.parse(raw)
        children=list(tree.getroot())
        for child in children: tree.getroot().remove(child)
        model=ET.SubElement(tree.getroot(),'Item',{'class':'DataModel','referent':'RBXRoot'})
        props=ET.SubElement(model,'Properties')
        ET.SubElement(props,'string',name='Name').text='RumalRush'
        for child in children: model.append(child)
        imported=tmp/'RumalRush.rbxmx'
        tree.write(imported,encoding='utf-8',xml_declaration=True)
        project=tmp/'release.project.json'
        project.write_text(json.dumps({'name':'RumalRush','tree':{'$path':str(imported)}}))
        for suffix in ('rbxl','rbxlx'):
            subprocess.run([str(rojo),'build',str(project),'--output',str(destination/f'RumalRush.{suffix}')],check=True)
        expected=sorted(p.read_text() for p in (ROOT/'src').rglob('*.lua'))
        actual=sorted(p.text for p in ET.parse(destination/'RumalRush.rbxlx').findall(".//Properties/*[@name=\'Source\']"))
        assert actual==expected,'Rojo conversion changed scripts'
        assert (destination/'RumalRush.rbxl').read_bytes().startswith(b'<roblox!')
        print('PASS: Rojo imports the complete place and preserves all source scripts')
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output-dir',type=Path,default=ROOT.parent/'dist')
    parser.add_argument('--rojo',type=Path,default=Path('/workspace/rumal-tools/rojo-7.7.1/rojo'))
    args=parser.parse_args();release(args.output_dir.resolve(),args.rojo)
