function data=fixgps3(d,opname)
% function data=fixgps3(d,opname) fixes the gps data by interpolating bad
% points of various kinds.  Also adds flags.
% 

% Dan Rudnick, September 1, 2008
% July 6, 2009.  fixed bug that would allow data.orig.time, lat, lon to be
% overwritten if fixgps is run more than once.
% August 21, 2009.  Major rewrite for version 2.
% Robert Todd, 29 October 2009: fix Gps_Too_Soon for postdive of dive 1 by
%   setting equal to predive for dive 2.
% Dan Rudnick, October 22 2014, removed Day Problem check.  Doesn't work
% for gliders in drift mode longer than a day.  Causes more problems than
% it fixes.
% Dan Rudnick, May 8, 2016, added constraint on a curvature check to avoid
% trying to access past end of array.
% Robert Todd, 19 May 2017, added confirmation that repeated GPS fixes
% don't have longitude sign flipped.

R=6378000; %radius of the earth (meters)
Too_Fast_On_Surface=5; %threshold for moving too fast on surface (m/s)
Too_Soon=60; %threshold for too short a dive (s)
Too_Far=100; %threshold for too far (km)
Bad_HDOP=12; %threshold for identifying fixes with bad HDOP

% GPS flags
Gps_Good=0;
Gps_Repeat=2;
Gps_Backward=3;
Gps_Too_Fast_On_Surface=4;
Gps_Too_Soon=5;
Gps_Too_Far=6;
Gps_Bad_HDOP=7;
Gps_Bad_Status=8;
Gps_No_Surfacing=9;

data=d;

% Version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='fixgps3';
data.qual.operator(nop).params.R=6378000;
data.qual.operator(nop).params.Too_Soon=Too_Soon;
data.qual.operator(nop).params.Too_Fast_On_Surface=Too_Fast_On_Surface;
data.qual.operator(nop).params.Too_Far=Too_Far;
data.qual.operator(nop).params.Bad_HDOP=Bad_HDOP;
data.qual.operator(nop).params.Gps_Good=Gps_Good;
data.qual.operator(nop).params.Gps_Repeat=Gps_Repeat;
data.qual.operator(nop).params.Gps_Backward=Gps_Backward;
data.qual.operator(nop).params.Gps_Too_Fast_On_Surface=Gps_Too_Fast_On_Surface;
data.qual.operator(nop).params.Gps_Too_Soon=Gps_Too_Soon;
data.qual.operator(nop).params.Gps_Too_Far=Gps_Too_Far;
data.qual.operator(nop).params.Gps_Bad_HDOP=Gps_Bad_HDOP;
data.qual.operator(nop).params.Gps_Bad_Status=Gps_Bad_Status;
data.qual.operator(nop).params.Gps_No_Surfacing=Gps_No_Surfacing;
data.qual.operator(nop).opentime=round(dn2ut(now));

% Check if fixgps has been run, so that data.orig exists.
% Then save original data, or bring it forward to use in the calculation.
if ~isfield(data,'orig') %fixgps has never been run
   data.orig.time=data.time;
   data.orig.lat=data.lat;
   data.orig.lon=data.lon;
else %fixgps has been run
   data.time=data.orig.time;
   data.lat=data.orig.lat;
   data.lon=data.orig.lon;
   % Make good any flags that were previously set by fixgps
   data.qual.gps(data.qual.gps > Gps_Good & data.qual.gps <= Gps_Bad_HDOP)=Gps_Good;
end

% Find dives with bad HDOP and fix.
if isfield(data.eng,'hdop')
   hdop=data.eng.hdop;
else
   hdop=data.eng.gps.hdop;
end
[nrow,ncol]=find(hdop(2:end-1,:) >= Bad_HDOP | hdop(2:end-1,:) < 0); %for all except first and last dive
if ~isempty(nrow)
   nrow=nrow+1;
   nn=nrow(ncol == 1);
   data.lon(nn,1)=data.lon(nn-1,2);
   data.lat(nn,1)=data.lat(nn-1,2);
   data.time(nn,1)=data.time(nn-1,2);
   data.qual.gps(nn,1)=Gps_Bad_HDOP;
   nn=nrow(ncol == 2);
   data.lon(nn,2)=data.lon(nn+1,1);
   data.lat(nn,2)=data.lat(nn+1,1);
   data.time(nn,2)=data.time(nn+1,1);
   data.qual.gps(nn,2)=Gps_Bad_HDOP;
