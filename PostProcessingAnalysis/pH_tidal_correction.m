%% pH tidal harmonic correction
%
% Fits tidal harmonics independently to data.ph.ph and data.ESPER.ph_adjusted
% at each depth level, subtracts the oscillatory tidal signal from each
% (mean preserved), then recomputes the anomaly from the detided series.
%
%   y(t) = a0 + sum_k [ a_k*cos(omega_k*t) + b_k*sin(omega_k*t) ]
%   tidal signal = oscillatory part only (a0 excluded so mean is preserved)
%
% Constituents: M2, S2, N2, K1, O1
% Input: workspace from pH_pipeline_workingScript.m
%        (data, ndive, data.ph.time_unix)

%% Tidal constituents
constituents = struct( ...
    'name', {'M2',      'S2',      'N2',      'K1',      'O1'     }, ...
    'T',    {12.4206,   12.0000,   12.6583,   23.9345,   25.8193  });  % [hours]
nc = numel(constituents);

%% Profile representative time: mean unix time of ascending obs below 150 m
t_prof_unix = nan(ndive, 1);
for ii = 1:ndive
    sel = data.ph.phase{ii} == 0 & data.ph.depth{ii} > 150;
    if ~any(sel); continue; end
    t_prof_unix(ii) = mean(data.ph.time_unix{ii}(sel), 'omitmissing');
