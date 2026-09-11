"""Documentation-only D12 close: preserve every byte of the old canonical ledger.
No model execution, network calls, credentials, or git operations in this script.
"""
from pathlib import Path
import hashlib,json,os

ROOT=Path.cwd(); DOC=ROOT/'docs/research/dynamic_fidelity'
MARKER=b'<!-- D12_CANONICAL_CLOSURE_20260911 -->'
EXPECTED={'docs/research/dynamic_fidelity/STEP_LEDGER.md':'57f91c0ea86f198eec5b2ff54cdc7020932bbcc0','RESEARCH_ENTRY.md':'cd8de12727ada6cde99bf9cceffbfb0806b8c496','CODEX_TASK.md':'f704e8ffa917469930165bdc7df6d411004c6d15'}
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def sha(raw):return hashlib.sha256(raw).hexdigest()
old={rel:(ROOT/rel).read_bytes() for rel in EXPECTED}
for rel,want in EXPECTED.items():
    if blob(old[rel])!=want:raise RuntimeError('Unexpected updated source; refuse overwrite: '+rel)
ledger=old['docs/research/dynamic_fidelity/STEP_LEDGER.md']
if MARKER in ledger:raise RuntimeError('D12 closure already present; do not duplicate')
readback=json.loads((DOC/'evidence_d12/runs/34642707267/crosscheck/READBACK_MANIFEST.json').read_text())
assert readback['passed'] and readback['matched_rows']==48
assert readback['matlab']['commit']=='872c566382cce21153e31e7e42561916bd31cb37'
backup=DOC/'evidence_d12/doc_close_before';backup.mkdir(parents=True,exist_ok=False)
for rel,raw in old.items():
    (backup/Path(rel).name).write_bytes(raw)
head=('''# 动态研发统一台账：当前有效状态D12\n\n<!-- D12_CANONICAL_CLOSURE_20260911 -->\n\n2026-09-11。最新有效结论为本文末的D11归档接续与D12章节。以下D00—D05及D06—D10原台账按原字节保留，其中“当前D05”“尚未提交”等是旧记录的历史时间语义，不是本页的当前远端状态。D11核心已上传，旧54MB原始总包未整体上传；D12 Python与原生MATLAB运行证据已永久入Git。\n\n## D00—D05原始台账（原文保留）\n\n''').encode()
d06=(DOC/'D06_D10_ARCHIVE_LEDGER.md').read_bytes();addition=(DOC/'D12_LEDGER_APPEND.md').read_bytes()
new=head+ledger+b'\n\n---\n\n'+d06+b'\n\n---\n\n'+addition
assert new.count(ledger)==1 and new.count(MARKER)==1
(ROOT/'docs/research/dynamic_fidelity/STEP_LEDGER.md').write_bytes(new)
(ROOT/'RESEARCH_ENTRY.md').write_bytes((DOC/'D12_RESEARCH_ENTRY_NEXT.md').read_bytes())
(ROOT/'CODEX_TASK.md').write_bytes((DOC/'D12_CODEX_TASK_NEXT.md').read_bytes())
record={'documentation_only':True,'scientific_models_executed':0,'execution_commit':os.environ.get('GITHUB_SHA'),'run_id':os.environ.get('GITHUB_RUN_ID'),'old_git_blobs':EXPECTED,'old_ledger_preserved_as_contiguous_bytes':True,'D06_D10_original_ledger_sha256':sha(d06),'D12_append_sha256':sha(addition),'new_files_sha256':{rel:sha((ROOT/rel).read_bytes()) for rel in EXPECTED},'D12_scientific_run':34642707267,'D12_scientific_source_commit':'872c566382cce21153e31e7e42561916bd31cb37','D12_scientific_evidence_commit':'b46062426ba85a7b99097bca6dfb4f55f300a39f'}
(DOC/'D12_DOC_CLOSE_RECORD.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False))
