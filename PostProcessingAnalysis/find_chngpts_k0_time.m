missionID = '26220301';
% SN        = missionID(6:8);
SN        = missionID(4:6);
fname     = fullfile("data", [missionID, '_esper.mat']);
reference_anomaly_method = 'depth';
load(fname);

% % --- Load calibration ---
% opts = detectImportOptions('data\ph_cal_locness_corrected.txt');
% opts = setvartype(opts, opts.VariableNames{1}, 'char');
% ph_cal = readtable('data\ph_cal_locness_corrected.txt', opts);
% ph_cal = ph_cal(ismember(ph_cal.Mission, missionID), :);
% Pcoefs = [ph_cal.fp_k1, ph_cal.fp_k2, ph_cal.fp_k3, ...
%           ph_cal.fp_k4, ph_cal.fp_k5, ph_cal.fp_k6]';
% --- Load calibration ---
opts = detectImportOptions("C:\Users\bwerb\Documents\GitHub\Spray2_Processing\parsing\ph_cal.csv");
% opts = setvartype(opts, opts.VariableNames{1}, 'char');
ph_cal = readtable("C:\Users\bwerb\Documents\GitHub\Spray2_Processing\parsing\ph_cal.csv", opts);
ph_cal = ph_cal(ph_cal.Mission == 203, :);
Pcoefs = [ph_cal.fp_k1, ph_cal.fp_k2, ph_cal.fp_k3, ...
          ph_cal.fp_k4, ph_cal.fp_k5, ph_cal.fp_k6]';
%% Reference surface settings
switch reference_anomaly_method
    case 'depth'
        level          = 450;
        levelTolerance = 5;
        ref_field      = 'depth';
        ref_label      = sprintf('Reference Depth %d +/- %d m', level, levelTolerance);
        ref_filetag    = sprintf('depth%d', level);
    case 'sigma'
        level          = 26.8182;
        levelTolerance = 0.01;
        ref_field      = 'sigma';
        ref_label      = sprintf('\\sigma_0 = %.2f \\pm %.2f kg/m^3', level, levelTolerance);
        ref_filetag    = sprintf('sig0_%.2f', level);
    otherwise
        error('Unknown reference_anomaly_method: %s', reference_anomaly_method)
end

ndive   = length(data.ESPER.ph);
profile = 1:ndive;

