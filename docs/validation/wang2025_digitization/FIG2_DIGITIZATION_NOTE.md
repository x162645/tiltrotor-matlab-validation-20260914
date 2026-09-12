# Wang et al. (2025) Figure 2 digitization note

`analysis/digitize_wang2025_fig2.py` extracts the visible dark-gray model trace,
red experiment markers, and blue literature trace from the published 3-by-3
panel image. It is a figure-level reconstruction; no original point arrays were
available. The panel rectangles are calibrated to the plotted axes, with a
12-pixel guard band against the frame and a 7-pixel guard band against the
vertical axes. Integer tick columns are omitted because they are black and can
otherwise be mistaken for a response trace.

The reported `pixel_uncertainty=2` is an image-reading uncertainty, not a
measurement uncertainty. Its native-unit equivalent is approximately
`2*(ymax-ymin)/(panel_height)` for each panel (about 0.5--1.1 native units in
these panels). The pointwise pairing uses the nearest extracted model sample in
time; it does not create additional experimental samples.

Some panels have no separable red experiment trace because it is hidden beneath
the model or the image compression. Those panels are intentionally absent from
the experiment rows in `FIG2_error_summary.csv`; they are not treated as zero
error. The blue trace is a literature frequency-response reference from the
paper, not a new synchronized flight record.

Outputs:

* `FIG2_digitized_points.csv` — extracted points with role and pixel uncertainty.
* `FIG2_error_summary.csv` — MAE/RMSE against each visible reference role.

Recompute from the repository root with:

```text
python analysis/digitize_wang2025_fig2.py
```

