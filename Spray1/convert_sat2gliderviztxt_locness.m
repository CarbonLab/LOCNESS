function [] = convert_sat2gliderviztxt_locness(s, missionname, is_sat)
%
% adopted from convert_mergedmat2fltviztxt.m
%
% This script converts the merged float data (created by
% merge_ctd_nitrate_matfiles.m) into a text file in a format that can be
% used by SAGE. The text file format follows that from floatviz
% (https://www.mbari.org/science/upper-ocean-systems/chemical-sensor-group/floatviz/).
%
% Options for is_sat are:
% 1 = real-time sat data (saves with RT.txt suffix)
% 2 = full resolution data (saves with .txt suffix)
% 3 = QC'd data (saves with *QC.txt suffix and under \QC\ folder)
% User input is fltname (string).
%
% Currently the text file name is fltnameKEO.txt (i.e. 2903330KEO.txt).
%
%
% Created by Yui Takeshita
% MBARI
% Dec 4, 2018
%
% Modification Notes
%
% December 10, 2018
% - Data file is now written from highest pressure to lowest, to be
% consistent with FltVIZ.
% - Moved the std_str outside of the for loop for rows to prevent errors
% with the profile spacer fprintf
% - Now does not write data from a specific row if all P, T, and S data are
% missing
%
% December 11, 2018
% - Added 'ODV' to the beginning of the written textfile (for SAGE), and
% now is included in the user input
% - Added line in // header for '//WMO ID: fltnum'. SAGE needs this in
% order to write the QC file using the 'Reprocess' button.
% - Added a flag conversion, where if JAMSTEC flag = 9, make it 8 (bad
% data; for oxygen these values were -9999.9999).
% - Added display at end of script to notify what file was written
%
% April 5, 2019
% - changed so it can do spray glider conversion
% - kept 'flt' structure, and added code to transcribe data from 's'
% structure to 'flt' structure
% - loops through and sees if the fieldname exists. if not, creates an NaN
% matrix
% - Commented out flag conversions, because the sat mat file alreayd uses
% argo flags
% - adjusted headers that are written (kept float ID though, cause I think
% it might break something downstream)
% - uncommented line that checks to see if all TSP are missing. If so,
% finishes writing that profile and moves onto the next.
%
% April 14-15, 2019
% - Changed this into a function so that it can be called from
% update_GliderVIZ_sat.m
%
% April 16, 2019
% - Default array for missing variable_QC is now ones instead of NaN.
% Before, the MVI was getting written into the QF column, when it should've
% been 1.
%
% June 23, 2020
% - added input of 'is_sat' boolan to determine whether the text and cfg file names will have the
% 'RT' extension.

% Parts of code taken from 'argo2odv_LIAR.m', author Josh Plant and Tanya
% Maurer at MBARI.

% *************************************************************************
% USER INPUT HERE: CHOOSE FLOAT NAME. WILL NEED A fltname_merged.mat FILE
% IN THE PATH, AND WILL CREATE fltname_fltviz.txt
% *************************************************************************

path = '\\sirocco\wwwroot\lobo\data\glidervizdata\';

% missionname = '19402901';
if(is_sat == 1)
    txtfilename = [missionname,'RT.txt']; % output file name with RT extension (real time)
    cfgfilename = [missionname,'RT.cfg']; % output file name with RT extension (real time)
elseif (is_sat == 2)
    txtfilename = [missionname,'.txt']; % output file name
    cfgfilename = [missionname,'.cfg']; % config file name
elseif (is_sat == 3)
    txtfilename = [missionname,'QC.txt']; % output file name
    cfgfilename = [missionname,'QC.cfg']; % config file name
    path = [path '\QC\'];
end

% ************************************************************************
% LOAD DATA AND CHANGE QUALITY FLAG TO ARGO FORMAT
% ************************************************************************

% load sat mat file
% load([strippath(cd,1),'\Deployments\',missionname,'\',missionname,'_sat.mat']);

% ================ NEW CODE ==============================
% extract variables and flags from s strcuture (spray) to flt structure (so we can
% recycle code)
flt.SDN = s.sdn;
if(isfield(s, 'lat_'))
    flt.LAT = s.lat_(2,:); % end of dive location
    flt.LONG = s.lon_(2,:); % end of dive location
else
    flt.LAT = s.lat2;
    flt.LONG = s.lon2;
end
if isfield(s,'position_QC')
    flt.POSITION_FLAG = s.position_QC;
end
if isfield(s, 'pres')
    flt.PRES = s.pres;
end
if isfield(s, 'pres_QC')
    flt.PRES_FLAG = s.pres_QC;
end
if isfield(s, 'tc')
    flt.TEMP = s.tc;
end
if isfield(s, 'tc_QC')
    flt.TEMP_FLAG = s.tc_QC;
end
if isfield(s, 'psal')
    flt.SAL = s.psal;
end
if isfield(s, 'psal_QC')
    flt.SAL_FLAG = s.psal_QC;
end
if isfield(s, 'pdens')
    flt.SIGMA_THETA = s.pdens;
end
if isfield(s, 'pdens_QC')
    flt.SIGMA_THETA_FLAG = s.pdens_QC;
end
if isfield(s, 'depth')
    flt.DEPTH = s.depth;
end
if isfield(s, 'depth_QC')
    flt.DEPTH_FLAG = s.depth_QC;
end
if isfield(s, 'doxy')
    flt.SBE63DO = s.doxy;
end
if isfield(s, 'doxy_QC')
    flt.SBE63DO_FLAG = s.doxy_QC;
end
if isfield(s, 'o2satper')
    flt.O2SATPER = s.o2satper;
end
if isfield(s, 'o2satper_QC')
    flt.O2SATPER_FLAG = s.o2satper_QC;
end
if isfield(s, 'opt')
    flt.CHL = s.opt;
end
if isfield(s, 'opt_QC')
    flt.CHL_FLAG = s.opt_QC;
end
if isfield(s, 'opt_QC')
    flt.RHODAMINE_FLAG = s.opt_QC;
end
if isfield(s,'pHin')
    flt.PH_IN_SITU_TOTAL = s.pHin;
    flt.PH_IN_SITU_TOTAL_FLAG = s.pHin_QC;
    flt.PH_25_ATM_TOTAL = s.pH25atm;
    flt.PH_25_ATM_TOTAL_FLAG = s.pH25atm_QC;
    flt.TA_CANYONB = s.ta_canb;
    flt.TA_CANYONB_FLAG = s.ta_canb_QC;
    flt.DIC_CANYONB = s.dic_canb;
    flt.DIC_CANYONB_FLAG = s.dic_canb_QC;
    flt.pCO2_CANYONB = s.pco2in;
    flt.pCO2_CANYONB_FLAG = s.pco2in_QC;
    flt.SAT_AR_CANYONB = s.satarin;
    flt.SAT_AR_CANYONB_FLAG = s.satarin_QC;
end
if isfield(s,'par')
    flt.PAR = s.par;
    flt.PAR_FLAG = s.par_QC;
    flt.IRRAD_380 = s.rad01;
    flt.IRRAD_380_FLAG = s.rad01_QC;
    flt.IRRAD_443 = s.rad02;
    flt.IRRAD_443_FLAG = s.rad02_QC;
    flt.IRRAD_490 = s.rad03;
    flt.IRRAD_490_FLAG = s.rad03_QC;
end
if isfield(s,'vrs')
    % add VRS, VRS_STD, VK, VK_STD, IK, IB, pHin_canb
    flt.VRS = s.vrs;
        flt.VRS_FLAG = s.pres_QC;
    flt.VRS_STD = s.vrs_std;
    flt.VK = s.vk;
    flt.VK_STD = s.vk_std;
    flt.IK = s.Ik;
    flt.IB = s.Ib;
    flt.PHIN_CANYONB = s.pHin_canb;
    
    flt.VRS_FLAG = s.pres_QC;
    flt.VRS_STD_FLAG = s.pres_QC;
    flt.VK_FLAG = s.pres_QC;
    flt.VK_STD_FLAG = s.pres_QC;
    flt.IK_FLAG = s.pres_QC;
    flt.IB_FLAG = s.pres_QC;
    flt.PHIN_CANYONB_FLAG = s.pin_canb_QC;
end
% add RHODAMINE if available
if(isfield(s, 'rhodamine'))
    flt.RHODAMINE = s.rhodamine;
    flt.RHODAMINE_FLAG = s.pres_QC;
end
% add RHODAMINE if available
if(isfield(s, 'divedir'))
    flt.DIVEDIR = s.divedir;
    flt.DIVEDIR_FLAG = s.divedir_QC;
end

% add any additional variables here.

% =========================================================================

% define some useful variables
[flt_c, flt_r] = size(flt.PRES);
MVI_str = '-1e10'; % missing value indicator for ODV

% ************************************************************************
% BUILD LOOK UP CELL ARRAY to match variables and set format string
% ************************************************************************
%
% this section basically taken from argo2odv_LIAR.m

%RAW ODV FILE
% column 1: header that will be printed to file
% column 2: string format for file
% column 3: variable name in float structure
flt_vars(1,:)  = {'Pressure[dbar]'        '%0.2f' 'PRES' '' '' ''}; % ?
flt_vars(2,:)  = {'Temperature[°C]'       '%0.4f' 'TEMP' '' '' ''};
flt_vars(3,:)  = {'Salinity[pss]'         '%0.4f' 'SAL' '' '' ''};
flt_vars(4,:)  = {'Sigma_theta[kg/m^3]'   '%0.3f' 'SIGMA_THETA' '' '' ''};
flt_vars(5,:)  = {'Depth[m]'              '%0.3f' 'DEPTH' '' '' ''};
flt_vars(6,:)  = {'Oxygen[µmol/kg]'       '%0.2f' 'SBE63DO' '' '' ''};
flt_vars(7,:)  = {'OxygenSat[%]'          '%0.1f' 'O2SATPER' '' '' ''};
flt_vars(8,:)  = {'Nitrate[µmol/kg]'      '%0.2f' 'NITRATE' '' '' ''};
flt_vars(9,:)  = {'Chl_a[mg/m^3]'         '%0.4f' 'CHL' '' '' ''};
flt_vars(10,:) = {'b_bp700[1/m]'          '%0.6f' 'BBP700' '' '' ''};

% ADD THESE FOR ODV FLAVOR #2
flt_vars(11,:) = {'pHinsitu[Total]'       '%0.4f' 'PH_IN_SITU_TOTAL' '' '' ''};

% ADD THESE FOR ODV FLAVOR #3 - NAVIS
flt_vars(12,:) = {'b_bp532[1/m]'          '%0.6f' 'BBP532' '' '' ''};
flt_vars(13,:) = {'CDOM[ppb]'             '%0.2f' 'FDOM' '' '' ''};

% These are for calculate carbonate parameters
flt_vars(14,:) = {'TALK_CANYONB[µmol/kg]' '%0.0f' 'TA_CANYONB' '' '' ''};
flt_vars(15,:) = {'DIC_CANYONB[µmol/kg]'  '%0.0f' 'DIC_CANYONB' '' '' ''};
flt_vars(16,:) = {'pCO2_CANYONB[µatm]'    '%0.1f' 'pCO2_CANYONB' '' '' ''};
flt_vars(17,:) = {'SAT_AR_CANYONB[]'      '%0.3f' 'SAT_AR_CANYONB' '' '' ''};
flt_vars(18,:) = {'pH25C_1atm[Total]'     '%0.4f' 'PH_25_ATM_TOTAL' '' '' ''};
flt_vars(19,:) = {'DOWNWELL_PAR[µmol Quanta/m^2/sec]'     '%0.1f' 'PAR' '' '' ''};
flt_vars(20,:) = {'DOWN_IRRAD380[W/m^2/nm]'     '%0.1f' 'IRRAD_380' '' '' ''};
flt_vars(21,:) = {'DOWN_IRRAD443[W/m^2/nm]'     '%0.1f' 'IRRAD_443' '' '' ''};
flt_vars(22,:) = {'DOWN_IRRAD490[W/m^2/nm]'     '%0.1f' 'IRRAD_490' '' '' ''};

flt_vars(23,:) = {'VRS[Volts]'          '%1.6f'  'VRS' '' '' ''};
flt_vars(24,:) = {'VRS_STD[Volts]'      '%1.6f'  'VRS_STD' '' '' ''};
flt_vars(25,:) = {'VK[Volts]'           '%1.6f'  'VK' '' '' ''};
flt_vars(26,:) = {'VK_STD[Volts]'       '%1.6f'  'VK_STD' '' '' ''};
flt_vars(27,:) = {'IK[nA]'              '%1.2f'  'IK' '' '' ''};
flt_vars(28,:) = {'Ib[nA]'              '%1.2f'  'IB' '' '' ''};
flt_vars(29,:) = {'PHIN_CANYONB[Total]'       '%0.4f' 'PHIN_CANYONB' '' '' ''};
flt_vars(30,:) = {'RHODAMINE[ppb]'          '%0.4f'  'RHODAMINE' '' '' ''};
flt_vars(31,:) = {'DIVEDIR'          '%d'  'DIVEDIR' '' '' ''};

% add additional variables here.

flt_var_ct = size(flt_vars,1); % number of variables to write

% ========================================================================
% Create NaN arrays for variables that don't exist: Sigma_theta, % modified
% for spray, 4/5/2019
% Changed the default array for the QC array to ones. 4/16/2019 YT

% check to see if the variables exist. if not, create it
for i = 1:size(flt_vars,1)
    if(~isfield(flt, flt_vars{i,3}))
        flt.(flt_vars{i,3}) = NaN(size(flt.TEMP));
        flt.([flt_vars{i,3},'_FLAG']) = ones(size(flt.PRES));
    end

end
% =======================================================================
% CHANGE QUALITY FLAGS FROM ARGO FORMAT TO GLIDERVIZ
%  0=Good, 4=Questionable, 8=Bad, 1=Missing or not inspected
for i = 1:size(flt_vars,1)
    flagvar = [flt_vars{i,3},'_FLAG']; % get name of flag variable
    tempflag = flt.(flagvar); % temporary variable to save flags into

    % if NaN -> 1; missing data
    tempflag(isnan(flt.(flagvar))) = 1;
        % if NaN -> 1; missing data
    tempflag(flt.(flagvar)==9) = 1;
    % if 1 -> 0; good data
    tempflag(flt.(flagvar)==1) = 0;
    % if 4 -> 8; bad data.
    tempflag(flt.(flagvar)==4) = 8;
    % if 2 or 3 -> 4; questionable data
    tempflag(flt.(flagvar)==2 | flt.(flagvar)==3) = 4;

    flt.(flagvar) = tempflag; % save over original flag
end

% Change quality flag for POSITION_FLAG and juld_QC (They were all good so
% just convert 1 to 0)
% flt.JULD_QC(flt.JULD_QC=='1') = '0';
% flt.POSITION_FLAG(flt.POSITION_FLAG=='1') = '0';

% *************************************************************************
% PRINT COMMENTED HEADERS
% *************************************************************************

% Open file, write access
fid = fopen(txtfilename, 'w');

if(is_sat)
    fprintf(fid, '//File Created from Spray glider sat file\r\n');
else
    fprintf(fid, '//File Created from full resolution Spray data upon recovery\r\n');
end

fprintf(fid, ['//File updated on ',datestr(now,'mm/dd/yyyy HH:MM'),'\r\n']);
fprintf(fid, ['//Float ID: ',missionname,'\r\n']);
fprintf(fid, ['//WMO ID: ',missionname,'\r\n']); % added 12/11/2018 YT
fprintf(fid, '//Missing data value = -1e10\r\n');
fprintf(fid, ['//Data quality flags: 0=Good, 4=Questionable, 8=Bad, '...
    '1=Missing or not inspected \r\n']);

% *************************************************************************
% PRINT VARIABLE HEADERS
% *************************************************************************
%
% this section basically taken from argo2odv_LIAR.m

% Standard ODV variable headers
std_ODV_vars   = {'Cruise' 'Station' 'Type' 'mon/day/yr' 'hh:mm' ...
    'Lon [°E]' 'Lat [°N]' 'QF'}; % SIZE = 8
std_size = size(std_ODV_vars,2);

for i = 1:std_size % PRINT STANDARD HEADER VARS
    fprintf(fid,'%s\t',std_ODV_vars{1,i}); % std vars
end

% Float specific variable headers
for i = 1:flt_var_ct % PRINT FLOAT SPECIFIC HEADER VARS
    if i < flt_var_ct
        fprintf(fid,'%s\t%s\t',flt_vars{i,1},'QF'); % std vars
    else
        fprintf(fid,'%s\t%s\r\n',flt_vars{i,1},'QF'); % std vars
    end
end

% *************************************************************************
% NOW PRINT DATA LINES TO FILE
% *************************************************************************

ODV_std_f = '%s\t%0.0f\t%s\t%s\t%s\t%0.3f\t%0.3f\t%0.0f\t'; %std_var format

% create string of n tabs, where n = number of variables
profspacertabs = '';
for i = 1:size(flt_vars,1)-1
    profspacertabs = [profspacertabs,'\t'];
end

nlines = 0; % counter for number of lines in the floatviz file

% loop through columns (c) and rows (r)
for c = 1:length(flt.SDN)
    if(~isnan(flt.SDN(c)))
        % get date str and time str
        date_str = datestr(flt.SDN(c), 'mm/dd/yyyy');
        time_str = datestr(flt.SDN(c), 'HH:MM');
        % Build standard variable string and write to file.
        % moved this section outside of for loop for r below. 12/10/2018 YT
        std_str = sprintf(ODV_std_f, missionname, c, 'C', ...
            date_str, time_str, flt.LONG(c), flt.LAT(c), flt.POSITION_FLAG(c));
        regexprep(std_str, 'NaN', MVI_str); % replace Nans with MVI
        % now loop through rows
        for r = size(flt.PRES,1):-1:1 % Changed this to decrement 12/10/2018 YT
            % check to see if there's any pressure data. if not, break.
            if(~isnan(flt.PRES(r,c)) && ~isnan(flt.TEMP(r,c)) && ~isnan(flt.SAL(r,c))) %Only write data if pressure, temp, or salt data exists % modified from just pressure, Dec-10-2018 YT

                fprintf(fid, std_str); % write std to file

                % Build float variable string and write to file

                var_str = ''; % initialize
                for v = 1:size(flt_vars,1) % loop through each variable
                    if(v < size(flt_vars,1)) % check to see if it's last one
                        % if it's not the last one, add tab
                        var_str = [var_str,sprintf([flt_vars{v,2},'\t%0.0f\t'], flt.(flt_vars{v,3})(r,c), flt.([flt_vars{v,3},'_FLAG'])(r,c))];
                    else
                        % if it's the last one, don't add tab, but \r\n
                        var_str = [var_str,sprintf([flt_vars{v,2},'\t%0.0f\r\n'], flt.(flt_vars{v,3})(r,c), flt.([flt_vars{v,3},'_FLAG'])(r,c))];
                    end
                end

                % replace NaN' w/ missing value indicator
                var_str = regexprep(var_str,'NaN',MVI_str);
                % write variable
                fprintf(fid, var_str);
                nlines = nlines+1;
            end
        end

        % at the end of each profile, add profile spacer line, which
        fprintf(fid, [std_str,profspacertabs,'\r\n']);
        nlines = nlines+1;
    end
end

% close file
fid = fclose(fid);

disp(txtfilename);

% make .cfg file
fcfg = fopen(cfgfilename, 'w');
fprintf(fcfg, ['//',num2str(nlines,'%0.0f')]);
fclose(fcfg);

% copy files to sirocco
copyfile(txtfilename, path);
copyfile(cfgfilename, path);































