function [s] = calcMLD(s, dens_thresh, ref_pres)
% function to calculate the mixed layer depth and average ML properties. 
% created 22 July 2025 by SNT
% last edit 29 July 2025 by SNT

% input:
        % s: struct of glider variables

% optional:
        % dens_thresh: density threshold (kg m^-3) [default = 0.03]
        % ref_pres: reference pressure (dbar) [default = 5]

% output:
    % "timeseries" variables: the mixed layer mean for the ascents and
    % dives individually
        % s.mld_ts = mixed layer (m)
        % s.phin_ts = in situ pH 
        % s.rhodamine_ts = rhodamine (ppb)
        % s.psal_ts = practical salinity (PSU)
        % s.tc_ts = temperature (ºC)
        % s.pH25atm_ts = pH at 25ºC
        % s.direction = dive direction (dive = -1; ascent = 1)

    % mixed layer average variables (mean of dive and ascent)
        % s.mld = mixed layer (m)
        % s.psal_mld = practical salinity (PSU)
        % s.tc_mld = temperature (ºC)
        % s.pHin_mld = in situ pH 
        % s.pH25atm_mld = pH at 25ºC
        % s.rhodamine_mld = rhodamine (ppb)


%% Handle optional inputs
if nargin < 2 || isempty(dens_thresh)
    dens_thresh = 0.03;  % default density threshold in kg m^-3
end

if nargin < 3 || isempty(ref_pres)
    ref_pres = 8;  % default reference pressure in dbar
end

%%
dnms = length(s.sdn) ; % number of dives
[nrows, ncolumns] = size(s.pres);
% calculate dive direction

s.divedir = NaN(nrows, ncolumns) ;
% make mock interpolated pressure grid
mockPres = fillmissing(s.pres,'linear','EndValues','none');
mockPres(1,:) = ones(1,width(mockPres));
s.divedir(2:end,:) = floor(diff(mockPres)) ;
d = s.divedir >= 0 ;
a = s.divedir <= 0 ;
s.divedir(d) = -1; % dives
s.divedir(a) = 1; % ascents
s.divedir(1,:) = -1 ;

%d = isnan(s.pres) ;
%s.divedir(d) = NaN; % no data

% if it is Spray1 glider that samples only on ASCENTS, swap the divedir
if strcmp(s.depID(4:end-2), '069') == 1
    s.divedir = s.divedir .* -1 ;
else
end

% preallocate variables for averages
s.mld = nan(size(s.sdn));
s.psal_mld = nan(size(s.sdn));
s.tc_mld = nan(size(s.sdn));
s.pHin_mld = nan(size(s.sdn));
s.pH25atm_mld = nan(size(s.sdn));
s.rhodamine_mld = nan(size(s.sdn));

% variables for "timeseries" (e.g. dives and ascents separately)
s.time_ts = reshape(s.sdn_,1,[]);
s.lat_ts = reshape(s.lat_,1,[]);
s.lon_ts = reshape(s.lon_,1,[]);
s.mld_ts = [];
s.phin_ts = [];
s.rhodamine_ts = [];
s.psal_ts = [];
s.tc_ts = [];
s.pH25atm_ts = [];
s.direction = [];

for i = 1:dnms
    % separate dive and ascent profiles
    down = s.divedir(:,i) == -1 ;
    up = s.divedir(:,i) == 1 ;

    % catch here if down is empty
if sum(down) <= 1 | sum(~isnan(s.pdens(down,i))) <= 1
        MLDd(i) = NaN;
        phd_mean = NaN;
        rd_mean = NaN;
        psald_mean = NaN;
        tempd_mean = NaN;
        ph25d_mean = NaN;
else
    % Dive first
    % calculate MLD
        pressure_prof = s.pres(down,i); % extract pressure profile
        density_prof = s.pdens(down,i); % extract density profile
        depth_prof = s.depth(down,i); % extract depth profile

        % find closest to reference depth
        [~,ref_idx] = min(abs(pressure_prof-ref_pres));
        % define reference density
        density_ref = density_prof(ref_idx);

    % interpolate pressure and density profs
    xq = 1:100 ;
    k = ~isnan(density_prof);
    density_prof = interp1(pressure_prof(k),density_prof(k), xq) ; clear k
    k = ~isnan(depth_prof);
    depth_prof = interp1(pressure_prof(k), depth_prof(k), xq);

    MLDd_idx = find(density_prof > density_ref+dens_thresh, 1);

    if isempty(MLDd_idx) == 1
            MLDd(i) = NaN ;
        else
            MLDd(i) = depth_prof(MLDd_idx) ; % dive MLD
    end

