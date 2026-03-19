% checking pH vs ESPER lag

%% xcorr on full profiles — no interpolation needed

dt_mean = mean(diff(data.time(:,1))) / 3600;   % mean hours between profile starts

z_grid = (100:1:300)';  % adjust to your depth range
nz = length(z_grid);

% build depth x profile matrices by finding nearest depth index
pH_grid    = nan(nz, ndive);
ESPER_grid = nan(nz, ndive);

for iz = 1:nz
    for prof = 1:ndive
        iuse = data.ph.depth{prof} == z_grid(iz) &data.ph.phase{prof} == 0;
        if any(iuse)
            pH_grid(iz, prof)    = mean(data.ph.ph{prof}(iuse),              'omitmissing');
            ESPER_grid(iz, prof) = mean(data.ESPER.ph_adjusted{prof}(iuse),  'omitmissing');
        end
    end
end

%% xcorr depth-by-depth
max_lag = 20;  % profiles
r_matrix    = nan(2*max_lag+1, nz);
lag_peak_by_depth = nan(1, nz);
r_peak_by_depth   = nan(1, nz);

for iz = 1:nz
    x = pH_grid(iz, :);
    y = ESPER_grid(iz, :);

    iuse = ~isnan(x) & ~isnan(y);
    if sum(iuse) < 10; continue; end

    x = x(iuse) - mean(x(iuse));
    y = y(iuse) - mean(y(iuse));

    [r, lags] = xcorr(x, y, max_lag, 'normalized');
    r_matrix(:, iz) = r;

    [~, ipeak] = max(abs(r));
    lag_peak_by_depth(iz) = lags(ipeak);
    r_peak_by_depth(iz)   = r(ipeak);
end

lags_hours = lags * dt_mean;  % from earlier

