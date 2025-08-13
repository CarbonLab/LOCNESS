classdef DrifterDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFile = 'remote:spot/'; 
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\Drifter';
        localFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\Drifter\drifter_data.csv';
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
        cruise
    end

    methods (Access = public)
        function obj = DrifterDataHandler() % Constructor
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

        function readCSV(obj,fname)
            obj.T_raw = readtable(fname,obj.ReadOptions);
            obj.T_raw = sortrows(obj.T_raw,'timestamp');
            obj.cruise = char(fname);
            obj.T_raw.timestamp.TimeZone = 'America/New_York';
            obj.T_raw.timestamp.TimeZone = 'UTC';
        end

        function buildTable(obj,fname)
            if isempty(obj.T_raw)
                obj.T_raw = readtable(fname,obj.ReadOptions);
            end
            t = obj.T_raw;
            f = obj.cruise;
            cruisename = f(end-13:end-4);
            nRows = length(t.timestamp);
            t.unixTimestamp = posixtime(t.timestamp);
            
            T_new = table( ...
            repmat(cruisename, nRows, 1), ...
            repmat("Drifter", nRows, 1), ...
            repmat("Surface", nRows, 1), ...
            repmat("Constant", nRows, 1), ...
            t.unixTimestamp, ...
            t.latitude, ...
            t.longitude, ...
            nan(nRows,1), ...
            nan(nRows,1), ...
            nan(nRows,1), ...
            nan(nRows,1), ...
            nan(nRows,1), ... 
            nan(nRows,1), ...
            'VariableNames', obj.mapProductVars);

            obj.T = T_new;
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
            % Create import options for 5 variables
            opts = delimitedTextImportOptions("NumVariables", 5);
            
            % Define data lines and delimiter
            opts.DataLines = [2, Inf];
            opts.Delimiter = ",";
            
            % Define variable names: id,timestamp,latitude,longitude,messageType
            opts.VariableNames = ["id", "timestamp", "latitude", "longitude", "messageType"];
            
            % Select only the needed variable names
            opts.SelectedVariableNames = ["id", "timestamp", "latitude", "longitude", "messageType"];
            
            % Define variable types
            opts.VariableTypes = ["string", "datetime", "double", "double", "string"];
            
            % Set datetime format for timestamp
            opts = setvaropts(opts, "timestamp", "InputFormat", "yyyy-MM-dd HH:mm:ss");
            
            % Set rules for extra columns and empty lines
            opts.ExtraColumnsRule = "ignore";
            opts.EmptyLineRule = "read";
        end
    end
end
