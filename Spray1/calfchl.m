function data=calfchl(data, mission, opname, calFilename, verbose)
% Apply chloropyll fluorescence calibration
%
% The actual calibration is another procedure, but here the obtained calibration
% coefficients are applied in the data.fl.
%
% G. Castelao, 30 Aug 2020
%
% Parameters
% ----------
% data : 
%     Spray standard data object
% mission : str
%     Mission name
% opname : str
%     Operator name
% calFilename : str, optional
%     Filename with full path. A csv file with the calibration coefficients
% verbose : bool, optional
%     true or false, to print warnings in the screen or to be quiet.
%
% Return
% ------
%
% data :
%     Same Spray standard data object, with updated fl.
% 
% Example
% -------
% data = calfchl(data, '19901301', 'Gui')
%
% Or defining an alternative calibration CSV table
%
% data = calfchl(data, '19901301', 'Gui', 'fchl_calibration.csv')
%
% Or for debugging
%
% data = calfchl(data, '19901301', 'Gui', true)
%
% Notes
% -----
% - Strongly based on calox().
% - Original fl (i.e. non-calibrated) is preserved as data.orig.fl.
% - An alternative to obtain the calibration coeeficients directly from the API
%     url = 'https://spraydata.ucsd.edu/curation/calibration/chl/';
%     o = weboptions('CertificateFilename','');
%     cal = webread(url, 'mission', mission_name, o);
%     cal = cal.results;
% - If missing calibration coefficients, set data.cal to false.
%

% ==== Handling default values ====
DEFAULT_CALFILE = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Calibration\fchl_calibration';
if nargin < 4
    calFilename = DEFAULT_CALFILE;
    verbose = false;
elseif nargin < 5
    if islogical(calFilename)
        verbose = calFilename;
        calFilename = DEFAULT_CALFILE;
    else
        verbose = false;
    end
end

assert(islogical(verbose), 'calfchl() syntax error. verbose must be boolean')
% Requires MatLab2017
%assert(isfile(calFilename), 'calfchl() error. Calibration file does not exist')

if ~isfield(data, 'fl')
    if verbose == true
        fprintf(1, '%s: ERROR - There is no fl in data\n', mission);
    end
    % Without fl don't even bother to record it.
    return
end

% Version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='calfchl';
data.qual.operator(nop).opentime=round(dn2ut(now));
data.qual.operator(nop).params.filename = calFilename;

% ==== Preserve original data ====
if isfield(data.orig, 'fl')
    assert(all(size(data.orig.fl) == size(data.fl)), 'fl shape is inconsistent.');
    data.fl = data.orig.fl;
else
    if verbose == true
        fprintf(1,'%s - Saving original chlorophyll fluorescence\n',mission);
    end
    data.orig.fl = data.fl;
end

%==== Read calibration ====
% warning('off','MATLAB:table:ModifiedAndSavedVarnames');
T=readtable(calFilename);

%find index to use
% ii=find(strcmp(mission, T.x_mission_) & T.UseFlag);
ii=find(strcmp(mission, T.mission));

% Give up quietly if can't find a calibration
if isempty(ii)
    if verbose == true
        fprintf(1,'%s No fchl calibration\n',mission);
    end

    data.cal.fl = false;

    data.qual.operator(nop).params.gain = 1;
    data.qual.operator(nop).params.power = 1;
    data.qual.operator(nop).params.offset = 0;
    data.qual.operator(nop).params.exp_fl_amp = 0;
    data.qual.operator(nop).params.exp_t_scale = 9e6;

    % Add a note into data.qual.operator!!!!
    data.qual.operator(nop).params.warning = 'No calibration found for this mission.';

    data.qual.operator(nop).closetime=round(dn2ut(now));
    return
end

data.cal.fl = true;

% Get the coefficients
cal = {};
cal.gain = T.gain(ii);
cal.power = T.power(ii);
cal.offset = T.offset(ii);
cal.exp_amp = T.exp_amplitude(ii);
cal.exp_t_scale = T.exp_t_scale_days(ii);


if verbose == true
    if cal.exp_amp > 0
        fprintf(1,'%s %f %f %f %f %i\n',mission,cal.gain,cal.power,cal.offset,cal.exp_amp,cal.exp_t_scale);
    else
        fprintf(1,'%s %f %f %f\n',mission,cal.gain,cal.power,cal.offset);
    end
end


%apply calibration
num=length(data.fl);
% Convert to running time [s] since start of the mission
for n=1:num
    if cal.exp_amp > 0
        t0 = data.time(n, 1) - min(min(data.time));
        t = t0 + 3 / 4 * (data.time(n, 2) - data.time(n, 1));
        offset = cal.offset + cal.exp_amp * exp(-t / cal.exp_t_scale);
    else
        offset = cal.offset;
    end
    fl = data.fl{n} - offset;
    fl(fl < 0) = 0;
    fl = cal.gain * fl .^ cal.power;
    % Avoid negligible small values such as 1e-9, which misguide log plots
    fl(fl < 0.002) = 0;
    data.fl{n} = fl;
end

data.qual.operator(nop).params.gain = cal.gain;
data.qual.operator(nop).params.power = cal.power;
data.qual.operator(nop).params.offset = cal.offset;
data.qual.operator(nop).params.exp_fl_amp = cal.exp_amp;
data.qual.operator(nop).params.exp_t_scale = cal.exp_t_scale;
data.qual.operator(nop).closetime=round(dn2ut(now));
