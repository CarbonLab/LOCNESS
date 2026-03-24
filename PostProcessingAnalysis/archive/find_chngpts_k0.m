missionID = '2507020902';
SN = missionID(6:8);
fname = fullfile("data",[missionID,'_esper.mat']);
load(fname);

opts = detectImportOptions('data\ph_cal_locness_corrected.txt');
opts = setvartype(opts, opts.VariableNames{1}, 'char');
ph_cal = readtable('data\ph_cal_locness_corrected.txt', opts);
ph_cal = ph_cal(ismember(ph_cal.Mission,missionID),:);
Pcoefs = [ph_cal.fp_k1,ph_cal.fp_k2,ph_cal.fp_k3,...
            ph_cal.fp_k4,ph_cal.fp_k5,ph_cal.fp_k6]';
% k2 = ph_cal.k2_fp_c0;
%% Compute reference anomaly
depth = 270;
depthTolerance = 5;  % meters

% Pre-allocate scalar time series
data.ESPER.referenceAnomalyTimeSeries   = NaN(1, length(data.ESPER.ph));
data.ph.phAtDepth                       = NaN(1, length(data.ESPER.ph));
data.ESPER.ph_correctedAtDepth          = NaN(1, length(data.ESPER.ph));
data.ESPER.k0                           = NaN(1, length(data.ESPER.ph));
data.ESPER.k0referenceAnomalyTimeSeries = NaN(1, length(data.ESPER.ph));
data.ph.ph_correctedAtDepth             = NaN(1, length(data.ESPER.ph));
for i = 1:length(data.ESPER.ph)
    % Logical index for phase == 0
    iphase = data.ph.phase{i} == 0;

    % Find closest depth index within phase==0 subset
    [minDist, idepth] = min(abs(data.ESPER.depth{i}(iphase) - depth));

    % Skip if closest depth is farther than tolerance
    if minDist > depthTolerance
        continue  % NaN already set by pre-allocation
    end

    % Map phase-filtered index back to full array
    iphase_idx = find(iphase);
    target_idx = iphase_idx(idepth);

    % Full anomaly profile (phase==0 only) — cell array of vectors
    data.ESPER.referenceAnomaly{i}       = data.ph.ph{i}(iphase) - data.ESPER.ph_corrected{i}(iphase);
    data.ph.phProfile{i}                 = data.ph.ph{i}(iphase);
    data.ESPER.ph_correctedProfile{i}    = data.ESPER.ph_corrected{i}(iphase);

    % Single value at target depth — numeric arrays indexed by dive
    data.ph.phAtDepth(i)                      = data.ph.ph{i}(target_idx);
    data.ESPER.ph_correctedAtDepth(i)         = data.ESPER.ph_corrected{i}(target_idx);
    data.ESPER.referenceAnomalyTimeSeries(i)  = data.ESPER.referenceAnomaly{i}(idepth);
    data.ESPER.k0(i) = k0frompH_claude(data.ph.Vrse{i}(target_idx),data.ph.p{i}(target_idx),data.ESPER.t{i}(target_idx),data.ESPER.s{i}(target_idx),data.ESPER.ph_corrected{i}(target_idx),ph_cal.k2,Pcoefs);
    data.ESPER.k0referenceAnomalyTimeSeries(i)  = ph_cal.k0 - data.ESPER.k0(i); % Lab k0 - ESPER k0
end
%% Find change points / drift fit
BIC_changepoints = 2;
profile = 1:length(data.ESPER.ph);

if BIC_changepoints == 0
    % Simple single linear drift fit across all profiles
    valid = ~isnan(data.ESPER.k0referenceAnomalyTimeSeries);
    p     = polyfit(profile(valid), data.ESPER.k0referenceAnomalyTimeSeries(valid), 1);
    linfit = polyval(p, profile);
    TF    = false(size(profile)); % no change points
else
    [TF,S1,S2] = ischange(data.ESPER.k0referenceAnomalyTimeSeries,'linear','MaxNumChanges',BIC_changepoints);
    S1_full    = fillmissing(S1, 'nearest');
    S2_full    = fillmissing(S2, 'nearest');
    linfit     = S1_full .* profile + S2_full;
