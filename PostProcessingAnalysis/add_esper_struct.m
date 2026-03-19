%% Calculate ESPER parameters for the raw spray2 glider values
% Interpolate everything onto the pH pressure grid
missionID = '2507020902';
fname = fullfile("data",[missionID,'.mat']);
load(fname,'data');
BIAS = str2double(readlines('BIAS.txt'));
BIAS = BIAS(1);
%% Preallocate struct variables
ndive = length(data.ph.p);
data.ESPER.ph = cell(ndive,1);
data.ESPER.ph_corrected = cell(ndive,1);
data.ESPER.s = cell(ndive,1);
data.ESPER.t = cell(ndive,1);
data.ESPER.oxumolkg = cell(ndive,1);
data.ESPER.depth = data.ph.p;
data.ESPER.depth = data.ph.depth;
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
%% ESPER(TSO)
for profile = 1:ndive
    iuse = data.ph.depth{profile} > 150 & data.ph.phase{profile} == 0;
    lat = repmat(data.lat(profile,1),length(data.ph.depth{profile}(iuse)),1);
    lon = repmat(data.lon(profile,1),length(data.ph.depth{profile}(iuse)),1);
    sdn = repmat(data.time(profile,1)/86400 + datenum(1970,1,1),length(data.ph.depth{profile}(iuse)),1);
    data.ESPER.ph{profile} = NaN(size(data.ESPER.s{profile})); % Save time by only calc esper for ascent dives below 150 m
    data.ESPER.ph_corrected{profile} = NaN(size(data.ESPER.s{profile}));
    if ~isempty(lat) && ~isempty(lon) && ~isempty(sdn)
        ESP = ESPER_TSO(lat,lon,data.ESPER.depth{profile}(iuse),data.ESPER.s{profile}(iuse),data.ESPER.t{profile}(iuse),data.ESPER.oxumolkg{profile}(iuse),sdn);
        data.ESPER.ph{profile}(iuse) = ESP.pH;
        data.ESPER.ph_corrected{profile}(iuse) = ESP.pH + BIAS;
    else
        continue
    end
    disp(['Finished ',num2str(profile),' / ', num2str(ndive)])
end
% Add info tag
data.ESPER.info =...
    {"ALGORITHM" , "ESPER_MIXED";...
    "BIAS", "MEAN BELOW 150M OF SPEC_INSITU - ESPER_PHIN (QC REMOVED VALUE AT 210 M)";...
    "PH_ADJUSTED", "ESPER_PH - |BIAS|"};
%% Save data struct with new ESPER vars
fsavename = fullfile("data",[missionID,'_esper.mat']);
save(fsavename,"data");