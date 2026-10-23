"""Install pinned Linux x86_64 verification tools outside the checkout."""
from pathlib import Path
import argparse
import hashlib
import io
import platform
import urllib.request
import zipfile

RELEASES = [
    ('luau-0.743','https://github.com/luau-lang/luau/releases/download/0.743/luau-ubuntu.zip',
     '99d45afb4afaee00ba631c526c8e8c76c67b60f6f119953ce6409be6d6953663',
     ('luau','luau-compile','luau-analyze','luau-ast')),
    ('rojo-7.7.1','https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip',
     '00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4',
     ('rojo',)),
]
def install(destination):
    if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64'):
        raise SystemExit('This optional verification bootstrap targets Linux x86_64. Studio users need no tools.')
    for name,url,digest,files in RELEASES:
        request=urllib.request.Request(url,headers={'User-Agent':'RumalRush-build/1.0'})
        with urllib.request.urlopen(request,timeout=60) as response: data=response.read()
        if hashlib.sha256(data).hexdigest()!=digest: raise RuntimeError(f'Checksum mismatch for {name}')
        folder=destination/name
        folder.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for filename in files:
                target=folder/filename
                target.write_bytes(archive.read(filename))
                target.chmod(0o755)
        print('Verified and installed',name)
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--destination',type=Path,default=Path('/workspace/rumal-tools'))
    install(parser.parse_args().destination)
