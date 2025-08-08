classdef ParticleTrackDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFile = 'remote:particle_tracks/20250721_gomofs.zarr'; % Need the new filename
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\ParticleTracks';
        localFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\ParticleTracks\20250721_gomofs.zarr';
        glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
        mapProductFile = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\LocnessMapProduct.txt';
        mapProductVars = { ...
                    'Cruise', 'Platform', 'Layer', 'CastDirection', ...
                    'unixTimestamp', 'lat', 'lon', 'temperature',...
                    'salinity', 'pHin', 'pH25atm', 'rhodamine', 'MLD', ...
                };
    end
    properties (Access = private)
        ReadOptions    % delimitedTextImportOptions for readtable
    end
    properties (Access = public)
        T_raw % Output from readtable
        T % Table to append to MapProduct
        message
    end

    methods (Access = public)

        function downloadStatus = downloadData(obj)
            % DOWNLOADDATA - Use rclone to copy data from remote to local.
            command = sprintf('"%s" copy %s "%s" --checksum', ...
                obj.rclonePath, obj.remoteFile, obj.localFolder);
            [status, ~] = system(command);

            if status == 0
                downloadStatus = true;
            else
                downloadStatus = false;
            end
        end
    end
end
