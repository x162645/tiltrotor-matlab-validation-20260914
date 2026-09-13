"""Compare actual V7 speed solves to Wang 2025 Figure 1(a), not to own interpolants.

The full-scale figure retains the paper's four rows and axis limits. Native
control pitch is not silently shifted into an unverified paper pitch datum.
Only visible literature/flight markers enter marker-level scores. Black
paper pixels describe a curve; they never count as independent experiments.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager


LABELS = ['总距 / (°)', '纵向杆位 / %', '俯仰角 / (°)', '旋翼需用功率 / kW']
LIMITS = [(30, 60), (0, 100), (-40, 40), (0, 2500)]
FIELDS = ['geometricRootPitch_deg', 'stick_pct', 'theta_deg', 'totalRotorPower_kW']
ROLES = {'blue_literature': '论文引文[26]数值参考', 'red_flight': '论文所示试飞点'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def twist(x):
    # Exactly the existing analysis/nasa_metal_twist_deg.m polynomial.
    return 289.98*x**5 - 892.87*x**4 + 987.06*x**3 - 438.31*x**2 + 15.695*x + 32.057


def model_at(points, field, x):
    """Linear interpolation between adjacent accepted solved speeds; no gap filling."""
    xx = points.speed_mps.to_numpy()
    yy = points[field].to_numpy()
    ok = points.numericallyAccepted.to_numpy(dtype=bool)
    i = int(np.searchsorted(xx, x))
    if i < len(xx) and abs(xx[i]-x) < 1e-10 and ok[i]:
        return float(yy[i]), 'ACTUAL_SOLVED_SPEED', i, i
    if i == 0 or i == len(xx) or not (ok[i-1] and ok[i]):
        return np.nan, 'NO_ACCEPTED_BRACKET', -1, -1
    if xx[i]-xx[i-1] > 5.01*0.514444:
        return np.nan, 'UNSOLVED_SPEED_GAP', -1, -1
    y = yy[i-1] + (yy[i]-yy[i-1])*(x-xx[i-1])/(xx[i]-xx[i-1])
    return float(y), 'LINEAR_INTERPOLATION_OF_ADJACENT_SOLVES', i-1, i


def paper_trace(ax, rows, color='#333333'):
    rows = rows.sort_values('x_value')
    x = rows.x_value.to_numpy()
    y = rows.y_value.to_numpy()
    if 'segment_id' in rows:
        breaks = np.flatnonzero(np.diff(rows.segment_id.to_numpy()) != 0) + 1
    else:
        breaks = np.flatnonzero(np.diff(x) > .2) + 1
    for k, ids in enumerate(np.split(np.arange(len(x)), breaks)):
        ax.plot(x[ids], y[ids], color=color, lw=1.7,
                label='王梓旭模型曲线（读图）' if k == 0 else None, zorder=2)


def paper_at(trace, row, x):
    """Read/interpolate the displayed paper curve; short marker occlusions only."""
    t = trace[trace.row == row].sort_values('x_value')
    xx, yy = t.x_value.to_numpy(), t.y_value.to_numpy()
    i = int(np.searchsorted(xx, x))
    if i < len(xx) and abs(xx[i]-x) < 1e-10:
        return float(yy[i]), 'VISIBLE_PAPER_CURVE_PIXEL'
    if i == 0 or i == len(xx) or xx[i]-xx[i-1] > 2.5:
        return np.nan, 'NO_PAPER_CURVE_BRACKET'
    value = yy[i-1]+(yy[i]-yy[i-1])*(x-xx[i-1])/(xx[i]-xx[i-1])
    return float(value), 'PAPER_CURVE_LINEAR_READOUT_MAX_GAP_2P5_MPS'


def draw_panel(ax, row, points, markers, traces, exact_limits):
    ax.axvspan(0, 40*.514444, color='#f2f3f4', zorder=0)
    ax.axvspan(100*.514444, 60, color='#f2f3f4', zorder=0)
    paper_trace(ax, traces[traces.row == row])
    for role, col, marker in [('blue_literature', '#315d9e', 's'), ('red_flight', '#d9363e', 'o')]:
        r = markers[(markers.row == row) & (markers.series == role)]
        ax.scatter(r.x_value, r.y_value, s=32, marker=marker, c=col,
                   label=ROLES[role], zorder=4)
    values = points[FIELDS[row]].where(points.numericallyAccepted.astype(bool))
    ax.plot(points.speed_mps, values, color='#008060', lw=1.8,
            ls='--' if row == 0 else '-', marker='.', ms=5,
            label='本模型几何根距（零点待核）' if row == 0 else '本模型加密计算', zorder=5)
    bad = points[(points.attemptCount > 0) & (~points.numericallyAccepted.astype(bool))]
    if len(bad):
        ax.scatter(bad.speed_mps, np.full(len(bad), .035), transform=ax.get_xaxis_transform(),
                   color='#b34b19', marker='x', s=32, label='该速度配平未通过', zorder=6)
    skipped = points[points.attemptCount == 0]
    if len(skipped):
        ax.scatter(skipped.speed_mps, np.full(len(skipped), .035), transform=ax.get_xaxis_transform(),
                   facecolors='none', edgecolors='#666666', marker='o', s=24,
                   label='接口域外／未求解', zorder=6, clip_on=False)
    ax.set_ylabel(LABELS[row])
    ax.set_xlabel('速度 V / (m/s)')
    ax.set_xlim(0, 60)
    ax.set_xticks(np.arange(0, 61, 10))
    if exact_limits:
        ax.set_ylim(*LIMITS[row])
        steps = [10, 20, 20, 500]
        ax.set_yticks(np.arange(LIMITS[row][0], LIMITS[row][1]+.01, steps[row]))
    ax.tick_params(direction='in', length=5)
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
    if row == 0:
        ax.text(.03, .07, '虚线：本模型 r/R=0.0875 处桨距\n论文总距基准未闭合，不计绝对误差',
                transform=ax.transAxes, fontsize=8, color='#00664d',
                bbox=dict(facecolor='white', alpha=.88, edgecolor='none', pad=1))
    if row == 1:
        ax.text(.03, .07, '本模型按 100×杆位(in)/9.6 换算；论文零点待确认',
                transform=ax.transAxes, fontsize=7.5, color='#444444',
                bbox=dict(facecolor='white', alpha=.88, edgecolor='none', pad=1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    out = args.out
    calc = out/'calculation'/'V7_SPEED_SWEEP_POINTS.csv'
    reference = out/'reference'
    markerfile = reference/'FIG1a_markers_v2.csv'
    tracefile = reference/'FIG1a_model_trace_v2.csv'
    points = pd.read_csv(calc).sort_values('speed_kt').reset_index(drop=True)
    markers, traces = pd.read_csv(markerfile), pd.read_csv(tracefile)
    assert len(points.speed_kt.unique()) == len(points), 'Repeated speed rows'
    assert set(markers.series) <= set(ROLES), 'Unexpected evidence role'
    fontfile = Path('C:/Windows/Fonts/msyh.ttc')
    assert fontfile.exists(), 'Chinese font missing'
    font_manager.fontManager.addfont(str(fontfile))
    font = font_manager.FontProperties(fname=str(fontfile)).get_name()
    plt.rcParams.update({'font.family': font, 'axes.unicode_minus': False,
                         'font.size': 10, 'svg.fonttype': 'path', 'savefig.dpi': 220})
    root_offset = twist(.0875)-twist(.75)
    points['geometricRootPitch_deg'] = points.theta75Deg + root_offset
    points.to_csv(out/'加密计算_绘图数据.csv', index=False, encoding='utf-8-sig')
    accepted = points[points.numericallyAccepted.astype(bool)]

    fig, axes = plt.subplots(4, 1, figsize=(6.2, 13.3))
    for row, ax in enumerate(axes):
        draw_panel(ax, row, points, markers, traces, True)
    fig.suptitle('与王梓旭论文图 1(a) 对照：短舱角 90°', fontsize=13, y=.993)
    handles, labels = axes[1].get_legend_handles_labels()
    fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(.53,.975),
               ncol=2, fontsize=9, frameon=False)
    fig.text(.52, .012, '沿用论文四行顺序、坐标范围与单位；每个绿色点均来自实际配平。\n'
             '灰区：零浸入设置超出 40–100 kt 已核实范围；试飞点为读图数据。',
             ha='center', fontsize=8.6)
    fig.subplots_adjust(left=.18, right=.965, top=.918, bottom=.075, hspace=.47)
    for ext in ['png', 'svg']:
        fig.savefig(out/f'王梓旭图1a_同坐标_加密对比.{ext}', facecolor='white')
    svg = out/'王梓旭图1a_同坐标_加密对比.svg'
    svg.write_text('\n'.join(line.rstrip() for line in svg.read_text(encoding='utf-8').splitlines())+'\n',
                   encoding='utf-8')
    plt.close(fig)

    fig, axes = plt.subplots(2, 2, figsize=(12, 8.4))
    for row, ax in enumerate(axes.flat):
        draw_panel(ax, row, points, markers, traces, False)
        ax.grid(alpha=.18)
    fig.suptitle('加密曲线局部量程：用于看清差异（纵轴与原图不同）', y=.995, fontsize=13)
    handles, labels = axes[0,1].get_legend_handles_labels()
    fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(.5,.965), ncol=4,
               frameon=False, fontsize=9)
    fig.subplots_adjust(left=.09, right=.985, top=.89, bottom=.075, wspace=.23, hspace=.38)
    fig.savefig(out/'加密对比_局部量程.png', facecolor='white')
    plt.close(fig)

    pairs = []
    # Exclude theta0 before looking at errors: its paper datum remains undefined.
    for _, source in markers[markers.row > 0].iterrows():
        field = FIELDS[int(source.row)]
        value, method, ilo, ihi = model_at(points, field, source.x_value)
        paper_value, paper_method = paper_at(traces, source.row, source.x_value)
        rec = dict(variable=source.variable, reference_role=source.series,
                   speed_scope='CORE_40_TO_100KT' if 40*.514444 <= source.x_value <= 100*.514444 else
                   'EXTRAPOLATED_ZERO_IMMERSION_CONFIGURATION',
                   comparison_contract='CONDITIONAL_STICK_FULL_STROKE_MAPPING' if source.row == 1 else
                   'PUBLISHED_CHART_CORRELATION_CASE_PARAMETERS_NOT_FULLY_MATCHED',
                   speed_mps=source.x_value, reference_value=source.y_value,
                   calculated_value=value, difference=value-source.y_value,
                   wang_curve_value=paper_value, wang_curve_difference=paper_value-source.y_value,
                   wang_curve_readout=paper_method,
                   model_sampling_method=method, y_reading_bound=source.y_uncertainty,
                   x_reading_bound_mps=source.x_uncertainty,
                   low_bracket_speed_kt=points.speed_kt.iloc[ilo] if ilo >= 0 else np.nan,
                   high_bracket_speed_kt=points.speed_kt.iloc[ihi] if ihi >= 0 else np.nan)
        # A sensitivity estimate to the *source reading* range, not a confidence interval.
        if ilo >= 0 and ihi != ilo:
            slope = abs((points[field].iloc[ihi]-points[field].iloc[ilo]) /
                        (points.speed_mps.iloc[ihi]-points.speed_mps.iloc[ilo]))
            rec['combined_reading_sensitivity'] = source.y_uncertainty+slope*source.x_uncertainty
        else:
            rec['combined_reading_sensitivity'] = source.y_uncertainty
        pairs.append(rec)
    paired = pd.DataFrame(pairs)
    paired.to_csv(out/'论文图示点_逐点对照.csv', index=False, encoding='utf-8-sig')
    summaries = []
    for (var, role, scope), g in paired.groupby(['variable', 'reference_role', 'speed_scope']):
        valid = g[np.isfinite(g.difference)]
        summaries.append(dict(variable=var, reference_role=role, speed_scope=scope, visible_marker_count=len(g),
            comparison_contract=g.comparison_contract.iloc[0],
            paired_marker_count=len(valid), MAE=float(valid.difference.abs().mean()),
            RMSE=float(np.sqrt((valid.difference**2).mean())),
            signed_mean_difference=float(valid.difference.mean()),
            max_absolute_difference=float(valid.difference.abs().max())))
    score = pd.DataFrame(summaries)
    score.to_csv(out/'论文图示点_误差汇总.csv', index=False, encoding='utf-8-sig')
    common = paired[np.isfinite(paired.difference) & np.isfinite(paired.wang_curve_difference)]
    head_to_head = []
    for (var, role, scope), g in common.groupby(['variable', 'reference_role', 'speed_scope']):
        head_to_head.append(dict(variable=var, reference_role=role, speed_scope=scope,
            common_visible_marker_count=len(g), comparison_contract=g.comparison_contract.iloc[0],
            our_MAE=float(g.difference.abs().mean()), wang_graph_MAE=float(g.wang_curve_difference.abs().mean()),
            qualification='SAME_VISIBLE_CHART_MARKERS_NOT_SAME_RAW_FLIGHT_RECORD_OR_PARAMETERS'))
    pd.DataFrame(head_to_head).to_csv(out/'同一图示点_本模型与论文模型.csv', index=False, encoding='utf-8-sig')
    minima = []
    for variable, field, row in [('power', 'totalRotorPower_kW', 3), ('stick', 'stick_pct', 1),
                                 ('geometric_root_pitch', 'geometricRootPitch_deg', 0)]:
        idx = accepted[field].idxmin()
        g = traces[traces.row == row]
        minimum = g.y_value.min()
        # A flat minimum covers several pixels; show its speed span, not false precision.
        reading_bound = float(g.y_uncertainty.max())
        near = g[g.y_value <= minimum + reading_bound]
        minima.append(dict(variable=variable, model_min_speed_mps=float(points.speed_mps.loc[idx]),
            minimum_identity='MINIMUM_AMONG_ACCEPTED_SOLVED_GRID_POINTS_NOT_CONTINUOUS_OPTIMUM',
            accepted_domain_mps=[float(accepted.speed_mps.min()), float(accepted.speed_mps.max())],
            nominal_grid_step_mps=5*.514444,
            failed_or_skipped_speeds_kt=points.speed_kt[~points.numericallyAccepted.astype(bool)].tolist(),
            paper_near_min_reading_bound=reading_bound,
            model_min_value=float(points[field].loc[idx]) if row != 0 else None,
            paper_curve_min=float(minimum) if row != 0 else None,
            value_comparison='NOT_COMPARED_PITCH_DATUM_UNRESOLVED' if row == 0 else 'CHART_CORRELATION',
            paper_min_speed_low=float(near.x_value.min()), paper_min_speed_high=float(near.x_value.max())))
    (out/'趋势特征.json').write_text(json.dumps(minima, ensure_ascii=False, indent=2), encoding='utf-8')

    config = dict(source_files={str(p.relative_to(out)): sha(p) for p in [calc, markerfile, tracefile]},
        source_figure='Wang et al. 2025 Figure 1(a)', configuration='nacelle90_V7_ZERO_IMMERSED',
        font=font, plotting_script_sha256=sha(Path(__file__)),
        exact_axis_limits=LIMITS, x_axis_limits_mps=[0,60],
        speed_conversion='V_mps = V_kt * 0.514444', stick_conversion='percent = 100 * stick_in / 9.6',
        stick_qualification='source-based full-stroke convention; exact Wang control implementation not independently recovered',
        power_definition='sum(left shaft torque*Omega + right shaft torque*Omega)/1000; no engine losses',
        displayed_pitch='theta75 + sourceTwist(0.0875) - sourceTwist(0.75)',
        displayed_pitch_offset_deg=root_offset, pitch_abs_error_scored=False,
        pitch_reason='paper theta0 radial station/datum not explicitly recovered; no fitted offset',
        reference_interpolation='only adjacent accepted actual solves; no extrapolation or failed-gap filling',
        secondary_comparison='both models against same visible markers; Wang curve readout permits marker gaps <=2.5m/s, not raw author arrays',
        physical_model_retuned=False, actual_model_points=int((points.attemptCount>0).sum()),
        zero_immersion_evidence_speed_range_kt=[40,100],
        outside_that_range='unchanged configuration extrapolation for diagnosis, not source-verified wake coverage',
        accepted_points=len(accepted), skipped_points=int((points.attemptCount==0).sum()))
    (out/'绘图与评分定义.json').write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')
    print(score.to_string(index=False))
    print(json.dumps(minima, ensure_ascii=False))
    print('PLOT_DONE', len(accepted), 'accepted actual trim points')


if __name__ == '__main__':
    main()
