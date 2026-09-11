"""Archive only read-back D05 evidence; do not rerun models or overwrite history."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path


def digest(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--request', type=Path, required=True)
    ap.add_argument('--incoming', type=Path)
    ap.add_argument('--destination', type=Path, default=Path('docs/research/dynamic_fidelity/evidence_d05'))
    ap.add_argument('--verify-only', action='store_true')
    args = ap.parse_args()
    dest = args.destination
    request = json.loads(args.request.read_text(encoding='utf-8'))
    if args.verify_only:
        idx = json.loads((dest/'ARCHIVE_INDEX.json').read_text(encoding='utf-8'))
        for name, item in idx['files'].items():
            p = dest/name
            if not p.is_file() or digest(p) != item['sha256'] or p.stat().st_size != item['bytes']:
                raise RuntimeError(f'Archived evidence mismatch: {name}')
        print(json.dumps({'verified_files':len(idx['files']), 'verified_bytes':sum(v['bytes'] for v in idx['files'].values())}))
        return
    if args.incoming is None:
        ap.error('--incoming is required for archival')
    old = json.loads((dest/'ARCHIVE_INDEX.json').read_text()) if (dest/'ARCHIVE_INDEX.json').exists() else {'files':{}}
    records = dict(old['files'])
    for case in request['artifacts']:
        src = args.incoming/case['folder']
        meta = json.loads((src/'RUN_MANIFEST.json').read_text())
        if meta['commit'] != case['source_commit'] or meta['checks'] != case['expected_checks'] or meta['allChecksPassed'] is not True:
            raise RuntimeError('Run metadata does not match reviewed evidence')
        with (src/'CHECKS.csv').open(newline='') as f:
            rows = list(csv.DictReader(f))
        if len(rows) != case['expected_checks'] or any(r['passed'].lower() not in ('1','true') for r in rows):
            raise RuntimeError('Raw check table does not match reviewed outcome')
        for name, expected in case['files'].items():
            if Path(name).is_absolute() or '..' in Path(name).parts:
                raise RuntimeError('Unsafe evidence path')
            source = src/name
            if digest(source) != expected['sha256'] or source.stat().st_size != expected['bytes']:
                raise RuntimeError(f'Original bytes mismatch: {case["run_id"]}/{name}')
            relative = f'run_{case["run_id"]}/{name}'
            target = dest/relative
            if target.exists() and digest(target) != expected['sha256']:
                raise RuntimeError(f'Refusing evidence overwrite: {target}')
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copyfile(source, target)
            records[relative] = dict(expected, run_id=case['run_id'], artifact_id=case['artifact_id'], source_commit=case['source_commit'], original_path=name)
    dest.mkdir(parents=True, exist_ok=True)
    idx = {'schema_version':1, 'request':request, 'files':records,
           'note':'Raw ZIP hashes separately checked on retrieval; all retained original members checked here. No new model run.'}
    (dest/'ARCHIVE_INDEX.json').write_text(json.dumps(idx,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'persisted_files':len(records),'persisted_bytes':sum(v['bytes'] for v in records.values())}))

if __name__ == '__main__':
    main()
