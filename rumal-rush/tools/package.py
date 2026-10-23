"""Package the built place and complete editable sources for a Studio user."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT=Path(__file__).resolve().parents[1]
DIST=ROOT.parent/'dist'

def package():
    files={}
    for name in ('RumalRush.rbxl','RumalRush.rbxlx','Arena-preview.png'):
        path=DIST/name
        if not path.is_file(): raise SystemExit(f'Missing release artifact: {path}')
        files[name]=path.read_bytes()
    files['START-HERE.txt']=(ROOT/'docs/START-HERE.txt').read_bytes()
    files['TEST-RESULTS.txt']=(ROOT/'docs/TESTING.md').read_bytes()
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file() or '__pycache__' in path.parts or path.suffix=='.pyc':
            continue
        files['source/'+path.relative_to(ROOT).as_posix()]=path.read_bytes()
    hashes={name:hashlib.sha256(data).hexdigest() for name,data in files.items()}
    files['SHA256SUMS.json']=json.dumps(hashes,indent=2,sort_keys=True).encode()
    output=DIST/'RumalRush-Full-Package.zip'
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,24,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o100644 << 16
            archive.writestr(info,data)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        for name,digest in hashes.items():
            assert hashlib.sha256(archive.read(name)).hexdigest()==digest
        assert len([n for n in archive.namelist() if n.startswith('source/src/') and n.endswith('.lua')])==7
    print(f'PASS: release ZIP integrity, hashes, 7 source scripts; {len(files)} entries; {output.stat().st_size:,} bytes')
    return output

if __name__=='__main__':
    package()
