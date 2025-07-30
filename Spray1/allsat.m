function [data,bindata]=allsat(file,pmin,pstep,pmax,pd,opname)
% function [data,bindata]=allsat(file,pmin,pstep,pmax,pd,opname) function
% to read spray data from file and make data and bindata.  pmin, pstep,
% pmax define the bins. pd is a string that takes the values 'p' or 'd' to
% bin over pressure or depth.  opname is the operator's name for version
% control.
%

% Dan Rudnick, Septmber 1, 2008
% Dan Rudnick, May 16, 2012, added adp and ph
% Dan Rudnick, 9 August 2021, calibrate ox and fl

data=readsat(file,opname);
data=fixgps3(data,opname);
data=calcvelsat(data,opname);
data=autoqcctd(data,opname);

if isfield(data,'ox')
   [~,mission,~]=fileparts(file);
   data=calox(data,mission,opname);
   if ~data.cal.ox
      warning('ox exists and no oxygen calibration');
   end
end

if isfield(data,'fl')
   [~,mission,~]=fileparts(file);
   data=calfchl(data,mission,opname);
end

bindata=binsat(data,pmin,pstep,pmax,pd);

if isfield(data,'adp')
   data=adpsat(data,opname);
   binadp=adpsatbin(data.adp,pmin,pstep,pmax);
   bindata.udop=binadp.u;
   bindata.vdop=binadp.v;
   bindata.abs=binadp.abs;
end

