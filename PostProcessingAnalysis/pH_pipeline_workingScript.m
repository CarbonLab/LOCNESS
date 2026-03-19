%% Step 2: pH Reference Anomaly  (following BGC-Argo protocol)
%
%   Anomaly: pHmeas - pHref at reference depth, over time, ascents only.
%   BIC changepoint detection to identify sensor drift segments.
%   Linear drift correction per segment.
%
%   BGC-Argo protocol:
%   https://archimer.ifremer.fr/doc/00866/97828/106985.pdf
%
%   Input:  data/data.mat  (Spray2 glider, data.ph, data.ESPER, data.dox)
%           phase encoding: 0 = ascent, 1 = descent
%
%   Four plots:
%     1) Raw measured pH and ESPER reference pH vs dive number
%     2) Reference anomaly (meas - ESPER) + per-segment drift fit
%     3) Corrected pH alongside ESPER reference
%     4) Post-correction residuals
%   BIC changepoint lines overlain on all panels.
%
%   Outputs stored in data.ESPER (workspace).

%% Load data
load('data/data.mat');

%% Interpolate CTD s,t onto pH depth grid; compute GSW density
% CTD and pH are sampled on different depth grids per profile.
% data.ESPER.s/t are already on the same depth grid as data.ph (confirmed).
% Pressure is approximated as gsw_p_from_z(-depth, lat).

ndive = numel(data.ph.ph);

for ii = 1:ndive
    lat_ii = mean(data.lat(ii,:), 'omitmissing');
    lon_ii = mean(data.lon(ii,:), 'omitmissing');

    dep_ph = data.ph.depth{ii};
    p_ph   = gsw_p_from_z(-dep_ph, lat_ii);

    % % --- Interpolate CTD s, t onto pH depth grid ---
    % dep_ctd = data.ctd.depth{ii};
    % s_ctd   = data.ctd.s{ii};
    % t_ctd   = data.ctd.t{ii};
    % valid   = isfinite(dep_ctd) & isfinite(s_ctd) & isfinite(t_ctd);
    % dep_ctd_v = dep_ctd(valid);
    % s_ctd_v   = s_ctd(valid);
    % t_ctd_v   = t_ctd(valid);
    % [dep_ctd_u, iu] = unique(dep_ctd_v);        % sort + deduplicate finite obs
    % s_ph = interp1(dep_ctd_u, s_ctd_v(iu), dep_ph, 'linear', NaN);
    % t_ph = interp1(dep_ctd_u, t_ctd_v(iu), dep_ph, 'linear', NaN);
    % 
    % data.ph.s{ii} = s_ph;
    % data.ph.t{ii} = t_ph;
    data.ph.s{ii} = data.ESPER.s{ii};
    data.ph.t{ii} = data.ESPER.t{ii};

    % GSW density on pH grid
    SA_ph = gsw_SA_from_SP(data.ph.s{ii}, data.ph.p{ii}, lon_ii, lat_ii);
    CT_ph = gsw_CT_from_t(SA_ph, data.ph.t{ii}, data.ph.p{ii});
    data.ph.SA{ii}     = SA_ph;
    data.ph.CT{ii}     = CT_ph;
    data.ph.sigma0{ii} = gsw_sigma0(SA_ph, CT_ph);

    % --- GSW density on ESPER grid (s, t already co-located with pH) ---
    dep_esp = data.ESPER.depth{ii};
    p_esp   = gsw_p_from_z(-dep_esp, lat_ii);

    SA_esp = gsw_SA_from_SP(data.ESPER.s{ii}, p_esp, lon_ii, lat_ii);
    CT_esp = gsw_CT_from_t(SA_esp, data.ESPER.t{ii}, p_esp);
    data.ESPER.SA{ii}     = SA_esp;
    data.ESPER.CT{ii}     = CT_esp;
    data.ESPER.sigma0{ii} = gsw_sigma0(SA_esp, CT_esp);

    % --- Absolute timestamp for each pH observation ---
    % data.time(ii,1) is the Unix start time of segment ii [s since 1970-01-01 UTC]
    % data.ph.time{ii} is seconds elapsed since that segment start
    t_unix = data.time(ii,1) + data.ph.time{ii};
    data.ph.time_unix{ii}     = t_unix;
    data.ph.time_datetime{ii} = datetime(t_unix, 'ConvertFrom', 'posixtime', ...
                                         'TimeZone', 'UTC');
    data.ESPER.time_unix{ii}     = t_unix;
    data.ESPER.time_datetime{ii} = datetime(t_unix, 'ConvertFrom', 'posixtime', ...
                                         'TimeZone', 'UTC');
