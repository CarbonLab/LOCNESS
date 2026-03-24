% pH lag from Robert's code
%
%
load /Users/straylor/Library/CloudStorage/GoogleDrive-straylor@mbari.org/'Shared drives'/NOPPmCDR/locness_data/spray/tmp_20260323/2507020902.mat ;
dataOrig = data ;
%%
path_to_ph_cal_csv = '/Users/straylor/Library/CloudStorage/GoogleDrive-straylor@mbari.org/My Drive/LOCNESS/data/ph_cal_locness_corrected.csv';
lag_in_seconds = 14;
data = ph_sp2(data, '2507020902', 'user_name', 'phcalfile', path_to_ph_cal_csv, 'dt', lag_in_seconds);
%%
% --- Side figure: dive (phase=1) vs ascent (phase=0) pH difference ---
i = 73;

% ---- Lag-corrected data ----
ph_all    = data.ph.ph{i}(:);
depth_all = data.ph.depth{i}(:);
phase_all = data.ph.phase{i}(:);

ph_dive = ph_all(phase_all == 1);
dep_dive = depth_all(phase_all == 1);
ph_asc  = ph_all(phase_all == 0);
dep_asc = depth_all(phase_all == 0);

valid_dive = isfinite(dep_dive) & isfinite(ph_dive);
valid_asc  = isfinite(dep_asc)  & isfinite(ph_asc);
dep_dive = dep_dive(valid_dive);  ph_dive = ph_dive(valid_dive);
dep_asc  = dep_asc(valid_asc);   ph_asc  = ph_asc(valid_asc);

[dep_dive, si] = sort(dep_dive);  ph_dive = ph_dive(si);
[dep_asc,  si] = sort(dep_asc);   ph_asc  = ph_asc(si);

dep_common = linspace(max([min(dep_dive), min(dep_asc)]), ...
                      min([max(dep_dive), max(dep_asc)]), 200)';
ph_dive_interp = interp1(dep_dive, ph_dive, dep_common, 'linear', NaN);
ph_asc_interp  = interp1(dep_asc,  ph_asc,  dep_common, 'linear', NaN);
ph_diff = ph_dive_interp - ph_asc_interp;

% ---- Original (uncorrected) data ----
ph_all_orig    = dataOrig.ph.ph{i}(:);
depth_all_orig = dataOrig.ph.depth{i}(:);
phase_all_orig = dataOrig.ph.phase{i}(:);

ph_dive_orig = ph_all_orig(phase_all_orig == 1);
dep_dive_orig = depth_all_orig(phase_all_orig == 1);
ph_asc_orig  = ph_all_orig(phase_all_orig == 0);
dep_asc_orig = depth_all_orig(phase_all_orig == 0);

valid_dive_orig = isfinite(dep_dive_orig) & isfinite(ph_dive_orig);
valid_asc_orig  = isfinite(dep_asc_orig)  & isfinite(ph_asc_orig);
dep_dive_orig = dep_dive_orig(valid_dive_orig);  ph_dive_orig = ph_dive_orig(valid_dive_orig);
dep_asc_orig  = dep_asc_orig(valid_asc_orig);    ph_asc_orig  = ph_asc_orig(valid_asc_orig);

[dep_dive_orig, si] = sort(dep_dive_orig);  ph_dive_orig = ph_dive_orig(si);
[dep_asc_orig,  si] = sort(dep_asc_orig);   ph_asc_orig  = ph_asc_orig(si);

dep_common_orig = linspace(max([min(dep_dive_orig), min(dep_asc_orig)]), ...
                           min([max(dep_dive_orig), max(dep_asc_orig)]), 200)';
ph_dive_interp_orig = interp1(dep_dive_orig, ph_dive_orig, dep_common_orig, 'linear', NaN);
ph_asc_interp_orig  = interp1(dep_asc_orig,  ph_asc_orig,  dep_common_orig, 'linear', NaN);
ph_diff_orig = ph_dive_interp_orig - ph_asc_interp_orig;

%%
figure(46); clf
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Left panel: dive and ascent profiles overlaid
ax1 = nexttile;
plot(dataOrig.ph.ph{i}(:), dataOrig.ph.depth{i}(:), '.', 'Color', [0.7 0.7 0.7], 'DisplayName', 'Original'); hold on
plot(ph_dive, dep_dive, 'b.', 'DisplayName', 'Dive (phase=1)');
plot(ph_asc,  dep_asc,  'r.', 'DisplayName', 'Ascent (phase=0)');
axis ij
xlabel('pH'); ylabel('Depth [m]');
title(sprintf('Dive %d — pH profiles', i));
legend('Location', 'best');
grid on

% Right panel: dive minus ascent difference
ax2 = nexttile;
plot(ph_diff_orig, dep_common_orig, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5, 'DisplayName', 'Original'); hold on
plot(ph_diff,      dep_common,      'k-', 'LineWidth', 1.5, 'DisplayName', sprintf('Lag = %ds', lag_in_seconds));
xline(0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'HandleVisibility', 'off');
axis ij
xlabel('\DeltapH (dive - ascent)'); ylabel('Depth [m]');
title(sprintf('Dive %d — pH hysteresis', i));
legend('Location', 'best');
grid on

linkaxes([ax1 ax2], 'y');