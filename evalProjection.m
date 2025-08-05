% Script to evalute the projected surfacing points of the gliders
% saves a CSV into the OBS lab's Locness/Data directory

% Import data
opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["Cruise", "Platform", "Layer", "CastDirection", "unixTimestamp", ...
    "lat", "lon", "temperature", "salinity", "pHin", "pH25atm", "rhodamine", "MLD"];
opts.VariableTypes = ["string", "categorical", "categorical", "categorical", "double", ...
    "double", "double", "double", "double", "double", "double", "double", "double"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, "Cruise", "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Cruise", "Platform", "Layer", "CastDirection"], "EmptyFieldRule", "auto");
filepath = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\'
data = readtable([filepath 'LocnessMapProduct.txt'], opts);
clear opts

% ----- Separate into structs by glider -----
data = data(data.Platform == 'Glider',:);
uniVars = unique(data.Cruise);
platforms = extractBetween(uniVars, 4, 6); % glider SN
S = struct();
for i = 1:numel(platforms)
    gliderID = "SN" + platforms(i);
    S.(gliderID) = data(data.Cruise == uniVars(i), :);
end

% ----- Process all gliders you care about -----
glidersToCompare = ["SN069", "SN209"];  % extend this list as needed

allResults = table();
for i = 1:numel(glidersToCompare)
    gliderID = glidersToCompare(i);
    T = S.(gliderID);
    results = compareWPTtoSurface(T, gliderID);
    
    % Save to CSV
    if ~isempty(results)
        % optional: save individual results
%         writetable(results, gliderID + "_diffs.csv");
        assignin('base', "results" + extractAfter(gliderID, 2), results);  % e.g., results069
        allResults = [allResults; results];
    end
end

% Save combined results
writetable(allResults, [filepath 'GliderProjectionResults\all_gliders_diffs.csv']);

% make figures and save
saveas(gcf,'Barchart.png')


% ----- Function to process one glider -----
function results = compareWPTtoSurface(T, gliderID)
    idx = T.Layer == 'WPT' | T.Layer == 'Surface';
    T = T(idx,:);
    T.date = datetime(T.unixTimestamp, 'ConvertFrom','posixtime');
    T = movevars(T, "date", "Before", "unixTimestamp");

    varsToSubtract = vartype('numeric');
    diffRows = [];

    for i = 1:height(T)-1
        if T.Layer(i) == "WPT" && T.Layer(i+1) == "Surface"
            rowDiff = T(i+1, :);
            rowDiff{:, varsToSubtract} = T{i+1, varsToSubtract} - T{i, varsToSubtract};
            rowDiff.distance = deg2km(distance(T{i+1, 'lat'}, T{i+1, 'lon'}, T{i, 'lat'}, T{i, 'lon'}));
            rowDiff.Layer = "SurfaceMinusWPT";
            diffRows = [diffRows; rowDiff]; %#ok<AGROW> 
        end
    end

    if isempty(diffRows)
        results = table();  % Return empty if no matches
        return;
    end

    diffRows = renamevars(diffRows, "date", "surfTime");

    results = table();
    results.gliderSN = repmat(gliderID, height(diffRows), 1);
    results.surfTime = diffRows.surfTime;
    results.latDiff = diffRows.lat;
    results.lonDiff = diffRows.lon;
    results.timeDiffMin = diffRows.unixTimestamp ./ 60;
    results.distance_km = diffRows.distance;
end