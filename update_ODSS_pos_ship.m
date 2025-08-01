function update_ODSS_pos_ship(inst_name, sdn, lon, lat)

% update_ODSS_pos_ship(inst_name, sdn, lon, lat)
%
% Updates position of ship positions on ODSS. 
%
% inst_name: character array of instrument name on ODSS
% sdn: serial date number for location
% lon: longitude for location
% lat: latitude for location

% Updated for ship; Shawnee, August 2025
% Written by: Yui Takeshita
% MBARI
% 12/18/2023


% convert to epoch time, which is what ODSS uses. 
epocht = posixtime(datetime(sdn,'ConvertFrom','datenum'));

% set email preferences
setpref('Internet', 'E_mail', 'straylor@mbari.org');
setpref('Internet', 'SMTP_Server', 'mail.mbari.org');

% send email to update ODSS location
sendmail('shiptrack@mbari.org', [inst_name,',',num2str(epocht),',',num2str(lon,'%1.5f'), ...
    ',',num2str(lat,'%1.5f')]);

end
