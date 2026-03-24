missionID = '2507020902';
SN        = missionID(6:8); % Spray glider SN
fname     = fullfile("data", [missionID, '_esper.mat']);
load(fname);

% --- Load calibration ---
opts = detectImportOptions('data\ph_cal_locness_corrected.txt');
opts = setvartype(opts, opts.VariableNames{1}, 'char');
ph_cal = readtable('data\ph_cal_locness_corrected.txt', opts);
ph_cal = ph_cal(ismember(ph_cal.Mission, missionID), :);
Pcoefs = [ph_cal.fp_k1, ph_cal.fp_k2, ph_cal.fp_k3, ...
          ph_cal.fp_k4, ph_cal.fp_k5, ph_cal.fp_k6]';

%% Compute reference anomaly at depth
depth          = 270;
depthTolerance = 5;
ndive          = length(data.ESPER.ph);
profile        = 1:ndive;

% Pre-allocate
data.ESPER.referenceAnomalyTimeSeries   = NaN(1, ndive);
data.ph.phAtDepth                       = NaN(1, ndive);
data.ESPER.ph_correctedAtDepth          = NaN(1, ndive);
data.ESPER.k0                           = NaN(1, ndive);
data.ESPER.k0referenceAnomalyTimeSeries = NaN(1, ndive);
data.ph.ph_correctedAtDepth             = NaN(1, ndive);

for i = 1:ndive
    iphase = data.ph.phase{i} == 0;
    [minDist, idepth] = min(abs(data.ESPER.depth{i}(iphase) - depth));
    if minDist > depthTolerance, continue, end

    iphase_idx = find(iphase);
    target_idx = iphase_idx(idepth);

    % Full phase==0 profiles
    data.ESPER.referenceAnomaly{i}    = data.ph.ph{i}(iphase) - data.ESPER.ph_corrected{i}(iphase);
    data.ph.phProfile{i}              = data.ph.ph{i}(iphase);
    data.ESPER.ph_correctedProfile{i} = data.ESPER.ph_corrected{i}(iphase);

    % Scalar at target depth
    data.ph.phAtDepth(i)                     = data.ph.ph{i}(target_idx);
    data.ESPER.ph_correctedAtDepth(i)        = data.ESPER.ph_corrected{i}(target_idx);
    data.ESPER.referenceAnomalyTimeSeries(i) = data.ESPER.referenceAnomaly{i}(idepth);
    data.ESPER.k0(i)                         = k0frompH_claude( ...
        data.ph.Vrse{i}(target_idx), data.ph.p{i}(target_idx), ...
        data.ESPER.t{i}(target_idx), data.ESPER.s{i}(target_idx), ...
        data.ESPER.ph_corrected{i}(target_idx), ph_cal.k2, Pcoefs);
    data.ESPER.k0referenceAnomalyTimeSeries(i) = ph_cal.k0 - data.ESPER.k0(i);
end