% --- Time axis: days since first dive, one value per profile ---
t_days    = (data.time(1:ndive, 1) - data.time(1, 1)) / 86400;
t_unix    = data.time(1:ndive, 1);
t_datenum = data.time(1:ndive, 1)/86400 + datenum(1970,1,1);
t_dt      = datetime(t_unix, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

% Pre-allocate
data.ESPER.referenceAnomalyTimeSeries   = NaN(1, ndive);
data.ph.phAtDepth                       = NaN(1, ndive);
data.ESPER.ph_correctedAtDepth          = NaN(1, ndive);
data.ESPER.k0                           = NaN(1, ndive);
data.ESPER.k0referenceAnomalyTimeSeries = NaN(1, ndive);
data.ph.ph_correctedAtDepth             = NaN(1, ndive);

%% Reference anomaly extraction
for i = 1:ndive
    iphase = data.ph.phase{i} == 0;
    if ~any(iphase), continue, end

    ref_vec           = data.ESPER.(ref_field){i}(iphase);
    [minDist, idepth] = min(abs(ref_vec - level));
    if minDist > levelTolerance, continue, end

    iphase_idx = find(iphase);
    target_idx = iphase_idx(idepth);

    data.ESPER.referenceAnomaly{i}    = data.ph.ph{i}(iphase) - data.ESPER.ph_corrected{i}(iphase);
    data.ph.phProfile{i}              = data.ph.ph{i}(iphase);
    data.ESPER.ph_correctedProfile{i} = data.ESPER.ph_corrected{i}(iphase);

    data.ph.phAtDepth(i)                       = data.ph.ph{i}(target_idx);
    data.ESPER.ph_correctedAtDepth(i)          = data.ESPER.ph_corrected{i}(target_idx);
    data.ESPER.referenceAnomalyTimeSeries(i)   = data.ESPER.referenceAnomaly{i}(idepth);
    data.ESPER.k0(i)                           = k0frompH_claude( ...
        data.ph.Vrse{i}(target_idx), data.ph.p{i}(target_idx), ...
        data.ESPER.t{i}(target_idx), data.ESPER.s{i}(target_idx), ...
        data.ESPER.ph_corrected{i}(target_idx), ph_cal.k2, Pcoefs);
    data.ESPER.k0referenceAnomalyTimeSeries(i) = ph_cal.k0 - data.ESPER.k0(i);
end

%% Output directory
outdir = fullfile("figures", "k0_correct");
if ~exist(outdir, 'dir'), mkdir(outdir); end

%% BIC-based optimal changepoint selection (x = time in days)
max_changepoints = 5;
bic_scores       = NaN(1, max_changepoints + 1);

y         = data.ESPER.k0referenceAnomalyTimeSeries(:);
valid     = ~isnan(y);
y_fit     = y(valid);
t_fit     = t_days(valid);       % time axis for valid obs [days since first dive]
t_fit_yr  = t_fit / 365.25;      % [years] for drift rate reporting
n         = length(y_fit);

errorLim = 0.0005;

for k = 0:max_changepoints
    if k == 0
        p        = polyfit(t_fit_yr, y_fit, 1);
        yhat     = polyval(p, t_fit_yr);
        n_params = 2;
    else
        [~, S1, S2] = ischange(y_fit, 'linear', 'MaxNumChanges', k);
        % ischange returns slope/intercept in index space — reconstruct fit
        % using sequence index, then evaluate residuals
        seq      = (1:n)';
        S1_full  = fillmissing(S1, 'nearest');
        S2_full  = fillmissing(S2, 'nearest');
        yhat     = S1_full .* seq + S2_full;
        n_params = 2 * (k + 1);
    end
    rss               = sum((y_fit - yhat).^2);
    bic_scores(k + 1) = n * log(rss/n + errorLim^2) + n_params * log(n);
end

[~, best_idx]    = min(bic_scores);
BIC_changepoints = best_idx - 1;
fprintf('BIC scores (k=0 to %d): %s\n', max_changepoints, num2str(bic_scores, '%.2f  '));
fprintf('Optimal changepoints:   %d\n', BIC_changepoints);

% BIC figure
fig_bic = figure('Visible', 'off');
plot(0:max_changepoints, bic_scores, 'ko-', 'LineWidth', 1.5, 'MarkerFaceColor', 'k');
xline(BIC_changepoints, 'r--', sprintf('k=%d (optimal)', BIC_changepoints), LabelVerticalAlignment='bottom');
grid on; xlabel('Number of changepoints'); ylabel('BIC')
title(sprintf('BIC model selection — SN%s', SN))
set(fig_bic, 'Units', 'inches', 'Position', [0 0 6 4]);
figname_bic = fullfile(outdir, sprintf('SN%s_BIC_selection_%s.png', SN, ref_filetag));
exportgraphics(fig_bic, figname_bic, 'Resolution', 300);
close(fig_bic);
fprintf('Saved: %s\n', figname_bic);

%% Drift fit in TIME space with optimal BIC changepoints
% Changepoints detected on valid-obs sequence, mapped back to profile indices
valid_idx = find(valid);   % maps sequence position → profile index

if BIC_changepoints == 0
    % Single linear segment fit in years
    p          = polyfit(t_fit_yr, y_fit, 1);
    TF         = false(n, 1);
    cp_seq     = [];
else
    [TF, ~, ~] = ischange(y_fit, 'linear', 'MaxNumChanges', BIC_changepoints);
    cp_seq     = find(TF)';   % changepoint positions in valid-obs sequence
end

% Map sequence changepoints → profile indices → times
cp_prof = valid_idx(cp_seq);          % profile index of each changepoint
cp_t    = t_dt(cp_prof);              % datetime of each changepoint

% Build segment boundaries in profile index space
seg_bounds = [1; cp_prof(:); ndive];
n_segs     = numel(seg_bounds) - 1;

% Fit correction in time (years) per segment, evaluate at every profile
linfit     = NaN(ndive, 1);
seg_params = struct('node', {}, 'drift_per_yr', {}, 'offset', {});

for s = 1:n_segs
    si   = seg_bounds(s);
    ei   = seg_bounds(s + 1);
    seg  = si:ei;
    use  = seg(valid(seg));              % profiles in segment with valid data

    t_node = t_days(si);                % segment reference time [days]
    dt_yr  = (t_days(use) - t_node) / 365.25;

    if numel(use) < 2
        off    = mean(y(use), 'omitnan');
        drift  = 0;
    else
        p      = polyfit(dt_yr, y(use), 1);
        drift  = p(1);
        off    = p(2);
    end

    seg_params(s).node        = si;
    seg_params(s).drift_per_yr = drift;
    seg_params(s).offset      = off;

    % Evaluate correction at every profile in this segment
    linfit(seg) = off + drift .* ((t_days(seg) - t_node) / 365.25);
end

% Fill any edge NaNs (profiles outside valid segment range)
linfit = fillmissing(linfit, 'nearest');

fprintf('\nSegment drift parameters:\n');
fprintf('  %6s  %+12s  %+12s\n', 'node', 'offset', 'drift(pH/yr)');
for s = 1:n_segs
    fprintf('  %6d  %+12.5f  %+12.5f\n', ...
        seg_params(s).node, seg_params(s).offset, seg_params(s).drift_per_yr);
end

data.ESPER.k0_corrected        = ph_cal.k0 - linfit(:)';
data.ESPER.k0anomaly_corrected = data.ESPER.k0 - linfit(:)';

%% Recompute pH with corrected k0
data.ph.ph_corrected = cell(size(data.ph.ph));
for n = 1:ndive
    if ~isempty(data.ph.Vrse{n})
        [~, iuse] = unique(data.ctd.time{n});
        if length(iuse) > 1
            ss = interp1(data.ctd.time{n}(iuse), data.ctd.s{n}(iuse), data.ph.time{n}, 'linear', 'extrap');
            tt = interp1(data.ctd.time{n}(iuse), data.ctd.t{n}(iuse), data.ph.time{n}, 'linear', 'extrap');
            [~, data.ph.ph_corrected{n}] = phcalc_jp(data.ph.Vrse{n}, data.ph.p{n}, tt, ss, ...
                data.ESPER.k0_corrected(n), ph_cal.k2, Pcoefs);
        else
            data.ph.ph_corrected{n} = NaN(size(data.ph.Vrse{n}));
        end
    end
end

%% Extract corrected pH at reference surface
data.ph.ph_correctedAtDepth = NaN(1, ndive);
for i = 1:ndive
    iphase = data.ph.phase{i} == 0;
    if ~any(iphase), continue, end

    ref_vec           = data.ESPER.(ref_field){i}(iphase);
    [minDist, idepth] = min(abs(ref_vec - level));
    if minDist > levelTolerance, continue, end

    iphase_idx = find(iphase);
    target_idx = iphase_idx(idepth);
    data.ph.ph_correctedAtDepth(i) = data.ph.ph_corrected{i}(target_idx);
end

rms_val = rms(data.ph.ph_correctedAtDepth - data.ESPER.ph_correctedAtDepth, 'omitnan');

data.ph.BIC = {'chngpnts', BIC_changepoints; 'Ref Method', reference_anomaly_method; ...
               'Ref Level', level; 'Tolerance', levelTolerance};

%% Fixed y-axis limits
ylim_ph_raw   = [min([data.ph.phAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') - 0.01, ...
                 max([data.ph.phAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') + 0.01];
k0_range      = data.ESPER.k0referenceAnomalyTimeSeries(~isnan(data.ESPER.k0referenceAnomalyTimeSeries));
pad           = 0.1 * range(k0_range);
ylim_k0       = [min(k0_range) - pad, max(k0_range) + pad];
ylim_residual = [-0.02, 0.02];

%% QC Figure — x-axis is datetime
fig = figure('Visible', 'off');
tl  = tiledlayout(2, 2);
title(tl,    sprintf('pH Correction SN%s', SN))
subtitle(tl, sprintf('BGC-ARGO Protocol | %s | BIC: %d changepoint(s) | RMS: %.4f', ...
         ref_label, BIC_changepoints, rms_val))

ax1 = nexttile(tl, 1);
plot(t_dt, data.ph.phAtDepth,              'o'); hold on
plot(t_dt, data.ESPER.ph_correctedAtDepth, 'o')
for k = 1:numel(cp_t), xline(cp_t(k), 'k--', 'HandleVisibility', 'off'); end
ylim(ylim_ph_raw); grid on
title('Measured vs ESPER Reference')
ylabel('pH_{total}'); xlabel('Date')
legend('pH_{meas}', 'pH_{ESPER}', Location='best')

ax2 = nexttile(tl, 2);
plot(t_dt, data.ESPER.k0referenceAnomalyTimeSeries, 'ko'); hold on
plot(t_dt, linfit, 'r-', 'LineWidth', 2)
for k = 1:numel(cp_t), xline(cp_t(k), 'k--'); end
if ~isempty(cp_t)
    legend('k0 Anom', 'Drift Fit', 'Change Points', Location='best')
else
    legend('k0 Anom', 'Drift Fit', Location='best')
end
ylim(ylim_k0); grid on
title('k0 Reference Anomaly')
ylabel('\Deltak_0 (lab - ESPER)'); xlabel('Date')

ax3 = nexttile(tl, 3);
plot(t_dt, data.ph.ph_correctedAtDepth,    'o'); hold on
plot(t_dt, data.ESPER.ph_correctedAtDepth, 'o')
for k = 1:numel(cp_t), xline(cp_t(k), 'k--', 'HandleVisibility', 'off'); end
ylim(ylim_ph_raw); grid on
title('Corrected pH vs ESPER Reference')
ylabel('pH_{total}'); xlabel('Date')
legend('pH_{meas}', 'pH_{ESPER}', Location='best')

ax4 = nexttile(tl, 4);
plot(t_dt, data.ph.ph_correctedAtDepth - data.ESPER.ph_correctedAtDepth, 'ko'); hold on
yline(-0.01, 'r--'); yline(0.01, 'r--'); yline(0, 'k', LineStyle=':')
for k = 1:numel(cp_t), xline(cp_t(k), 'k--', 'HandleVisibility', 'off'); end
ylim(ylim_residual); grid on
title('Post-Correction Residuals')
ylabel('\DeltapH (Corrected - ESPER)'); xlabel('Date')

linkaxes([ax1 ax2 ax3 ax4], 'x')
% Lock x-axis to April–May
% xlim([datetime(2026,4,1,TimeZone="UTC") datetime(2026,5,1,TimeZone="UTC")])

figname = fullfile(outdir, sprintf('SN%s_BIC%d_%s_k0_pH_Correction.png', SN, BIC_changepoints, ref_filetag));
set(fig, 'Units', 'inches', 'Position', [0 0 11 8.5]);
exportgraphics(fig, figname, 'Resolution', 300);
close(fig);
fprintf('Saved: %s\n', figname);