end
if hdop(1,2) >= Bad_HDOP || hdop(1,2) < 0 %post-first dive fix
   data.lon(1,2)=data.lon(2,1);
   data.lat(1,2)=data.lat(2,1);
   data.time(1,2)=data.time(2,1);
   data.qual.gps(1,2)=Gps_Bad_HDOP;
end
if hdop(end,1) >= Bad_HDOP || hdop(end,1) < 0 %pre-last dive fix
   data.lon(end,1)=data.lon(end-1,2);
   data.lat(end,1)=data.lat(end-1,2);
   data.time(end,1)=data.time(end-1,2);
   data.qual.gps(end,1)=Gps_Bad_HDOP;
end
if hdop(1,1) >= Bad_HDOP || hdop(1,1) < 0 %first point flag only
   data.qual.gps(1,1)=Gps_Bad_HDOP;
end
if hdop(end,2) >= Bad_HDOP || hdop(end,2) < 0 %last point flag only
   data.qual.gps(end,2)=Gps_Bad_HDOP;
end

% Sometimes dives with good HDOP are flagged bad in the sat and raw files.
% Any Gps_Bad_Status flag that gets this far must be in this category.
% Set these to good, and change the sign on longitude.
ii=data.qual.gps == Gps_Bad_Status;
data.qual.gps(ii)=Gps_Good;
data.lon(ii)=-data.lon(ii);


% Find backwards time across a surface interval and fix
% Fix the point with the largest curvature in time
dt= data.time(2:end,1)-data.time(1:end-1,2);
nn2=find(dt < 0 & data.qual.gps(2:end,1) == Gps_Good & data.qual.gps(1:end-1,2) == Gps_Good);
if ~isempty(nn2) && (max(nn2) < size(data.time,1)-1) %constraint on size of nn2 added 5/8/16
   nn1=nn2+1;
   curvtime1=abs(data.time(nn1+1,1)-2*data.time(nn1,1)+data.time(nn1-1,1));
   curvtime2=abs(data.time(nn2+1,2)-2*data.time(nn2,2)+data.time(nn2-1,2));
   for n=1:length(nn2)
      if curvtime1 > curvtime2
         data.time(nn1(n),1)=data.time(nn2(n),2);
         data.lat(nn1(n),1)=data.lat(nn2(n),2);
         data.lon(nn1(n),1)=data.lon(nn2(n),2);
         data.qual.gps(nn1(n),1)=Gps_Backward;
      else
         data.time(nn2(n),2)=data.time(nn1(n),1);
         data.lat(nn2(n),2)=data.lat(nn1(n),1);
         data.lon(nn2(n),2)=data.lon(nn1(n),1);
         data.qual.gps(nn2(n),2)=Gps_Backward;
      end
   end
end

% Find repeated times on the surface
% Flag the second one as bad
nn=find(dt == 0 & data.qual.gps(2:end,1) == Gps_Good & data.qual.gps(1:end-1,2) == Gps_Good)+1;
data.qual.gps(nn,1)=Gps_Repeat;
data.lon(nn,1) = data.lon(nn-1,2); % make sure longitude is repeated from previous fix in case HDOP check flipped sign

