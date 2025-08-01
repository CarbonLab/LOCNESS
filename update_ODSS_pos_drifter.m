function update_ODSS_pos_drifter(inst_name, sdn, lon, lat)

% update_ODSS_pos(inst_name, sdn, lon, lat)
%
% Updates position of drifter positions on ODSS. 
%
% inst_name: character array of instrument name on ODSS
% sdn: serial date number for location
% lon: longitude for location
% lat: latitude for location

% Updated for drifter; Shawnee, August 2025
% Written by: Yui Takeshita
% MBARI
% 12/18/2023


% convert to epoch time, which is what ODSS uses. 
epocht = posixtime(datetime(sdn,'ConvertFrom','datenum'));

% set email preferences
setpref('Internet', 'E_mail', 'straylor@mbari.org');
setpref('Internet', 'SMTP_Server', 'mail.mbari.org');

% send email to update ODSS location
sendmail('driftertrack@mbari.org', [inst_name,',',num2str(epocht),',',num2str(lon,'%1.5f'), ...
    ',',num2str(lat,'%1.5f')]);

end
