classdef ParticleTrackDataHandler < handle
    properties (Constant)
        rclonePath = 'C:\Users\spraydata\rclone\rclone.exe';
        remoteFolder = 'remote:particle_tracks';
        localFolder = '\\atlas.shore.mbari.org\ProjectLibrary\901805_Coastal_Biogeochemical_Sensing\Locness\Data\ParticleTracks';
        file_gomofs = 'current_gomofs.csv';
        file_doppio = 'current_doppio.csv';
        glidervizFolder = '\\sirocco\wwwroot\lobo\data\glidervizdata\';
    end
    
    properties (Access = public)
        downloadStatus
    end
    
    methods (Access = public)
        
        function obj = ParticleTrackDataHandler()
            % Constructor (optional: could auto-run update here if desired)
        end
        
        function downloadStatus = downloadAll(obj)
            % DOWNLOADALL - Download both particle track files in one call
            cmd = sprintf('"%s" copy "%s" "%s" --include "%s" --include "%s" --size-only', ...
                obj.rclonePath, obj.remoteFolder, obj.localFolder, ...
                obj.file_gomofs, obj.file_doppio);
            
            fprintf('Running rclone download...\n');
            tic;
            [status, cmdout] = system(cmd);
            fprintf('Rclone output:\n%s\n', cmdout);
            fprintf('Download took %.2f seconds\n', toc);
            
            obj.downloadStatus = (status == 0);
            downloadStatus = obj.downloadStatus;
        end
        
        function copyAllToGliderViz(obj)
            % COPYALLTOGLIDERVIZ - Copy both local files to gliderviz folder as .txt
            try
                % Convert gomofs.csv -> gomofs.txt
                dest_gomofs = fullfile(obj.glidervizFolder, strrep(obj.file_gomofs, '.csv', '.txt'));
                copyfile(fullfile(obj.localFolder, obj.file_gomofs), dest_gomofs);
                
                % Convert doppio.csv -> doppio.txt
                dest_doppio = fullfile(obj.glidervizFolder, strrep(obj.file_doppio, '.csv', '.txt'));
                copyfile(fullfile(obj.localFolder, obj.file_doppio), dest_doppio);
                
                fprintf('Copied files to GliderViz as .txt successfully.\n');
            catch ME
                warning('Error copying files to GliderViz: %s', ME.message);
            end
        end

        
        function updateAll(obj)
            % UPDATEALL - Download and copy in one go
            if obj.downloadAll()
                obj.copyAllToGliderViz();
            else
                warning('Download failed — skipping copy to GliderViz.');
            end
        end
    end
end
