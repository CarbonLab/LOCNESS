classdef LRAUVDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFile = 'remote:lrauv/polaris_merged.csv'; % Need the new filename
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LRAUV';
        localFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LRAUV\polaris_merged.csv';
        glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
        mapProductFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
        mapProductVars = { ...
                    'Cruise', 'Platform', 'Layer', 'CastDirection', ...
                    'unixTimestamp', 'lat', 'lon', 'temperature',...
                    'salinity', 'pHin', 'pH25atm', 'rhodamine', 'MLD', ...
                };
    end
    properties (Access = private)
        ReadOptions    % delimitedTextImportOptions for readtable
    end
    properties (Access = public)
        T_raw % Output from readtable
        T % Table to append to MapProduct
        message
    end

    methods (Access = public)
        function obj = LRAUVDataHandler() % Constructor
            obj.ReadOptions = obj.defaultOptions();
        end

        function downloadStatus = downloadData(obj)
            % DOWNLOADDATA - Use rclone to copy data from remote to local.
            command = sprintf('"%s" copy %s "%s" --checksum', ...
                obj.rclonePath, obj.remoteFile, obj.localFolder);
            [status, ~] = system(command);

            if status == 0
                downloadStatus = true;
            else
                downloadStatus = false;
            end
        end

        function readLRAUVCSV(obj)
            obj.T_raw = readtable(obj.localFile,obj.ReadOptions);
        end

        function buildTableLRAUV(obj)
            if isempty(obj.T_raw)
                obj.T_raw = readtable(obj.localFile,obj.ReadOptions);
            end
            t = obj.T_raw;
            t.datetime = datetime(t.EpochSeconds,'ConvertFrom','posixtime') ;
            t.pressure = NaN(size(t.depth));
            d = t.depth >= 0 ;
            t.pressure(d) = gsw_p_from_z(-1 .* t.depth(d),t.latitude(d)); % check latitude vs latitude fix
            t.unixTimestamp = t.EpochSeconds ; % is this the same?
            t.rhodamine = t.WetLabsBB2FL_Output650 ;
            t.pHin = NaN(size(t.WetLabsBB2FL_Output650)) ;
            t.pH25atm = NaN(size(t.WetLabsBB2FL_Output650)) ;

            % Parameters
            depthMin = 2;
            depthMax = 10;
            maxGapSec = 1800;  % 1 hour
            
            % Sort by datetime
            t = sortrows(t, 'datetime');
            
            % Flag rows within 2–10 m
            inRange = t.depth >= depthMin & t.depth <= depthMax;
            
            % Label continuous in-range segments with <1hr gap
            group = zeros(height(t), 1);
            label = 0;
            for i = 2:height(t)
                if inRange(i)
                    dt = seconds(t.datetime(i) - t.datetime(i-1));
                    if ~inRange(i-1) || dt > maxGapSec
                        label = label + 1;
                    end
                    group(i) = label;
                end
            end
            
            % Get valid profile group labels
            validGroups = unique(group(group > 0));
            
            % Preallocate
            n = length(validGroups);
            profileType = strings(n,1);
            timestamp   = NaT(n,1);
            lat         = NaN(n,1);
            lon         = NaN(n,1);
            temp        = NaN(n,1);
            salt        = NaN(n,1);
            rhod        = NaN(n,1);
            pHin          = NaN(n,1);
            pH25          = NaN(n,1);
            
            % Process each group
            for i = 1:n
                idx = group == validGroups(i);
                segment = t(idx, :);
            
                % Determine direction from depth trend
                d = segment.depth;
                if mean(diff(d), 'omitnan') > 0
                    profileType(i) = "Down";
                    timestamp(i) = segment.datetime(1);  % start datetime for dive
                elseif mean(diff(d), 'omitnan') < 0
                    profileType(i) = "Up";
                    timestamp(i) = segment.datetime(end);  % end datetime for ascent
                else
                    profileType(i) = "unknown";
                    timestamp(i) = segment.datetime(round(end/2));
                end
            
                % Mean stats
                lat(i)  = mean(segment.latitude_fix, 'omitnan');
                lon(i)  = mean(segment.longitude_fix, 'omitnan');
                temp(i) = mean(segment.temperature, 'omitnan');
                salt(i) = mean(segment.salinity, 'omitnan');
                rhod(i) = mean(segment.rhodamine, 'omitnan');
                pHin(i)   = mean(segment.pHin, 'omitnan');  % or pH25atm if preferred
                pH25(i)   = mean(segment.pH25atm, 'omitnan');  % or pH25atm if preferred
            end
            
            % Final table
            profileTable = table(profileType, timestamp, lat, lon, temp, salt, rhod, pHin, pH25);

            % Number of rows to preallocate
            n = height(profileTable);
            
            % Preallocate variables with appropriate types
            Cruise        = strings(n,1);
            Platform      = strings(n,1);
            Layer         = strings(n,1);
            CastDirection = strings(n,1);
            unixTimestamp = NaN(n,1);        % assuming numeric timestamps
            lat           = NaN(n,1);
            lon           = NaN(n,1);
            temperature   = NaN(n,1);
            salinity      = NaN(n,1);
            pHin          = NaN(n,1);
            pH25atm       = NaN(n,1);
            rhodamine     = NaN(n,1);
            MLD           = NaN(n,1);
            
            % Create the table
            Tnew = table(Cruise, Platform, Layer, CastDirection, unixTimestamp, ...
                         lat, lon, temperature, salinity, pHin, pH25atm, ...
                         rhodamine, MLD);
            % Populate the new table with the correct variables from the old
            Tnew.Cruise = repmat("25800001", n, 1); % Replace "CruiseName" with actual cruise name if available
            Tnew.Platform = repmat("LRAUV", n, 1); % Replace "PlatformName" with actual platform name if available
            Tnew.Layer = repmat("MLD", n, 1); % Initialize Layer with empty strings or appropriate values
            Tnew.CastDirection = profileTable.profileType; % Initialize CastDirection with empty strings or appropriate values
            Tnew.unixTimestamp = profileTable.timestamp; % Assuming EpochSeconds is the correct timestamp
            Tnew.lat = profileTable.lat; % Populate latitude
            Tnew.lon = profileTable.lon; % Populate longitude
            Tnew.temperature = profileTable.temp; % Populate temperature
            Tnew.salinity = profileTable.salt; % Populate salinity
            Tnew.pHin = profileTable.pHin; % Initialize pHin with NaN or appropriate values
            Tnew.pH25atm = profileTable.pH25; % Initialize pH25atm with NaN or appropriate values
            Tnew.rhodamine = profileTable.rhod; % Initialize rhodamine with NaN or appropriate values
            Tnew.MLD = NaN(n,1); % Initialize MLD with NaN or appropriate values

            obj.T = Tnew;
        end

        function appendMapProduct(obj)
            % read existing table and find unique rows to append
            if isfile(obj.mapProductFile) && ~isempty(obj.T) % if map file exists and there is data in T
                T_old = readtable(obj.mapProductFile); % Read old table
                T_old.Properties.VariableNames = obj.mapProductVars; % Ensure correct var names
                iappend = ~ismember(obj.T(:,"unixTimestamp"), T_old(:,"unixTimestamp"),'rows'); % Unique row index
                writetable(obj.T(iappend,:),obj.mapProductFile,"WriteMode","append"); % Append new rows
            elseif ~isfile(obj.mapProductFile) && ~isempty(obj.T)
                writetable(obj.T,obj.mapProductFile,"WriteMode","overwrite")
            else
                obj.message = 'No new data to append';
            end
        end
    end

    methods (Static, Access = private)
        function opts = defaultOptions()
            opts = delimitedTextImportOptions("NumVariables", 17);
            opts.DataLines = [2, Inf];
            opts.Delimiter = ",";

            opts.VariableNames = ["datetime", "EpochSeconds", "platform_battery_charge", "depth", ...
                "time_fix", "latitude_fix", "longitude_fix", "platform_average_current", ...
                "height_above_sea_floor", "latitude", "longitude", ...
                "fix_residual_percent_distance_traveled", "temperature", ...
                "salinity", "WetLabsBB2FL_Output650", ...
                "BPC1_reserve_battery_charge", "platform_battery_voltage"];

            opts.SelectedVariableNames = ["datetime", "EpochSeconds", "depth", ...
                "time_fix", "latitude_fix", "longitude_fix", ...
                "latitude", "longitude", "temperature", ...
                "salinity", "WetLabsBB2FL_Output650"];

            opts.VariableTypes = ["string", "double", "string", "double", ...
                "double", "double", "double", "string", ...
                "string", "double", "double", "string", ...
                "double", "double", "double", "string", "string"];

            opts.ExtraColumnsRule = "ignore";
            opts.EmptyLineRule = "read";

            preserveVars = ["platform_battery_charge", "platform_average_current", ...
                "height_above_sea_floor", "fix_residual_percent_distance_traveled", ...
                "BPC1_reserve_battery_charge", "platform_battery_voltage"];

            opts = setvaropts(opts, preserveVars, "WhitespaceRule", "preserve");

            emptyAutoVars = ["platform_battery_charge", "platform_average_current", ...
                "height_above_sea_floor", "fix_residual_percent_distance_traveled", ...
                "WetLabsBB2FL_Output650", "BPC1_reserve_battery_charge", ...
                "platform_battery_voltage"];

            opts = setvaropts(opts, emptyAutoVars, "EmptyFieldRule", "auto");
        end
    end
end
