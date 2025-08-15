classdef ShipDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFile_parquet = 'remote:/synthetic_data/locness.parquet';
        localFolder_parquet = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\RVConnecticut';
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness';
        glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
        mapProductFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
        mapProductVars = { ...
                    'Cruise', 'Platform', 'Layer', 'CastDirection', ...
                    'unixTimestamp', 'lat', 'lon', 'temperature',...
                    'salinity', 'pHin', 'pH25atm', 'rhodamine', 'MLD', ...
                };
        shipDataVars = {'datetime_utc','id','latitude','longitude','rho_ppb','ph_total','ph_corrected', 'temp','salinity'}
        table_name = 'locness-underway-summary';
    end
    properties (Access = private)
        TT  % The resampled timetable
    end
    properties (Access = public)
        currentPosition
        T_resample
        dynamodb_status
        tbl % Raw table
        Currentidx
    end

    methods
        function downloadStatus = downloadData(obj)
            % DOWNLOADDATA - Use rclone to copy data from remote to local.
            command = sprintf('"%s" copy %s "%s" --checksum', ...
                obj.rclonePath, obj.remoteFile_parquet, obj.localFolder_parquet);
            [status, ~] = system(command);

            if status == 0
                downloadStatus = true;
            else
                downloadStatus = false;
            end
        end

        function querytable(obj, ntime, limit)
            % Single query for current time - ntime hours
            % Returns tbl: all data available at 0.5 Hz resolution
            if nargin < 2
                ntime = 1; % default 1 hour of data
            end
            if nargin < 3
                limit = '2700'; % limit is 90 min, 1:30 of data
            end
            end_time = datetime('now', 'Format', 'uuuu-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC');
            start_time = end_time - hours(ntime);
            key_condition = '"static_partition = :pk AND datetime_utc BETWEEN :start_dt AND :end_dt"';
            attr_values = ['"{\":pk\":{\"S\":\"data\"},\":start_dt\":{\"S\":\"', char(start_time), '\"},\":end_dt\":{\"S\":\"', char(end_time), '\"}}"'];