end
data.ESPER.k0_corrected = ph_cal.k0 - linfit;
data.ESPER.k0anomaly_corrected   = data.ESPER.k0 - linfit;
data.ph.ph_corrected        = cell(size(data.ph.ph));
% Now need to recompute pH with new k0 per profile
for n = 1:length(data.ESPER.ph)

    if ~isempty(data.ph.Vrse{n})

        [~,iuse] = unique(data.ctd.time{n});
        if length(iuse)>1
            ss = interp1(data.ctd.time{n}(iuse),data.ctd.s{n}(iuse),data.ph.time{n},'linear','extrap'); % interpolate in time rather than pressure since time is monotonic
            tt = interp1(data.ctd.time{n}(iuse),data.ctd.t{n}(iuse),data.ph.time{n},'linear','extrap');

            [~,data.ph.ph_corrected{n}] = phcalc_jp(data.ph.Vrse{n},data.ph.p{n},tt,ss,data.ESPER.k0_corrected(n),ph_cal.k2,Pcoefs);

        else
            data.ph.ph_corrected{n} = nan(size(data.ph.Vrse{n}));
        end

    end

end

for i = 1:length(data.ESPER.ph)
    % Logical index for phase == 0
    iphase = data.ph.phase{i} == 0;

    % Find closest depth index within phase==0 subset
    [minDist, idepth] = min(abs(data.ESPER.depth{i}(iphase) - depth));

    % Skip if closest depth is farther than tolerance
    if minDist > depthTolerance
        continue  % NaN already set by pre-allocation
    end

    % Map phase-filtered index back to full array
    iphase_idx = find(iphase);
    target_idx = iphase_idx(idepth);
    data.ph.ph_correctedAtDepth(i) = data.ph.ph_corrected{i}(target_idx);
end

rms_val = rms(data.ph.ph_correctedAtDepth - data.ESPER.ph_correctedAtDepth, 'omitnan');
% Figure
fig = figure;
clf
tl = tiledlayout(2, 2);
title(tl, sprintf('pH Correction SN%s',SN))
subtitle(tl, sprintf('BGC-ARGO Protocol | Reference Depth %d +/- %dm | BIC: %d changepoint(s) | RMS: %.4f', depth, depthTolerance, BIC_changepoints, rms_val))

ax1 = nexttile(tl,1);
plot(profile, data.ph.phAtDepth, 'o')
hold on
plot(profile, data.ESPER.ph_correctedAtDepth, 'o')
grid on
title('Measured vs ESPER Reference')
ylabel('pH_t_o_t_a_l')
legend('pH_m_e_a_s', 'pH_E_S_P_E_R', Location='southeast')

ax2 = nexttile(tl,2);
plot(profile, data.ESPER.k0referenceAnomalyTimeSeries, 'ko')
hold on
plot(profile, linfit, 'r-', 'LineWidth', 2)
if any(TF)
    xline(profile(TF))
    legend('Ref Anom', 'Drift Fit', 'Change Points', Location='northeast')
else
    legend('Ref Anom', 'Drift Fit', Location='northeast')
end
title('k0 Reference Anomaly')
ylabel('\Deltak_0 (lab - ESPER)')
ylim([-.005 .005])
yticks(-0.005:0.001:0.005)
grid on

ax3 = nexttile(tl,3);
plot(profile, data.ph.ph_correctedAtDepth, 'o')
hold on
plot(profile, data.ESPER.ph_correctedAtDepth, 'o')
grid on
title('Corrected pH vs ESPER Reference')
ylabel('pH_t_o_t_a_l')
legend('pH_m_e_a_s', 'pH_E_S_P_E_R', Location='southeast')

ax4 = nexttile(tl,4);
plot(profile, data.ph.ph_correctedAtDepth-data.ESPER.ph_correctedAtDepth, 'ko')
hold on
yline(-0.01, 'r--')
yline( 0.01, 'r--')
yline(0, 'k', LineStyle=':')
grid on
title('Post-Correction Residuals')
ylabel('\DeltapH (Corrected - ESPER)')
ylim([-0.02 0.02])
%
% linkaxes([ax1 ax3],'y')
% linkaxes([ax2 ax4],'y')

