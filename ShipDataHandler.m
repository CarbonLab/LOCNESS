classdef ShipDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFile = 'remote:7day-sensor-data_resampled.csv';
%         remoteFile = 'remote:fake-data-all.parquet';
        remoteFile_parquet = 'remote:7day-sensor-data_resampled.parquet'; % Need the new filename
        localFolder_parquet = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\RVConnecticut';
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness';
        glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
        mapProductFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
        mapProductVars = { ...
                    'Cruise', 'Platform', 'Layer', 'CastDirection', ...
                    'unixTimestamp', 'lat', 'lon', 'temperature',...
                    'salinity', 'pHin', 'pH25atm', 'rhodamine', 'MLD', ...
                };
        shipDataVars = {'timestamp', 'lat', 'lon', 'rhodamine', 'ph', 'temp', 'salinity', 'ph_ma'};
    end
    properties (Access = private)
        TT  % The resampled timetable
    end
    properties (Access = public)
        currentPosition
    end

    methods
        function downloadStatus = downloadData(obj)
            % DOWNLOADDATA - Use rclone to copy data from remote to local.
%             command = sprintf('"%s" copy %s "%s"', ...
%                 obj.rclonePath, obj.remoteFile, obj.localFolder);
            command = sprintf('"%s" copy %s "%s" --checksum', ...
                obj.rclonePath, obj.remoteFile_parquet, obj.localFolder_parquet);
            [status, ~] = system(command);

            if status == 0
                downloadStatus = true;
            else
                downloadStatus = false;
            end
        end

        function resampleData(obj, n)
            % RESAMPLEDATA - Resample CSV data to n-minute interval and save
            pds = parquetDatastore(obj.localFolder_parquet,"IncludeSubfolders", ...
                true,"OutputType","table","SelectedVariableNames",obj.shipDataVars);
            T = pds.readall;
            if ~isdatetime(T.timestamp)
                T.Time = datetime(T.timestamp, 'InputFormat', ...
                    'yyyy-MM-dd HH:mm:ss', "TimeZone", "UTC");
            else
                T.Time = T.timestamp;
            end
            T = sortrows(T,'Time','ascend');
            tempTT = table2timetable(T, 'RowTimes', 'Time');
            obj.TT = retime(tempTT, 'regular', 'lastvalue', 'TimeStep', ...
                minutes(n)); % Resample
        end

        function copyToGliderviz(obj, filePath)
            % COPYTOGLIDERVIZ - Copy file to the Gliderviz folder
            copyfile(filePath, obj.glidervizFolder);
        end
        
        function appendMapProduct(obj)
            TTlocal = obj.TT;
            nRows = length(TTlocal.Time);
           
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
            MapProduct.unixTimestamp = posixtime(TTlocal.Time); % unix
            MapProduct.lat = TTlocal.lat;
            MapProduct.lon = TTlocal.lon;
            MapProduct.temperature = TTlocal.temp;
            MapProduct.salinity = TTlocal.salinity;
            MapProduct.pHin = TTlocal.ph;
            MapProduct.pH25atm = NaN(size(TTlocal.ph));
            MapProduct.rhodamine = TTlocal.rhodamine;
            MapProduct.MLD = NaN(size(TTlocal.ph));
            
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