% Find surface intervals where the surface velocity is too fast
% Fix the point with the largest curvature in lat or lon
% dist=gcircle(data.lat(3:end-1,1),data.lon(3:end-1,1),data.lat(2:end-2,2),data.lon(2:end-2,2))*1000;
dx=pi/180*R*(data.lon(3:end-1,1)-data.lon(2:end-2,2)).*cos(pi/180*(data.lat(3:end-1,1)+data.lat(2:end-2,2))/2);
dy=pi/180*R*(data.lat(3:end-1,1)-data.lat(2:end-2,2));
dist=sqrt(dx.^2+dy.^2);
dt=data.time(3:end-1,1)-data.time(2:end-2,2);
usurf=dist./dt;
nn2=find(usurf > Too_Fast_On_Surface & data.qual.gps(3:end-1,1) == Gps_Good & data.qual.gps(2:end-2,2) == Gps_Good)+1;
if ~isempty(nn2)
   nn1=nn2+1;
   curvlat1=abs(data.lat(nn1+1,1)-2*data.lat(nn1,1)+data.lat(nn1-1,1));
   curvlon1=abs(data.lon(nn1+1,1)-2*data.lon(nn1,1)+data.lon(nn1-1,1));
   curvlat2=abs(data.lat(nn2+1,2)-2*data.lat(nn2,2)+data.lat(nn2-1,2));
   curvlon2=abs(data.lon(nn2+1,2)-2*data.lon(nn2,2)+data.lon(nn2-1,2));
   clatd=abs(curvlat1-curvlat2);
   clond=abs(curvlon1-curvlon2);
   for n=1:length(nn2)
      if clatd(n) > clond(n)
         if curvlat1(n) > curvlat2(n)
            data.time(nn1(n),1)=data.time(nn2(n),2);
            data.lat(nn1(n),1)=data.lat(nn2(n),2);
            data.lon(nn1(n),1)=data.lon(nn2(n),2);
            data.qual.gps(nn1(n),1)=Gps_Too_Fast_On_Surface;
         else
            data.time(nn2(n),2)=data.time(nn1(n),1);
            data.lat(nn2(n),2)=data.lat(nn1(n),1);
            data.lon(nn2(n),2)=data.lon(nn1(n),1);
            data.qual.gps(nn2(n),2)=Gps_Too_Fast_On_Surface;
         end
      else
         if curvlon1(n) > curvlon2(n)
            data.time(nn1(n),1)=data.time(nn2(n),2);
            data.lat(nn1(n),1)=data.lat(nn2(n),2);
            data.lon(nn1(n),1)=data.lon(nn2(n),2);
            data.qual.gps(nn1(n),1)=Gps_Too_Fast_On_Surface;
         else
            data.time(nn2(n),2)=data.time(nn1(n),1);
            data.lat(nn2(n),2)=data.lat(nn1(n),1);
            data.lon(nn2(n),2)=data.lon(nn1(n),1);
            data.qual.gps(nn2(n),2)=Gps_Too_Fast_On_Surface;
         end
      end
   end
end

% Find too soon time across a dive and fix
nn=find(diff(data.time(2:end-1,:),1,2) <= Too_Soon & all(data.qual.gps(2:end-1,:) == Gps_Good,2))+1; %for all except last dive
if ~isempty(nn)
   curvtime1=abs(data.time(nn+1,1)-2*data.time(nn,1)+data.time(nn-1,1));
   curvtime2=abs(data.time(nn+1,2)-2*data.time(nn,2)+data.time(nn-1,2));
   for n=1:length(nn)
      if curvtime1 > curvtime2
         data.time(nn(n),1)=data.time(nn(n)-1,2);
         data.lat(nn(n),1)=data.lat(nn(n)-1,2);
         data.lon(nn(n),1)=data.lon(nn(n)-1,2);
         data.qual.gps(nn(n),1)=Gps_Too_Soon;
      else
         data.time(nn(n),2)=data.time(nn(n)+1,1);
         data.lat(nn(n),2)=data.lat(nn(n)+1,1);
         data.lon(nn(n),2)=data.lon(nn(n)+1,1);
         data.qual.gps(nn(n),2)=Gps_Too_Soon;
      end
   end
end
if data.time(1,2)-data.time(1,1) <= Too_Soon && all(data.qual.gps(1,:) == Gps_Good,2); %first dive
   data.qual.gps(1,2)=Gps_Too_Soon;
   data.time(1,2) = data.time(2,1);
   data.lat(1,2) = data.lat(2,1);
   data.lon(1,2) = data.lon(2,1);
end
if data.time(end,2)-data.time(end,1) <= Too_Soon && all(data.qual.gps(end,:) == Gps_Good,2); %last dive, flag only
   data.qual.gps(end,2)=Gps_Too_Soon;
