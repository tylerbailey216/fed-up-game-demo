"""Vendor the display/UI typefaces with their SIL Open Font License notices."""
from pathlib import Path
import urllib.request
DEST=Path(__file__).resolve().parents[1]/'assets/fonts'
DEST.mkdir(exist_ok=True)
for family,files in {'bangers':['Bangers-Regular.ttf','OFL.txt'],'barlowcondensed':['BarlowCondensed-Medium.ttf','BarlowCondensed-Bold.ttf','OFL.txt']}.items():
    for name in files:
        target=DEST/(family+'-'+name if name=='OFL.txt' else name)
        urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/'+family+'/'+name,target)
        print('Saved',target.name,flush=True)
