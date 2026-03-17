opts = detectImportOptions("LocnessMapProduct_08252025.txt");
types = opts.VariableTypes;
types(1) = {'char'};
opts.VariableTypes = types;
T = readtable("LocnessMapProduct_08252025.txt",opts);


latbound = [41, 43.5];
lonbound = [-71, -68.5];

ipositionFilter = T.lat > latbound(1) & T.lat < latbound(2) & T.lon > lonbound(1) & T.lon < lonbound(2); % flag bad gps data
ishipFilter = ismember(T.Platform,'Ship');
ilrauvFilter = ismember(T.Platform,'LRAUV') & ismember(T.CastDirection,'Up');
igliderFilter = ismember(T.Platform,'Glider') & ismember(T.CastDirection,'Up');
idrifterFilter = ismember(T.Platform,'Drifter');
T_filter = T(ipositionFilter & (ishipFilter | ilrauvFilter | igliderFilter | idrifterFilter),:);
%% Map
geobasemap("satellite")
geoscatter(T_filter,"lat","lon")
geolimits([41.3472,42.8314],[-71.272,-68.5051])
%% Save
writetable(T_filter,'locness_animation.txt');