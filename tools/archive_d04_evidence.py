"""Preserve read-back D04 artifacts and validate their complete member-index seal."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil


def digest(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def seal(entries: dict) -> str:
    return hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def members(root: Path) -> dict:
    out = {}
    for p in sorted(root.rglob('*')):
        if p.is_symlink():
            raise RuntimeError(f'Symlink not allowed in evidence: {p}')
        if not p.is_file():
            continue
        name = p.relative_to(root).as_posix()
        if name.startswith('source_acquisition/'):
            continue
        out[name] = {'sha256': digest(p), 'bytes': p.stat().st_size}
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--request', type=Path, required=True)
    ap.add_argument('--incoming', type=Path)
    ap.add_argument('--destination', type=Path, default=Path('docs/research/dynamic_fidelity/evidence_d04'))
    ap.add_argument('--verify-only', action='store_true')
    a = ap.parse_args()
    request = json.loads(a.request.read_text())
    if a.verify_only:
        index = json.loads((a.destination/'ARCHIVE_INDEX.json').read_text())
        for case in request['artifacts']:
            prefix = f'run_{case["run_id"]}/'
            current = {}
            for rel, row in index['files'].items():
                if rel.startswith(prefix):
                    p = a.destination/rel
                    current[rel[len(prefix):]] = {'sha256': digest(p), 'bytes': p.stat().st_size}
                    if current[rel[len(prefix):]] != {'sha256': row['sha256'], 'bytes': row['bytes']}:
                        raise RuntimeError(f'Archived byte mismatch: {rel}')
            if seal(current) != case['member_index_sha256']:
                raise RuntimeError('Archived member seal differs from reviewed original artifact')
        print(json.dumps({'verified_files': len(index['files']), 'verified_bytes': sum(x['bytes'] for x in index['files'].values())}))
        return
    if a.incoming is None:
        ap.error('--incoming required for archival')
    a.destination.mkdir(parents=True, exist_ok=True)
    entries = {}
    for case in request['artifacts']:
        src = a.incoming/case['folder']
        data = members(src)
        if seal(data) != case['member_index_sha256'] or len(data) != case['file_count']:
            raise RuntimeError(f'Incoming artifact member seal mismatch: {case["run_id"]}')
        if sum(x['bytes'] for x in data.values()) != case['byte_count']:
            raise RuntimeError('Incoming byte count mismatch')
        meta = json.loads((src/case['manifest']).read_text())
        if meta['commit'] != case['source_commit'] or meta['checks'] != case['expected_checks'] or meta['allChecksPassed'] != case['expected_all_passed']:
            raise RuntimeError('Wrong computation identity or outcome')
        with (src/case['checks_csv']).open(newline='') as f:
            rows = list(csv.DictReader(f))
        if len(rows) != case['expected_checks'] or any(r['passed'].strip().lower() not in {'1','true'} for r in rows):
            raise RuntimeError('Checks contradict read-back results')
        for name, row in data.items():
            rel = f'run_{case["run_id"]}/{name}'
            p = a.destination/rel
            if p.exists() and digest(p) != row['sha256']:
                raise RuntimeError(f'Refusing historical overwrite: {rel}')
            p.parent.mkdir(parents=True, exist_ok=True)
            if not p.exists():
                shutil.copyfile(src/name, p)
            entries[rel] = {**row, 'run_id': case['run_id'], 'artifact_id': case['artifact_id'], 'source_commit': case['source_commit']}
    index = {'schema_version': 1, 'request': request, 'files': entries,
             'note': 'Member seal fixed from independently downloaded original ZIPs; no model recomputation or result alteration.'}
    (a.destination/'ARCHIVE_INDEX.json').write_text(json.dumps(index, indent=2)+'\n')
    print(json.dumps({'persisted_files': len(entries), 'persisted_bytes': sum(x['bytes'] for x in entries.values())}))


if __name__ == '__main__':
    main()
