%% Calculate ESPER parameters for the raw spray2 glider values
% Interpolate everything onto the pH pressure grid
missionID = '2507020902';
fname = fullfile("data",[missionID,'.mat']);
load(fname,'data');
BIAS = str2double(readlines('BIAS.txt'));
BIAS = BIAS(1);
%% Optional pump lag adjustment
% ph_cal = 'C:\Users\bwerb\Documents\GitHub\LOCNESS\PostProcessingAnalysis\data\ph_cal_locness_corrected.txt';
% pump_time_lag = 5; % seconds to lag
% data = ph_sp2(data,missionID,'BW','phcalfile',ph_cal,'dt',pump_time_lag);
%% Preallocate struct variables
ndive = length(data.ph.p);
data.ESPER.ph = cell(ndive,1);
data.ESPER.ph_corrected = cell(ndive,1);
data.ESPER.s = cell(ndive,1);
data.ESPER.t = cell(ndive,1);
data.ESPER.oxumolkg = cell(ndive,1);
data.ESPER.depth = data.ph.p;
data.ESPER.depth = data.ph.depth;
data.ESPER.sdn = data.time(:,1)/86400 + datenum(1970,1,1); % Start of dive time
data.ESPER.bias = BIAS;
for n = 1:ndive
    if ~isempty(data.ph.Vrse{n}) & ~isempty(data.ctd.s{n})
        [~,iuse] = unique(data.ctd.time{n});
        dox_flag_good = data.qual.dox.ox{n} == 0;
        if sum(iuse)>1
            % interpolate in time rather than pressure since time is monotonic
            data.ESPER.s{n} = interp1(data.ctd.time{n}(iuse),data.ctd.s{n}(iuse),data.ph.time{n},'linear','extrap'); 
            data.ESPER.t{n} = interp1(data.ctd.time{n}(iuse),data.ctd.t{n}(iuse),data.ph.time{n},'linear','extrap');
            data.ESPER.oxumolkg{n} = interp1(data.dox.time{n}(dox_flag_good),data.dox.oxumolkg{n}(dox_flag_good),data.ph.time{n},'linear','extrap');
        else
            data.ph.ph{n} = nan(size(data.ph.Vrse{n}));
        end

    end

end
%% ESPER(TSO) **SLOW**
% for profile = 1:ndive
%     iuse = data.ph.depth{profile} > 250 & data.ph.phase{profile} == 0;
%     lat = repmat(data.lat(profile,1),length(data.ph.depth{profile}(iuse)),1);
%     lon = repmat(data.lon(profile,1),length(data.ph.depth{profile}(iuse)),1);
%     sdn = repmat(data.time(profile,1)/86400 + datenum(1970,1,1),length(data.ph.depth{profile}(iuse)),1);
%     data.ESPER.ph{profile} = NaN(size(data.ESPER.s{profile})); % Save time by only calc esper for ascent dives below 150 m
%     data.ESPER.ph_corrected{profile} = NaN(size(data.ESPER.s{profile}));
%     if ~isempty(lat) && ~isempty(lon) && ~isempty(sdn)
%         ESP = ESPER_TSO(lat,lon,data.ESPER.depth{profile}(iuse),data.ESPER.s{profile}(iuse),data.ESPER.t{profile}(iuse),data.ESPER.oxumolkg{profile}(iuse),sdn);
%         data.ESPER.ph{profile}(iuse) = ESP.pH;
%         data.ESPER.ph_corrected{profile}(iuse) = ESP.pH + BIAS;
%     else
%         continue
%     end
%     disp(['Finished ',num2str(profile),' / ', num2str(ndive)])
% end
% % Add info tag
% data.ESPER.info =...
%     {"ALGORITHM" , "ESPER_MIXED";...
%     "BIAS", "MEAN BELOW 150M OF SPEC_INSITU - ESPER_PHIN (QC REMOVED VALUE AT 210 M)";...
%     "PH_ADJUSTED", "ESPER_PH - |BIAS|"};
% %% Save data struct with new ESPER vars
% fsavename = fullfile("data",[missionID,'_esper.mat']);
% save(fsavename,"data");

%% ESPER(TSO) - Vectorized across all profiles, all depths and phases **FAST**
% Pre-allocate output cell arrays
data.ESPER.ph           = cellfun(@(x) NaN(size(x)), data.ESPER.s, 'UniformOutput', false);
data.ESPER.ph_corrected = cellfun(@(x) NaN(size(x)), data.ESPER.s, 'UniformOutput', false);

% --- Build concatenated input arrays across all valid profiles ---
all_lat    = [];
all_lon    = [];
all_sdn    = [];
all_depth  = [];
all_s      = [];
all_t      = [];
all_ox     = [];

profile_idx = zeros(ndive, 2);
cursor = 0;

for profile = 1:ndive
    n = length(data.ESPER.depth{profile});

    if n == 0
        profile_idx(profile, :) = [0, 0];
        continue
    end

    lat = repmat(data.lat(profile,1), n, 1);
    lon = repmat(data.lon(profile,1), n, 1);
    sdn = repmat(data.time(profile,1)/86400 + datenum(1970,1,1), n, 1);

    all_lat   = [all_lat;   lat];
    all_lon   = [all_lon;   lon];
    all_sdn   = [all_sdn;   sdn];
    all_depth = [all_depth; data.ESPER.depth{profile}(:)];
    all_s     = [all_s;     data.ESPER.s{profile}(:)];
    all_t     = [all_t;     data.ESPER.t{profile}(:)];
    all_ox    = [all_ox;    data.ESPER.oxumolkg{profile}(:)];

    profile_idx(profile, :) = [cursor + 1, cursor + n];
    cursor = cursor + n;
end

% --- Single ESPER_TSO call ---
if ~isempty(all_lat)
    disp('Running ESPER_TSO on all profiles...');
    ESP_all = ESPER_TSO(all_lat, all_lon, all_depth, all_s, all_t, all_ox, all_sdn);
    disp('ESPER_TSO complete.');
end

% --- Scatter results back into cell arrays ---
for profile = 1:ndive
    r = profile_idx(profile, :);

    if r(1) == 0, continue, end

    idx = r(1):r(2);
    data.ESPER.ph{profile}           = ESP_all.pH(idx);
    data.ESPER.ph_corrected{profile} = ESP_all.pH(idx) + BIAS;
end

% Add info tag
data.ESPER.info = ...
    {"ALGORITHM" , "ESPER_MIXED"; ...
     "BIAS",       "MEAN BELOW 150M OF SPEC_INSITU - ESPER_PHIN (QC REMOVED VALUE AT 210 M)"; ...
     "PH_ADJUSTED","ESPER_PH - |BIAS|"};
%% Save data struct with new ESPER vars
fsavename = fullfile("data",[missionID,'_esper.mat']);
save(fsavename,"data");