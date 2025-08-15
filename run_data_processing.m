% .m file to process all data for locness mission
clear all; close all;
addpath(genpath('C:\Users\spraydata\Documents\GitHub\'));
rmpath(genpath('C:\Users\spraydata\Documents\GitHub\MBARIWireWalker'));
%% Controlls
% Put controls here when that is integrated into classes
%% Pull the latest shipboard data, resample, and write to map product. Handled separately now.
% processShipData = 0;
% if processShipData == 1
%     try
%         tic
%         handler = ShipDataHandler();
%         handler.querytable(0.2); % 0.2 hr ~10 min
%         handler.resampleData(5); % 5 min
%         handler.appendMapProduct(); % append map product
%         lat = handler.currentPosition.lat;
%         lon = handler.currentPosition.lon;
%         sdn = datenum(datetime(handler.currentPosition.unixTimestamp, ...
%                            'ConvertFrom', 'posixtime', ...
%                            'TimeZone', 'UTC'));
%         update_ODSS_pos_ship('RV_Conn', sdn, lon, lat);
%         shipdownload = toc;
%     catch
%         disp('failed to process ship data')
%     end
% end
%% Process Spray 2 data
ProcessSpray2Data = 1;
if ProcessSpray2Data == 1
    try
        run C:\Users\spraydata\Documents\GitHub\Spray2_Processing\prelim_plot_spray2pH.m;
    catch
        disp('failed to run spray2 processing')
    end
end
%% Process Spray 1 data
ProcessSpray1Data = 1;
if ProcessSpray1Data == 1
    try 
        run C:\Users\spraydata\Documents\GitHub\LOCNESS\Spray1DataHandler.m;
    catch
        disp('failed to run spray 1 processing')
    end
end
%% Load latest glider data and write to local map product 
try
    tic
    handler = GliderDataHandler();
    handler.processGliderData('25720901');
    handler.processGliderData('25706901');
    handler.processGliderData('25821001');
    gliderdownload = toc;
catch
    disp('Failed to process glider map product')
end
%% Process LRAUV data and append local map product 
processLRAUVData = 1;
if processLRAUVData == 1
    try
        tic;
        handler = LRAUVDataHandler();
        handler.downloadData();
        handler.readLRAUVCSV();
        handler.buildTableLRAUV();
        handler.appendMapProduct();
        processLRAUVdata = toc;
    catch
        disp('Failed to process new LRAUV data');
    end
end
%% Process Drifter data and append local map product 
% Might have the wrong "Cruise" for the drifters? All of the values are
% unique
%id,timestamp,latitude,longitude,messageType
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
            handler.appendMapProduct(); 
%             t = handler.T(end,:);
%             sdn = datenum(datetime(t.unixTimestamp, ...
%                'ConvertFrom', 'posixtime', ...
%                'TimeZone', 'UTC'));
%             lat = t.lat(end);
%             lon = t.lon(end);
%             update_ODSS_pos_drifter(char(drifternames(i)),sdn,lon,lat);
            processDrifterdata = toc;
        end
        processDrifterdata = toc;
    catch
        disp('Failed to process new Drifter data');
    end
end
%% Copy local map product to FTP site Sirroco
try
    tic
    outputFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
    glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
    copyfile(outputFile,glidervizFolder)
    copy = toc;
catch
    disp('Failed to copy map product to Gliderviz')
end
%% Update Particle Track Info
try
    tic
    handler = ParticleTrackDataHandler();
    handler.updateAll();
    ptracks = toc;
catch
    disp('Failed to update particle tracks')
end
%% Convert map product to kml and push latest data to ODSS
try % Add a check
    tic;
    run C:\Users\spraydata\Documents\GitHub\LOCNESS\write_ODSS.m;
    updateODSS = toc;
catch
    disp('Failed to run write ODSS'); % add an email with error code
end
%% Evaluate how good the projection is
try
    run C:\Users\spraydata\Documents\GitHub\LOCNESS\evalProjection.m;
catch
    disp('Failed to run evalprojection.m'); % add an email with error code
end