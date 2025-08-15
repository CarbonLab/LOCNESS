addpath(genpath('C:\Users\spraydata\Documents\GitHub\'));
rmpath(genpath('C:\Users\spraydata\Documents\GitHub\MBARIWireWalker'));
%% Pull the latest shipboard data, resample, and write to map product
processShipData = 1;
if processShipData == 1
    try
        tic
%         handler = ShipDataHandler();
%         handler.GetCurrentData();
%         handler.CurrentLocation();
        handler = ShipDataHandler();
        handler.AppendCurrentLocation();
        handler.copyToGliderviz();
        lat = handler.currentPosition.lat;
        lon = handler.currentPosition.lon;
        sdn = datenum(datetime(handler.currentPosition.unixTimestamp, ...
                           'ConvertFrom', 'posixtime', ...
                           'TimeZone', 'UTC'));
        update_ODSS_pos_ship('RV_Conn', sdn, lon, lat);
        shipdownload = toc;
    catch
        disp('failed to process ship data')
    end
end