% Main function with your current code
function [] = manualDrifters()

%% Define folder containing drifter CSVs
dataFolder = "/Users/straylor/Library/CloudStorage/GoogleDrive-straylor@mbari.org/Shared drives/locness/spot/";

% Find all DRIFTER_XX.csv files
fileList = dir(fullfile(dataFolder, "DRIFTER_*.csv"));

%% Set up the Import Options
opts = delimitedTextImportOptions("NumVariables", 6);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["id", "timestamp", "latitude", "longitude", "messageType", "drifter_id"];
opts.VariableTypes = ["double", "datetime", "double", "double", "categorical", "double"];

% File-level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Variable properties
opts = setvaropts(opts, "messageType", "EmptyFieldRule", "auto");
opts = setvaropts(opts, "timestamp", "InputFormat", "yyyy-MM-dd HH:mm:ss", "DatetimeFormat", "preserveinput");
opts = setvaropts(opts, "drifter_id", "TrimNonNumeric", true);
opts = setvaropts(opts, "drifter_id", "ThousandsSeparator", ",");

%% Loop through each drifter CSV
for k = 1:numel(fileList)
    filePath = fullfile(fileList(k).folder, fileList(k).name);
    [~, baseName, ~] = fileparts(fileList(k).name);  % e.g., "DRIFTER_01"
    
    % Read CSV into table
    T = readtable(filePath, opts);
    
    % Get the most recent row
    [~, idxLatest] = max(T.timestamp);
    sdn = datenum(T.timestamp(idxLatest)); % MATLAB datetime
    lat = T.latitude(idxLatest);
    lon = T.longitude(idxLatest);
    
    % Robust, case-insensitive drifter number extraction
drifterNum = regexp(baseName, '(?i)(?<=drifter[_-]?)(\d+)$', 'tokens', 'once'); 
if ~isempty(drifterNum)
    drifterNum = drifterNum{1};
elseif any(~isnan(T.drifter_id))
    % fallback: from data column (may not have leading zeros)
    drifterNum = strtrim(num2str(T.drifter_id(idxLatest)));
else
    error('Could not parse drifter number from "%s".', baseName);
end

% Update ODSS
update_ODSS_pos_drifter(['SPOT0' drifterNum], sdn, lon, lat);
    
    fprintf('Updated %s with time %s, lat %.4f, lon %.4f\n', ...
        baseName, string(sdn), lat, lon);
end

%% Clear opts if not needed anymore
clear opts
end

