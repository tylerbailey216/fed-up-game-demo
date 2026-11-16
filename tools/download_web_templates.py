"""Fetch only the single-threaded web template from the official archive."""
import io, shutil, urllib.request, zipfile
from pathlib import Path

VERSION='4.5.1'
URL=f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz'
DEST=Path(__file__).resolve().parent/'web_templates'
TEMPLATE='web_nothreads_release.zip'

class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL,headers={'Range':'bytes=0-0'}),timeout=60) as r:
            if r.status!=206:raise RuntimeError('Server must support range downloads')
            self.url=r.url
            self.size=int(r.headers['Content-Range'].split('/')[-1])
        self.pos=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else self.pos+offset if whence==1 else self.size+offset
        return self.pos
    def read(self,n=-1):
        n=min(self.size-self.pos,n if n>=0 else self.size)
        if n<=0:return b''
        request=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{self.pos+n-1}'})
        with urllib.request.urlopen(request,timeout=120) as r:
            if r.status!=206:raise RuntimeError('Range request rejected')
            data=r.read(n)
        self.pos+=len(data)
        return data

if __name__=='__main__':
    DEST.mkdir(exist_ok=True)
    with zipfile.ZipFile(RemoteZip()) as archive:
        name=next(n for n in archive.namelist() if n.endswith('/'+TEMPLATE))
        print('Downloading',name,flush=True)
        with archive.open(name) as source,(DEST/TEMPLATE).open('wb') as target:shutil.copyfileobj(source,target)
    with zipfile.ZipFile(DEST/TEMPLATE) as web:
        bad=web.testzip()
        if bad:raise RuntimeError('Corrupt template member: '+bad)
    print('Verified',DEST/TEMPLATE,flush=True)
