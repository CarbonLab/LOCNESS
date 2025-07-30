function [binned] = binData(data, time, interval)
% function to bin data into a lower time resolution
% input: data, time (in datetime)  & interval (in minutes)
% output: binnedData

% Step 1: Define the time bin edges for 1-minute bins
startTime = dateshift(time(1), 'start', 'minute');
endTime   = dateshift(time(end), 'end', 'minute');
edges = (startTime:minutes(interval):endTime)';

% Step 2: Bin the data using discretize
binIdx = discretize(time, edges);

% Step 3: Initialize outputs
binnedTime = edges(1:end-1) + minutes(interval./2);  % bin center
binnedData = NaN(length(binnedTime), 1);

% Step 4: Compute mean for each bin
for i = 1:length(binnedData)
    binnedData(i) = mean(data(binIdx == i), 'omitnan');
end

binned = table(binnedTime, binnedData,'VariableNames',{'Time','Data'}) ;

% Output:
% binnedTime - timestamps at 1-minute interval (bin center)
% binnedData - corresponding mean values for each minute

end