"""Targeted Figure 1(a) re-digitization from Wang et al. (2025) F001.

This reads only the 90 deg nacelle column. Marker centers are chart data;
black pixels are a visualization curve, never independent experiments.
No model output is used to choose source points. Old digitizations are kept.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


AXES = [
    dict(row=0, variable="theta0", unit="deg", x0=116, x1=455,
         y0=23, y1=198, xmin=0, xmax=60, ymin=30, ymax=60, band=[85, 145]),
    dict(row=1, variable="delta_lon", unit="percent", x0=116, x1=455,
         y0=306, y1=481, xmin=0, xmax=60, ymin=0, ymax=100, band=[335, 419]),
    dict(row=2, variable="theta", unit="deg", x0=116, x1=455,
         y0=601, y1=775, xmin=0, xmax=60, ymin=-40, ymax=40, band=[666, 735]),
    dict(row=3, variable="P", unit="kW", x0=116, x1=455,
         y0=895, y1=1070, xmin=0, xmax=60, ymin=0, ymax=2500, band=[947, 1040]),
]


def convert(a, x, y):
    return (a["xmin"] + (x-a["x0"])/(a["x1"]-a["x0"])*(a["xmax"]-a["xmin"]),
            a["ymax"] - (y-a["y0"])/(a["y1"]-a["y0"])*(a["ymax"]-a["ymin"]))


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    source = Image.open(args.source).convert("RGB")
    if source.size != (1889, 1254):
        raise ValueError("Axis calibration is specific to the 1889 x 1254 F001 image")
    rgb = np.asarray(source).astype(int)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    colors = {
        "blue_literature": (b-r > 35) & (b-g > 8) & (b > 90) & (r < 150),
        "red_flight": (r-g > 65) & (r-b > 55) & (r > 160) & (g < 160),
    }
    dark = (rgb.max(2) < 105) & ((rgb.max(2)-rgb.min(2)) < 20)
    points = []
    bbox_rows = []
    for a in AXES:
        for series, color_mask in colors.items():
            # Include the part of the boundary marker protruding outside the frame.
            top, left = a["y0"]+3, 110
            mask = color_mask[top:a["y1"]-3, left:456]
            active_cols = np.flatnonzero(mask.sum(0))
            groups = np.split(active_cols, np.flatnonzero(np.diff(active_cols) > 3)+1)
            for group in groups:
                if len(group) == 0:
                    continue
                ys, xs = np.nonzero(mask[:, group.min():group.max()+1])
                if len(xs) < 15:
                    continue
                xs = xs + group.min()+left
                ys = ys + top
                box = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
                xp, yp = (box[0]+box[2])/2, (box[1]+box[3])/2
                note = "visible_color_bbox_center; fragments_at_same_x_merged"
                unc_y = 1.5
                # Three square tops are hidden by black/red ink. The visible
                # bottom edge and 13 px square width bound the center. This
                # limited reconstruction is disclosed with 3 px uncertainty.
                if series == "blue_literature" and (
                    (a["row"] == 0 and 280 < xp < 300) or
                    (a["row"] in (2, 3) and 225 < xp < 245)
                ):
                    yp = box[3] - (box[2]-box[0])/2
                    unc_y = 3.0
                    note = "partly_occluded_square; center_from_visible_bottom_and_square_width"
                if series == "red_flight" and a["row"] == 1:
                    unc_y = 2.5  # black curve clips the red disk; retain the wider bound
                    note += "; partly_occluded_by_black_curve"
                xv, yv = convert(a, xp, yp)
                row = dict(figure=1, panel=0, row=a["row"], series=series,
                           x_value=xv, y_value=yv, variable=a["variable"],
                           x_unit="m/s", y_unit=a["unit"], x_pixel=xp, y_pixel=yp,
                           data_role="visible_published_marker", x_uncertainty=1.5*60/339,
                           y_uncertainty=unc_y*(a["ymax"]-a["ymin"])/(a["y1"]-a["y0"]),
                           uncertainty_role="reading_bound_not_statistical_CI",
                           note=note, source_image="F001.jpg", digitization_version="FIG1A_V2",
                           segment_id="")
                points.append(row)
                bbox_rows.append((a["row"], series, box, xp, yp))
        # Trace only observed achromatic pixels in the curve band, excluding axes.
        previous_x, segment_id = None, 0
        # Left-axis ticks intrude to x~127. A wider guard avoids treating the
        # 40 deg/0 deg/1000 kW tick as the model curve. No missing segment is filled.
        for xp in range(133, 450):
            ys = np.flatnonzero(dark[a["band"][0]:a["band"][1]+1, xp])+a["band"][0]
            if not len(ys):
                continue
            if previous_x is None or xp != previous_x+1:
                segment_id += 1
            previous_x = xp
            yp = float(np.median(ys))
            xv, yv = convert(a, xp, yp)
            points.append(dict(figure=1, panel=0, row=a["row"], series="black_model",
                               x_value=xv, y_value=yv, variable=a["variable"],
                               x_unit="m/s", y_unit=a["unit"], x_pixel=xp, y_pixel=yp,
                               data_role="observed_curve_pixel_not_independent_sample",
                               x_uncertainty=1.5*60/339,
                               y_uncertainty=1.5*(a["ymax"]-a["ymin"])/(a["y1"]-a["y0"]),
                               uncertainty_role="reading_bound_not_statistical_CI",
                               note="median_achromatic_curve_pixels; no_interpolation",
                               source_image="F001.jpg", digitization_version="FIG1A_V2",
                               segment_id=segment_id))
    points.sort(key=lambda q: (q["row"], q["series"], q["x_value"]))
    markers = [x for x in points if x["series"] != "black_model"]
    trace = [x for x in points if x["series"] == "black_model"]
    write_csv(args.out/"FIG1a_digitized_points_v2.csv", points)
    write_csv(args.out/"FIG1a_markers_v2.csv", markers)
    write_csv(args.out/"FIG1a_model_trace_v2.csv", trace)
    expected_counts = {0: {"blue_literature": 6, "red_flight": 0},
                       1: {"blue_literature": 5, "red_flight": 3},
                       2: {"blue_literature": 6, "red_flight": 3},
                       3: {"blue_literature": 6, "red_flight": 3}}
    counts = {i: {s: sum(x["row"] == i and x["series"] == s for x in markers)
                  for s in colors} for i in range(4)}
    if counts != expected_counts:
        raise AssertionError(("Unexpected marker count", counts))
    qa = source.crop((0, 0, 465, 1205)).copy()
    draw = ImageDraw.Draw(qa)
    for a in AXES:
        draw.rectangle((a["x0"], a["y0"], a["x1"], a["y1"]), outline="lime", width=1)
    for rr, ss, box, xp, yp in bbox_rows:
        draw.rectangle(box, outline="cyan" if ss == "blue_literature" else "magenta", width=1)
        draw.line((xp-3, yp, xp+3, yp), fill="yellow", width=1)
        draw.line((xp, yp-3, xp, yp+3), fill="yellow", width=1)
    qa.save(args.out/"FIG1a_pixel_QA_v2.png")
    trace_qa = source.crop((0, 0, 465, 1205)).copy()
    draw = ImageDraw.Draw(trace_qa)
    for point in trace:
        xx, yy = point["x_pixel"], point["y_pixel"]
        draw.ellipse((xx-1, yy-1, xx+1, yy+1), fill="cyan")
    trace_qa.save(args.out/"FIG1a_black_trace_QA_v2.png")
    source.save(args.out/"F001_source.png")
    source.crop((0, 0, 465, 1205)).save(args.out/"FIG1a_source_column.png")
    metadata = dict(version="FIG1A_V2", source=str(args.source),
                    source_sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),
                    source_size_px=list(source.size), axes=AXES, counts=counts,
                    trace_rows=len(trace), corrected_scope="Figure 1(a), nacelle 90 deg, four rows",
                    hidden_markers=["delta_lon blue marker near 20.9 m/s is obscured; omitted"],
                    source_roles={"blue_literature": "Wang Figure 1 literature[26] (CR166537)",
                                  "red_flight": "published flight marker, original raw record not available",
                                  "black_model": "Wang model curve pixel trajectory"},
                    qualifications=["No model predictions used for extraction or selection",
                                    "Pixel traces are correlated visualization samples, not experiments",
                                    "x<=132 px excluded from black trace to remove axis ticks; gaps not filled",
                                    "Reading bounds are not statistical confidence intervals",
                                    "theta0 station and delta_lon percent mapping remain separate definition audits",
                                    "No unseen/fully occluded blue or red marker is invented",
                                    "Old FIG1 digitization remains unchanged"])
    (args.out/"FIG1a_axes_and_provenance_v2.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    note = """# 王梓旭图1(a)定向数字化修订 V2