MLDd_idx = find(s.depth(down,i) > MLDd(i),1);

% calculate average properties
        % pH
            phd = (s.pHin(down,i));
            phd_mean = nanmean(phd(1:MLDd_idx)) ;

            ph25d = (s.pH25atm(down,i));
            ph25d_mean = nanmean(ph25d(1:MLDd_idx)) ;

            % rhodamine
            rd = (s.rhodamine(down,i));
            rd_mean = nanmean(rd(1:MLDd_idx)) ;

            % psal
            psald = (s.psal(down,i));
            psald_mean = nanmean(psald(1:MLDd_idx)) ;
        
            % temp
            tempd = (s.tc(down,i));
            tempd_mean = nanmean(tempd(1:MLDd_idx)) ;
clear pressure_prof density_prof ref_idx density_ref depth_ref
end

% catch if no density profile on ascent
if sum(up) <= 1 || sum(~isnan(s.pdens(up,i))) <= 1
        MLDa(i) = NaN;
        pha_mean = NaN;
        ra_mean = NaN;
        psala_mean = NaN;
        tempa_mean = NaN;
        ph25a_mean = NaN;
else
    % Ascent
    % calculate MLD
        pressure_prof = flipud(s.pres(up,i)); % extract pressure profile
        density_prof = flipud(s.pdens(up,i)); % extract density profile
        depth_prof = flipud(s.depth(up,i)); % extract depth profile

        % find closest to reference depth
        [~,ref_idx] = min(abs(pressure_prof-ref_pres));
        % define reference density
        density_ref = density_prof(ref_idx);

    % interpolate pressure and density profs
    xq = 1:100 ;
    k = ~isnan(density_prof);
    density_prof = interp1(pressure_prof(k),density_prof(k), xq) ; clear k
    k = ~isnan(depth_prof);
    depth_prof = interp1(pressure_prof(k), depth_prof(k), xq);


        MLDa_idx = find(density_prof > density_ref+dens_thresh, 1);
        if isempty(MLDa_idx) == 1
            MLDa(i) = NaN ;
        else
            MLDa(i) = depth_prof(MLDa_idx) ; % ascent MLD
        end

        MLDa_idx = find(flipud(s.depth(up,i)) > MLDa(i),1);

% calculate average properties
        % pH
            pha = flipud(s.pHin(up,i));
            pha_mean = nanmean(pha(1:MLDa_idx)) ;
            
            s.pH25atm(s.pH25atm == -999) = NaN;
            ph25a = flipud(s.pH25atm(up,i));
            ph25a_mean = nanmean(ph25a(1:MLDa_idx)) ;

            % rhodamine 
            ra = flipud(s.rhodamine(up,i));
            ra_mean = nanmean(ra(1:MLDa_idx)) ;

            % psal
            psala = flipud(s.psal(up,i));
            psala_mean = nanmean(psala(1:MLDa_idx)) ;
        
            % temp
            tempa = flipud(s.tc(up,i));
            tempa_mean = nanmean(tempa(1:MLDa_idx)) ;

end
clear pressure_prof density_prof ref_idx density_ref depth_ref

        % save new variables

        % timeseries ML means, both ascents and dives
        s.mld_ts = [s.mld_ts MLDd(i) MLDa(i)] ;
        s.phin_ts = [s.phin_ts phd_mean pha_mean] ;
        s.rhodamine_ts = [s.rhodamine_ts rd_mean ra_mean] ;
        s.psal_ts = [s.psal_ts psald_mean psala_mean] ;
        s.tc_ts = [s.tc_ts tempd_mean tempa_mean] ;
        s.pH25atm_ts = [s.pH25atm_ts ph25d_mean ph25a_mean] ;
        s.direction = [s.direction -1 1];

        % save average of dive and ascent
        s.mld(i) = nanmean([MLDd(i) MLDa(i)]) ;
        s.psal_mld(i) = nanmean([psald_mean psala_mean]) ;
        s.tc_mld(i) = nanmean([tempd_mean tempa_mean]) ;
        s.pHin_mld(i) = nanmean([phd_mean pha_mean]) ;
        s.pH25atm_mld(i) = nanmean([ph25d_mean ph25a_mean]) ;
        s.rhodamine_mld(i) = nanmean([rd_mean ra_mean]) ;

end

end