end

% Find move too far between predives and separately postdives and fix
% Fix the point where consecutive distances are too far
% Good for isolated bad points only
% dist=gcircle(data.lat(1:end-1,:),data.lon(1:end-1,:),data.lat(2:end,:),data.lon(2:end,:));
dx=pi/180*R*(data.lon(1:end-1,:)-data.lon(2:end,:)).*cos(pi/180*(data.lat(1:end-1,:)+data.lat(2:end,:))/2);
dy=pi/180*R*(data.lat(1:end-1,:)-data.lat(2:end,:));
dist=sqrt(dx.^2+dy.^2)/1000;
nn1=dist(:,1) > Too_Far & data.qual.gps(1:end-1,1) == Gps_Good & data.qual.gps(2:end,1) == Gps_Good;
nn1=find(nn1(1:end-1) & nn1(2:end))+1;
nn2=dist(:,2) > Too_Far & data.qual.gps(1:end-1,2) == Gps_Good & data.qual.gps(2:end,2) == Gps_Good;
nn2=find(nn2(1:end-1) & nn2(2:end))+1;
if ~isempty(nn1)
   data.time(nn1,1)=data.time(nn1-1,2);
   data.lat(nn1,1)=data.lat(nn1-1,2);
   data.lon(nn1,1)=data.lon(nn1-1,2);
   data.qual.gps(nn1,1)=Gps_Too_Far;
end
if ~isempty(nn2)
   data.time(nn2,2)=data.time(nn2+1,1);
   data.lat(nn2,2)=data.lat(nn2+1,1);
   data.lon(nn2,2)=data.lon(nn2+1,1);
   data.qual.gps(nn2,2)=Gps_Too_Far;
end
   

% Deal with the problem of consecutive bad fixes during a surface interval
tmpflag=(data.qual.gps(1:end-1,2) <= Gps_Bad_HDOP & data.qual.gps(1:end-1,2) >= Gps_Repeat) ...
   & (data.qual.gps(2:end,1) <= Gps_Bad_HDOP & data.qual.gps(2:end,1) >= Gps_Repeat);
tmpflag=[tmpflag; false];

% Find and fix values that never surface
pp=data.qual.gps(:,2) == Gps_No_Surfacing | tmpflag;
ppd2=diff(pp);
istart=find(ppd2 == 1)+1;
iend=find(ppd2 == -1);
isflash=isfield(data.eng,'time');
for n=1:length(istart)
   im=istart(n):iend(n)+1;
   mim=length(im);
   tprof=zeros(mim,1);
   if isflash %flash data
      for m=1:mim
         tprof(m)=data.eng.time{im(m)}(end);
      end
   else %sat data
      for m=1:mim
         tprof(m)=length(data.p{im(m)});
      end
   end
   tcs=cumsum(tprof);
   tcs=tcs(1:end-1)/tcs(end);
   data.time(istart(n):iend(n),2)=round(data.time(istart(n),1)+tcs*(data.time(iend(n)+1,2)-data.time(istart(n),1)));
   data.lat(istart(n):iend(n),2)=data.lat(istart(n),1)+tcs*(data.lat(iend(n)+1,2)-data.lat(istart(n),1));
   data.lon(istart(n):iend(n),2)=data.lon(istart(n),1)+tcs*(data.lon(iend(n)+1,2)-data.lon(istart(n),1));
   data.time(istart(n)+1:iend(n)+1,1)=data.time(istart(n):iend(n),2);
   data.lat(istart(n)+1:iend(n)+1,1)=data.lat(istart(n):iend(n),2);
   data.lon(istart(n)+1:iend(n)+1,1)=data.lon(istart(n):iend(n),2);
end

% Recalculate depth for flagged values
ii=find(data.qual.gps(:,1) > Gps_Good | data.qual.gps(:,2) > Gps_Good);
latd=data.lat(ii,1)+.75*(data.lat(ii,2)-data.lat(ii,1));
for n=1:length(ii)
   data.depth{ii(n)}=sw_dpth(data.p{ii(n)},latd(n));
end

data.qual.operator(nop).closetime=round(dn2ut(now));
