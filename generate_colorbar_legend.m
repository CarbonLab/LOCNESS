function generate_colorbar_legend(tmin, tmax, varname)
% GENERATE_COLORBAR_LEGEND - Creates a colorbar image for a given variable range.
%
% Inputs:
%   tmin    - Minimum value of the variable
%   tmax    - Maximum value of the variable
%   varname - Name of the variable (e.g., 'Temperature', 'Salinity'), used for title and filename
global rep_kml_global kml_global

    % Make a clean variable label and filename
    varLabel = strrep(varname, '_', ' ');
    fileLabel = lower(strrep(varname, ' ', '_'));

    % Generate invisible figure
    figure('Visible','off');
    c = colorbar('southoutside');

    if strcmp(lower(varname),'rhodamine') == 1
        t = cmocean('amp',64) ;
        t = t .* [1 .6 1.5] ; t(t>1) = 1;
        t(1,:) = [1 1 1];
        t(2:20,:) = [linspace(t(1,1),t(20,1),19)' linspace(t(1,2),t(20,2),19)' linspace(t(1,3),t(20,3),19)'];
        colormap(t)
        c.Label.String = 'Rhodamine (ppb)';
        caxis([0 tmax]);
    
    elseif strcmp(lower(varname),'ph') == 1
        cmocean('speed')
        c.Label.String = 'pH';
        caxis([7.5 8.5]);
        c.Ticks = [7.5:.1:8.5];

    elseif strcmp(lower(varname),'temperature') == 1
    
    else
        colormap(gcf);
        c.Label.String = sprintf('%s', varLabel);
        caxis([tmin tmax]);
    end
    
   c.FontSize = 16 ;
    
% Add padding by changing the axes position
ax = gca;
outerMargin = 0.37; % Fraction of figure space
ax.Position = [outerMargin outerMargin 1-2*outerMargin 1-2*outerMargin];

  %  set(gcf, 'Position', [24   487   204   356]); % wide format
    % set(c,'Position', [0.4000    0.1400    0.5000    0.0700])
    axis off

% Export to file
    filename = fullfile(rep_kml_global, 'legend-icons', sprintf('%s.png', fileLabel));
    %filename = sprintf('%s.png', fileLabel);
%     exportgraphics(gcf, filename,'Padding', 80, 'BackgroundColor', 'none');
    exportgraphics(gcf, filename);
    close
    
end
%%
