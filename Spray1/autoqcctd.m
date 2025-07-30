function data=autoqcctd(d,opname)
% function data=autoqcctd(data) applies auto QC on pressure, temperature, and
% salinity.
%

% Gui Castelao, Dec 9 2016. Strongly based on qcctdvar.m version:
%     Dan Rudnick, August 16, 2013, survives aborted dives
% D. Rudnick, Dec 15 2016, mods to name and a few minor things

globalRangeMinP = -1;
globalRangeMaxP = 1600;
globalRangeMinT = -2.5;
globalRangeMaxT = 45.0;
globalRangeMinS = 2.0;
globalRangeMaxS = 41.0;

% CTD flags
Ctd_Sensor_Off = 9;
Ctd_autoBad=4;
Ctd_Good=0;

data=d;

nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='autoqcctd';
data.qual.operator(nop).params.Ctd_Good=Ctd_Good;
data.qual.operator(nop).params.Ctd_autoBad=Ctd_autoBad;
data.qual.operator(nop).params.Ctd_Sensor_Off=Ctd_Sensor_Off;
data.qual.operator(nop).params.globalRangeMinP=globalRangeMinP;
data.qual.operator(nop).params.globalRangeMaxP=globalRangeMaxP;
data.qual.operator(nop).params.globalRangeMinT=globalRangeMinT;
data.qual.operator(nop).params.globalRangeMaxT=globalRangeMaxT;
data.qual.operator(nop).params.globalRangeMinS=globalRangeMinS;
data.qual.operator(nop).params.globalRangeMaxS=globalRangeMaxS;
data.qual.operator(nop).opentime=round(dn2ut(now));

num=size(data.time,1);

% Pressure
if ~isfield(data.qual, 'p')
    data.qual.p=cell(num,1);
end
% Temperature
if ~isfield(data.qual, 't')
    data.qual.t=cell(num,1);
end
% Salinity
if ~isfield(data.qual, 's')
    data.qual.s=cell(num,1);
end
for n=1:num
   % Pressure
   if isempty(data.qual.p{n})
       data.qual.p{n} = zeros(size(data.p{n}));
   end
   % No measurement (NaN)
   idx = (data.qual.p{n} < Ctd_Sensor_Off) & isnan(data.p{n});
   data.qual.p{n}(idx) = Ctd_Sensor_Off;
   % Out of range
   idx = (data.qual.p{n} < Ctd_autoBad);
   idx = idx & (data.p{n} < globalRangeMinP) | (data.p{n} > globalRangeMaxP);
   data.qual.p{n}(idx) = Ctd_autoBad;

   % Temperature
   if isempty(data.qual.t{n})
       data.qual.t{n} = zeros(size(data.t{n}));
   end
   % No measurement (NaN)
   idx = (data.qual.t{n} < Ctd_Sensor_Off) & isnan(data.t{n});
   data.qual.t{n}(idx) = Ctd_Sensor_Off;
   % Out of range
   idx = (data.qual.t{n} < Ctd_autoBad);
   idx = idx & (data.t{n} < globalRangeMinT) | (data.t{n} > globalRangeMaxT);
   data.qual.t{n}(idx) = Ctd_autoBad;

   % Salinity
   if isempty(data.qual.s{n})
       data.qual.s{n} = zeros(size(data.s{n}));
   end
   % No measurement (NaN)
   idx = (data.qual.s{n} < Ctd_Sensor_Off) & isnan(data.s{n});
   data.qual.s{n}(idx) = Ctd_Sensor_Off;
   % Out of range
   idx = (data.qual.s{n} < Ctd_autoBad);
   idx = idx & (data.s{n} < globalRangeMinS) | (data.s{n} > globalRangeMaxS);
   % Salinity measurements depends on temperature, so can't be better than T.
   idx = idx | (data.qual.t{n} == Ctd_autoBad);
   data.qual.s{n}(idx) = Ctd_autoBad;

end

data.qual.operator(nop).closetime=round(dn2ut(now));
