"""Persist fixed completed D02 Actions artifacts; never run the model here."""
from __future__ import annotations
import argparse, hashlib, io, json, os, pathlib, urllib.request, zipfile
REPO='x162645/tiltrotor-matlab'
BASE=pathlib.Path('docs/research/dynamic_fidelity/evidence_d02_1')

def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument('--request',required=True)
    parser.add_argument('--verify-only',action='store_true')
    args=parser.parse_args()
    spec=json.loads(pathlib.Path(args.request).read_text(encoding='utf-8'))
    if args.verify_only:
        manifest=json.loads((BASE/'ARCHIVE_INDEX.json').read_text())
        for item in manifest['files']:
            raw=(BASE/item['path']).read_bytes()
            if hashlib.sha256(raw).hexdigest()!=item['sha256']:
                raise RuntimeError('Byte verification failed: '+item['path'])
        print('VERIFIED',len(manifest['files']),'files; no model execution')
        return
    token=os.environ['GH_TOKEN']
    BASE.mkdir(parents=True,exist_ok=True)
    entries=[]
    for source in spec['artifacts']:
        url=f"https://api.github.com/repos/{REPO}/actions/artifacts/{source['artifact_id']}/zip"
        req=urllib.request.Request(url,headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','User-Agent':'d02-fixed-evidence-archive'})
        raw=urllib.request.urlopen(req,timeout=120).read()
        if hashlib.sha256(raw).hexdigest()!=source['zip_sha256']:
            raise RuntimeError('Artifact ZIP hash mismatch')
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            manifest=json.loads(z.read('RUN_MANIFEST.json'))
            if manifest['sourceCommit']!=source['source_commit']:
                raise RuntimeError('Execution commit mismatch')
            if bool(manifest['allChecksPassed'])!=source['expected_checks_passed']:
                raise RuntimeError('Unexpected verification status; do not relabel')
            for info in z.infolist():
                path=pathlib.PurePosixPath(info.filename)
                if path.is_absolute() or '..' in path.parts:
                    raise RuntimeError('Unsafe ZIP member')
                if info.is_dir() or len(path.parts)!=1 or path.suffix.lower() not in {'.csv','.json','.mat','.txt'}:
                    continue
                payload=z.read(info)
                rel=pathlib.Path('run_'+str(source['run_id']))/path.name
                dest=BASE/rel;dest.parent.mkdir(parents=True,exist_ok=True)
                if dest.exists() and dest.read_bytes()!=payload:
                    raise RuntimeError('Refuse to overwrite different historical bytes: '+str(rel))
                dest.write_bytes(payload)
                entries.append({'path':str(rel),'sha256':hashlib.sha256(payload).hexdigest(),'bytes':len(payload),'source_member':info.filename,'source_commit':source['source_commit'],'run_id':source['run_id'],'artifact_id':source['artifact_id']})
    result={'role':'FIXED_EXECUTED_D02_EVIDENCE_NOT_NEW_MODEL_RUN','archival_workflow_run':os.environ.get('GITHUB_RUN_ID'),'artifacts':spec['artifacts'],'files':entries}
    (BASE/'ARCHIVE_INDEX.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('ARCHIVED',len(entries),'files; no model execution')
if __name__=='__main__':main()
