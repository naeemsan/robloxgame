"""Offline checks; not a substitute for Roblox engine, network, or device tests."""
from pathlib import Path
from collections import deque
import argparse
import math
import subprocess
import tempfile
import wave
import xml.etree.ElementTree as ET
from build import build
from manor_layout import layout

ROOT=Path(__file__).resolve().parents[1]
def boxes():
    output=[]
    for p in layout()[0]:
        if not p.get('collide',True):continue
        x,y,z=p['pos'];sx,sy,sz=p['size']
        angle=math.radians(p.get('rotation',(0,0,0))[1])
        ex=abs(math.cos(angle))*sx/2+abs(math.sin(angle))*sz/2
        ez=abs(math.sin(angle))*sx/2+abs(math.cos(angle))*sz/2
        output.append((p['name'],x-ex,y-sy/2,z-ez,x+ex,y+sy/2,z+ez))
    return output
def navigation_check():
    # Conservative 2D capsule clearance model. Engine navmesh remains untested.
    rects=[b for b in boxes() if b[5]>1 and b[2]<6]
    def blocked(x,z):
        return any(x>b[1]-1.5 and x<b[4]+1.5 and z>b[3]-1.5 and z<b[6]+1.5 for b in rects)
    walkable={(x,z) for x in range(-60,61) for z in range(-66,50) if not blocked(x,z)}
    start=(0,38)
    assert start in walkable,'Entry spawn collides with geometry'
    reachable={start};queue=deque([start])
    while queue:
        x,z=queue.popleft()
        for other in ((x-1,z),(x+1,z),(x,z-1),(x,z+1)):
            if other in walkable and other not in reachable:
                reachable.add(other);queue.append(other)
    def near(pos,radius=7.5):
        x,y,z=pos
        return any((px-x)**2+(3.5-y)**2+(pz-z)**2<radius*radius for px,pz in reachable)
    for marker in layout()[3]:
        if marker['kind'] in ('Loot','Hide','Patrol'):
            assert near(marker['pos']),f"Unreachable {marker['name']} at {marker['pos']}"
        if marker['kind']=='Hide':
            x,y,z=marker['pos']
            assert not blocked(x,z),f"Hiding exit overlaps geometry: {marker['name']} {marker['pos']}"
    for name in ('GeneratorPanel','BurnPrompt','ExitPrompt'):
        p=next(s for s in layout()[0] if s['name']==name)
        assert near(p['pos']),f'Interaction not reachable: {name}'
    print(f'PASS: {len(reachable)} connected walkable grid cells; all loot, refuge exits, patrol zones and mission stations reachable in clearance model')

def verify(luau):
    files=list((ROOT/'src').rglob('*.lua'))
    for source in files:
        result=subprocess.run([str(luau/'luau-compile'),str(source)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        if result.returncode:raise RuntimeError(f'{source}: {result.stderr.decode(errors="replace")}')
    print(f'PASS: {len(files)} production Luau scripts compile',flush=True)
    subprocess.run([str(luau/'luau'),str(ROOT/'tests/rules.luau')],check=True)
    navigation_check()
    assert layout()==layout(),'Layout generation must be deterministic'
    with tempfile.TemporaryDirectory() as tmp:
        a,b=Path(tmp)/'a.rbxlx',Path(tmp)/'b.rbxlx'
        build(a);build(b);assert a.read_bytes()==b.read_bytes()
        tree=ET.parse(a)
        sources=[p.text for p in tree.findall(".//Properties/*[@name='Source']")]
        assert sorted(sources)==sorted(p.read_text() for p in files)
        assert len(layout()[0])<650
        assert len(layout()[1])<=16
        for m in tree.findall(".//Item[@class='StarterPlayer']"):
            assert m.find("Properties/float[@name='CameraMinZoomDistance']").text=='5'
            assert m.find("Properties/float[@name='CameraMaxZoomDistance']").text=='10'
        assert tree.find(".//Item[@class='Lighting']/Properties/token[@name='LightingStyle']").text=='0'
    audios=list((ROOT/'assets/audio').glob('*.wav'))
    assert len(audios)==7
    for path in audios:
        with wave.open(str(path)) as f:
            assert f.getnchannels()==1 and f.getsampwidth()==2 and f.getframerate()==44100
            assert f.getnframes()>44100
    print('PASS: deterministic place; exact script embedding; 507-part / 15-light budget; third-person camera; realistic lighting; 7 original WAVs')
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--luau-dir',type=Path,default=Path('/workspace/rumal-tools/luau-0.743'))
    verify(parser.parse_args().luau_dir)