%% Compute fixed y-axis limits once from the raw data (consistent across BIC)
ylim_ph_raw  = [min([data.ph.phAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') - 0.01, ...
                max([data.ph.phAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') + 0.01];
ylim_k0      = [-0.005, 0.005];
ylim_residual= [-0.02,  0.02];
% ph_corrected tile will share ylim_ph_raw (set after correction loop)

%% Output directory
outdir = fullfile("figures", "k0_correct");
if ~exist(outdir, 'dir'), mkdir(outdir); end

%% Loop over BIC changepoints 0-2
for BIC_changepoints = 0:2

    % --- Drift fit ---
    if BIC_changepoints == 0
        valid  = ~isnan(data.ESPER.k0referenceAnomalyTimeSeries);
        p      = polyfit(profile(valid), data.ESPER.k0referenceAnomalyTimeSeries(valid), 1);
        linfit = polyval(p, profile);
        TF     = false(size(profile));
    else
        [TF, S1, S2] = ischange(data.ESPER.k0referenceAnomalyTimeSeries, 'linear', 'MaxNumChanges', BIC_changepoints);
        S1_full      = fillmissing(S1, 'nearest');
        S2_full      = fillmissing(S2, 'nearest');
        linfit       = S1_full .* profile + S2_full;
    end

    data.ESPER.k0_corrected        = ph_cal.k0 - linfit;
    data.ESPER.k0anomaly_corrected = data.ESPER.k0 - linfit;

    % --- Recompute pH with corrected k0 ---
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

    % --- Extract corrected pH at depth ---
    data.ph.ph_correctedAtDepth = NaN(1, ndive);
    for i = 1:ndive
        iphase = data.ph.phase{i} == 0;
        [minDist, idepth] = min(abs(data.ESPER.depth{i}(iphase) - depth));
        if minDist > depthTolerance, continue, end
        iphase_idx = find(iphase);
        target_idx = iphase_idx(idepth);
        data.ph.ph_correctedAtDepth(i) = data.ph.ph_corrected{i}(target_idx);
    end

    rms_val = rms(data.ph.ph_correctedAtDepth - data.ESPER.ph_correctedAtDepth, 'omitnan');

    % Corrected pH y-limits (computed per BIC since correction changes)
    ylim_ph_corr = [min([data.ph.ph_correctedAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') - 0.005, ...
                    max([data.ph.ph_correctedAtDepth, data.ESPER.ph_correctedAtDepth], [], 'omitnan') + 0.005];

    %% Figure
    fig = figure('Visible', 'off');
    tl  = tiledlayout(2, 2);
    title(tl,    sprintf('pH Correction SN%s', SN))
    subtitle(tl, sprintf('BGC-ARGO Protocol | Reference Depth %d +/- %dm | BIC: %d changepoint(s) | RMS: %.4f', ...
             depth, depthTolerance, BIC_changepoints, rms_val))

    ax1 = nexttile(tl, 1);
    plot(profile, data.ph.phAtDepth,          'o'); hold on
    plot(profile, data.ESPER.ph_correctedAtDepth, 'o')
    ylim(ylim_ph_raw); grid on
    title('Measured vs ESPER Reference')
    ylabel('pH_{total}')
    legend('pH_{meas}', 'pH_{ESPER}', Location='southeast')

    ax2 = nexttile(tl, 2);
    plot(profile, data.ESPER.k0referenceAnomalyTimeSeries, 'ko'); hold on
    plot(profile, linfit, 'r-', 'LineWidth', 2)
    if any(TF)
        xline(profile(TF))
        legend('k0 Anom', 'Drift Fit', 'Change Points', Location='northeast')
    else
        legend('k0 Anom', 'Drift Fit', Location='northeast')
    end
    ylim(ylim_k0); yticks(-0.005:0.001:0.005); grid on
    title('k0 Reference Anomaly')
    ylabel('\Deltak_0 (lab - ESPER)')

    ax3 = nexttile(tl, 3);
    plot(profile, data.ph.ph_correctedAtDepth,    'o'); hold on
    plot(profile, data.ESPER.ph_correctedAtDepth, 'o')
    % ylim(ylim_ph_corr); grid on
    % yticks(linspace(ylim_ph_corr))
    ylim(ylim_ph_raw); grid on
    title('Corrected pH vs ESPER Reference')
    ylabel('pH_{total}')
    legend('pH_{meas}', 'pH_{ESPER}', Location='southeast')

    ax4 = nexttile(tl, 4);
    plot(profile, data.ph.ph_correctedAtDepth - data.ESPER.ph_correctedAtDepth, 'ko'); hold on
    yline(-0.01, 'r--'); yline(0.01, 'r--'); yline(0, 'k', LineStyle=':')
    ylim(ylim_residual); grid on
    title('Post-Correction Residuals')
    ylabel('\DeltapH (Corrected - ESPER)')

    % Save
    figname = fullfile(outdir, sprintf('SN%s_BIC%d_k0_pH_Correction.png', SN, BIC_changepoints));
    set(fig, 'Units', 'inches', 'Position', [0 0 11 8.5]);
    exportgraphics(fig, figname, 'Resolution', 300);
    close(fig);
    fprintf('Saved: %s\n', figname);
end