end
fprintf('GSW density computed and timestamps created for %d profiles\n', ndive);

%% plotting for my sanity
% plot timeseries of pH and ESPER pH across depths
depth_min  = 245;
deltaDepth = 10;
depth_levels = depth_min + (0:3) * deltaDepth;   % [250 260 270 280]
ndepths      = numel(depth_levels);

pH_depth    = nan(ndive, ndepths);
ESPER_depth = nan(ndive, ndepths);
s_depth     = nan(ndive, ndepths);
t_depth     = nan(ndive, ndepths);
s_esp_depth = nan(ndive, ndepths);
t_esp_depth = nan(ndive, ndepths);

for prof = 1:ndive
    for id = 1:ndepths
        z = depth_levels(id);
        iuse_ph  = data.ph.depth{prof}    > z & data.ph.depth{prof}    < z+1 & data.ph.phase{prof}  == 0;
        iuse_ctd = data.ctd.depth{prof}   > z & data.ctd.depth{prof}   < z+1 & data.ctd.phase{prof} == 0;
        iuse_esp = data.ESPER.depth{prof}  > z & data.ESPER.depth{prof} < z+1 & data.ph.phase{prof}  == 0;
        pH_depth(prof,id)    = mean(data.ph.ph{prof}(iuse_ph),             'omitmissing');
        ESPER_depth(prof,id) = mean(data.ESPER.ph_adjusted{prof}(iuse_ph), 'omitmissing');
        s_depth(prof,id)     = mean(data.ctd.s{prof}(iuse_ctd),            'omitmissing');
        t_depth(prof,id)     = mean(data.ctd.t{prof}(iuse_ctd),            'omitmissing');
        s_esp_depth(prof,id) = mean(data.ESPER.s{prof}(iuse_esp),          'omitmissing');
        t_esp_depth(prof,id) = mean(data.ESPER.t{prof}(iuse_esp),          'omitmissing');
    end
end

