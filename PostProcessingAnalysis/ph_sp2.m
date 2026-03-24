function data = ph_sp2(data,mission,opname,varargin)

% Compute pH using calibration coefficients from MBARI. Input can be
% near-realtime (satdata) or flash (data).
% 
% Optional parameter/value inputs:
% - 'phcalfile', name (and path) to ph calibration file
% - 'dt', number of seconds to shift pH back in time to align with CTD
%
% Robert Todd, 4 September 2025
% Robert Todd, 30 September 2025, switch to storing pH_total instead of
% pH_free per Ben W. (MBARI).
% Robert Todd, 1 October 2025, avoid error if dive too short
% Robert Todd, 6 October 2025, catch to run if no calibration data; include
% initialzation of ph fields from ctdvars_sp2.m (satdata)/flashvars_sp2.m
% (flash)
% Robert Todd, 7 October 2025, applies psurf to flash but not sat (already
% done in json); Use Ctd_Good to initialize quality field; optional calfile
% input
% Dan Rudnick, 7 October 2025, survives not finding calibration file, fixed
% dimensions of Pcoefs when no calibration is available, fixed behavior
% when no calibration is found in file, write out calibrations used as in
% calox
% Robert Todd, 16 October 2025, switch to parameter/value pairs for
% optional inputs
% Robert Todd, 17 November 2025, initialize depth adn qual.ph fields
% Robert Todd, 5 December 2025, change sum(iuse) to length(iuse) in
% conditional before interpolation
% Robert Todd, 4 March 2026, implement time shift in flash processing to 
% account for plumbing
% Robert Todd, 5 March 2026, handle psurf correctly when shifting in time

% parameters
%calfile = '/Users/Shared/spray/data/csv/ph_cal.csv';
calfile = '/Users/straylor/Library/CloudStorage/GoogleDrive-straylor@mbari.org/My Drive/LOCNESS/data/ph_cal_locness_corrected.csv';
Ctd_Good = 0;
dt = 0; % default time shift, s

% parse inputs
if nargin > 3
    nopt = length(varargin)/2;
    if nopt~=ceil(nopt) % not even number optional inputs
        error('ph_sp2.m: Wrong number of inputs!');
    end
    for iopt = 1:nopt
        switch varargin{2*iopt-1}
            case 'phcalfile'
                calfile = varargin{2*iopt};
            case 'dt'
                dt = varargin{2*iopt};
            otherwise
                error('ph_sp2.m: Wrong optional parameter input!')
        end
    end
end

% determine if flash or sat data;
if isfield(data.eng,'psurf') % flash
    isflash = true;
else % sat
    isflash = false;
end

% version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='ph_sp2';
data.qual.operator(nop).params.calfile = calfile;
data.qual.operator(nop).params.Ctd_Good = Ctd_Good;
data.qual.operator(nop).params.dt = dt;
data.qual.operator(nop).opentime=round(dn2ut(now));

ndive = length(data.ph.p);
data.ph.depth = cell(ndive,1);
data.qual.ph.ph = cell(ndive,1);

% time shift for flash
if isflash & dt ~= 0
    
    % Check if ph_sp2 has already been run, so that data.orig.ph exists.
    % Then save original data, or bring it forward to use in the calculation.
    if ~isfield(data.orig,'ph') % ph_sp2 has not previously been run
        data.orig.ph.time = data.ph.time;
        data.orig.ph.p = data.ph.p;
        % should phase be adjusted???-------------------------------------
    else % ph_sp2 has been run before
        data.ph.time = data.orig.ph.time;
        data.ph.p = data.orig.ph.p;
    end

    % shift time backwards by dt, get pressure by interpolation from CTD
    for n = 1:ndive
        if ~isempty(data.ph.time{n}) & ~isempty(data.ctd.time{n})
            data.ph.time{n} = data.ph.time{n}-dt;
            t = data.ctd.time{n};
            p = data.ctd.p{n}+data.eng.psurf(n); % psurf not yet applied to data.ph.p, so being consistent here
            [t,ii] = unique(t);
            p = p(ii);
            data.ph.p{n} = interp1(t,p,data.ph.time{n});
        end
    end

end

for n = 1:ndive
    % compute depth for pH
    if ~any(isnan(data.lat(n,:)))
        t = data.ph.time{n}+data.time(n,1);
        lat = interp1(data.time(n,:),data.lat(n,:),t);
    elseif any(~isnan(data.lat(n,:))) % then use the one good fix
        lat = mean(data.lat(n,:),'omitnan');
    else
        lat = NaN;
    end
    if isflash
        data.ph.p{n}=data.ph.p{n}-data.eng.psurf(n);
    end
    data.ph.depth{n}=sw_dpth(data.ph.p{n},lat);

    % initialize qc field
    data.qual.ph.ph{n}=Ctd_Good*ones(size(data.ph.time{n}));
end

% read calibration file and find row for this mission
if exist(calfile,"file")
    opts = delimitedTextImportOptions("NumVariables", 11);

    % Specify range and delimiter
    opts.DataLines = [2, Inf];
    opts.Delimiter = ",";
    
    % Specify column names and types
    opts.VariableNames = ["Mission", "FETSN", "k0", "k2", "fp_k0", "fp_k1", "fp_k2", "fp_k3", "fp_k4", "fp_k5", "fp_k6"];
    opts.VariableTypes = ["string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double"];

    % Specify file level properties
    opts.ExtraColumnsRule = "ignore";
    opts.EmptyLineRule = "read";

    % Specify variable properties
    opts = setvaropts(opts, "FETSN", "WhitespaceRule", "preserve");
    opts = setvaropts(opts, "FETSN", "EmptyFieldRule", "auto");

   ph_cal = readtable(calfile,opts);
   missions = ph_cal{:,1};
   imission = find(strcmp(missions,mission));
   if ~isempty(imission) % found calibration data
      data.cal.ph = true;
      k0 = ph_cal{imission,3};
      k2 = ph_cal{imission,4};
      Pcoefs = ph_cal{imission,6:11}';
   else
      data.cal.ph = false;
      k0 = NaN; % will make computed pH = NaN
      k2 = NaN;
      Pcoefs = nan(6,1);
      fprintf(1,'%s No pH Calibration\n',mission);
   end
else
   data.cal.ph = false;
   k0 = NaN; % will make computed pH = NaN
   k2 = NaN;
   Pcoefs = nan(6,1);
   fprintf(1,'ph_sp2: ph exists but no Calibration file.\n');
end

%write what is happening
fprintf(1,'pH %s %f %f\n',mission,k0,k2);

data.qual.operator(nop).params.k0 = k0;
data.qual.operator(nop).params.k2 = k2;
data.qual.operator(nop).params.Pcoefs = Pcoefs;

% interpolate t,s to p of pressure and compute ph
data.ph.ph = cell(ndive,1);
for n = 1:ndive

    if ~isempty(data.ph.Vrse{n})

        [~,iuse] = unique(data.ctd.time{n});
        if length(iuse)>1
            ss = interp1(data.ctd.time{n}(iuse),data.ctd.s{n}(iuse),data.ph.time{n},'linear','extrap'); % interpolate in time rather than pressure since time is monotonic
            tt = interp1(data.ctd.time{n}(iuse),data.ctd.t{n}(iuse),data.ph.time{n},'linear','extrap');

            [~,data.ph.ph{n}] = phcalc_jp(data.ph.Vrse{n},data.ph.p{n},tt,ss,k0,k2,Pcoefs);

        else
            data.ph.ph{n} = nan(size(data.ph.Vrse{n}));
        end

    end

end

% version control
data.qual.operator(nop).closetime=round(dn2ut(now));