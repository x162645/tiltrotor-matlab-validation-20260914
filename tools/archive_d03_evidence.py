"""Persist verified D03 source/results without recomputation or overwriting history."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--request', required=True, type=Path)
    ap.add_argument('--incoming', type=Path)
    ap.add_argument('--destination', type=Path, default=Path('docs/research/dynamic_fidelity/evidence_d03'))
    ap.add_argument('--verify-only', action='store_true')
    args = ap.parse_args()
    dest = args.destination
    if args.verify_only:
        index = json.loads((dest/'ARCHIVE_INDEX.json').read_text())
        for name, row in index['files'].items():
            p = dest/name
            if not p.is_file() or digest(p) != row['sha256']:
                raise RuntimeError(f'Archive hash mismatch: {name}')
        print(json.dumps({'verified_files':len(index['files']), 'verified_bytes':sum(x['bytes'] for x in index['files'].values())}))
        return
    if args.incoming is None:
        ap.error('--incoming is required for archival')
    request = json.loads(args.request.read_text())
    dest.mkdir(parents=True, exist_ok=True)
    files = {}

    def preserve(source: Path, relative: str, run: int) -> None:
        target = dest/relative
        h = digest(source)
        if target.exists() and digest(target) != h:
            raise RuntimeError(f'Refusing to overwrite different evidence: {target}')
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copyfile(source, target)
        row = files.setdefault(relative, {'sha256':h, 'bytes':target.stat().st_size, 'source_runs':[]})
        row['source_runs'].append(run)

    for case in request['artifacts']:
        source = args.incoming/case['folder']
        for name, expected in case['expected_file_sha256'].items():
            if digest(source/name) != expected:
                raise RuntimeError(f'Original file hash mismatch: {case["run_id"]}/{name}')
        meta = json.loads((source/'RUN_MANIFEST.json').read_text())
        if meta['commit'] != case['source_commit'] or meta['checkCount'] != 78:
            raise RuntimeError('Wrong run identity or check count')
        if meta['allChecksPassed'] != case['expected_all_checks_passed']:
            raise RuntimeError('Run outcome differs from reviewed evidence')
        with (source/'CHECKS.csv').open(newline='') as f:
            checks = list(csv.DictReader(f))
        failed = sum(r['pass'].strip().lower() not in ('1','true') for r in checks)
        if len(checks) != 78 or failed != case['expected_failed_checks']:
            raise RuntimeError('Check table contradicts reviewed outcome')
        pdf = source/'NASA_TM_88327.pdf'
        if digest(pdf) != request['source_pdf_sha256']:
            raise RuntimeError('Wrong source PDF version')
        for p in sorted(source.iterdir()):
            if p.is_file() and p.suffix.lower() in {'.mat','.csv','.json','.txt'}:
                preserve(p,f'run_{case["run_id"]}/{p.name}',case['run_id'])
        preserve(pdf,'sources/NASA_TM_88327.pdf',case['run_id'])
        for page in ('pdf_009.png','pdf_010.png','pdf_011.png'):
            preserve(source/'source_pages'/page, 'sources/'+page, case['run_id'])
    index = {'schema_version':1, 'request':request, 'files':files,
             'note':'Original ZIP hashes were independently checked before archiving. This utility checks listed original member hashes and retained file hashes; no model runs.'}
    (dest/'ARCHIVE_INDEX.json').write_text(json.dumps(index,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'persisted_files':len(files),'persisted_bytes':sum(x['bytes'] for x in files.values())}))

if __name__ == '__main__':
    main()
