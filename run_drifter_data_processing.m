addpath(genpath('C:\Users\spraydata\Documents\GitHub\'));
rmpath(genpath('C:\Users\spraydata\Documents\GitHub\MBARIWireWalker'));
%% Drifter data
processDrifterData = 1;
if processDrifterData == 1
    try
        tic;
        handler = DrifterDataHandler();
        handler.downloadData();
        fnames = dir('\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\Drifter\*.csv');
        folder = {fnames.folder}.';
        names = {fnames.name}.';
        fnames = fullfile(folder,names);
        drifternames = {'SPOT001','SPOT002','SPOT003','SPOT004','SPOT005',...
            'SPOT006','SPOT007','SPOT008','SPOT009','SPOT010','SPOT011','SPOT012'};
        for i = 1:length(fnames)
            handler.readCSV(string(fnames(i)));
            handler.buildTable();
            t = handler.T(end,:);
            sdn = datenum(datetime(t.unixTimestamp, ...
               'ConvertFrom', 'posixtime', ...
               'TimeZone', 'UTC'));
            lat = t.lat(end);
            lon = t.lon(end);
            update_ODSS_pos_drifter(char(drifternames(i)),sdn,lon,lat);
            processDrifterdata = toc;
        end
        processDrifterdata = toc;
    catch
        disp('Failed to process new Drifter data');
    end
end