%% plot 1: xcorr as depth x lag heatmap
fig = figure;
set(gcf,'Position',[500 44 600 700])
imagesc(lags_hours, z_grid, r_matrix')
set(gca,'YDir','reverse')
cmocean('balance')   % or 'RdBu' via cmocean if you have it
clim([-1 1])
cb = colorbar; ylabel(cb, 'correlation')
xlabel('lag (hours)')
ylabel('depth (m)')
title('SN209: xcorr(raw pH, ESPER pH) by depth', 'Interpreter', 'none')
xline(0, '--k', 'LineWidth', 1.5)
xline( 12.42, ':w', 'M2',  'LabelVerticalAlignment','bottom','LabelHorizontalAlignment','center')
xline(-12.42, ':w', 'LineWidth', 1)
saveas(fig, 'SN209_xcorr_depth_heatmap.png')

%% plot 2: peak lag vs depth and peak r vs depth
fig = figure;
set(gcf,'Position',[67 44 800 500])
tl = tiledlayout(1, 2);
title(tl, 'SN209: xcorr peak by depth', 'Interpreter', 'none', 'fontsize', 16)

nexttile
plot(lag_peak_by_depth * dt_mean, z_grid, 'k', 'LineWidth', 1.5)
xline(0, '--r')
xline( 12.42, ':b', 'M2')
xline(-12.42, ':b')
set(gca,'YDir','reverse')
xlabel('lag at peak r (hours)'); ylabel('depth (m)')
grid on

nexttile
plot(r_peak_by_depth, z_grid, 'k', 'LineWidth', 1.5)
xline(0, '--k')
set(gca,'YDir','reverse')
xlabel('peak |r|'); ylabel('depth (m)')
xlim([0 1]); grid on

saveas(fig, 'SN209_xcorr_peak_by_depth.png')

%% xcorr within each profile — lag in time [seconds]
% ESPER is derived from CTD, which is believed to sample ~14 s before the
% pH sensor sees the same water.  xcorr(ph, esper) in sample space finds
% the optimal shift to apply to ESPER to best match raw pH.
%
% Convention: positive lag means ESPER leads pH (CTD faster than pH),
% so we expect peak near +14 s if the hypothesis holds.
% Restricts to ascending obs (phase==0) where ESPER is valid (depth>=150m).

max_lag_s = 60;   % maximum lag to search [s]

lag_peak_s  = nan(ndive, 1);   % optimal lag per profile [s]
r_peak      = nan(ndive, 1);   % correlation at peak
dt_profile  = nan(ndive, 1);   % median sample interval per profile [s]
r_all_t     = [];              % will store xcorr rows after first valid profile
lags_s_ref  = [];

for ii = 1:ndive
    asc      = data.ph.phase{ii} == 0;
    dep      = data.ph.depth{ii};
    ph       = data.ph.ph{ii};
    esp      = data.ESPER.ph_adjusted{ii};
    t        = data.ph.time{ii};   % seconds within segment

    % ascending obs where ESPER is valid
    valid = asc & dep >= 150 & isfinite(ph) & isfinite(esp);
    if sum(valid) < 20; continue; end

    ph_v  = ph(valid);
    esp_v = esp(valid);
    t_v   = t(valid);

    dt = median(diff(t_v));           % sample interval [s]
    if ~isfinite(dt) || dt <= 0; continue; end
    dt_profile(ii) = dt;

    max_lag_n = round(max_lag_s / dt);

    x = ph_v  - mean(ph_v);
    y = esp_v - mean(esp_v);

    [r, lags_n] = xcorr(x, y, max_lag_n, 'normalized');
    lags_s      = lags_n * dt;       % convert samples → seconds

    % store on a common lag grid after first valid profile
    if isempty(lags_s_ref)
        lags_s_ref = lags_s;
        r_all_t    = nan(ndive, numel(lags_s));
    end

    % only accumulate if lag grid matches (same dt)
    if numel(lags_s) == numel(lags_s_ref) && ...
            abs(lags_s(1) - lags_s_ref(1)) < 0.5
        r_all_t(ii, :) = r;
    end

    [~, ipeak]      = max(r);        % peak of positive correlation
    lag_peak_s(ii)  = lags_s(ipeak);
    r_peak(ii)      = r(ipeak);
end

n_valid = sum(~isnan(lag_peak_s));
med_lag = median(lag_peak_s, 'omitnan');
med_dt  = median(dt_profile,  'omitnan');
fprintf('Per-profile time-lag xcorr: %d / %d profiles valid\n', n_valid, ndive);
fprintf('Median sample interval: %.1f s\n', med_dt);
fprintf('Median optimal lag: %.1f s   (hypothesis: +14 s)\n', med_lag);

%% Plot 1: histogram of per-profile optimal lag
fig = figure;
set(gcf, 'Position', [67 44 600 400])
histogram(lag_peak_s, 'BinWidth', med_dt, ...
          'FaceColor', [0.4667 0.6745 0.1882], 'EdgeColor', 'none')
hold on
xline(0,    '--k',  'LineWidth', 1.2)
xline(14,   '-r',   '14 s hypothesis', 'LineWidth', 1.5, ...
      'LabelVerticalAlignment', 'bottom')
xline(med_lag, '--b', sprintf('median = %.1f s', med_lag), ...
      'LineWidth', 1.5, 'LabelVerticalAlignment', 'top')
xlabel('optimal lag (s)');  ylabel('profiles')
title('SN209: per-profile xcorr peak lag — raw pH vs ESPER', ...
      'Interpreter', 'none')
grid on
saveas(fig, 'SN209_xcorr_lag_histogram.png')

%% Plot 2: mean xcorr across profiles (on common lag grid)
mean_r_t = mean(r_all_t, 1, 'omitmissing');

fig = figure;
set(gcf, 'Position', [67 44 700 400])
plot(lags_s_ref, mean_r_t, 'Color', [0.4667 0.6745 0.1882], 'LineWidth', 1.5)
hold on
xline(0,    '--k', 'LineWidth', 1.2)
xline(14,   '-r',  '14 s', 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom')
xline(med_lag, '--b', sprintf('median peak = %.1f s', med_lag), ...
      'LineWidth', 1.2, 'LabelVerticalAlignment', 'top')
yline(0, '-k', 'LineWidth', 0.8)
xlabel('lag (s)');  ylabel('mean r')
title('SN209: mean per-profile xcorr(raw pH, ESPER) in time', ...
      'Interpreter', 'none')
xlim([-max_lag_s max_lag_s]);  grid on
saveas(fig, 'SN209_xcorr_mean_time.png')

%% Plot 3: optimal lag vs profile number
fig = figure;
set(gcf, 'Position', [67 44 1149 400])
scatter(1:ndive, lag_peak_s, 15, r_peak, 'filled')
cb = colorbar;  ylabel(cb, 'r at peak')
clim([0 1]);    cmocean('matter')
hold on
yline(0,      '--k', 'LineWidth', 1.2)
yline(14,     '-r',  '14 s', 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom')
yline(med_lag, '--b', sprintf('median = %.1f s', med_lag), ...
      'LineWidth', 1.2, 'LabelVerticalAlignment', 'top')
xlabel('profile');  ylabel('optimal lag (s)')
title('SN209: per-profile optimal ESPER lag — raw pH vs ESPER', ...
      'Interpreter', 'none')
grid on
saveas(fig, 'SN209_xcorr_lag_per_profile.png')