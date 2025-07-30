function data=calox(data,mission,opname,calfilename)
% function data=calox(data,opname) calibrates oxygen, reading oxygen
% calibration constants from spreadsheet
%

% D. Rudnick, 14 July 2020
% D. Rudnick, 17 February 2021 new calibration file
% D. Rudnick, 9 August 2021, add oxumolkg
% D. Rudnick, 26 August 2021, introduce logical data.cal.ox

filename='/Users/Shared/spray/data/ox/doxcal.xlsx';
sheetname='AllOxMissions';
DOConv=44660; %DO conversion constant from ml/l to micromole/kg

if nargin == 4
   filename=calfilename;
end

% Version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='calox';
data.qual.operator(nop).params.filename=filename;
data.qual.operator(nop).params.sheetname=sheetname;
data.qual.operator(nop).params.DOConv=DOConv;
data.qual.operator(nop).opentime=round(dn2ut(now));

%read spreadsheet
% warning('off','MATLAB:table:ModifiedAndSavedVarnames');
T=readtable(filename,'Sheet',sheetname,'Format','auto');

%find index to use
jj=strlength(T.MissionName) < 8; %find active missions
T.MissionName(jj)=cellfun(@(x) sprintf('%04d',str2double(x)),T.MissionName(jj),'UniformOutput',false); %add 00 to front
ii=find(strcmp(mission,T.MissionName) & ~isnan(T.CalValue1));

if isempty(ii) %if no match, set Gain=1, Offset=0
   data.cal.ox=false;
   fprintf(1,'%s No Calibration\n',mission);
   Gain=1;
   Offset=0;
else %if match then get gain, offset from spreadsheet
   data.cal.ox=true;
   Gain=T.CalValue1(ii);
   Offset=T.CalValue2(ii);
end

% Check if oxygen has already been calibrated, so that data.orig.ox exists.
% Then save original data, or bring it forward to use in the calculation.
if ~isfield(data.orig,'ox') %oxygen has not previously calibrated
   data.orig.ox=data.ox;
   data.orig.oxconc=data.oxconc;
else %oxygen has been previously calibrated
   data.ox=data.orig.ox;
   data.oxconc=data.orig.oxconc;
end

%write what is happening
fprintf(1,'%s %f %f\n',mission,Gain,Offset);

%apply calibration
num=length(data.ox);
for n=1:num
   data.oxconc{n}=data.oxconc{n}*Gain+Offset;
   data.ox{n}=data.oxconc{n}./oxs_calc(data.t{n},data.s{n});
   data.oxumolkg{n}=DOConv*data.oxconc{n}./(data.sigma{n}+1000);
end

%Save gain, offset, and close
data.qual.operator(nop).params.Gain=Gain;
data.qual.operator(nop).params.Offset=Offset;
data.qual.operator(nop).closetime=round(dn2ut(now));