% --- pH timeseries ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: pH','Interpreter','none','fontsize',24)
xlabel(tl,'profile','fontsize',16)
for id = 1:ndepths
    nexttile; hold on
    scatter(1:ndive, pH_depth(:,id),    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(1:ndive, ESPER_depth(:,id), 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('%.0fm', depth_levels(id)), 'Interpreter', 'none')
    xlim([0 ndive]); grid on
end
saveas(fig,'SN209_pH_ESPER_comparison.png');

% --- delta pH timeseries ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: \DeltapH (raw-ESPER)','fontsize',24)
xlabel(tl,'profile','fontsize',16)
for id = 1:ndepths
    nexttile
    scatter(1:ndive, pH_depth(:,id) - ESPER_depth(:,id), 'o', 'MarkerEdgeColor', [0.4706    0.8118    0.0235])
    ylabel(sprintf('\x0394pH %.0fm', depth_levels(id)), 'Interpreter', 'none')
    xlim([0 ndive]); grid on
    ylim([-.08 -.04])
end
saveas(fig,'SN209_deltapH.png');

% --- Salinity timeseries ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: salinity','Interpreter','none','fontsize',24)
xlabel(tl,'profile','fontsize',16)
for id = 1:ndepths
    nexttile; hold on
    scatter(1:ndive, s_depth(:,id),     'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(1:ndive, s_esp_depth(:,id), 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('%.0fm', depth_levels(id)), 'Interpreter', 'none')
    xlim([0 ndive]); grid on
end
saveas(fig,'SN209_sal_ESPER_comparison.png');

% --- Temperature timeseries ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: temperature','Interpreter','none','fontsize',24)
xlabel(tl,'profile','fontsize',16)
for id = 1:ndepths
    nexttile; hold on
    scatter(1:ndive, t_depth(:,id),     'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(1:ndive, t_esp_depth(:,id), 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('%.0fm', depth_levels(id)), 'Interpreter', 'none')
    xlim([0 ndive]); grid on
end
saveas(fig,'SN209_temp_ESPER_comparison.png');

% --- pH vs salinity ---
fig = figure;
set(gcf,'Position',[67 44 495 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: pH vs salinity','Interpreter','none','fontsize',24)
xlabel(tl,'salinity','fontsize',16)
for id = 1:ndepths
    nexttile; hold on
    scatter(s_depth(:,id),     pH_depth(:,id),    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(s_esp_depth(:,id), ESPER_depth(:,id), 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('%.0fm', depth_levels(id)), 'Interpreter', 'none')
    grid on
end
legend('CTD', 'ESPER')
saveas(fig,'SN209_pH_vs_sal.png');

% --- pH vs temperature ---
fig = figure;
set(gcf,'Position',[67 44 495 822])
tl = tiledlayout(ndepths,1);
title(tl,'SN209: pH vs temperature','Interpreter','none','fontsize',24)
xlabel(tl,'temperature','fontsize',16)
for id = 1:ndepths
    nexttile; hold on
    scatter(t_depth(:,id),     pH_depth(:,id),    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(t_esp_depth(:,id), ESPER_depth(:,id), 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('%.0fm', depth_levels(id)), 'Interpreter', 'none')
    grid on
end
legend('CTD', 'ESPER')
saveas(fig,'SN209_pH_vs_temp.png');


%% plot timeseries of pH and ESPER pH on isopycnals
sigma_window = 0.01; % kg/m³ half-width for isopycnal bin — adjust as needed

% First pass: find reference sigma at each target depth from a reference profile
% (use the median sigma across all profiles at each target depth)
target_depths = depth_min + (0:3)*deltaDepth;
ndepths = length(target_depths);
depth_labels = target_depths;

% Get reference sigma at each target depth (median across all profiles)
ref_sigma = nan(1, ndepths);
for d = 1:ndepths
    sigma_at_depth = nan(1, ndive);
    for prof = 1:ndive
        iuse = data.ph.depth{prof} > target_depths(d) & data.ph.depth{prof} < target_depths(d) + 1 & data.ph.phase{prof} == 0;
        if any(iuse)
            sigma_at_depth(prof) = mean(data.ph.sigma0{prof}(iuse), 'omitmissing');
        end
    end
    ref_sigma(d) = median(sigma_at_depth, 'omitmissing');
end
fprintf('Reference sigmas: '); fprintf('%.4f  ', ref_sigma); fprintf('\n');
%%Main loop: average pH and ESPER on isopycnals
pH_iso    = cell(ndepths,1);
ESPER_iso = cell(ndepths,1);
s_iso     = cell(ndepths,1);
s_ESPER_iso = cell(ndepths,1);
t_iso     = cell(ndepths,1);
t_ESPER_iso = cell(ndepths,1);

for d = 1:ndepths
    pH_iso{d}       = nan(1, ndive);
    ESPER_iso{d}    = nan(1, ndive);
    s_iso{d}        = nan(1, ndive);
    s_ESPER_iso{d}  = nan(1, ndive);
    t_iso{d}        = nan(1, ndive);
    t_ESPER_iso{d}  = nan(1, ndive);

    for prof = 1:ndive
        % pH sensor — bin by sigma
        iuse = abs(data.ph.sigma0{prof} - ref_sigma(d)) < sigma_window;
        if any(iuse)
            temp = data.ph.ph{prof}(iuse) ;
            phases = data.ph.phase{prof}(iuse) ;
            pH_iso{d}(prof) = mean(temp(phases ==0), 'omitmissing');
        end

        % ESPER — bin by sigma
        iuse = abs(data.ESPER.sigma0{prof} - ref_sigma(d)) < sigma_window;
        if any(iuse)
            ESPER_iso{d}(prof)   = mean(data.ESPER.ph_adjusted{prof}(iuse), 'omitmissing');
            s_ESPER_iso{d}(prof) = mean(data.ESPER.s{prof}(iuse),           'omitmissing');
            t_ESPER_iso{d}(prof) = mean(data.ESPER.t{prof}(iuse),           'omitmissing');
        end

        % CTD — data.ctd.sigma
        iuse = abs(data.ctd.sigma{prof} - ref_sigma(d)) < sigma_window;
        if any(iuse)
            temp = data.ctd.t{prof}(iuse) ;
            sal = data.ctd.s{prof}(iuse) ;
            phases = data.ctd.phase{prof}(iuse) ;
            s_iso{d}(prof) = mean(sal(phases ==0), 'omitmissing');  
            t_iso{d}(prof) = mean(temp(phases ==0), 'omitmissing');
        end
    end
end

% --- pH timeseries figure ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: pH (isopycnal)', 'Interpreter', 'none', 'fontsize', 24)
xlabel(tl, 'profile')
for d = 1:ndepths
    nexttile
    scatter(1:ndive, pH_iso{d},    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    hold on
    scatter(1:ndive, ESPER_iso{d}, 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    xlim([0 ndive]); grid on
end
legend('raw', 'ESPER_{corr}')
saveas(fig, 'SN209_pH_ESPER_isopycnal.png');

% --- delta pH figure ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: \DeltapH raw-ESPER (isopycnal)', 'fontsize', 24)
xlabel(tl, 'profile')
for d = 1:ndepths
    nexttile
    scatter(1:ndive, pH_iso{d} - ESPER_iso{d}, 'o', 'MarkerEdgeColor', [0.4706    0.8118    0.0235])
    ylabel(sprintf('\\Delta pH \\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    xlim([0 ndive]); grid on
    ylim([-.08 -.04])
end
saveas(fig, 'SN209_deltapH_isopycnal.png');

% --- Salinity timeseries figure ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: salinity (isopycnal)', 'Interpreter', 'none', 'fontsize', 24)
xlabel(tl, 'profile')
for d = 1:ndepths
    nexttile
    scatter(1:ndive, s_iso{d},       'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    hold on
    scatter(1:ndive, s_ESPER_iso{d}, 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    xlim([0 ndive]); grid on
end
legend('CTD', 'ESPER')
saveas(fig, 'SN209_sal_isopycnal.png');

% --- Temperature timeseries figure ---
fig = figure;
set(gcf,'Position',[67 44 1149 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: temperature (isopycnal)', 'Interpreter', 'none', 'fontsize', 24)
xlabel(tl, 'profile')
for d = 1:ndepths
    nexttile
    scatter(1:ndive, t_iso{d},       'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    hold on
    scatter(1:ndive, t_ESPER_iso{d}, 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    xlim([0 ndive]); grid on
end
legend('CTD', 'ESPER')
saveas(fig, 'SN209_temp_isopycnal.png');

% --- pH vs salinity figure ---
fig = figure;
set(gcf,'Position',[67 44 495 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: pH vs salinity (isopycnal)', 'Interpreter', 'none', 'fontsize', 24)
xlabel(tl, 'salinity')
for d = 1:ndepths
    nexttile
    scatter(s_iso{d},       pH_iso{d},    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    hold on
    scatter(s_ESPER_iso{d}, ESPER_iso{d}, 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    grid on
end
legend('CTD', 'ESPER')
saveas(fig, 'SN209_pH_vs_sal_isopycnal.png');

% --- pH vs temperature figure ---
fig = figure;
set(gcf,'Position',[67 44 495 822])
tl = tiledlayout(ndepths, 1);
title(tl, 'SN209: pH vs temperature (isopycnal)', 'Interpreter', 'none', 'fontsize', 24)
xlabel(tl, 'temperature')
for d = 1:ndepths
    nexttile
    scatter(t_iso{d},       pH_iso{d},    'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    hold on
    scatter(t_ESPER_iso{d}, ESPER_iso{d}, 'o', 'MarkerEdgeColor', [1 0 0])
    ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
    grid on
end
legend('CTD', 'ESPER')
saveas(fig, 'SN209_pH_vs_temp_isopycnal.png');


% %% cross-correlation between raw pH and ESPER pH at each isopycnal
% fig = figure;
% set(gcf,'Position',[67 44 1149 822])
% tl = tiledlayout(ndepths, 1);
% title(tl, 'SN209: xcorr(raw pH, ESPER pH) by isopycnal', 'Interpreter', 'none', 'fontsize', 24)
% xlabel(tl, 'lag (profiles)')
% 
% for d = 1:ndepths
%     % pull out the two series and remove NaNs by finding valid overlap
%     x = pH_iso{d};
%     y = ESPER_iso{d};
%     x = data.ph.ph{50};
%     y = data.ESPER.ph_adjusted{50};
%     % keep only profiles where both are valid
%     iuse = ~isnan(x) & ~isnan(y);
%     x = x(iuse);
%     y = y(iuse);
% 
%     % remove mean (xcorr on anomalies is more interpretable)
%     x = x - mean(x);
%     y = y - mean(y);
% 
%     % compute normalized cross-correlation
%     [r, lags] = xcorr(x, y, 'normalized');
% 
%     % find lag of peak correlation
%     [~, ipeak] = max(abs(r));
%     lag_peak = lags(ipeak);
% 
%     nexttile
%     stem(lags, r, 'filled', 'MarkerSize', 2, 'Color', [0.4706    0.8118    0.0235])
%     hold on
%     xline(0,   '--k', 'LineWidth', 1)
%     xline(lag_peak, '-r', sprintf('lag=%d', lag_peak), 'LineWidth', 1.5, ...
%           'LabelVerticalAlignment', 'bottom')
%     yline(0, '-k')
%     ylabel(sprintf('\\sigma=%.4f', ref_sigma(d)), 'Interpreter', 'tex')
%     ylim([-1 1]); grid on
%     xlim([-20 20])  % show ±20 profiles; adjust as needed
% end
% %saveas(fig, 'SN209_xcorr_pH_ESPER.png');


%% salinity-normalized pH
% pH_norm = pH - b*(S - S_ref)
% where b = dpH/dS from linear regression, S_ref = mean salinity
%
% norm_mode: 'depth'     — use depth-aligned matrices (pH_depth, s_depth, etc.)
%            'isopycnal' — use isopycnal cell arrays  (pH_iso, s_iso, etc.)

norm_mode = 'depth';   % <-- switch here

switch norm_mode
    case 'depth'
        norm_pH    = num2cell(pH_depth,    1);  % convert columns to cell array
        norm_ESPER = num2cell(ESPER_depth, 1);
        norm_s     = num2cell(s_depth,     1);
        norm_s_esp = num2cell(s_esp_depth, 1);
        norm_labels = arrayfun(@(z) sprintf('%.0f m', z), depth_levels, 'UniformOutput', false);
        norm_title_sfx = '(depth-aligned)';
    case 'isopycnal'
        norm_pH    = pH_iso;
        norm_ESPER = ESPER_iso;
        norm_s     = s_iso;
        norm_s_esp = s_ESPER_iso;
        norm_labels = arrayfun(@(s) sprintf('\\sigma=%.4f', s), ref_sigma, 'UniformOutput', false);
        norm_title_sfx = '(isopycnal)';
    otherwise
        error('norm_mode must be ''depth'' or ''isopycnal''');
end

pH_norm    = cell(ndepths, 1);
ESPER_norm = cell(ndepths, 1);

fig_depth = figure;
set(gcf,'Position',[67 44 1149 822])
tl_depth = tiledlayout(ndepths, 1);
title(tl_depth, ['SN209: salinity-normalized pH ' norm_title_sfx], 'Interpreter', 'tex', 'fontsize', 24)
xlabel(tl_depth, 'profile')

fig_scatter = figure;
set(fig_scatter,'Position',[67 44 495 822])
tl_sc = tiledlayout(ndepths, 1);
title(tl_sc, ['SN209: pH vs salinity with regression ' norm_title_sfx], 'Interpreter', 'tex', 'fontsize', 24)
xlabel(tl_sc, 'salinity')

for d = 1:ndepths
    x_s   = norm_s{d}(:);
    x_se  = norm_s_esp{d}(:);
    y_ph  = norm_pH{d}(:);
    y_esp = norm_ESPER{d}(:);

    iuse_ph  = ~isnan(x_s)  & ~isnan(y_ph);
    iuse_esp = ~isnan(x_se) & ~isnan(y_esp);

    p_ph  = polyfit(x_s(iuse_ph),   y_ph(iuse_ph),   1);
    p_esp = polyfit(x_se(iuse_esp), y_esp(iuse_esp), 1);

    S_ref_ph  = mean(x_s(iuse_ph),   'omitmissing');
    S_ref_esp = mean(x_se(iuse_esp), 'omitmissing');

    pH_norm{d}    = y_ph  - p_ph(1)  .* (x_s  - S_ref_ph);
    ESPER_norm{d} = y_esp - p_esp(1) .* (x_se - S_ref_esp);

    % --- timeseries tile ---
    figure(fig_depth)
    nexttile; hold on
    scatter(1:ndive, y_ph,          'o', 'MarkerEdgeColor', [0.7 0.7 0.7])
    scatter(1:ndive, y_esp,         'o', 'MarkerEdgeColor', [1.0 0.7 0.7])
    scatter(1:ndive, pH_norm{d},    'o', 'MarkerEdgeColor', [0   0.4470 0.7410])
    scatter(1:ndive, ESPER_norm{d}, 'o', 'MarkerEdgeColor', [1   0      0     ])
    ylabel(norm_labels{d}, 'Interpreter', 'tex')
    xlim([0 ndive]); grid on

    % --- scatter tile ---
    figure(fig_scatter)
    nexttile; hold on
    s_fit = linspace(min(x_s(iuse_ph)), max(x_s(iuse_ph)), 100);
    scatter(x_s(iuse_ph),   y_ph(iuse_ph),   'o', 'MarkerEdgeColor', [0 0.4470 0.7410])
    scatter(x_se(iuse_esp), y_esp(iuse_esp), 'o', 'MarkerEdgeColor', [1 0 0])
    plot(s_fit, polyval(p_ph,  s_fit), '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5)
    plot(s_fit, polyval(p_esp, s_fit), '-', 'Color', [1 0 0],           'LineWidth', 1.5)
    ylabel(norm_labels{d}, 'Interpreter', 'tex')
    title(sprintf('dpH/dS: raw=%.4f  ESPER=%.4f', p_ph(1), p_esp(1)), 'fontsize', 9)
    grid on
end

figure(fig_depth)
legend('raw pH', 'raw ESPER', 'S-norm pH', 'S-norm ESPER', 'Location', 'best')
saveas(fig_depth,      'SN209_pH_sal_normalized_depth.png');

figure(fig_scatter)
legend('raw pH', 'raw ESPER', 'fit pH', 'fit ESPER', 'Location', 'best')
saveas(fig_scatter, 'SN209_pH_sal_normalized_scatter.png');

%%delta pH before and after normalization
fig_delta = figure;
set(gcf,'Position',[67 44 1149 822])
tl_d = tiledlayout(ndepths, 1);
title(tl_d, 'SN209: \DeltapH raw-ESPER before/after S-normalization', 'fontsize', 24)
xlabel(tl_d, 'profile')

for d = 1:ndepths
    nexttile; hold on
    scatter(1:ndive, norm_pH{d}(:) - norm_ESPER{d}(:), 'o', 'MarkerEdgeColor', [0.7 0.7 0.7])
    scatter(1:ndive, pH_norm{d}    - ESPER_norm{d},    'o', 'MarkerEdgeColor', [0.4706    0.8118    0.0235])
    yline(0, '--k')
    ylabel(norm_labels{d}, 'Interpreter', 'tex')
    xlim([0 ndive]); grid on
    ylim([-0.08 -0.04])
end
legend('\DeltapH raw', '\DeltapH S-norm', 'Location', 'best')
saveas(fig_delta, 'SN209_deltapH_sal_normalized.png');
%% Use the plots from above to choose how to find the drifts in pH


%% Reference selection
% ref_mode: 'depth'     — deepest depth level (pH_depth / ESPER_depth)
%           'isopycnal' — deepest isopycnal level (pH_iso / ESPER_iso)
%           'snorm'     — S-normalised series (pH_norm / ESPER_norm)

ref_mode = 'snorm';   % default: match whatever normalisation was used above
                        % override here if desired, e.g. ref_mode = 'depth';

ref_depth_min = depth_levels(ndepths) - 5;   % [m]  (used for depth mode label)
ref_depth_max = depth_levels(ndepths) + 5;

n_prof = numel(data.ph.ph);
dn_asc = (1:n_prof)';
cyc    = (1:n_prof)';
n_asc  = n_prof;

switch ref_mode
    case 'depth'
        ph_meas_ref  = pH_depth(:, ndepths);
        ph_esper_ref = ESPER_depth(:, ndepths);
        ref_str = sprintf('%d\x2013%d m (depth)', ref_depth_min, ref_depth_max);
    case 'isopycnal'
        ph_meas_ref  = pH_iso{ndepths}(:);
        ph_esper_ref = ESPER_iso{ndepths}(:);
        ref_str = sprintf('\\sigma=%.4f (isopycnal)', ref_sigma(ndepths));
    case 'snorm'
        ph_meas_ref  = pH_norm{ndepths}(:);
        ph_esper_ref = ESPER_norm{ndepths}(:);
        ref_str = sprintf('%d m S-norm', depth_levels(ndepths));
    otherwise
        error('ref_mode must be ''depth'', ''isopycnal'', or ''snorm''');
end

ref_str = strtrim(ref_str);
fprintf('Reference depth: %s\n', ref_str);
fprintf('Profiles with valid ref obs: %d / %d\n', ...
    sum(~isnan(ph_meas_ref) & ~isnan(ph_esper_ref)), n_prof);

%% Reference anomaly  (scalar per profile)
anomaly  = ph_meas_ref - ph_esper_ref;
has_data = ~isnan(anomaly);

%% BIC changepoint detection
% BIC(k) = n*log(RSS_k/n) + (k+1)*log(n)
% k = number of changepoints; k+1 = number of segment means
anom_use = anomaly(has_data);
n_v      = numel(anom_use);
max_cp   = min(2, floor(n_v / 10));

BIC_val    = nan(max_cp + 1, 1);
rss0       = sum((anom_use - nanmean(anom_use)).^2);
BIC_val(1) = n_v * log(rss0 / n_v) + 1 * log(n_v);   % k=0: 1 segment mean

for k = 1:max_cp
    [~, rss_k]   = findchangepts(anom_use, 'MaxNumChanges', k, 'Statistic', 'mean');
    BIC_val(k+1) = n_v * log(rss_k / n_v) + (k + 1) * log(n_v);
end

[~, best_idx] = min(BIC_val);
best_k        = best_idx - 1;
fprintf('BIC-optimal changepoints: %d\n', best_k);

if best_k > 0
    cp_local = findchangepts(anom_use, 'MaxNumChanges', best_k, 'Statistic', 'mean');
else
    cp_local = [];
end

% Map local indices back to full profile indices
has_data_idx = find(has_data);
cp_idx       = has_data_idx(cp_local);
cp_dn        = dn_asc(cp_idx);

%% Drift correction: linear fit per segment, applied to raw profiles
% Time axis: days since first profile
t_days = (data.time(1:n_prof, 1) - data.time(1, 1)) / 86400;

seg_bounds = [1; cp_idx(:); n_asc];
n_segs     = numel(seg_bounds) - 1;
correction = nan(n_asc, 1);

% Pre-allocate per-segment parameter table
seg_params = struct( ...
    'node',   num2cell(nan(n_segs, 1)), ...
    'gain',   num2cell(ones(n_segs, 1)), ...
    'offset', num2cell(nan(n_segs, 1)), ...
    'drift',  num2cell(nan(n_segs, 1)));   % [pH yr⁻¹]

for s = 1:n_segs
    si      = seg_bounds(s);
    ei      = seg_bounds(s + 1);
    seg     = si:ei;
    use     = seg(has_data(seg));
    t_node  = t_days(si);               % reference time = segment start [days]

    seg_params(s).node = si;

    if numel(use) < 2
        off = nanmean(anomaly(use));
        seg_params(s).offset = off;
        seg_params(s).drift  = 0;
        correction(seg) = off;
    else
        % fit: anomaly = offset + drift * (t - t_node)/365
        dt_yr  = (t_days(use) - t_node) / 365;
        p      = polyfit(dt_yr, anomaly(use), 1);   % p(1)=drift, p(2)=offset
        seg_params(s).offset = p(2);
        seg_params(s).drift  = p(1);
        correction(seg) = p(2) + p(1) .* ((t_days(seg) - t_node) / 365);
    end
end

fprintf('Segment correction parameters:\n');
fprintf('  %4s  %5s  %8s  %10s\n', 'node', 'gain', 'offset', 'drift(pH/yr)');
for s = 1:n_segs
    fprintf('  %4d  %5.1f  %+8.4f  %+10.4f\n', ...
        seg_params(s).node, seg_params(s).gain, ...
        seg_params(s).offset, seg_params(s).drift);
end

% Apply per-profile correction to each raw ascending profile
ph_corrected = cell(n_prof, 1);
for ii = 1:n_prof
    asc = data.ph.phase{ii} == 0;
    tmp = data.ph.ph{ii};
    tmp(asc) = tmp(asc) - correction(ii);
    ph_corrected{ii} = tmp;
end

%% Post-correction reference scalar
% The correction is a per-profile scalar, so the corrected reference is
% simply the input reference minus that scalar — valid for all ref_modes.
ph_corr_ref = ph_meas_ref - correction;

resid    = ph_corr_ref - ph_esper_ref;
rms_post = sqrt(nanmean(resid(has_data).^2));

%% Print summary
fprintf('\n--- Correction summary ---\n');
fprintf('Pre-correction:  bias = %+.4f  RMS = %.4f\n', ...
    nanmean(anomaly(has_data)), sqrt(nanmean(anomaly(has_data).^2)));
fprintf('Post-correction: bias = %+.4f  RMS = %.4f\n', ...
    nanmean(resid(has_data)),   sqrt(nanmean(resid(has_data).^2)));

%% ---- Plotting ----
cmap = lines(numel(seg_bounds) - 1);

figure('Position', [50 50 1400 900]);
sgtitle({'pH Reference Anomaly Spray Glider 209', ...
         sprintf('BGC-Argo protocol | ref depth %s | BIC: %d changepoint(s)', ...
                 ref_str, best_k)}, ...
        'FontSize', 23, 'FontWeight', 'bold');

% ---- Plot 1: Measured and ESPER reference pH ----
ax1 = subplot(2, 2, 1);  hold on;
plot(dn_asc,           ph_meas_ref,            'bo', 'MarkerSize', 7);
plot(dn_asc(has_data), ph_esper_ref(has_data), 'ro', 'MarkerSize', 7);
for k = 1:numel(cp_dn)
    xline(cp_dn(k), 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
xlabel('Dive number');  ylabel('pH_{total}');
title(sprintf('(1) Measured vs ESPER reference pH  [%s]', ref_str));
legend({'pH_{meas}', 'pH_{ESPER}'}, 'Location', 'best');
grid on;

% ---- Plot 2: Reference anomaly and drift fit ----
ax2 = subplot(2, 2, 2);  hold on;
plot(dn_asc(has_data), anomaly(has_data), 'ko', 'MarkerSize', 7);
yline(0, 'k:', 'LineWidth', 1);
for s = 1:numel(seg_bounds) - 1
    si  = seg_bounds(s);  ei = seg_bounds(s + 1);
    seg = si:ei;
    use = seg(has_data(seg));
    if ~isempty(use)
        plot(dn_asc(seg), correction(seg), '-', ...
             'Color', cmap(s, :), 'LineWidth', 2);
    end
end
for k = 1:numel(cp_dn)
    xline(cp_dn(k), 'k--', 'LineWidth', 1.2);
end
xlabel('Dive number');  ylabel('\DeltapH  (meas - ESPER)');
title(sprintf('(2) Reference anomaly + drift fit  [%s]', ref_str));
grid on;

% ---- Plot 3: Corrected pH alongside ESPER reference ----
ax3 = subplot(2, 2, 3);  hold on;
plot(dn_asc,           ph_corr_ref,            'bo', 'MarkerSize', 7);
plot(dn_asc(has_data), ph_esper_ref(has_data), 'ro', 'MarkerSize', 7);
for k = 1:numel(cp_dn)
    xline(cp_dn(k), 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
xlabel('Dive number');  ylabel('pH_{total}');
title(sprintf('(3) Corrected pH vs ESPER reference  [%s]', ref_str));
legend({'pH_{corrected}', 'pH_{ESPER}'}, 'Location', 'best');
grid on;

% ---- Plot 4: Post-correction residuals ----
ax4 = subplot(2, 2, 4);  hold on;
plot(dn_asc(has_data), resid(has_data), 'ko', 'MarkerSize', 7, 'HandleVisibility', 'off');
yline(0,          'k:',  'LineWidth', 1, 'HandleVisibility', 'off');
yline( rms_post,  'r--', 'LineWidth', 1, ...
       'DisplayName', sprintf('+/-RMS = %.4f', rms_post));
yline(-rms_post,  'r--', 'LineWidth', 1, 'HandleVisibility', 'off');
for k = 1:numel(cp_dn)
    xline(cp_dn(k), 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
xlabel('Dive number');  ylabel('\DeltapH  (corr - ESPER)');
title(sprintf('(4) Post-correction residuals  [%s]  |  RMS = %.4f', ...
              ref_str, rms_post));
legend('Location', 'best');
grid on;

linkaxes([ax1 ax2 ax3 ax4], 'x');

%% Store results in data.ESPER
data.ESPER.pH_meas_ref   = ph_meas_ref;    % per-profile mean pH at ref depth
data.ESPER.pH_ESPER_ref  = ph_esper_ref;   % per-profile mean ESPER pH at ref depth
data.ESPER.bias          = anomaly;        % per-profile pre-correction anomaly
data.ESPER.correction    = correction;     % per-profile drift correction
data.ESPER.pH_corrected  = ph_corrected;   % cell array of corrected raw pH
data.ESPER.residual      = resid;          % per-profile post-correction residual
data.ESPER.cp_divenum    = cp_dn;
data.ESPER.BIC_vals      = BIC_val;

fprintf('\nResults stored in data.ESPER  (workspace)\n');
