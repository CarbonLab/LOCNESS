% script to write rhodamine and pH layers to ODSS
% dependencies: 'binData.m', 'write_kml_st.m',
% 'write_map.m','generate_colorbar_legend.m', and the cmocean package*
% *can send MAT files of the colormaps if you don't have cmocean

% +++ Ben - edit this section +++
% read in data
opts = delimitedTextImportOptions("NumVariables", 13);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["Cruise", "Platform", "Layer", "CastDirection", "unixTimestamp", "lat", "lon", "temperature", "salinity", "pHin", "pH25atm", "rhodamine", "MLD"];
opts.VariableTypes = ["categorical", "categorical", "categorical", "categorical", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, ["Cruise", "Platform", "Layer", "CastDirection"], "EmptyFieldRule", "auto");

% Import the data
MapProduct = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
T = readtable(MapProduct, opts);
clear opts 

% convert to datetime
T.date = datetime(T.unixTimestamp, 'ConvertFrom', 'posixtime','TimeZone','UTC');

% define time range
% e.g., past 24 hrs
end_time = datetime('now','TimeZone','UTC'); 
start_time = end_time - hours(24); 
start_time.TimeZone = "UTC";
d = T.date >= start_time & T.date <= end_time ;
T = T(d,:);

% apply binning to ship data if necessary
interval = 5 ; % in minutes
k = T.Platform == 'Ship' ;
ship = T(k,:) ;
rest = T(~k,:) ;
if ~isempty(ship) % Bin if there is ship data
    [binnedRhodamine] = binData(ship.rhodamine, ship.date, interval) ;
    [binnedpH] = binData(ship.pHin, ship.date, interval) ;
    [binnedLat] = binData(ship.lat, ship.date, interval) ;
    [binnedLon] = binData(ship.lon, ship.date, interval) ;
else
    binnedLat.Time = NaT;
    binnedLat.Data = NaN;
    binnedLon.Time = NaT;
    binnedLon.Data = NaN;
    binnedRhodamine.Data = NaN;
    binnedpH.Data = NaN;
end

% choose only mean MLD values
% this only takes gliders, needs to be augmented to add drifters
k = rest.Platform == 'Glider' | rest.Platform == 'LRAUV' & rest.Layer == 'MLD' & rest.CastDirection == 'Up';
rest = rest(k,:) ;

data = table();
if ~isempty(ship)
    data.time = [binnedLat.Time; rest.date];
    data.lat = [binnedLat.Data; rest.lat];
    data.lon = [binnedLon.Data; rest.lon];
    data.rhodamine = [binnedRhodamine.Data; rest.rhodamine];
    data.ph = [binnedpH.Data; rest.pHin];
else
    data.time = rest.date;
    data.lat = rest.lat;
    data.lon = rest.lon;
    data.rhodamine = rest.rhodamine;
    data.ph = rest.pHin;
end

% Filter out NaNs
e = ~isnan(data.ph) ;
data_ph = data(e,:) ;
d = ~isnan(data.rhodamine) ;
data = data(d,:) ;

global rep_kml_global kml_global
% rep_kml_global = '/Volumes/ODSS/data/mapserver/mapfiles/assets/' ;
% rep_kml_global = '\\\\atlas\\ODSS\\data\\mapserver\\mapfiles\\assets\\';
rep_kml_global = '\\atlas\ODSS\data\mapserver\mapfiles\assets\';  % only one backslash per segment

% generate files and save to ODSS server
kml_global = 'rhodamine' ;

[list_colors, mat_rgb] = write_kml_st('rhodamine.kml',data.time, data.lat, data.lon, 'rhodamine',data.rhodamine,'point');
generate_colorbar_legend(min(data.rhodamine), max(data.rhodamine),'rhodamine');
write_map(mat_rgb, list_colors,'rhodamine','point');

clear kml_global
kml_global = 'ph' ;
[list_colors, mat_rgb] = write_kml_st('ph.kml',data_ph.time, data_ph.lat, data_ph.lon, 'ph',data_ph.ph,'point');
generate_colorbar_legend(min(data_ph.ph), max(data_ph.ph),'ph');
write_map(mat_rgb, list_colors,'ph','point');



