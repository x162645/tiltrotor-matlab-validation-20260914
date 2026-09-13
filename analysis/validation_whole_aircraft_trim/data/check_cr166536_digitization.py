"""Sanity checks for manually digitized CR-166536 appendix tables.

This does not validate the physics or claim model agreement.  It only checks
that the CSVs are readable, source pages are present, and expected table
blocks have the expected number of cells.
"""
from collections import Counter
from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parent

def read_rows(name):
    with (ROOT / name).open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def main():
    b1 = read_rows("CR166536_DIGITIZED_TABLES_BATCH1.csv")
    b2 = read_rows("CR166536_DIGITIZED_TABLES_BATCH2.csv")
    c1, c2 = Counter(r["table_id"] for r in b1), Counter(r["table_id"] for r in b2)
    expected1 = {
        "TABLE_023": 12, "TABLE_1_II_ENDURANCE_SUPP": 27,
        "TABLE_024": 8, "TABLE_025": 10,
        "TABLE_001": 128, "TABLE_002": 128, "TABLE_003": 128,
        "TABLE_004": 129, "TABLE_2_II_SUPP": 50,
    }
    expected2 = {
        "TABLE_005": 108, "TABLE_006": 108, "TABLE_007": 54,
        "TABLE_011": 8, "TABLE_013": 10, "TABLE_014": 10,
        "TABLE_015": 20, "TABLE_016": 21, "TABLE_017": 7,
        "TABLE_018": 7,
    }
    for key, n in expected1.items():
        assert c1[key] == n, (key, c1[key], n)
    for key, n in expected2.items():
        assert c2[key] == n, (key, c2[key], n)
    for rows in (b1, b2):
        assert all(r["source_pdf_page"] and r["printed_page"] for r in rows)
        assert all(r["read_status"] for r in rows)
    print(f"batch1={len(b1)} cells, batch2={len(b2)} cells, checks=PASS")

if __name__ == "__main__":
    main()
