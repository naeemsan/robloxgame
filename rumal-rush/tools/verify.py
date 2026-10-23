"""Checks executed without Studio. Engine-dependent checks remain in TESTING.md."""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from build import build
ROOT=Path(__file__).resolve().parents[1]

def run(command):
    subprocess.run([str(x) for x in command],cwd=ROOT,check=True)

def verify(luau_dir):
    compiler=luau_dir/'luau-compile'
    scripts=list((ROOT/'src').rglob('*.lua'))
    for source in scripts:
        result=subprocess.run([str(compiler),str(source)],capture_output=True,text=True)
        if result.returncode: raise RuntimeError(f'{source}: {result.stderr}')
    print(f'PASS: {len(scripts)} production scripts compile',flush=True)
    run([luau_dir/'luau',ROOT/'tests'/'rules.luau'])
    rules=(ROOT/'src/ReplicatedStorage/RumalShared/Rules.lua').read_text()
    profiles=(ROOT/'src/ServerScriptService/RumalServer/Profiles.lua').read_text()
    fixture=(ROOT/'tests/profiles_fixture.luau').read_text()
    cases=(ROOT/'tests/profiles_cases.luau').read_text()
    with tempfile.TemporaryDirectory() as directory:
        directory=Path(directory)
        test=directory/'profiles.luau'
        test.write_text('local ACTUAL_RULES = (function()\n'+rules+'\nend)()\n'+fixture+
            '\nlocal Profiles = (function()\n'+profiles+'\nend)()\n'+cases)
        run([luau_dir/'luau',test])
        bot_test=directory/'bot.luau'
        bot_test.write_text((ROOT/'tests/bot_fixture.luau').read_text()+
            '\nlocal Bot = (function()\n'+(ROOT/'src/ServerScriptService/RumalServer/Bot.lua').read_text()+
            '\nend)()\n'+(ROOT/'tests/bot_cases.luau').read_text())
        run([luau_dir/'luau',bot_test])
        a,b=directory/'a.rbxlx',directory/'b.rbxlx'
        build(a);build(b)
        assert a.read_bytes()==b.read_bytes(),'Non-deterministic place output'
        tree=ET.parse(a)
        embedded=tree.findall('.//ProtectedString')
        assert sorted(s.text for s in embedded)==sorted(s.read_text() for s in scripts)
        names=[n.text for n in tree.findall(".//Item/Properties/string[@name='Name']")]
        assert names.count('Arena')==1 and names.count('LobbySpawn')==1
        assert names.count('Main')==1 and names.count('RumalClient')==1
        parts=[i for i in tree.findall('.//Item') if i.get('class') in ('Part','SpawnLocation')]
        assert len(parts)<=180
        assert all(i.find("Properties/bool[@name='Anchored']").text=='true' for i in parts)
        refs=[i.get('referent') for i in tree.findall('.//Item')]
        assert len(refs)==len(set(refs))
        assert tree.find(".//Item[@class='Workspace']/Properties/bool[@name='StreamingEnabled']").text=='false'
    project=json.loads((ROOT/'default.project.json').read_text())
    assert project['tree']['Workspace']['Arena']['$path']=='assets/Arena.rbxmx'
    print('PASS: deterministic XML build; complete script embedding; arena budget; unique references; Rojo manifest')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--luau-dir',type=Path,default=Path('/workspace/rumal-tools/luau-0.743'))
    verify(parser.parse_args().luau_dir)
