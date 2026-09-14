"""Traceable CR-166536 table reader. Standard library only; no aircraft model.

Exact source coordinates remain explicit. The optional 1-D linear interpolation
is an implementation policy, not a transcription or the full GTRS algorithm.
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE_SHA256 = "a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d"
ALIASES = {
    "TABLE_023": "1-I", "TABLE_1_II_ENDURANCE_SUPP": "1-II/endurance",
    "TABLE_024": "1-II/sideward", "TABLE_025": "1-III",
    "TABLE_001": "2-I(a)", "TABLE_002": "2-I(b)",
    "TABLE_003": "2-I(c)", "TABLE_004": "2-I(d)", "TABLE_2_II_SUPP": "2-II",
    "TABLE_005": "5-V(a)", "TABLE_006": "5-V(b)", "TABLE_007": "5-V(c)",
    "TABLE_011": "5-VI", "TABLE_026": "5-VII",
    "TABLE_013": "8a-I", "TABLE_027": "8a-II", "TABLE_014": "8a-III",
    "TABLE_015": "8a-IV", "TABLE_028": "8a-V", "TABLE_016": "8a-VI",
    "TABLE_017": "8a-VII", "TABLE_018": "8a-VIII", "TABLE_020_T4_I": "4-I",
    "TABLE_020_WING_PYLON_CONSTANTS": "4/constants",
}
COORDINATE_FIELDS = {
    "table_name": ["row_axis", "row_value", "flap_setting", "mast_angle_deg",
                   "mach_label", "coefficient", "alpha_deg", "elevator_deg", "quantity", "parameter"],
    "table_id": ["row_key", "row_value", "col_key", "col_value", "quantity",
                 "mach_key", "rudder_deg", "mast_deg", "flap_setting", "row_axis", "col_axis",
                 "subtable_id", "flap_setting_code", "mast_angle_deg", "mach_number", "mach_condition",
                 "alpha_condition"],
}


class TableError(ValueError):
    pass


def canonical(name):
    if name in ALIASES:
        return ALIASES[name]
    if name.startswith("TABLE_3_"):
        return name.replace("TABLE_3_", "3-")
    if re.fullmatch(r"TABLE_\d+_T4_[IVX]+", name):
        return "4-" + name.rsplit("_", 1)[1]
    if name in {"Horizontal stabilizer constants", "Horizontal stabilizer coefficients"}:
        return "5/constants"
    if name in {"Vertical stabilizer constants", "Vertical fin constants"}:
        return "6/constants"
    return name[len("Table "):] if name.startswith("Table ") else name


def numeric(value):
    try:
        result = float(value)
    except (ValueError, TypeError):
        return None
    return result if math.isfinite(result) else None


def token(value):
    """Equivalent numeric spelling only; intervals and groups stay opaque."""
    number = numeric(value)
    return number if number is not None else str(value)


def resolved_unit(table, raw):
    unit = raw.get("value_unit", raw.get("unit", ""))
    if table in {"4-I", "4-VIII"}:
        return "dimensionless"
    if table == "3-VIII":
        return "ft3"
    return unit


class TableDatabase:
    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.cells = []
        self.by_table = defaultdict(list)
        self.files = []
        for path in sorted(self.root.glob("CR166536*.csv")):
            if path.name in {"CR166536_ALL_CELLS.csv", "CR166536_TABLE_CATALOG.csv"}:
                continue
            with path.open(encoding="utf-8-sig", newline="") as stream:
                rows = list(csv.DictReader(stream))
            if not rows:
                raise TableError(f"Empty source CSV: {path.name}")
            field = "table_name" if "table_name" in rows[0] else "table_id"
            if field not in rows[0]:
                # Constant sheets have a separate schema and are catalogued,
                # but must not be guessed into an aerodynamic lookup table.
                self.files.append(dict(file=path.name, rows=len(rows), kind="constants",
                                       sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
                continue
            for line, raw in enumerate(rows, 2):
                table = canonical(raw[field])
                coordinates = {k: v for k, v in raw.items()
                               if k in COORDINATE_FIELDS[field]}
                cell = dict(table=table, file=path.name, csv_line=line,
                            pdf_page=raw.get("source_pdf_page", raw.get("pdf_page", "")),
                            printed_page=raw.get("printed_page", ""), coordinates=coordinates,
                            value=numeric(raw.get("value")), raw_value=raw.get("value", ""),
                            status=raw.get("read_status", raw.get("status", "")),
                            unit=resolved_unit(table, raw), raw=raw)
                self.cells.append(cell)
                self.by_table[table].append(cell)
            self.files.append(dict(file=path.name, rows=len(rows), kind="tables",
                                   sha256=hashlib.sha256(path.read_bytes()).hexdigest()))

    def select(self, table, **selectors):
        table = canonical(table)
        if table not in self.by_table:
            raise TableError(f"Unknown table {table}")
        cells = self.by_table[table]
        keys = set().union(*(c["coordinates"] for c in cells))
        if set(selectors) - keys:
            raise TableError(f"Unknown coordinate(s) {set(selectors) - keys}; available {sorted(keys)}")
        selected = [c for c in cells if all(token(c["coordinates"].get(k, "")) == token(v)
                                             for k, v in selectors.items())]
        if not selected:
            raise TableError(f"No source cells: {table}, {selectors}")
        return selected

    @staticmethod
    def provenance(cells):
        return [dict(file=c["file"], csv_line=c["csv_line"], pdf_page=c["pdf_page"],
                     printed_page=c["printed_page"]) for c in cells]

    def _at_node(self, table, cells, axis, x, selectors):
        values = {c["value"] for c in cells if c["value"] is not None}
        if values:
            if len(values) != 1 or any("NOT_DEFINED" in c["status"] for c in cells):
                raise TableError(f"Conflicting source cells at {table} {axis}={x}")
            return dict(value=values.pop(), unit=cells[0]["unit"], operation="source_node",
                        source_rows=self.provenance(cells))
        # Only two explicit source references are implemented here. No implicit
        # mirroring, Mach/flap scheduling, sign extension or missing-cell filling.
        if table == "5-II" and all("REFERENCE" in c["status"] for c in cells):
            result = self.curve("5-I", "alpha_deg", x, elevator_deg=0,
                                mach_label="0-0.2", quantity="C_LH")
        elif table == "6-II" and all("REFERENCE" in c["status"] for c in cells):
            result = self.curve("6-I", "row_key", x, col_key=0)
        else:
            raise TableError(f"Source undefined/blank at {table} {axis}={x}: "
                             f"{sorted({c['status'] for c in cells})}")
        return dict(result, operation="explicit_source_reference/" + result["operation"],
                    source_rows=self.provenance(cells) + result["source_rows"])

    def curve(self, table, axis, x, **selectors):
        """Read a knot or linearly interpolate between adjacent valid knots.

        All remaining coordinates must identify one curve. Reject interval/group
        axes, extrapolation, undefined endpoints, and mixed configurations.
        """
        table = canonical(table)
        x = numeric(x)
        if x is None:
            raise TableError("Query must be finite numeric")
        if axis in selectors:
            raise TableError("Do not supply interpolation axis as a selector")
        cells = self.select(table, **selectors)
        if axis not in cells[0]["coordinates"]:
            raise TableError(f"Unknown axis {axis}")
        for key in cells[0]["coordinates"]:
            if key != axis and len({token(c["coordinates"][key]) for c in cells}) > 1:
                raise TableError(f"Ambiguous curve: specify {key}")
        # The printed low-Mach references explicitly cover -180..180 deg,
        # beyond the secondary tables' displayed -40..40 deg row grid.
        if table in {"5-II", "6-II"} and all("REFERENCE" in c["status"] for c in cells):
            return self._at_node(table, cells, axis, x, selectors)
        groups = defaultdict(list)
        for cell in cells:
            coordinate = numeric(cell["coordinates"][axis])
            if coordinate is None:
                raise TableError(f"Axis has interval/group labels; use select(): {axis}")
            groups[coordinate].append(cell)
        if x in groups:
            return self._at_node(table, groups[x], axis, x, selectors)
        grid = sorted(groups)
        if x < grid[0] or x > grid[-1]:
            raise TableError(f"Extrapolation refused: {x} outside [{grid[0]}, {grid[-1]}]")
        lo = max(v for v in grid if v < x)
        hi = min(v for v in grid if v > x)
        lower = self._at_node(table, groups[lo], axis, lo, selectors)
        upper = self._at_node(table, groups[hi], axis, hi, selectors)
        if lower["unit"] != upper["unit"]:
            raise TableError("Inconsistent units")
        return dict(value=lower["value"] + (upper["value"] - lower["value"]) * (x-lo)/(hi-lo),
                    unit=lower["unit"], operation="linear_interpolation_not_source_sample",
                    bracket=[lo, hi], source_rows=lower["source_rows"] + upper["source_rows"])

    def catalog(self):
        tables = []
        for table, cells in sorted(self.by_table.items()):
            tables.append(dict(table=table, records=len(cells), numeric=sum(c["value"] is not None for c in cells),
                               status_counts=dict(Counter(c["status"] for c in cells)),
                               pdf_pages=sorted({int(c["pdf_page"]) for c in cells}),
                               files=sorted({c["file"] for c in cells}),
                               coordinate_fields=sorted(cells[0]["coordinates"]),
                               units=sorted({c["unit"] for c in cells})))
        return dict(source_pdf_sha256=SOURCE_SHA256, data_role="report_model_input_not_independent_experiment",
                    records=len(self.cells), numeric=sum(c["value"] is not None for c in self.cells),
                    files=self.files, tables=tables)

    def export(self):
        catalog = self.catalog()
        (self.root / "CR166536_TABLE_CATALOG.json").write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        with (self.root / "CR166536_ALL_CELLS.csv").open("w", encoding="utf-8-sig", newline="") as stream:
            names = ["table", "file", "csv_line", "pdf_page", "printed_page", "coordinates_json",
                     "value", "unit", "status", "raw_row_json"]
            writer = csv.DictWriter(stream, fieldnames=names)
            writer.writeheader()
            for cell in self.cells:
                record = {k: cell[k] for k in names if k in cell}
                record["coordinates_json"] = json.dumps(cell["coordinates"], ensure_ascii=False)
                record["raw_row_json"] = json.dumps(cell["raw"], ensure_ascii=False)
                writer.writerow(record)
        return catalog


if __name__ == "__main__":
    report = TableDatabase().export()
    print(json.dumps({k: report[k] for k in ("records", "numeric")}, ensure_ascii=False))
