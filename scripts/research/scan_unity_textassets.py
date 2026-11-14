#!/usr/bin/env python3
"""Inventory Unity TextAssets from bounded APK entries; retain metadata, not game text."""
import collections, hashlib, json, sys, zipfile
from pathlib import Path
import UnityPy

apk = Path(sys.argv[1]); output = Path(sys.argv[2])
counts=collections.Counter(); assets=[]; errors=[]
with zipfile.ZipFile(apk) as z:
    bundle = len(sys.argv) > 3 and sys.argv[3] == 'bundles'
    entries=[i for i in z.infolist() if ((bundle and i.filename.startswith('assets/aa/Android/') and i.filename.endswith('.bundle')) or (not bundle and i.filename.startswith('assets/bin/Data/') and '/' not in i.filename[len('assets/bin/Data/'):] and not i.filename.endswith('.resource'))) and 32 <= i.file_size <= 2*1024*1024]
    for idx, item in enumerate(entries,1):
        try:
            env=UnityPy.load(z.read(item)); objects=list(env.objects)
            for obj in objects:
                counts[obj.type.name]+=1
                if obj.type.name!='TextAsset': continue
                a=obj.read(); text=a.m_Script
                raw=text if isinstance(text,bytes) else text.encode('utf-8','surrogateescape')
                assets.append({'apk_entry':item.filename,'path_id':obj.path_id,'name':a.m_Name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'prefix':raw[:256].decode('utf-8','replace')})
        except Exception as e:
            if len(errors)<20: errors.append({'entry':item.filename,'error':str(e)[:200]})
        if idx%500==0: print(f'{apk.name}: {idx}/{len(entries)} entries, {len(assets)} TextAssets',flush=True)
output.write_text(json.dumps({'apk':str(apk),'scope':('assets/aa/Android bundles' if bundle else 'assets/bin/Data direct non-resource files') + ' 32 bytes to 2 MiB','entries':len(entries),'objects':dict(counts),'textassets':assets,'sample_errors':errors},ensure_ascii=True,indent=2))
print(f'Done: {apk.name}: {len(entries)} entries, {len(assets)} TextAssets',flush=True)