仅重取直升机构型90°的四行。源图为1889×1254的期刊F001，轴框和源SHA见JSON。
旧文件保留；`work/wang_F001.jpg`是HTML错误响应，不作为源图。

旧CSV存在轴标定偏差；对蓝方块只识别一块可见颜色碎片，也会产生中心偏差。
V2先按同一x位置合并可见颜色碎片，再取标记外框中心。三个蓝方块上部被线/红点遮挡，
用可见底边和方块宽度约束中心，标记为部分遮挡，并将读图范围放宽为±3像素。
第二行约20.9m/s的蓝点完全无法独立分离，省略；不从模型或别处反算。
三行红点均保留约43.3m/s处，修复旧提取漏点。

数据列沿用row、series、x_value、y_value；row=0/1/2/3分别为θ0、纵向杆量、θ、P。
黑线每个可见像素列取中位深灰像素，作为可视化轨迹，绝不计为独立试验点。
黑轨迹排除x<=132像素的轴刻度区，故V<3.01m/s缺轨迹；不补造、不外推。segment_id遇缺列即断开。
仅蓝/红标记可用于图示点级配对；蓝是CR-166537模型参考，红是论文标为试飞的数据。
读图范围是像素和遮挡导致的保守界，不是统计置信区间。原CSV的十几位小数不代表该精度。

总距定义、杆位百分比的零点/方向以及功率统计对象必须另核；坐标一致不自动等于物理定义一致。
源图首列范围：V=0–60m/s；θ0=30–60°；δlon=0–100%；θ=−40–40°；P=0–2500kW。
"""
    (args.out/"FIG1a_DIGITIZATION_NOTE_v2.md").write_text(note, encoding="utf-8")
    print(json.dumps(dict(marker_counts=counts, black_trace_rows=len(trace), out=str(args.out))))


if __name__ == "__main__":
    main()
