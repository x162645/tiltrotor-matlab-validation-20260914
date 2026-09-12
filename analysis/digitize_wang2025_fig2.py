"""Digitize Wang et al. (2025) Fig. 2 color traces.

This is a figure-level extraction, not recovery of source arrays. The output
must be reported with the stated pixel uncertainty.
"""
from pathlib import Path
import csv, math
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "docs/validation/wang2025_digitization/source_images/F002.jpg"
OUT = ROOT / "docs/validation/wang2025_digitization"
PANELS = [
    ("r1c1", (115,20,550,171), (0,5), (-20,20)), ("r1c2", (716,20,1158,171), (0,5), (-40,40)), ("r1c3", (1328,20,1741,171), (0,5), (-20,20)),
    ("r2c1", (115,282,550,434), (0,5), (-20,20)), ("r2c2", (716,282,1158,434), (0,5), (-20,20)), ("r2c3", (1328,282,1741,434), (0,6), (-20,20)),
    ("r3c1", (115,543,550,694), (0,5), (-30,10)), ("r3c2", (716,543,1158,694), (0,5), (-20,40)), ("r3c3", (1328,543,1741,694), (0,5), (-10,30)),
]

def classify(px):
    r,g,b = px[:3]
    if r > 165 and r > 1.35*g and r > 1.35*b and g < 145 and b < 145: return "experiment"
    if b > 105 and b > 1.10*r and b > 1.02*g and r < 165: return "literature"
    # The published model trace is dark gray after JPEG compression
    # (approximately RGB 100), so a strict black threshold misses most of it.
    if max(r,g,b) < 160 and max(r,g,b)-min(r,g,b) < 28: return "model"
    return None

def pix_to_data(x,y,rect,xr,yr):
    x0,y0,x1,y1 = rect
    return xr[0]+(x-x0)/(x1-x0)*(xr[1]-xr[0]), yr[1]-(y-y0)/(y1-y0)*(yr[1]-yr[0])

def extract(im,rect,xr,yr,role):
    x0,y0,x1,y1=rect; rows=[]
    # Leave a guard band around the axes/frame.  The black model trace
    # overlaps the zero line, while the frame is also black; including the
    # first/last pixels creates spurious +/- full-scale values.
    gx, gy = 7, 12
    # Remove the small vertical tick marks at the integer time labels.  They
    # are black/gray and otherwise look like full-scale model samples.
    tick_px = []
    for tv in range(int(xr[0])+1, int(xr[1])):
        tick_px.append(round(x0 + (tv-xr[0])/(xr[1]-xr[0])*(x1-x0)))
    for x in range(x0+gx,x1-gx+1):
        if any(abs(x-tx) <= 4 for tx in tick_px):
            continue
        ys=[y for y in range(y0+gy,y1-gy+1) if classify(im.getpixel((x,y)))==role]
        if ys:
            y=sorted(ys)[len(ys)//2]; xd,yd=pix_to_data(x,y,rect,xr,yr); rows.append((xd,yd))
    return rows

def main():
    im=Image.open(IMG).convert("RGB"); output=[]
    for panel,rect,xr,yr in PANELS:
        for role in ("model","experiment","literature"):
            for x,y in extract(im,rect,xr,yr,role): output.append({"panel":panel,"role":role,"time_s":x,"value_native":y,"pixel_uncertainty":2})
    OUT.mkdir(parents=True,exist_ok=True)
    with (OUT/"FIG2_digitized_points.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=output[0].keys()); w.writeheader(); w.writerows(output)
    by={}
    for row in output: by.setdefault((row["panel"],row["role"]),[]).append(row)
    summary=[]
    for panel,_,_,_ in PANELS:
        model=by.get((panel,"model"),[])
        if not model: continue
        for ref_role in ("experiment","literature"):
            ref=by.get((panel,ref_role),[])
            if not ref: continue
            vals=[min(model,key=lambda p:abs(p["time_s"]-q["time_s"]))["value_native"]-q["value_native"] for q in ref]
            summary.append({"panel":panel,"reference":ref_role,"n":len(vals),"MAE_native":sum(abs(v) for v in vals)/len(vals),"RMSE_native":math.sqrt(sum(v*v for v in vals)/len(vals)),"pixel_uncertainty":2,"role_note":"figure_digitization_not_source_array"})
    with (OUT/"FIG2_error_summary.csv").open("w",newline="",encoding="utf-8") as f:
        fields=summary[0].keys() if summary else ["panel"]; w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(summary)
    print(f"WROTE FIG2 points={len(output)} summaries={len(summary)}")

if __name__ == "__main__": main()
