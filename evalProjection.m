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
filepath = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\';
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

% for mac
%writetable(allResults, [filepath 'GliderProjectionResults/all_gliders_diffs.csv']);

% make figures and save
%figure(43); clf
figure('Visible','off');
set(gcf, 'Position', [1     1   960   635])
sgtitle('Projected Surfacing Results')
subplot 211
plot(results069.surfTime, results069.timeDiffMin,'.','MarkerSize',20)
hold on; grid on
plot(results.surfTime, results.timeDiffMin,'^','LineWidth',2)
ylabel('real - proj. time (min)');
%ylim([-1 40])
set(gca,'FontSize',14)
txt = sprintf('SN069_{mean}: %.f%c%.f min\nSN209_{mean}: %.f%c%.f min',...
    nanmean(results069.timeDiffMin),char(177),nanstd(results069.timeDiffMin),...
    nanmean(results209.timeDiffMin),char(177),nanstd(results209.timeDiffMin));
text(results069.surfTime(1)-1/24, -3,txt);
legend('SN069','SN209');

subplot 212
plot(results069.surfTime, 1000.*results069.distance_km,'.','MarkerSize',20)
hold on; 
plot(results209.surfTime, 1000.*results209.distance_km,'^','LineWidth',2)
ylabel('distance (m)')
txt = sprintf('SN069_{mean}: %.f%c%.f m\nSN209_{mean}: %.f%c%.f m',...
    1000.*nanmean(results069.distance_km),char(177),1000.*nanstd(results069.distance_km),...
    1000.*nanmean(results209.distance_km),char(177),1000.*nanstd(results209.distance_km));

text(results069.surfTime(1)-1/24, 800,txt);

set(gca,'FontSize',12)
grid on
legend('SN069','SN209')
%ylim([-10 1000])

saveas(gcf,[filepath 'GliderProjectionResults\projResults.png']);
% for mac
% saveas(gcf,[filepath 'GliderProjectionResults/projResults.png']);

% plot as histogram
%figure(44); clf
figure('Visible','off');
set(gcf, 'Position', [1     1   960   635])
sgtitle('Projected Surfacing Results')
subplot 211
histogram(results069.timeDiffMin,10)
hold on; grid on
histogram(results209.timeDiffMin,10)

xlabel('real - proj. time (min)')
%ylim([0 13])
set(gca,'FontSize',12)
txt = sprintf('SN069_{mean}: %.f%c%.f min\nSN209_{mean}: %.f%c%.f min',...
    nanmean(results069.timeDiffMin),char(177),nanstd(results069.timeDiffMin),...
    nanmean(results209.timeDiffMin),char(177),nanstd(results209.timeDiffMin));
text(-5, 10, txt);

legend('SN069','SN209','Location','NW')

subplot 212
histogram(1000.*results069.distance_km,15)
hold on; 
histogram(1000.*results209.distance_km,15)
xlabel('distance (m)')

txt = sprintf('SN069_{mean}: %.f%c%.f m\nSN209_{mean}: %.f%c%.f m',...
    1000.*nanmean(results069.distance_km),char(177),1000.*nanstd(results069.distance_km),...
    1000.*nanmean(results209.distance_km),char(177),1000.*nanstd(results209.distance_km));

text(600, 5,txt);

set(gca,'FontSize',14)
grid on
legend('SN069','SN209')
%ylim([0 8])

saveas(gcf,[filepath 'GliderProjectionResults/projResults_hist.png']);
% for mac
% saveas(gcf,[filepath 'GliderProjectionResults/projResults_hist.png']);


% ----- Function to process one glider -----
% function results = compareWPTtoSurface(T, gliderID)
%     idx = T.Layer == 'WPT' | T.Layer == 'Surface';
%     T = T(idx,:);
%     T.date = datetime(T.unixTimestamp, 'ConvertFrom','posixtime');
%     T = movevars(T, "date", "Before", "unixTimestamp");
% 
%     varsToSubtract = vartype('numeric');
%     diffRows = [];
% 
%     for i = 1:height(T)-1
%         if T.Layer(i) == "WPT" && T.Layer(i+1) == "Surface"
%             rowDiff = T(i+1, :);
%             rowDiff{:, varsToSubtract} = T{i+1, varsToSubtract} - T{i, varsToSubtract};
%             rowDiff.distance = deg2km(distance(T{i+1, 'lat'}, T{i+1, 'lon'}, T{i, 'lat'}, T{i, 'lon'}));
%             rowDiff.Layer = "SurfaceMinusWPT";
%             diffRows = [diffRows; rowDiff]; %#ok<AGROW> 
%         end
%     end
% 
%     if isempty(diffRows)
%         results = table();  % Return empty if no matches
%         return;
%     end
% 
%     diffRows = renamevars(diffRows, "date", "surfTime");
% 
%     results = table();
%     results.gliderSN = repmat(gliderID, height(diffRows), 1);
%     results.surfTime = diffRows.surfTime;
%     results.latDiff = diffRows.lat;
%     results.lonDiff = diffRows.lon;
%     results.timeDiffMin = diffRows.unixTimestamp ./ 60;
%     results.distance_km = diffRows.distance;
% end

function results = compareWPTtoSurface(T, gliderID)
% Keep only WPT and Surface
    idx = T.Layer == 'WPT' | T.Layer == 'Surface';
    T = T(idx,:);
    T.date = datetime(T.unixTimestamp, 'ConvertFrom','posixtime');
    T = movevars(T, "date", "Before", "unixTimestamp");

    varsToSubtract = vartype('numeric');
    diffRows = [];

    % Get WPT and Surface indices
    iWPT = find(T.Layer == "WPT");
    iSurf = find(T.Layer == "Surface");

    for k = 1:length(iWPT)
        i = iWPT(k);
        rowWPT = T(i, :);

        % Try immediate next row
        if i < height(T) && T.Layer(i+1) == "Surface"
            j = i + 1;

        else
            % Search for closest Surface within 20 min after WPT
            surfAfter = iSurf(iSurf > i);
            if isempty(surfAfter)
                continue;
            end

            timeDiffs = T.unixTimestamp(surfAfter) - T.unixTimestamp(i);
            [minDt, relIdx] = min(abs(timeDiffs));

            if minDt > 1200  % more than 20 minutes
                continue;
            end

            j = surfAfter(relIdx);  % matched Surface row index
        end

        % Compute difference: Surface - WPT
        rowSurf = T(j, :);
        rowDiff = rowSurf;
        rowDiff{:, varsToSubtract} = rowSurf{:, varsToSubtract} - rowWPT{:, varsToSubtract};
        rowDiff.distance = deg2km(distance(rowSurf.lat, rowSurf.lon, rowWPT.lat, rowWPT.lon));
        rowDiff.Layer = "SurfaceMinusWPT";

        diffRows = [diffRows; rowDiff]; 
    end

    if isempty(diffRows)
        results = table();  % Return empty if no matches
        return;
    end

    % Rename date to surfTime
    diffRows = renamevars(diffRows, "date", "surfTime");

    % Final output table
    results = table();
    results.gliderSN     = repmat(gliderID, height(diffRows), 1);
    results.surfTime     = diffRows.surfTime;
    results.latDiff      = diffRows.lat;
    results.lonDiff      = diffRows.lon;
    results.timeDiffMin  = diffRows.unixTimestamp ./ 60;
    results.distance_km  = diffRows.distance;
end