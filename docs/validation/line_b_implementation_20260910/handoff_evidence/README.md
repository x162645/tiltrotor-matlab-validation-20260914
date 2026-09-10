# 已执行证据的永久副本

38 个固定 Actions 产物，176 个文件，92309230 字节。

MAT/CSV/JSON 和四份来源 PDF 为原始字节副本，不是重跑结果。重复代码快照不重复入库；代码由 ARCHIVE_INDEX.json 的 source_commit 定位。原 ZIP 名称、run、artifact、哈希和各源文件名均保存。

先读根目录 WORK_HANDOFF.md 与逐步台账。`python tools/archive_work_handoff.py --verify-only` 离线核验字节，不执行模型。
