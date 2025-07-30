function bindata=binsat(data,pmin,pstep,pmax,pd,exclude)
% function bindata=binsat(data,pmin,pstep,pmax,pd,exclude) makes the structure
% bindata of data binnned in pressure on the grid [pmin:pstep:pmax].  The
% string pd can be either 'p' or 'd' to bin in pressure or depth. The
% optional string exclude can be 'none','bad','questionable' to tell the
% routine which points to exclude. The default is 'bad'.
% 

% Dan Rudnick, September 1, 2008
% Robert Todd, 15 September 2008, added flag support
%              27 October 2008, added time of creation field (bintime)
%              7 July 2009, added timeu,latu,lonu,u,v fields
%              8 July 2009, bindata.u,v set to NaN where quality flag not Gps_Good
% Dan Rudnick, March 2, 2011, added oxygen, and logic to tell whether fl
% and ox are present
% Dan Rudnick, July 17 2014, new way of calculating time, lat, lon
% Dan Rudnick, February 26 2021, added oxumolkg
%


% Define flags
Ctd_Sensor_Off = 9;
Ctd_Bad=7;
Ctd_Questionable=3;
Gps_Good = 0;
Time_Sample=8;

bindata.time=data.time(:,1)+.75*(data.time(:,2)-data.time(:,1));
bindata.lat=data.lat(:,1)+.75*(data.lat(:,2)-data.lat(:,1));
bindata.lon=data.lon(:,1)+.75*(data.lon(:,2)-data.lon(:,1));
bindata.timeu=data.time(:,1)+.5*(data.time(:,2)-data.time(:,1));
bindata.latu=data.lat(:,1)+.5*(data.lat(:,2)-data.lat(:,1));
bindata.lonu=data.lon(:,1)+.5*(data.lon(:,2)-data.lon(:,1));
bindata.u=data.u;
bindata.v=data.v;
bindata.u(data.qual.u~=Gps_Good)=NaN;
bindata.v(data.qual.u~=Gps_Good)=NaN;
% BW add start and end dive
bindata.time_=[data.time(:,1),data.time(:,2)];
bindata.lat_=[data.lat(:,1),data.lat(:,2)];
bindata.lon_=[data.lon(:,1),data.lon(:,2)];

% use different method to determin time, lat, lon for dives in drift mode
if isfield(data.eng,'ed');
   jj=find(data.eng.ed.drifttime > 0);
   for m=1:length(jj)
      n=jj(m);
      if ~isempty(data.t{n});
         num=length(data.t{n});
         time2m=data.time(n,2)-data.eng.en.tend(n)-max(data.eng.gps.tfix(n,2),0);
         bindata.time(n)=time2m-(num-1)/2*Time_Sample*data.eng.ef.navg(n);
         bindata.lat(n)=data.lat(n,1)+(bindata.time(n)-data.time(n,1))/(data.time(n,2)-data.time(n,1))*(data.lat(n,2)-data.lat(n,1));
         bindata.lon(n)=data.lon(n,1)+(bindata.time(n)-data.time(n,1))/(data.time(n,2)-data.time(n,1))*(data.lon(n,2)-data.lon(n,1));
      end
   end
end

if pd == 'p'
   bindata.p=(pmin:pstep:pmax)';
   pstr='p';
elseif pd =='d'
   bindata.depth=(pmin:pstep:pmax)';
   pstr='depth';
else
   error('pd must be ''p'' (pressure) or ''d'' (depth)');
end

if nargin == 6
    switch exclude(1)
        case 'n'
            maxflag = Ctd_Sensor_Off;
        case 'b'
            maxflag = Ctd_Bad;
        case 'q'
            maxflag = Ctd_Questionable;
        otherwise
            error('exclude must be ''none'', ''bad'' or ''questionable''');
    end
else
    maxflag = Ctd_Bad;
end

nt=length(bindata.time);
np=length(bindata.(pstr));
bindata.t=nan(np,nt);
bindata.s=nan(np,nt);
if isfield(data,'fl')
   bindata.fl=nan(np,nt);
end
if isfield(data,'cdom')
   bindata.cdom=nan(np,nt);
end
if isfield(data,'ox')
   bindata.ox=nan(np,nt);
end
bindata.theta=nan(np,nt);
bindata.sigma=nan(np,nt);
bindata.rho=nan(np,nt);
if isfield(data,'oxconc')
   bindata.oxconc=nan(np,nt);
end
if isfield(data,'oxumolkg')
   bindata.oxumolkg=nan(np,nt);
end

for n=1:nt
    if ~isempty(data.(pstr){n}) % then there are data to bin
        ibin=round((data.(pstr){n}-pmin)/pstep)+1;
        for m=1:np
            iit = (ibin == m) & data.qual.t{n} < maxflag;
            iis = (ibin == m) & data.qual.s{n} < maxflag;
            ii = iit & iis;
            bindata.t(m,n)=nanmean(data.t{n}(iit));
            bindata.s(m,n)=nanmean(data.s{n}(iis));
            if isfield(data,'fl')
               iifl = (ibin == m) & data.qual.fl{n} < maxflag;
               bindata.fl(m,n)=nanmean(data.fl{n}(iifl));
            end
            if isfield(data,'cdom')
               iicdom = (ibin == m) & data.qual.cdom{n} < maxflag;
               bindata.cdom(m,n)=nanmean(data.cdom{n}(iicdom));
            end
            if isfield(data,'ox')
               iiox = (ibin == m) & data.qual.ox{n} < maxflag;
               bindata.ox(m,n)=nanmean(data.ox{n}(iiox));
               bindata.oxconc(m,n)=nanmean(data.oxconc{n}(iiox));
               if isfield(data,'oxumolkg')
                  iioxumolkg = iiox & ii;
                  bindata.oxumolkg(m,n)=nanmean(data.oxumolkg{n}(iioxumolkg));
               end
            end
            bindata.theta(m,n)=nanmean(data.theta{n}(ii));
            bindata.sigma(m,n)=nanmean(data.sigma{n}(ii));
            bindata.rho(m,n)=nanmean(data.rho{n}(ii));
        end
    end
end

bindata.function='binsat';
bindata.bintime = round(dn2ut(now));
