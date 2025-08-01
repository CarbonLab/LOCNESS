% .m file to process all data for locness mission
clear all; close all;
addpath(genpath('C:\Users\spraydata\Documents\GitHub\'));
rmpath(genpath('C:\Users\spraydata\Documents\GitHub\MBARIWireWalker'));
%% Controlls
processShipData = 0;
%% Pull the latest shipboard data, resample, and write to map product
if processShipData == 1
    tic
    handler = ShipDataHandler();
    if handler.downloadData()
        handler.resampleData(10);         % 10
        handler.appendMapProduct(); % waiting for real data
    else
        warning("Download failed. Skipping resample.");
    end
    sdn = handler.currentPosition.unixTimestamp/ 86400 + datenum(1970,1,1);
    lat = handler.currentPosition.lat;
    lon = handler.currentPosition.lon;
    update_ODSS_pos_ship('RV Connecticut', lon, lat);
    shipdownload = toc;
end
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
%% Load latest glider data and write to map product
try
    tic
    handler = GliderDataHandler();
    handler.processGliderData('25720901');
    handler.processGliderData('25706901');
    gliderdownload = toc;
catch
    disp('Failed to process glider map product')
end
%% Process LRAUV data and append map product
processLRAUVData = 0;
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
%% Copy map product to FTP
try
    tic
    outputFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
    glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
    copyfile(outputFile,glidervizFolder)
    copy = toc;
catch
    disp('Failed to copy map product to Gliderviz')
end
%% Convert map product to kml and push latest data to ODSS
try % Add a check
    tic;
    run C:\Users\spraydata\Documents\GitHub\LOCNESS\write_ODSS.m;
    updateODSS = toc;
catch
    disp('Failed to run write ODSS'); % add an email with error code
end