"""Pixel-supported digitization of NASA TM89428 Fig4.34. No OCR or model fitting.
Manual solid-line guides are explicit. Multiple ink groups retain a conservative
union envelope, not an experimental confidence interval. Dashed ink is never a
central flight label; crossings may be unresolved by this scanned source.
"""
from pathlib import Path
import argparse,hashlib,json,csv
import numpy as np
from PIL import Image,ImageDraw
import fitz
PDF_SHA='252f7df0c0e05bd8dece0a923d337df2231c0148f897f0376f930f6102b90ba2'
ORIGIN=np.array([750,1475])
GUIDE=np.array([(75,810),(103,811),(118,783),(138,829),(151,805),(166,727),
 (183,752),(193,740),(208,706),(215,703),(229,716),(246,729),(266,694),
 (279,720),(283,724),(293,702),(307,730),(316,699),(332,735),(344,737),
 (354,708),(360,720),(371,776),(385,743),(391,741),(405,743),(425,805),
 (438,769),(448,784),(457,814),(474,848),(487,802),(506,854),(520,815),
 (535,853),(550,812),(565,850),(578,840),(592,803),(609,826),(624,797),
 (635,798),(650,823),(664,787),(680,821),(693,810),(707,820),(723,839),
 (738,849),(750,872),(762,934),(772,974),(780,959),(787,968),(795,947),
 (805,944),(817,915),(826,918),(835,909),(849,898),(860,909),(870,875),
 (890,866),(900,845),(909,822),(917,835),(937,812),(951,778),(962,757),
 (973,770),(981,766),(989,767),(1000,783),(1017,768),(1027,762)],float)+ORIGIN
CAL={'input':{'pixel':[[821,1954],[1805,1949],[819,1509]],'value':[[0,-10],[30,-10],[0,5]]},
 'flight':{'pixel':[[821,2511],[1805,2508],[818,2065]],'value':[[0,-.1],[30,-.1],[0,.1]]}}
def affine(which):
 q=CAL[which];return np.linalg.solve(np.c_[q['pixel'],np.ones(3)],np.array(q['value']))
def runs(y):return [q for q in np.split(y,np.flatnonzero(np.diff(y)>1)+1) if len(q)]
def extract(pdf,out):
 if out.exists():raise FileExistsError('Use new digitization directory')
 out.mkdir(parents=True)
 if hashlib.sha256(pdf.read_bytes()).hexdigest()!=PDF_SHA:raise ValueError('Different source PDF')
 d=fitz.open(pdf);im=d.extract_image(d[119].get_images()[0][0]);native=out/'TM89428_p120_native.png';native.write_bytes(im['image'])
 arr=np.asarray(Image.open(native).convert('L'));assert arr.shape==(3274,2480);black=arr<100
 allrows={};selections=[]
 for which in ['input','flight']:
  A=affine(which);rows=[]
  for x in range(830,1778,3):
   lo,hi=(1518,1895) if which=='input' else (2145,2465)
   ys=np.flatnonzero(black[lo:hi+1,x])+lo;groups=runs(ys)
   if not groups:raise ValueError(f'No pixel support at {which} x={x}')
   if which=='input':
    if len(groups)!=1:raise ValueError(f'Ambiguous input x={x}')
    g=groups[0]
   else:
    guide=np.interp(x,GUIDE[:,0],GUIDE[:,1]);g=min(groups,key=lambda q:abs(np.mean(q)-guide))
    if abs(np.mean(g)-guide)>20:raise ValueError(f'Flight guide has no nearby ink: x={x}')
   y=float(np.mean(g));t,v=np.array([x,y,1.])@A;candidates=ys if which=='flight' else g
   vs=np.c_[np.full(len(candidates),x),candidates,np.ones(len(candidates))]@A
   pad=3*abs(A[1,1])+abs(A[0,1]);vlo=float(np.min(vs[:,1])-pad);vhi=float(np.max(vs[:,1])+pad)
   rows.append([t,v,vlo,vhi,x,y,len(groups),float(np.max(g)-np.min(g))]);selections.append((which,x,y))
  rows=np.array(rows);assert (np.diff(rows[:,0])>0).all()
  filename='FIG434_POWER_INPUT.csv' if which=='input' else 'FIG434_FLIGHT_AZ.csv'
  with (out/filename).open('w',newline='') as f:
   w=csv.writer(f);w.writerow(['time_s','value','read_lower','read_upper','pixel_x','pixel_y','ink_groups','selected_stroke_width_px']);w.writerows(rows)
  allrows[which]=len(rows)
 overlay=Image.open(native).convert('RGB');draw=ImageDraw.Draw(overlay)
 for which,x,y in selections:draw.ellipse((x-2,y-2,x+2,y+2),outline=(230,0,0))
 overlay.crop((750,1475,1850,2670)).save(out/'SOLID_TRACE_READBACK.png')
 meta={'source':'NASA TM89428 Fig4.34, PDF120 / printed97; interpretation continues PDF121 / printed98','source_pdf_sha256':PDF_SHA,'native_image_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'page_index_zero':119,'pixel_shape_yx':[3274,2480],'calibration':CAL,'solid_trace_manual_guides':GUIDE.tolist(),'columns':{'start':830,'exclusive_stop':1778,'step':3},'counts':allrows,'roles':{'input':'power lever increase percentage points','output':'solid-line flight vertical acceleration downward in g','dashed_model':'not a flight target; excluded from central selections; included only in conservative multiple-ink envelopes'},'uncertainty':'stroke/axis and ambiguous-ink read envelope, not experimental confidence or a probability model','not_new_flight_experiment':True,'not_new_blind_validation':True,'target_predictions_used_to_select_ink':False}
 (out/'DIGITIZATION_PROVENANCE.json').write_text(json.dumps(meta,indent=2));print(allrows)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--pdf',type=Path,required=True);a.add_argument('--out',type=Path,required=True);x=a.parse_args();extract(x.pdf,x.out)
