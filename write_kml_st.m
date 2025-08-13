function [list_colors, mat_rgb] = write_kml_st(filename, time, lat, lon, varname, data, type)
% WRITE_KML_ST - Writes a KML file with color-coded placemarks or polygons.
%
% Inputs:
%   filename     - Output KML filename
%   time         - datetime or datenum array
%   lat, lon     - Vectors of coordinates
%   varname      - String, name of variable
%   data         - Vector of variable
%   type         - 'point' or 'polygon'
global rep_kml_global kml_global

% Validate input
if ~isequal(length(time), length(lat), length(lon), length(data))
    error('All inputs must have the same length.');
end


% Make a clean variable label and filename
varLabel = strrep(varname, '_', ' ');
fileLabel = lower(strrep(varname, ' ', '_'));
% make sentence case
varName = strcat(upper(fileLabel(1)),lower(fileLabel(2:end)));

% Normalize variable to colormap
npts = length(data);
if strcmp(lower(varname),'rhodamine') == 1
    colormapJet = cmocean('amp',64);
    colormapJet = colormapJet .* [1 .6 1.5] ;
    colormapJet(1,:) = [1 1 1];
    colormapJet(2:20,:) = [linspace(colormapJet(1,1),colormapJet(20,1),19)' linspace(colormapJet(1,2),colormapJet(20,2),19)' linspace(colormapJet(1,3),colormapJet(20,3),19)'];
    tmin = 0;
    tmax = max(data);

elseif strcmp(lower(varname),'ph') == 1
    colormapJet = cmocean('speed',64);
    tmin = 7.9;
    tmax = 8.5;
elseif strcmp(lower(varname),'grid') == 1
    colormapJet = zeros(64,3);
    tmin = 0;
    tmax = 1;
else
    colormapJet = cmocean('phase',64);
    tmin = min(data);
    tmax = max(data);
end

tidx = round(rescale(data, 1, 64));  % map to 1–64
colorsRGB = colormapJet(tidx, :);

% Convert RGB to KML hex color
toKmlColor = @(rgb) sprintf('ff%02x%02x%02x', round(rgb(3)*255), round(rgb(2)*255), round(rgb(1)*255));  % AABBGGRR

% Get unique RGB colors and assign style IDs
[uniqueColors, ~, ic] = unique(colorsRGB, 'rows');
styleIds = strcat("style", string(1:size(uniqueColors,1)));
styleMap = containers.Map;
for i = 1:length(styleIds)
    styleMap(mat2str(uniqueColors(i,:))) = styleIds(i);
end

% filename=[rep_kml_global,kml_global,'.kml']; % can use this if global
% variables start working again
filename=[rep_kml_global,varname,'.kml'];

% Open file
fid = fopen(filename, 'w');
if fid == -1, error('Could not open file for writing.'); end

% KML Header
fprintf(fid, '<?xml version=''1.0'' encoding=''UTF-8''?><kml xmlns=''http://earth.google.com/kml/2.2''><Folder>\n');
%fprintf(fid, '<kml xmlns="http://earth.google.com/kml/2.2">\n');
%fprintf(fid, '<Document>\n');
fprintf(fid, '<name>Layer #0</name>\n');

% % Write styles
% for i = 1:size(uniqueColors,1)
%     rgb = uniqueColors(i,:);
%     kmlColor = toKmlColor(rgb);
%     fprintf(fid, '<Style id="%s">\n', styleIds(i));
% 
%     if strcmp(type, 'point')
%         fprintf(fid, '  <IconStyle>\n');
%         fprintf(fid, '    <color>%s</color>\n', kmlColor);
%         fprintf(fid, '    <scale>1.5</scale>\n');
%         fprintf(fid, '    <Icon>\n');
%         fprintf(fid, '      <href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href>\n');
%         fprintf(fid, '    </Icon>\n');
%         fprintf(fid, '  </IconStyle>\n');
%     elseif strcmp(type, 'polygon')
%         fprintf(fid, '  <PolyStyle>\n');
%         fprintf(fid, '    <color>%s</color>\n', kmlColor);
%         fprintf(fid, '    <fill>1</fill>\n');
%         fprintf(fid, '    <outline>0</outline>\n');
%         fprintf(fid, '  </PolyStyle>\n');
%     end
% 
%     fprintf(fid, '</Style>\n');
% end

% Generate Placemarks
if strcmp(type,'polygon')
    dx = 0.001; dy = 0.001; % polygon size

    for i = 1:npts
        % colorKey = mat2str(colorsRGB(i,:));
        % styleUrl = styleMap(colorKey);
        kmlColor = toKmlColor(colorsRGB(i,:));
        lon_i = lon(i); lat_i = lat(i);

        corners = [ lon_i-dx/2, lat_i-dy/2;
                    lon_i+dx/2, lat_i-dy/2;
                    lon_i+dx/2, lat_i+dy/2;
                    lon_i-dx/2, lat_i+dy/2;
                    lon_i-dx/2, lat_i-dy/2 ];  % close loop

        fprintf(fid, '<Placemark>\n');
        fprintf(fid, '<name>%s</name>', kmlColor);
        % fprintf(fid, '  <styleUrl>#%s</styleUrl>\n', styleUrl);
        fprintf(fid, '  <description>%s: %.2f°C</description>\n', varName, data(i));
        fprintf(fid, '  <Polygon>\n');
        fprintf(fid, '<altitudeMode>clampToGround</altitudeMode>\n');
        fprintf(fid, '    <outerBoundaryIs><LinearRing><coordinates>\n');
        for j = 1:size(corners,1)
            fprintf(fid, '      %.6f,%.6f,0\n', corners(j,1), corners(j,2));
        end
        fprintf(fid, '    </coordinates></LinearRing></outerBoundaryIs>\n');
        fprintf(fid, '  </Polygon>\n');
        fprintf(fid, '</Placemark>\n');
    end

else  % Point type
    for i = 1:npts
        if isdatetime(time)
            timeStr = datestr(time(i), 'yyyy-mm-ddTHH:MM:SSZ');
        else
            timeStr = datestr(datetime(time(i), 'ConvertFrom', 'datenum'), 'yyyy-mm-ddTHH:MM:SSZ');
        end
        % colorKey = mat2str(colorsRGB(i,:));
        % styleUrl = styleMap(colorKey);
        kmlColor = toKmlColor(colorsRGB(i,:));

        fprintf(fid, '<Placemark>\n');
        fprintf(fid, '  <name>%s</name>\n', kmlColor);
        fprintf(fid, '  <TimeStamp><when>%s</when></TimeStamp>\n', timeStr);
%       fprintf(fid, '  <styleUrl>#%s</styleUrl>\n', styleUrl);
%        fprintf(fid, '  <description>%s: %.2f°C</description>\n', varName, data(i));
        fprintf(fid, '  <Point>\n');
        fprintf(fid, '      <altitudeMode>absolute</altitudeMode>\n');
        fprintf(fid, '      <coordinates>%.6f,%.6f,0</coordinates>\n', lon(i), lat(i));
        fprintf(fid, '  </Point>\n');
        fprintf(fid, '</Placemark>\n');
    end
end

% % Optional: colorbar overlay
% fprintf(fid, '<ScreenOverlay>\n');
% fprintf(fid, '  <name>Colorbar</name>\n');
% fprintf(fid, '  <Icon>\n');
% fprintf(fid, '    <href>colorbar.png</href>\n');
% fprintf(fid, '  </Icon>\n');
% fprintf(fid, '  <overlayXY x="0" y="0" xunits="fraction" yunits="fraction"/>\n');
% fprintf(fid, '  <screenXY x="0.05" y="0.05" xunits="fraction" yunits="fraction"/>\n');
% fprintf(fid, '  <size x="0.3" y="0.05" xunits="fraction" yunits="fraction"/>\n');
% fprintf(fid, '</ScreenOverlay>\n');

% Close file
fprintf(fid, '</Folder>\n</kml>\n');
fclose(fid);

fprintf('KML with %s-coded %s written to "%s"\n', varName, type, filename);

mat_rgb = uniqueColors ; 
for i =1:size(uniqueColors,1) ;
list_colors{i} = toKmlColor(uniqueColors(i,:));
end

end