end
t0      = min(t_prof_unix, [], 'omitmissing');
t_hours = (t_prof_unix - t0) / 3600;
t_dt    = datetime(t_prof_unix, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

%% Depth levels to analyse
depth_levels = [150, 250, 260, 270, 280];
dz           = 2;      % ±2 m window
ndepths      = numel(depth_levels);

%% Pre-allocate
ph_raw_ts    = nan(ndive, ndepths);
esper_raw_ts = nan(ndive, ndepths);
ph_det_ts    = nan(ndive, ndepths);
esper_det_ts = nan(ndive, ndepths);
anomaly_raw  = nan(ndive, ndepths);
anomaly_det  = nan(ndive, ndepths);
tide_ph      = nan(ndive, ndepths);
tide_esper   = nan(ndive, ndepths);
amp_ph       = nan(nc,    ndepths);
amp_esper    = nan(nc,    ndepths);

%% Fit and detide at each depth
for id = 1:ndepths
    z = depth_levels(id);

    % Per-profile mean pH and ESPER at this depth
    ph_ts    = nan(ndive, 1);
    esper_ts = nan(ndive, 1);
    for ii = 1:ndive
        asc  = data.ph.phase{ii} == 0;
        iuse = asc & data.ph.depth{ii} >= z - dz & data.ph.depth{ii} <= z + dz;
        if ~any(iuse); continue; end
        ph_ts(ii)    = mean(data.ph.ph{ii}(iuse),             'omitmissing');
        esper_ts(ii) = mean(data.ESPER.ph_adjusted{ii}(iuse), 'omitmissing');
    end

    ph_raw_ts(:,id)    = ph_ts;
    esper_raw_ts(:,id) = esper_ts;
    anomaly_raw(:,id)  = ph_ts - esper_ts;

    % Fit and subtract tidal harmonics from pH
    [tide_ph(:,id), amp_ph(:,id)]       = harmonic_fit(t_hours, ph_ts,    constituents, nc);
    [tide_esper(:,id), amp_esper(:,id)] = harmonic_fit(t_hours, esper_ts, constituents, nc);

    ph_det_ts(:,id)    = ph_ts    - tide_ph(:,id);
    esper_det_ts(:,id) = esper_ts - tide_esper(:,id);
    anomaly_det(:,id)  = ph_det_ts(:,id) - esper_det_ts(:,id);

    % Variance explained
    ifit_p = isfinite(t_hours) & isfinite(ph_ts);
    ifit_e = isfinite(t_hours) & isfinite(esper_ts);
    vp  = 100*(1 - var(ph_det_ts(ifit_p,id),'omitnan')    / var(ph_ts(ifit_p),'omitnan'));
    ve  = 100*(1 - var(esper_det_ts(ifit_e,id),'omitnan') / var(esper_ts(ifit_e),'omitnan'));
    fprintf('depth %3d m:  pH tidal var = %5.1f%%   ESPER tidal var = %5.1f%%\n', z, vp, ve);
end

%% Amplitude tables
fprintf('\npH tidal amplitudes [pH units]:\n');
fprintf('%-5s', '');  for id=1:ndepths; fprintf('  %5dm',depth_levels(id)); end; fprintf('\n');
for k=1:nc; fprintf('%-5s',constituents(k).name); for id=1:ndepths; fprintf('  %6.4f',amp_ph(k,id)); end; fprintf('\n'); end

fprintf('\nESPER tidal amplitudes [pH units]:\n');
fprintf('%-5s', '');  for id=1:ndepths; fprintf('  %5dm',depth_levels(id)); end; fprintf('\n');
for k=1:nc; fprintf('%-5s',constituents(k).name); for id=1:ndepths; fprintf('  %6.4f',amp_esper(k,id)); end; fprintf('\n'); end

%% Plot 1: raw pH, tidal fit, detided pH
fig = figure;
set(gcf, 'Position', [67 44 1149 900])
tl = tiledlayout(ndepths, 1, 'TileSpacing', 'compact');
title(tl, 'SN209: raw pH — tidal fit and detided', 'fontsize', 14)
for id = 1:ndepths
    nexttile;  hold on
    plot(t_dt, ph_raw_ts(:,id),  '.', 'Color', [0.7 0.7 0.7],  'MarkerSize', 6)
    plot(t_dt, ph_det_ts(:,id),  '.', 'Color', [0 0.447 0.741],'MarkerSize', 6)
    plot(t_dt, tide_ph(:,id) + mean(ph_raw_ts(:,id),'omitmissing'), ...
         '-', 'Color', [0.85 0.2 0.1], 'LineWidth', 1.5)
    ylabel(sprintf('%d m', depth_levels(id)));  grid on
end
legend('raw pH', 'detided pH', 'tidal fit (offset to mean)', 'Location', 'best')
saveas(fig, 'SN209_pH_detided.png')

%% Plot 2: raw ESPER, tidal fit, detided ESPER
fig = figure;
set(gcf, 'Position', [67 44 1149 900])
tl = tiledlayout(ndepths, 1, 'TileSpacing', 'compact');
title(tl, 'SN209: ESPER pH — tidal fit and detided', 'fontsize', 14)
for id = 1:ndepths
    nexttile;  hold on
    plot(t_dt, esper_raw_ts(:,id), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 6)
    plot(t_dt, esper_det_ts(:,id), '.', 'Color', [1 0 0],        'MarkerSize', 6)
    plot(t_dt, tide_esper(:,id) + mean(esper_raw_ts(:,id),'omitmissing'), ...
         '-', 'Color', [0.85 0.2 0.1], 'LineWidth', 1.5)
    ylabel(sprintf('%d m', depth_levels(id)));  grid on
end
legend('raw ESPER', 'detided ESPER', 'tidal fit (offset to mean)', 'Location', 'best')
saveas(fig, 'SN209_ESPER_detided.png')

%% Plot 3: anomaly before and after detiding
fig = figure;
set(gcf, 'Position', [67 44 1149 900])
tl = tiledlayout(ndepths, 1, 'TileSpacing', 'compact');
title(tl, 'SN209: pH–ESPER anomaly — raw vs detided', 'fontsize', 14)
for id = 1:ndepths
    nexttile;  hold on
    plot(t_dt, anomaly_raw(:,id), '.', 'Color', [0.7 0.7 0.7],  'MarkerSize', 6)
    plot(t_dt, anomaly_det(:,id), '.', 'Color', [0 0.447 0.741], 'MarkerSize', 6)
    yline(0, '--k', 'LineWidth', 0.8)
    ylabel(sprintf('%d m', depth_levels(id)));  grid on
end
legend('raw \DeltapH', 'detided \DeltapH', 'Location', 'best')
saveas(fig, 'SN209_anomaly_detided.png')

%% Plot 4: tidal amplitudes — pH vs ESPER
fig = figure;
set(gcf, 'Position', [67 44 900 500])
tl = tiledlayout(1, 2, 'TileSpacing', 'compact');
title(tl, 'SN209: tidal amplitudes by constituent', 'fontsize', 14)
cmap = lines(nc);

nexttile;  hold on
for k = 1:nc
    plot(amp_ph(k,:), depth_levels, 'o-', 'Color', cmap(k,:), ...
         'LineWidth', 1.5, 'MarkerFaceColor', cmap(k,:), 'DisplayName', constituents(k).name)
end
set(gca,'YDir','reverse');  grid on
xlabel('amplitude (pH units)');  ylabel('depth (m)');  title('raw pH')
legend('Location', 'best')

nexttile;  hold on
for k = 1:nc
    plot(amp_esper(k,:), depth_levels, 'o-', 'Color', cmap(k,:), ...
         'LineWidth', 1.5, 'MarkerFaceColor', cmap(k,:), 'HandleVisibility', 'off')
end
set(gca,'YDir','reverse');  grid on
xlabel('amplitude (pH units)');  title('ESPER')
saveas(fig, 'SN209_tidal_amplitudes.png')

%% -----------------------------------------------------------------------
function [tide, amp_out] = harmonic_fit(t_h, y, constituents, nc)
% Fit tidal harmonics; return oscillatory signal (mean excluded) and amplitudes.
    tide    = nan(size(t_h));
    amp_out = nan(nc, 1);

    ifit = isfinite(t_h) & isfinite(y);
    if sum(ifit) < 2*nc + 5;  return;  end

    t_f = t_h(ifit);
    y_f = y(ifit);

    A = ones(sum(ifit), 1 + 2*nc);
    for k = 1:nc
        w = 2*pi / constituents(k).T;
        A(:, 2*k)   = cos(w * t_f);
        A(:, 2*k+1) = sin(w * t_f);
    end
    coef = A \ y_f;

    osc = zeros(numel(t_h), 1);
    for k = 1:nc
        w   = 2*pi / constituents(k).T;
        osc = osc + coef(2*k)   * cos(w * t_h) ...
                  + coef(2*k+1) * sin(w * t_h);
        amp_out(k) = sqrt(coef(2*k)^2 + coef(2*k+1)^2);
    end
    tide = osc;
end
