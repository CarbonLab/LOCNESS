clear all; close all;
%% Controls:
forceprocess = 0;
sendemails = 1;
dbg = 1;
%%
MissionID = '25706901';
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
% WriteLog(dbg, logfile, 'Read aws json file size info')

if status == 0
    metadata = jsondecode(output);
    fsizenew = metadata.ContentLength;
    WriteLog(dbg, logfile, 'json decoded')
else
%     warning('Failed to get file metadata:\n%s', output);
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
%%
pmin = 0;
pstep = 2;
pmax = 1000;
pd = 'd'; % bin by depth
opname = 'Ben Werb';

[t,bindata] = allsat(file,pmin,pstep,pmax,pd,opname);
WriteLog(dbg, logfile, 'New data processed to mat file')

% Make it fit our gliderviz standard format
s.sdn = bindata.time' / 86400 + datenum(1970,1,1); % back to matlab sdn
s.sdn_ = bindata.time_' / 86400 + datenum(1970,1,1); % back to matlab sdn
s.lat = bindata.lat';
s.lon = bindata.lon';
s.lat_ = bindata.lat_';
s.lon_ = bindata.lon_';
s.nxtlat_proj = nan(size(s.lat));
s.nxtlon_proj = nan(size(s.lon));
s.nxtsurface_proj = nan(size(s.sdn));
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
s.pdens = bindata.sigma;
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
[s.nxtlat_proj(end), s.nxtlon_proj(end)] = nxtwpt_proj(t,1); % 1 for spray 1
% last_dive_duration = s.sdn_(2,end) - s.sdn_(1,end); % last dive duration
last_dive_duration = s.sdn_(2,end) - s.sdn_(2,end-1); % current dive end - last dive end factors in surface time
s.nxtsurface_proj(end) = s.sdn_(2,end)+last_dive_duration; % projected time surfacing time
filename = fullfile(missionpath, [char(MissionID), 'sat.mat']);
save(filename, 's')
WriteLog(dbg, logfile, 's struct created and saved')
% Send ODSS
if sendemails == 1 % Don't send ODSS if testing
    % Update last location to ODSS
    update_ODSS_pos('SN069',s.sdn(end),s.lon(end),s.lat(end)); % last position
%     last_dive_duration = s.sdn_(2,end-1) - s.sdn_(1,end-1);
%     prj_time = s.sdn(end)+last_dive_duration; % projected time is same as the previous dive duration + dive_start time
    update_ODSS_pos('SN069_nxtwpt',s.nxtsurface_proj(end),s.nxtlon_proj(end),s.nxtlat_proj(end)); % last position
    WriteLog(dbg, logfile, 'update odss successful')
end
convert_sat2gliderviztxt_locness(s,s.depID,true);
WriteLog(dbg, logfile, 'GliderViz file created and uploaded');