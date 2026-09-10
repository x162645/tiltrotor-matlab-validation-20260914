#!/usr/bin/env python3
"""Persist previously executed evidence; no models are run or modified.
Only pinned repository artifacts are accepted. ZIP/file hashes are retained.
Never store credentials or temporary download URLs. Verify-only is offline.
"""
from __future__ import annotations
import argparse, concurrent.futures, hashlib, io, json, os, pathlib, stat
import subprocess, time, urllib.error, urllib.request, zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/validation/line_b_implementation_20260910'
DEST=DOC/'handoff_evidence'
REPO='x162645/tiltrotor-matlab'
BRANCH='implementation/line-b-external-validation-20260910'
TOKEN=os.environ.get('GH_TOKEN','')
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl): return None
def get(url,authenticated=True):
    if authenticated and not url.startswith(f'https://api.github.com/repos/{REPO}/'):
        raise ValueError('Authenticated URL is outside the authorized repository.')
    if not url.startswith('https://'): raise ValueError('HTTPS required.')
    headers={'User-Agent':'tiltrotor-handoff-archive','Accept':'application/vnd.github+json'}
    if authenticated: headers['Authorization']='Bearer '+TOKEN
    req=urllib.request.Request(url,headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.build_opener(NoRedirect()).open(req,timeout=120) as res: return res.read()
        except urllib.error.HTTPError as exc:
            if exc.code in (301,302,303,307,308):
                return get(exc.headers['Location'],False) # Never forward the token to storage.
            if exc.code not in (429,500,502,503,504) or attempt==2: raise
            time.sleep(2**attempt)
    raise RuntimeError('Request failed')
def sha(data): return hashlib.sha256(data).hexdigest()
def safe_relative(name):
    p=pathlib.PurePosixPath(name)
    if p.is_absolute() or not p.parts or '..' in p.parts or '\\' in name:
        raise ValueError('Unsafe archive path')
    return p
def preserve(item):
    metadata=json.loads(get(f'https://api.github.com/repos/{REPO}/actions/artifacts/{item["artifact_id"]}'))
    if metadata.get('expired'): raise RuntimeError(item['key']+': expired, do not substitute.')
    wr=metadata.get('workflow_run',{})
    if wr.get('id')!=item['run_id']: raise RuntimeError('Run identity mismatch')
    raw=get(f'https://api.github.com/repos/{REPO}/actions/artifacts/{item["artifact_id"]}/zip')
    if sha(raw)!=item['zip_sha256']: raise RuntimeError(item['key']+': ZIP SHA256 mismatch')
    digest=metadata.get('digest')
    if digest and digest!='sha256:'+item['zip_sha256']: raise RuntimeError('Server digest mismatch')
    saved=[]
    pdfs={'A03_SOURCE_GTRS':{'Kleinhesselink_2007.pdf','NASA_CR_166536.pdf'},
          'A12_ROTOR_DISCONTINUITY':{'Koning_CR2016_219086.pdf'},
          'A32_ORIGINAL_SOURCE':{'NASA_CR_166537.pdf'}}
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        members=[]
        for entry in archive.infolist():
            name=entry.filename;rel=safe_relative(name)
            take=len(rel.parts)==1 and rel.suffix.lower() in {'.csv','.json','.mat'}
            take=take or name in pdfs.get(item['key'],set())
            if item['key']=='A25_FORWARD_REGRESSION' and rel.parts[0] in {'source','generated'} and rel.suffix.lower() in {'.m','.csv','.md','.json'}: take=True
            if item['key']=='A12_ROTOR_DISCONTINUITY' and (name.startswith('instrumented_source/') or (len(rel.parts)==1 and rel.suffix=='.m')): take=True
            if take: members.append(name)
        if not members: raise RuntimeError('Empty selection: '+item['key'])
        for name in members:
            relative=safe_relative(name);info=archive.getinfo(name)
            if stat.S_ISLNK(info.external_attr>>16): raise RuntimeError('Symlink rejected')
            if info.file_size>49_000_000: raise RuntimeError('Unexpected large file; do not silently skip')
            data=archive.read(info);path=DEST/item['key']/str(relative)
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.exists() and path.read_bytes()!=data: raise RuntimeError('Immutable evidence conflict')
            path.write_bytes(data)
            saved.append({'path':str(path.relative_to(ROOT)),'source_member':name,'bytes':len(data),'sha256':sha(data)})
    rec={k:item[k] for k in ('key','run_id','artifact_id','zip_filename','zip_sha256')}
    rec.update(source_commit=wr.get('head_sha'),source_branch=wr.get('head_branch'),artifact_name=metadata['name'],
        original_expires_at=metadata.get('expires_at'),run_url=f'https://github.com/{REPO}/actions/runs/{item["run_id"]}',
        files=saved,status='PERSISTED_BYTE_FOR_BYTE')
    return rec
def validate_index():
    index=json.loads((DEST/'ARCHIVE_INDEX.json').read_text())
    for a in index['artifacts']:
        for f in a['files']:
            data=(ROOT/safe_relative(f['path'])).read_bytes()
            if sha(data)!=f['sha256'] or len(data)!=f['bytes']: raise RuntimeError('Checksum failure: '+f['path'])
    return index
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    if args.verify_only:
        index=validate_index();print('HASH_VERIFIED',len(index['artifacts']),index['file_count']);return
    req=json.loads((DOC/'HANDOFF_ARCHIVE_REQUEST.json').read_text())
    if req['repository']!=REPO or req['branch']!=BRANCH or len(req['artifacts'])!=38: raise RuntimeError('Archive contract mismatch')
    if not TOKEN: raise RuntimeError('GH_TOKEN required for retrieval; verify-only works offline')
    records=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for rec in pool.map(preserve,req['artifacts']):
            records.append(rec);print(rec['key'],'persisted',len(rec['files']),'files',flush=True)
    records.sort(key=lambda a:a['key'])
    index={'schema_version':1,'repository':REPO,'branch':BRANCH,
        'handoff_request_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
        'last_physics_commit':req['physical_head'],'archival_only':True,'new_matlab_runs':0,'new_physics_changes':0,
        'artifacts':records,'file_count':sum(len(r['files']) for r in records),
        'total_bytes':sum(f['bytes'] for r in records for f in r['files'])}
    DEST.mkdir(parents=True,exist_ok=True)
    (DEST/'ARCHIVE_INDEX.json').write_text(json.dumps(index,indent=2,ensure_ascii=False)+'\n')
    (DEST/'SHA256SUMS.txt').write_text(''.join(f'{f["sha256"]}  {f["path"]}\n' for r in records for f in r['files']))
    (DEST/'README.md').write_text('# 已执行证据的永久副本\n\n'+
        f'{len(records)} 个固定 Actions 产物，{index["file_count"]} 个文件，{index["total_bytes"]} 字节。\n\n'+
        'MAT/CSV/JSON 和四份来源 PDF 为原始字节副本，不是重跑结果。重复代码快照不重复入库；代码由 ARCHIVE_INDEX.json 的 source_commit 定位。原 ZIP 名称、run、artifact、哈希和各源文件名均保存。\n\n'+
        '先读根目录 WORK_HANDOFF.md 与逐步台账。`python tools/archive_work_handoff.py --verify-only` 离线核验字节，不执行模型。\n',encoding='utf-8')
    validate_index();print('ARCHIVE_COMPLETE',index['file_count'],index['total_bytes'],flush=True)
if __name__=='__main__': main()
