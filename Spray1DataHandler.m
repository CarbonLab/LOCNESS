clear all; close all;
%% Controls:
forceprocess = 0;
sendemails = 1;
dbg = 1;
%%
MissionID = '25706901';
SNID = 'SN069';
basepath = fullfile('\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\','Spray_Data'); % Create basepath to 901805/Spray_Data/
missionpath = fullfile(basepath,MissionID); % Create missionpath to Spray_Data/missionID
file = fullfile(missionpath,"0069.sat");
logfile = 'C:\Users\spraydata\Documents\GitHub\LOCNESS\logs\debugging_log.txt';
%% Determine current file size (bytes)
if isfile(file)
    finfo = dir(file); % Get file info
    fsizeold = finfo.bytes; % Get file size in bytes
    close('all')
    WriteLog(dbg, logfile, 'File exists')
else
    fsizeold = 0;
    WriteLog(dbg, logfile, 'File does not exist')
end
%% Determine new file size (bytes)
command = 'aws s3api head-object --bucket sio-idg --key spray/sushi/active/0069.sat --profile yui'; 
[status, output] = system(command); % Get meta data from AWS .json file w/o downloading it
WriteLog(dbg, logfile, 'Read aws json file size info')

if status == 0
    metadata = jsondecode(output);
    fsizenew = metadata.ContentLength;
    WriteLog(dbg, logfile, 'json decoded')
else
    WriteLog(dbg, logfile, 'failed to decode json')
end
%% Compare current fsize to new fsize. If same stop here. If new > current then download and process data
if fsizenew == fsizeold
    disp('File unchanged')
    WriteLog(dbg, logfile, 'file size unchanged')
    WriteLog(dbg, logfile, 'END OF RUN')
    if forceprocess == 0
        return; % End script
    end
else
    disp('New data received, proceeding with download and processing!')
    WriteLog(dbg, logfile, 'new data received!')
end
%% Download data from IDG's AWS bucket
command = ['aws s3 --profile yui cp s3://sio-idg/spray/sushi/active/0069.sat ', missionpath];
system(command, '-echo');
WriteLog(dbg, logfile, '.sat downloaded')
%% Parse sat file
pmin = 0;
pstep = 2;
pmax = 1000;
pd = 'd'; % bin by depth
opname = 'Ben Werb';
[t,bindata] = allsat(file,pmin,pstep,pmax,pd,opname);
fname_t_struct = fullfile(missionpath,'t_struct.mat');
save(fname_t_struct,'t');
WriteLog(dbg, logfile, 'New data processed to mat file')
%% Make it fit our gliderviz standard format
s.sdn = bindata.time' / 86400 + datenum(1970,1,1); % back to matlab sdn
s.sdn_ = bindata.time_' / 86400 + datenum(1970,1,1); % back to matlab sdn
s.lat = bindata.lat';
s.lon = bindata.lon';
s.lat_ = bindata.lat_';
s.lon_ = bindata.lon_';
s.nxtlat_proj = nan(size(s.lat));
s.nxtlon_proj = nan(size(s.lon));
s.nxtsurface_proj = nan(size(s.sdn));
s.nxtwptlat = nan(size(s.lat));
s.nxtwptlon = nan(size(s.lon));
s.position_QC = zeros(size(s.sdn));
s.depID = MissionID;
vec_vars = fieldnames(s);
s.tc = bindata.t;
s.psal = bindata.s; % abs sal
s.depth_grid = bindata.depth;
s.depth = repmat(s.depth_grid,1,length(s.sdn));
inan = isnan(s.tc);
s.depth(inan) = NaN;
s.pres = sw_pres(s.depth,s.lat);
% s.pdens = bindata.sigma;
s.sigma = bindata.sigma; % sw_pden(data.s{ndive},data.t{ndive},data.p{ndive},0)-1000;
s.rhodamine = bindata.fl;
s.pHin = nan(size(s.depth));
s.pH25atm = nan(size(s.depth));
s.divedir = nan(size(s.depth));
s.divedir(~inan) = 1;
s.ta_canb = nan(size(s.depth));
s.pHin_canb = nan(size(s.depth));
s.pHin_canbtadic = nan(size(s.depth));
s.dic_canb = nan(size(s.depth));
s.pco2in = nan(size(s.depth));
s.co2in = nan(size(s.depth));
s.satarin = nan(size(s.depth));
s.satcain = nan(size(s.depth));
allvars = fieldnames(s);
matvars = allvars(~ismember(allvars,vec_vars));
% now make QC fields
for i = 1:length(matvars)
    s.([matvars{i},'_QC']) = zeros(size(s.tc));
end
%% Back fill all the previous proj data
% proj_fname = fullfile('\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing','Locness','Data','GliderProjectionResults',[char(SNID),'_projections.csv']);
% T = readtable(proj_fname);
% idx = T.lat == s.lat_(2,:)' & T.lon == s.lon_(2,:)';
% s.nxtlat_proj(idx) = 
% 
% 
% s.nxtlat_proj = nan(size(s.lat));
% s.nxtlon_proj = nan(size(s.lon));
% s.nxtsurface_proj = nan(size(s.sdn));
% s.nxtwptlat = nan(size(s.lat));
% s.nxtwptlon = nan(size(s.lon));
%% Calculate next surfacing time and location (_proj)
try
    [s.nxtlat_proj(end), s.nxtlon_proj(end), s.nxtwptlat(end), s.nxtwptlon(end)] = nxtwpt_proj(t,1); % 1 for spray 1
    last_dive_duration = s.sdn_(2,end) - s.sdn_(2,end-1); % current dive end - last dive end factors in surface time
    s.nxtsurface_proj(end) = s.sdn_(2,end)+last_dive_duration; % projected time surfacing time
    WriteLog(dbg,logfile,'Projected next location and surfacing time');
catch % If fail, set nxt_proj as last coordinate
    s.nxtlat_proj(end) = s.lat_(2,end);
    s.nxtlon_proj(end) = s.lon_(2,end);
    s.nxtsurface_proj(end) = s.sdn_(2,end);
    WriteLog(dbg,logfile,'Failed to project next surfacing, replacing with last location and time');
end
%% Save s struct
filename = fullfile(missionpath, [char(MissionID), 'sat.mat']);
save(filename, 's')
WriteLog(dbg, logfile, 's struct created and saved')
%% Save wpt data
% Define the variables
try
    SNID = "SN069";  % example string
    projection_tbl = table( ...
        SNID, ...
        s.sdn(end), ...
        s.lat_(2,end), ...
        s.lon_(2,end), ...
        t.eng.en.wlat(end), ...
        t.eng.en.wlon(end), ...
        s.nxtsurface_proj(end), ...
        s.nxtlat_proj(end), ...
        s.nxtlon_proj(end), ...
        s.nxtwptlat(end), ...
        s.nxtwptlon(end), ...
    'VariableNames', { ...
        'SNID', 'sdn', 'lat', 'lon', ...
        'lastwptlat', 'lastwptlon', ...
        'nxtsurface_proj', 'nxtlat_proj', 'nxtlon_proj', ...
        'nxtwptlat', 'nxtwptlon' ...
    } ...
);
        writetable(projection_tbl,proj_fname,"WriteMode","append");
catch
    WriteLog(dbg,logfile,'Could not write projection table')
    disp('didnt work')
end
%% Send ODSS
if sendemails == 1 % Don't send ODSS if testing
    if ~isnan(s.sdn(end)) && ~isnan(s.lon(end)) && ~isnan(s.lat(end))
        % Update last location to ODSS
        update_ODSS_pos('SN069',s.sdn(end),s.lon(end),s.lat(end)); % last position
        WriteLog(dbg, logfile, 'update odss successful')
    elseif isnan(s.sdn(end)) && isnan(s.lon(end)) && isnan(s.lat(end))
        WriteLog(dbg, logfile, 'update odss not successful - missing location data');
    end
    if ~isnan(s.sdn(end)) && ~isnan(s.nxtlon_proj(end)) && ~isnan(s.nxtlat_proj(end))
        % Update last location to ODSS
%         update_ODSS_pos('SN069_proj',s.nxtsurface_proj(end),s.nxtlon_proj(end),s.nxtlat_proj(end)); % projected position
      update_ODSS_pos('SN069_proj',s.sdn(end),s.nxtlon_proj(end),s.nxtlat_proj(end)); % projected position
        WriteLog(dbg, logfile, 'update odss projected successful')
    elseif isnan(s.nxtsurface_proj(end)) && isnan(s.nxtlon_proj(end)) && isnan(s.nxtlat_proj(end))
        WriteLog(dbg, logfile, 'update odss not successful - missing projected location data');
    end
end
%% Convert to GliderVIZ
convert_sat2gliderviztxt_locness(s,s.depID,true);
WriteLog(dbg, logfile, 'GliderViz file created and uploaded');