%             limit = '2700';
            region = 'us-east-1';
            profile = 'RVCONNDB';
            command = sprintf('aws dynamodb query --table-name %s --key-condition-expression %s --expression-attribute-values %s --limit %s --region %s --output json --profile %s', ...
                obj.table_name, key_condition, attr_values, limit, region, profile);
            [obj.dynamodb_status, output] = system(command);
            result = jsondecode(output);
            % Use the function
            obj.tbl = dynamodb_to_table(result.Items);
            obj.tbl(end,:) = []; % Last table entry is usually 0 likely because mid upload
        end

        function FindLastIndex(obj)
            t = obj.tbl;
            % Columns to check
            colsToCheck = {'vrse','ph_total','latitude','longitude','ph_corrected',...
                'ph_corrected_ma','ph_total_ma','rho_ppb','salinity','temp'};
            
            % Start from last row
            rowIdx = height(t);
            
            while rowIdx > 0
                rowData = table2array(t(rowIdx, colsToCheck));
                
                if all(rowData ~= 0) % No zeros found
                    break; % Found the row we want
                end
                
                rowIdx = rowIdx - 1; % Move up
            end
            
            obj.Currentidx = rowIdx;
        end

        function resampleData(obj, n)
            % Faster resample by picking last row in each n-minute bin, aligned to :00,
            % except last bin keeps original timestamp.
        
            T = obj.tbl;
        
            % Ensure datetime type
            if ~isdatetime(T.datetime_utc)
                T.datetime_utc = datetime(T.datetime_utc, ...
                    'InputFormat', 'yyyy-MM-dd HH:mm:ss', ...
                    'TimeZone', 'UTC');
            end
        
            % Sort if needed
            if ~issorted(T.datetime_utc)
                T = sortrows(T, 'datetime_utc');
            end
        
            % Align bins to top-of-hour
            startTime = dateshift(T.datetime_utc(1), 'start', 'hour');
            minutesSinceStart = minutes(T.datetime_utc - startTime);
            binIdx = floor(minutesSinceStart / n);
        
            % Bin start times for each row
            binStartTimes = startTime + minutes(binIdx * n);
        
            % Identify last row in each bin
            isLastInBin = [diff(binIdx) ~= 0; true];
        
            % Keep only last rows
            T_resampled = T(isLastInBin, :);
        
            % Relabel timestamps for all but last bin
            binEndTimes = binStartTimes(isLastInBin) + minutes(n);
            T_resampled.datetime_utc(1:end-1) = binEndTimes(1:end-1);
        
            % Store
            obj.T_resample = T_resampled;
        end
        
        function GetCurrentData(obj)
            obj.querytable(1/60); % query 1 minute of data
            obj.FindLastIndex; % idx last non zero row
            obj.T_resample = obj.tbl(obj.Currentidx,:); % Last data point
        end

        function copyToGliderviz(obj)
            % COPYTOGLIDERVIZ - Copy file to the Gliderviz folder
            copyfile(obj.mapProductFile, obj.glidervizFolder);
        end
        
        function CurrentLocation(obj)
        % Build table to update odss
            T_resample_local = obj.T_resample;
            nRows = length(T_resample_local.datetime_utc);
           
            MapProduct = table( ...
                strings(nRows,1), ...           % Cruise
                strings(nRows,1), ...           % Platform
                strings(nRows,1), ...           % Layer
                strings(nRows,1), ...           % Cast direction
                NaN(nRows,1), ...               % unixTimestamp as datetime (or use double if raw Unix time)
                NaN(nRows,1), ...               % lat
                NaN(nRows,1), ...               % lon
                NaN(nRows,1), ...               % temperature
                NaN(nRows,1), ...               % salinity
                NaN(nRows,1), ...               % pHin
                NaN(nRows,1), ...               % pH25atm
                NaN(nRows,1), ...               % rodamine
                NaN(nRows,1), ...               % MLD
                'VariableNames', obj.mapProductVars);
            MapProduct.Cruise = repmat("RV Connecticut",nRows,1);
            MapProduct.Platform = repmat("Ship",nRows,1);
            MapProduct.Layer = repmat("MLD",nRows,1);
            MapProduct.CastDirection = repmat("Constant",nRows,1); % Always mean for ship data
            MapProduct.unixTimestamp = posixtime(T_resample_local.datetime_utc); % unix
            MapProduct.lat = T_resample_local.latitude;
            MapProduct.lon = T_resample_local.longitude;
            MapProduct.temperature = T_resample_local.temp;
            MapProduct.salinity = T_resample_local.salinity;
            MapProduct.pHin = T_resample_local.ph_corrected; % calculated with t,s
            MapProduct.pH25atm = NaN(size(T_resample_local.ph_total));
            MapProduct.rhodamine = T_resample_local.rho_ppb;
            MapProduct.MLD = NaN(size(T_resample_local.ph_total));

            obj.currentPosition = MapProduct;
        end

        function AppendCurrentLocation(obj)
            % Build table to update odss
            obj.GetCurrentData;
            obj.CurrentLocation;

            % Check if only one location
            if height(obj.currentPosition) ~= 1
                return; % No valid location to append
            end
            % Check if file exists
            fileExists = isfile(obj.mapProductFile);
            % Retry settings
            maxRetries = 5;   % number of times to try
            waitSeconds = 1;  % pause between tries (seconds)
             % Wait until file is not locked (only if it exists)
            if fileExists
                retryCount = 0;
                while retryCount < maxRetries
                    [fid, msg] = fopen(obj.mapProductFile, 'a');
                    if fid ~= -1
                        fclose(fid); % file is available
                        break;
                    else
                        retryCount = retryCount + 1;
                        pause(waitSeconds);
                    end
                end
        
                % If after retries it’s still locked, give up
                if fid == -1
                    warning('Could not access "%s" after %d retries: %s', obj.mapProductFile, maxRetries, msg);
                    return;
                end
            end
            % Append or create file
            if fileExists
                writetable(obj.currentPosition, obj.mapProductFile, "WriteMode", "append");
            else
                writetable(MapProduct, obj.mapProductFile, "WriteMode", "overwrite");
            end
        end

        function appendMapProduct(obj)
            T_resample_local = obj.T_resample;
            nRows = length(T_resample_local.datetime_utc);
           
            MapProduct = table( ...
                strings(nRows,1), ...           % Cruise
                strings(nRows,1), ...           % Platform
                strings(nRows,1), ...           % Layer
                strings(nRows,1), ...           % Cast direction
                NaN(nRows,1), ...               % unixTimestamp as datetime (or use double if raw Unix time)
                NaN(nRows,1), ...               % lat
                NaN(nRows,1), ...               % lon
                NaN(nRows,1), ...               % temperature
                NaN(nRows,1), ...               % salinity
                NaN(nRows,1), ...               % pHin
                NaN(nRows,1), ...               % pH25atm
                NaN(nRows,1), ...               % rodamine
                NaN(nRows,1), ...               % MLD
                'VariableNames', obj.mapProductVars);
            MapProduct.Cruise = repmat("RV Connecticut",nRows,1);
            MapProduct.Platform = repmat("Ship",nRows,1);
            MapProduct.Layer = repmat("MLD",nRows,1);
            MapProduct.CastDirection = repmat("Constant",nRows,1); % Always mean for ship data
            MapProduct.unixTimestamp = posixtime(T_resample_local.datetime_utc); % unix
            MapProduct.lat = T_resample_local.latitude;
            MapProduct.lon = T_resample_local.longitude;
            MapProduct.temperature = T_resample_local.temp;
            MapProduct.salinity = T_resample_local.salinity;
            MapProduct.pHin = T_resample_local.ph_corrected; % calculed with t,s
            MapProduct.pH25atm = NaN(size(T_resample_local.ph_total));
            MapProduct.rhodamine = T_resample_local.rho_ppb;
            MapProduct.MLD = NaN(size(T_resample_local.ph_total));
            
            % read existing table and find unique rows to append
            if isfile(obj.mapProductFile)
                T_old = readtable(obj.mapProductFile); % Read old table
                T_old.Properties.VariableNames = obj.mapProductVars; % Ensure correct var names
                iappend = ~ismember(MapProduct(:,"unixTimestamp"), T_old(:,"unixTimestamp"),'rows'); % Unique row index
                writetable(MapProduct(iappend,:),obj.mapProductFile,"WriteMode","append"); % Append new rows
                d = MapProduct(iappend,:); % new rows
                obj.currentPosition = d(end,:); % last row
            elseif ~isfile(obj.mapProductFile)
                writetable(MapProduct,obj.mapProductFile,"WriteMode","overwrite")
            end
        end
    end
end
