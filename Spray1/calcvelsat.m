function data=calcvelsat(d,opname)
% function calcvelsat(data,opname) calculates velocity given sat data
% structure d.  This is specifically for sat data, as it does not take
% advantage of post-processed dr.
%

% D. Rudnick September 1, 2008
% Robert Todd, 3 January 2016, deal with multi-cycle dives

R=6378000; %radius of the earth (meters)
Gps_No_Surfacing=9; %no surface flag


data=d;

% Version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='calcvelsat';
data.qual.operator(nop).params.R=R;
data.qual.operator(nop).params.Gps_No_Surfacing=Gps_No_Surfacing;
data.qual.operator(nop).opentime=round(dn2ut(now));

% Do it
dx=pi/180*R*diff(data.lon,1,2).*cos(pi/180*mean(data.lat,2));
dy=pi/180*R*diff(data.lat,1,2);
dt=diff(data.time,1,2);
data.u=(dx-data.eng.en.drx)./dt;
data.v=(dy-data.eng.en.dry)./dt;
data.qual.u=max(data.qual.gps,[],2);

% Deal with multi-cycle dives
pp=data.qual.gps(:,2) == Gps_No_Surfacing;
ppd2=diff(pp);
istart=find(ppd2 == 1)+1;
iend=find(ppd2 == -1);
for n=1:length(istart)
   im=istart(n):iend(n)+1;
   drx=data.eng.en.drx(iend(n));
   dry=data.eng.en.dry(iend(n));
   dx=pi/180*R*(data.lon(im(end),2)-data.lon(im(1),1))*cos(pi/180*(data.lat(im(end),2)+data.lat(im(1),1))/2);
   dy=pi/180*R*(data.lat(im(end),2)-data.lat(im(1),1));
   dt=(data.time(im(end),2)-data.time(im(1),1));
   data.u(im)=(dx-drx)/dt;
   data.v(im)=(dy-dry)/dt;
end

data.qual.operator(nop).closetime=round(dn2ut(now));