figname = fullfile("figures",sprintf('SN%s_BIC%d_k0_pH_Correction.png',SN,BIC_changepoints));
set(fig, 'Units', 'inches', 'Position', [0 0 11 8.5]);  % landscape letter
exportgraphics(fig, figname, 'Resolution', 300);
%% get ph cal
% pHcal = readtable("ph_cal_locness_corrected.txt");
% obj.getpHCal;
% Pcoefs = [obj.pHcal.fp_k1,obj.pHcal.fp_k2,obj.pHcal.fp_k3,...
% obj.pHcal.fp_k4,obj.pHcal.fp_k5,obj.pHcal.fp_k6]';
%% Format data as a table
% T = obj.T;
% T.sdn = data.ESPER.sdn(:)
%% Get index at correction depth
% idx = T.depth == 450 & ~isnan(T.phin) & ~isnan(T.phin_canb); % nans don't work in regression
% 
% 
% 
% Cal.sdn = T.sdn(idx);
% Cal.lat = T.lat(idx);
% Cal.lon = T.lon(idx);
% Cal.pres = T.pres(idx);
% Cal.tc = T.tc(idx);
% Cal.psal = T.psal(idx);
% Cal.doxy = T.doxy(idx);
% Cal.pHin = T.phin(idx);
% Cal.pHin_canb = T.phin_canb(idx);
% Cal.ta_canb_QC = NaN(size(Cal.pHin));
% Cal.cycle = T.divenumber(idx);
% Cal.k0_canb = k0frompH(T.vrse(idx),T.pres(idx),T.tc(idx),T.psal(idx),T.phin_canb(idx),obj.pHcal.k2_fp_c0,Pcoefs);
% Cal.k0 = ones(size(Cal.k0_canb)) * obj.pHcal.k0_seawater;
% DATA = struct('sdn',Cal.sdn,'ref_data',Cal.pHin_canb,'flt_data',Cal.pHin,'flt_cycs',Cal.cycle,'flt_depths',Cal.pres,'flt_k0_canb',Cal.k0_canb);
% Cal.nMaxChangepH = on_findchpts_SG(DATA);
% Cal.deltapH = Cal.pHin - Cal.pHin_canb;
% Cal.deltak0 = Cal.k0 - Cal.k0_canb;
% Cal.chptsTF = ischange(Cal.deltapH, 'linear', 'maxNumChanges', Cal.nMaxChangepH);
% % Use identified change points and do piecewise linear regression
% Xfit_data = Cal.sdn - T.sdn(1);
% % set up X and Y variables for piecewise linear regression
% Cal.Xi = [Xfit_data(1); Xfit_data(Cal.chptsTF); Xfit_data(end)];
% Yfit_data = Cal.deltak0;
% % Need to carry through the actual date that Cal.Xi and Cal.Yi corresponds to
% Cal.DTi = [Cal.sdn(1); Cal.sdn(Cal.chptsTF); Cal.sdn(end)];
% % piecewise linear regression based on change points detected above.
% Cal.Yi = lsq_lut_piecewise_v2(Xfit_data, Yfit_data, Cal.Xi);
% % Apply delta to all profiles
% deldt = T.sdn(:) - T.sdn(1);
% % Add start point if not already contained
% if Cal.Xi(1) ~= 0
% Cal.Xi = [0;Cal.Xi];
% Cal.Yi = [Cal.Yi(1);Cal.Yi];
% Cal.DTi = [T.sdn(1);Cal.DTi];
% end
% % Add end point if not already contained
% if Cal.Xi(end) ~= deldt(end)
% Cal.Xi = [Cal.Xi;deldt(end)];
% Cal.Yi = [Cal.Yi;Cal.Yi(end)];
% Cal.DTi = [Cal.DTi;T.sdn(end)];
% end
% % Calculate k0 for each dive
% Cal.deltak0fit = interp1(Cal.Xi, Cal.Yi, deldt); % date
% T.k0_corr = (-Cal.deltak0fit) + obj.pHcal.k0_seawater;
% % Recalculate pHin to check
% % [~, T.phin_corr] = phcalc_jp(T.vrse,T.pres,T.tc,T.psal,T.k0_corr,obj.pHcal.k2_fp_c0,Pcoefs);
% obj.T = T;