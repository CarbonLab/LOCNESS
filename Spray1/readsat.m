function data=readsat(file,opname)
% function data=readsat(file,opname) reads spray data from file and puts it into
% structure data
% opname is a string intended to be filled with the person's name who ran
% the function
% 

% D. Rudnick, September 1, 2008
% D. Rudnick, May 16, 2012, Update to include DO and ADP should either
% exist
% D. Rudnick, 6 Aug 2019, Change to sbd line
% D. Rudnick, 9 Aug 2021, added oxumolkg

maxdives=3000; %maximum number of dives
Gps_Good=0; %Good gps flag
Gps_Bad=8; %Flag for bad gps as indicated by status flag (based on HDOP)
Gps_No_Dive=99; %Flag to indicate that the dive did not exist
Gps_No_Surfacing=9; %Flag to indcate that there was no surfacing
DOConv=44660; %DO conversion constant from ml/l to micromole/kg

data.sn=[];
data.mission='';
data.time=nan(maxdives,2);
data.lat=nan(maxdives,2);
data.lon=nan(maxdives,2);
data.u=[];
data.v=[];
data.p=cell(maxdives,1);
data.t=cell(maxdives,1);
data.s=cell(maxdives,1);
data.fl=cell(maxdives,1);
data.cdom=cell(maxdives,1);
data.ox=cell(maxdives,1);
data.theta=cell(maxdives,1);
data.sigma=cell(maxdives,1);
data.rho=cell(maxdives,1);
data.depth=cell(maxdives,1);
data.oxconc=cell(maxdives,1);
data.oxumolkg=cell(maxdives,1);

data.adp.eng.ncell=nan(maxdives,1);
data.adp.eng.cellsize=nan(maxdives,1);
data.adp.eng.pulselength=nan(maxdives,1);
data.adp.eng.minsnr=nan(maxdives,1);
data.adp.eng.dp1=nan(maxdives,1);
data.adp.eng.voff=nan(maxdives,1);
data.adp.eng.absoff=nan(maxdives,1);
data.adp.eng.ampoff=nan(maxdives,1);
data.adp.eng.p=cell(maxdives,1);
data.adp.eng.u=cell(maxdives,1);
data.adp.eng.v=cell(maxdives,1);
data.adp.eng.w=cell(maxdives,1);
data.adp.eng.amp=cell(maxdives,1);
data.adp.eng.pitch=cell(maxdives,1);
data.adp.eng.roll=cell(maxdives,1);
data.adp.eng.head=cell(maxdives,1);
data.adp.eng.abs=cell(maxdives,1);

data.eng.mod='';
data.eng.nsensor=nan;
data.eng.ctdtype=nan;
data.eng.eepromver='';
data.eng.optsens='';
data.eng.argosid=nan;
data.eng.pcal=nan(4,1);
data.eng.tcal=nan(4,1);
data.eng.scal=nan(4,1);
data.eng.ocal=nan(6,1);
data.eng.dcal=nan(6,1);
data.eng.oxcal=nan(6,1);
data.eng.compcal.magvar=nan;
data.eng.compcal.usemc=nan;
data.eng.compcal.file='';
data.eng.gps.tfix=nan(maxdives,2);
data.eng.gps.nsat=nan(maxdives,2);
data.eng.gps.minsnr=nan(maxdives,2);
data.eng.gps.meansnr=nan(maxdives,2);
data.eng.gps.maxsnr=nan(maxdives,2);
data.eng.gps.hdop=nan(maxdives,2);
data.eng.gps.gpsstat=cell(maxdives,2);
data.eng.gps.wingstat=cell(maxdives,2);
data.eng.wpt.npts=nan(maxdives,1);
data.eng.wpt.index=cell(maxdives,1);
data.eng.wpt.lat=cell(maxdives,1);
data.eng.wpt.lon=cell(maxdives,1);
data.eng.rte.npts=nan(maxdives,1);
data.eng.rte.next=nan(maxdives,1);
data.eng.rte.endaction=nan(maxdives,1);
data.eng.rte.dir=nan(maxdives,1);
data.eng.rte.currentbuck=nan(maxdives,1);
data.eng.rte.currentxangle=nan(maxdives,1);
data.eng.rte.cbuckmaxdive=nan(maxdives,1);
data.eng.rte.mansteer=nan(maxdives,1);
data.eng.rte.manstrmaxdive=nan(maxdives,1);
data.eng.rte.steerpt=nan(maxdives,1);
data.eng.rte.strptmaxdive=nan(maxdives,1);
data.eng.rte.mincorrangle=nan(maxdives,1);
data.eng.rte.maxcorrangle=nan(maxdives,1);
data.eng.rte.index=cell(maxdives,1);
data.eng.rte.detectmode=cell(maxdives,1);
data.eng.rte.wcradius=cell(maxdives,1);
data.eng.rte.appangle=cell(maxdives,1);
data.eng.ec.ntries=nan(maxdives,1);
data.eng.ec.nsent=nan(maxdives,1);
data.eng.ec.stat=nan(maxdives,1);
data.eng.ec.shorestat=cell(maxdives,1);
data.eng.ec.time=nan(maxdives,1);
data.eng.ec.wing=nan(maxdives,1);
data.eng.ed.pstart=nan(maxdives,1);
data.eng.ed.pavg=nan(maxdives,1);
data.eng.ed.pend=nan(maxdives,1);
data.eng.ed.drifttime=nan(maxdives,1);
data.eng.ed.numsamp=nan(maxdives,1);
data.eng.ed.pumptime=nan(maxdives,1);
data.eng.ef.navg=nan(maxdives,1);
data.eng.ef.psurf=nan(maxdives,1);
data.eng.ef.zmax=nan(maxdives,1);
data.eng.ef.pitch=nan(maxdives,1);
data.eng.ef.altz=nan(maxdives,1);
data.eng.ef.altintensity=nan(maxdives,1);
data.eng.ef.zatalt=nan(maxdives,1);
data.eng.ef.rollerr=nan(maxdives,1);
data.eng.ef.excstat=cell(maxdives,1);
data.eng.en.drx=nan(maxdives,1);
data.eng.en.dry=nan(maxdives,1);
data.eng.en.wlat=nan(maxdives,1);
data.eng.en.wlon=nan(maxdives,1);
data.eng.en.tleave=nan(maxdives,1);
data.eng.en.tend=nan(maxdives,1);
data.eng.en.tslow=nan(maxdives,1);
data.eng.en.deshead=nan(maxdives,1);
data.eng.en.f=cell(maxdives,1);
data.eng.ep.zmax=nan(maxdives,1);
data.eng.ep.volt=nan(maxdives,1);
data.eng.ep.amp=nan(maxdives,1);
data.eng.ep.nbadamp=nan(maxdives,1);
data.eng.ep.tmaxamp=nan(maxdives,1);
data.eng.ep.maxamp=nan(maxdives,1);
data.eng.ep.vacuum=nan(maxdives,1);
data.eng.ep.tpump1=nan(maxdives,1);
data.eng.ep.tpump2=nan(maxdives,1);
data.eng.ep.venttm=nan(maxdives,1);
data.eng.ep.airflag=nan(maxdives,1);
data.eng.et.time=cell(maxdives,1);
data.eng.et.p=cell(maxdives,1);
data.eng.et.head=cell(maxdives,1);
data.eng.et.pitch=cell(maxdives,1);
data.eng.et.roll=cell(maxdives,1);
data.eng.et.pitchpot=cell(maxdives,1);
data.eng.et.rollpot=cell(maxdives,1);
data.eng.command=cell(maxdives,1);
data.eng.sbd.emailtime=cell(maxdives,1);
data.eng.sbd.sbdtime=cell(maxdives,1);
data.eng.sbd.spraysn=cell(maxdives,1);
data.eng.sbd.imei=cell(maxdives,1);
data.eng.sbd.flag=cell(maxdives,1);
data.eng.sbd.momsn=cell(maxdives,1);
data.eng.sbd.nbytes=cell(maxdives,1);
data.eng.sbd.lat=cell(maxdives,1);
data.eng.sbd.lon=cell(maxdives,1);
data.eng.sbd.stdfix=cell(maxdives,1);
data.eng.sbd.packetid=cell(maxdives,1);
data.eng.sbd.timedelay=cell(maxdives,1);
data.qual.gps=nan(maxdives,2);
data.qual.u=[];
data.qual.t=cell(maxdives,1);
data.qual.s=cell(maxdives,1);
data.qual.fl=cell(maxdives,1);
data.qual.cdom=cell(maxdives,1);
data.qual.ox=cell(maxdives,1);
data.qual.changetime=nan(maxdives,1);
data.qual.looktime=nan(maxdives,1);
data.qual.operator(1).name=opname;
data.qual.operator(1).function='readsat';
data.qual.operator(1).params.maxdives=maxdives;
data.qual.operator(1).params.Gps_Good=Gps_Good;
data.qual.operator(1).params.Gps_Bad=Gps_Bad;
data.qual.operator(1).params.Gps_No_Dive=Gps_No_Dive;
data.qual.operator(1).params.Gps_No_Surfacing=Gps_No_Surfacing;
data.qual.operator(1).params.DOConv=DOConv;
data.qual.operator(1).opentime=round(dn2ut(now));

ntot=0;
fid=fopen(file);
while 1
   line=fgetl(fid);
   if ~ischar(line), break, end
   if length(line) > 1
      switch line(1:2)
         case 'MO'
            if isempty(data.eng.mod)
               nmod=1;
               data.eng.mod{nmod,1}=sscanf(line,'%c');
            else
               nmod=nmod+1;
               data.eng.mod{nmod,1}=sscanf(line,'%c');
            end
         case 'MD'
            data.mission=sscanf(line,'%c');
         case 'VN'
            x=textscan(line,'%*s %f %f %f %s');
            data.sn=x{1};
            data.eng.nsensor=x{2};
            data.eng.ctdtype=x{3};
            data.eng.eepromver=x{4}{:};
         case 'VO'
            data.eng.optsens=sscanf(line,'%*s %s');
         case 'VA'
            data.eng.argosid=sscanf(line,'%*s %f');
         case 'CP'
            data.eng.pcal=sscanf(line,'%*s %f %f %f %f');
         case 'CT'
            data.eng.tcal=sscanf(line,'%*s %f %f %f %f');
         case 'CS'
            data.eng.scal=sscanf(line,'%*s %f %f %f %f');
         case 'CO'
            data.eng.ocal=sscanf(line,'%*s %f %f %f %f %f %f');
         case 'CD'
            data.eng.dcal=sscanf(line,'%*s %f %f %f %f %f %f');
         case 'CH'
            x=textscan(line,'%*s %f %f %s');
            data.eng.compcal.magvar=x{1};
            data.eng.compcal.usemc=x{2};
            data.eng.compcal.file=x{3}{:};
         case 'CX'
            oxver=sscanf(line,'CX%d',1);
            if oxver == 61
               data.eng.oxcal=sscanf(line,'%*s %f %f %f %f %f %f');
            elseif oxver == 62
               data.eng.oxcal=sscanf(line,'%*s %f %f %f %f',4);
            else
               error('Problem reading oxygen calibration line CX');
            end
         case 'G '
            x=textscan(line,'%*s %f %f %17c %f %f %f %f %f %f %f %f %f %f %f %s %s %f %f');
            ndive=x{1};
            istat=x{2};
            if ndive > 0 && istat < 3 && istat > 0
               data.time(ndive,istat)=datenum(x{3});
               data.lat(ndive,istat)=x{17};
               data.lon(ndive,istat)=x{18};
               if x{4} == 1
                  data.qual.gps(ndive,istat)=Gps_Good;
               else
                  data.qual.gps(ndive,istat)=Gps_Bad;
               end
               data.eng.gps.tfix(ndive,istat)=x{9};
               data.eng.gps.nsat(ndive,istat)=x{10};
               data.eng.gps.minsnr(ndive,istat)=x{11};
               data.eng.gps.meansnr(ndive,istat)=x{12};
               data.eng.gps.maxsnr(ndive,istat)=x{13};
               data.eng.gps.hdop(ndive,istat)=x{14};
               data.eng.gps.gpsstat(ndive,istat)=x{15};
               data.eng.gps.wingstat(ndive,istat)=x{16};
            end
         case 'W '
            x=sscanf(line,'%*s %f %f');
            ndive=x(1);
            if ndive > 0
               data.eng.wpt.npts(ndive)=x(2);
               x=textscan(fid,'w %f %f %f',data.eng.wpt.npts(ndive));
               data.eng.wpt.index{ndive}=x{1};
               data.eng.wpt.lat{ndive}=x{2};
               data.eng.wpt.lon{ndive}=x{3};
            end
         case 'R '
            x=sscanf(line,'%*s %f %f %f %f %f %f %f %f %f %f %f %f %f %f');
            ndive=x(1);
            if ndive > 0
               data.eng.rte.npts(ndive)=x(2);
               data.eng.rte.next(ndive)=x(3);
               data.eng.rte.endaction(ndive)=x(4);
               data.eng.rte.dir(ndive)=x(5);
               data.eng.rte.currentbuck(ndive)=x(6);
               data.eng.rte.currentxangle(ndive)=x(7);
               data.eng.rte.cbuckmaxdive(ndive)=x(8);
               data.eng.rte.mansteer(ndive)=x(9);
               data.eng.rte.manstrmaxdive(ndive)=x(10);
               data.eng.rte.steerpt(ndive)=x(11);
               data.eng.rte.strptmaxdive(ndive)=x(12);
               data.eng.rte.mincorrangle(ndive)=x(13);
               data.eng.rte.maxcorrangle(ndive)=x(14);
               x=textscan(fid,'r %f %f %f %f',data.eng.rte.npts(ndive));
               data.eng.rte.index{ndive}=x{1};
               data.eng.rte.detectmode{ndive}=x{2};
               data.eng.rte.wcradius{ndive}=x{3};
               data.eng.rte.appangle{ndive}=x{4};
            end
         case 'EC'
            x=textscan(line,'%*s %f %f %f %f %s %f %f');
            ndive=x{1};
            data.eng.ec.ntries(ndive)=x{2};
            data.eng.ec.nsent(ndive)=x{3};
            data.eng.ec.stat(ndive)=x{4};
            data.eng.ec.shorestat(ndive)=x{5};
            data.eng.ec.time(ndive)=x{6};
            data.eng.ec.wing(ndive)=x{7};
         case 'ED'
            x=sscanf(line,'%*s %f %f %f %f %f %f %f');
            ndive=x(1);
            data.eng.ed.pstart(ndive)=x(2);
            data.eng.ed.pavg(ndive)=x(3);
            data.eng.ed.pend(ndive)=x(4);
            data.eng.ed.drifttime(ndive)=x(5);
            data.eng.ed.numsamp(ndive)=x(6);
            data.eng.ed.pumptime(ndive)=x(7);
         case 'EF'
            efver=sscanf(line,'EF%d',1);
            if efver == 1
               x=textscan(line,'%*s %f %f %f %f %f %f %f %f %s');
               ndive=x{1};
               data.eng.ef.navg(ndive)=x{2};
               data.eng.ef.psurf(ndive)=x{3};
               data.eng.ef.zmax(ndive)=x{4};
               data.eng.ef.pitch(ndive)=x{5};
               data.eng.ef.altz(ndive)=x{6};
               data.eng.ef.altintensity(ndive)=x{7};
               data.eng.ef.rollerr(ndive)=x{8};
               data.eng.ef.excstat(ndive)=x{9};
            elseif efver == 2
               x=textscan(line,'%*s %f %f %f %f %f %f %f %f %f %s');
               ndive=x{1};
               data.eng.ef.navg(ndive)=x{2};
               data.eng.ef.psurf(ndive)=x{3};
               data.eng.ef.zmax(ndive)=x{4};
               data.eng.ef.pitch(ndive)=x{5};
               data.eng.ef.altz(ndive)=x{6};
               data.eng.ef.altintensity(ndive)=x{7};
               data.eng.ef.zatalt(ndive)=x{8};
               data.eng.ef.rollerr(ndive)=x{9};
               data.eng.ef.excstat(ndive)=x{10};
            end
         case 'EN'
            x=textscan(line,'%*s %f %f %f %f %f %f %f %f %f %s');
            ndive=x{1};
            data.eng.en.drx(ndive)=x{2};
            data.eng.en.dry(ndive)=x{3};
            data.eng.en.wlat(ndive)=x{4};
            data.eng.en.wlon(ndive)=x{5};
            data.eng.en.tleave(ndive)=x{6};
            data.eng.en.tend(ndive)=x{7};
            data.eng.en.tslow(ndive)=x{8};
            data.eng.en.deshead(ndive)=x{9};
            data.eng.en.f(ndive)=x{10};
         case 'EP'
            epver=sscanf(line,'EP%d',1);
            if epver == 1
               x=sscanf(line,'%*s %f %f %f %f %f %f %f %f %f %f');
               ndive=x(1);
               data.eng.ep.zmax(ndive)=x(2);
               data.eng.ep.volt(ndive)=x(3);
               data.eng.ep.amp(ndive)=x(4);
               data.eng.ep.nbadamp(ndive)=x(5);
               data.eng.ep.tmaxamp(ndive)=x(6)*10;
               data.eng.ep.maxamp(ndive)=x(7);
               data.eng.ep.vacuum(ndive)=x(8);
               data.eng.ep.tpump1(ndive)=x(9)*10;
               data.eng.ep.tpump2(ndive)=x(10)*10;
            elseif epver == 2
               x=sscanf(line,'%*s %f %f %f %f %f %f %f %f %f %f %f %f');
               ndive=x(1);
               data.eng.ep.zmax(ndive)=x(2);
               data.eng.ep.volt(ndive)=x(3);
               data.eng.ep.amp(ndive)=x(4);
               data.eng.ep.nbadamp(ndive)=x(5);
               data.eng.ep.tmaxamp(ndive)=x(6)*10;
               data.eng.ep.maxamp(ndive)=x(7);
               data.eng.ep.vacuum(ndive)=x(8);
               data.eng.ep.tpump1(ndive)=x(9)*10;
               data.eng.ep.tpump2(ndive)=x(10)*10;
               data.eng.ep.venttm(ndive)=x(11);
               data.eng.ep.airflag(ndive)=x(12);
            end
         case 'ET'
            sensid=sscanf(line,'ET%d',1);
            x=sscanf(line,'%*s %f %f %f');
            ndive=x(1);
            num=x(2);
            numout=x(3);
            fmt=['%*s' repmat(' %f',1,numout)];
            x=fscanf(fid,fmt,num);
            switch sensid
               case 0
                  data.eng.et.time{ndive}=x;
               case 1
                  data.eng.et.p{ndive}=data.eng.pcal(3)+data.eng.pcal(4)*(data.eng.pcal(2)*(x-data.eng.ef.psurf(ndive)));
               case 2
                  data.eng.et.head{ndive}=x/10;
               case 3
                  data.eng.et.pitch{ndive}=x/10;
               case 4
                  data.eng.et.roll{ndive}=x/10;
               case 5
                  data.eng.et.pitchpot{ndive}=x;
               case 6
                  data.eng.et.rollpot{ndive}=x;
            end
         case 'D '
            x=sscanf(line,'%*s %f %f');
            ndive=x(1);
            num=x(2);
            ncol=max(data.eng.nsensor,4); % workaound because there are always at least 4 col in d lines regardless of nsensor
            x=textscan(fid,['p %*f %*f' repmat(' %f',[1 ncol])],num);
            data.p{ndive}=data.eng.pcal(3)+data.eng.pcal(4)*(data.eng.pcal(2)*(x{1}-data.eng.ef.psurf(ndive)));
            data.t{ndive}=data.eng.tcal(3)+data.eng.tcal(4)*(data.eng.tcal(1)+data.eng.tcal(2)*x{2});
            data.s{ndive}=data.eng.scal(3)+data.eng.scal(4)*(data.eng.scal(1)+data.eng.scal(2)*x{3});
            data.theta{ndive}=sw_ptmp(data.s{ndive},data.t{ndive},data.p{ndive},0);
            data.sigma{ndive}=sw_pden(data.s{ndive},data.t{ndive},data.p{ndive},0)-1000;
            data.rho{ndive}=sw_dens(data.s{ndive},data.t{ndive},data.p{ndive})-1000;
            data.qual.t{ndive}=zeros(num,1);
            data.qual.s{ndive}=zeros(num,1);
            if data.eng.nsensor >= 4
               data.fl{ndive}=data.eng.ocal(5)+data.eng.ocal(6)*data.eng.ocal(4)*(data.eng.ocal(1)+data.eng.ocal(2)*x{4});
               data.qual.fl{ndive}=zeros(num,1);
            end
            if data.eng.nsensor == 5
               if oxver == 61
                  data.ox{ndive}=f2dox(data.eng.oxcal,x{5},data.t{ndive},data.p{ndive});
                  data.qual.ox{ndive}=zeros(num,1);
                  data.oxconc{ndive}=data.ox{ndive}.*oxs_calc(data.t{ndive},data.s{ndive});
                  data.oxumolkg{ndive}=DOConv*data.oxconc{ndive}./(data.sigma{ndive}+1000);
               elseif oxver == 62
                  data.oxconc{ndive}=data.eng.oxcal(3)+data.eng.oxcal(4)*(data.eng.oxcal(1)+data.eng.oxcal(2)*x{5});
                  data.oxconc{ndive}=oxcorrect(data.oxconc{ndive},data.s{ndive},data.t{ndive},data.p{ndive});
                  data.qual.ox{ndive}=zeros(num,1);
                  data.ox{ndive}=data.oxconc{ndive}./oxs_calc(data.t{ndive},data.s{ndive});
                  data.oxumolkg{ndive}=DOConv*data.oxconc{ndive}./(data.sigma{ndive}+1000);
               else
                  error('Error in reading oxygen, version number must be wrong');
               end
            end
            if ndive > ntot, ntot=ndive; end
         case 'S '
            ndive=sscanf(line,'%*s %f',1);
            if ndive > 0
               data.eng.command{ndive}=[data.eng.command{ndive} sscanf(line(8:end),'%c')];
            end
         case '!d'
            x=textscan(line,'%*s %f %*f %18c');
            ndive=x{1};
            if ndive > 0
               dn=datenum(x{2});
               dv=datevec(dn);
               year=dv(1);
               data.eng.sbd.emailtime{ndive}=[data.eng.sbd.emailtime{ndive}; dn2ut(dn)];
            end
         case 'SB'
            x=sscanf(line,'%*s %f %f %f %f %f %f %f %f %f %f %f %f');
            ndive=x(1);
            if ndive > 0
               data.eng.sbd.sbdtime{ndive}=[data.eng.sbd.sbdtime{ndive}; round(dn2ut(datenum(year,1,1)+x(4)-1))];
               data.eng.sbd.spraysn{ndive}=[data.eng.sbd.spraysn{ndive}; x(2)];
               data.eng.sbd.imei{ndive}=[data.eng.sbd.imei{ndive}; x(3)];
               data.eng.sbd.flag{ndive}=[data.eng.sbd.flag{ndive}; x(5)];
               data.eng.sbd.momsn{ndive}=[data.eng.sbd.momsn{ndive}; x(6)];
               data.eng.sbd.nbytes{ndive}=[data.eng.sbd.nbytes{ndive}; x(7)];
               data.eng.sbd.lat{ndive}=[data.eng.sbd.lat{ndive}; x(8)];
               data.eng.sbd.lon{ndive}=[data.eng.sbd.lon{ndive}; x(9)];
               data.eng.sbd.stdfix{ndive}=[data.eng.sbd.stdfix{ndive}; x(10)];
               data.eng.sbd.packetid{ndive}=[data.eng.sbd.packetid{ndive}; x(11)];
               data.eng.sbd.timedelay{ndive}=[data.eng.sbd.timedelay{ndive}; x(12)];
            end
         case 'B1'
            x=sscanf(line,'%*s %f %f %f %f %f %f %f %f %f');
            ndive=x(1);
            data.adp.eng.ncell(ndive)=x(2);
            data.adp.eng.cellsize(ndive)=x(3);
            data.adp.eng.pulselength(ndive)=x(4);
            if x(5) ~= 255
               data.adp.eng.minsnr(ndive)=x(5); % otherwise not used, leave nan
            end
            data.adp.eng.dp1(ndive)=x(6);
            data.adp.eng.voff(ndive)=x(7);
            data.adp.eng.absoff(ndive)=x(8);
            data.adp.eng.ampoff(ndive)=x(9);
         case 'B2'
            x=textscan(line,'%*s %f %f %f %f %f %f %f %f %f %f %f');
            ndive=x{1};
            data.adp.eng.ncell(ndive)=x{2};
            data.adp.eng.cellsize(ndive)=x{3};
            data.adp.eng.cellavg(ndive)=x{4};
            data.adp.eng.ad2cpdz(ndive)=x{5};
            data.adp.eng.maxdt(ndive)=x{6};
            data.adp.eng.ntkexc(ndive)=x{7};
            data.adp.eng.dp1(ndive)=x{8};
            data.adp.eng.voff(ndive)=x{9};
            data.adp.eng.absoff(ndive)=x{10};
            data.adp.eng.ampoff(ndive)=x{11};
         case 'AT'
            x=sscanf(line,'%*s %f %f %f %f');
            sentype=str2double(line(3:4));
            ndive=x(1);
            ndat=x(2);
            num=ceil(ndat/x(3));
            fmt=['a' repmat(' %f',[1 x(3)])];
            x=textscan(fid,fmt,num);
            x=cell2mat(x)';
            x=x(1:ndat)';
            switch sentype
               case 0 % pressure
                  data.adp.eng.p{ndive}=x;
               case 1 % east velocity
                  data.adp.eng.u{ndive}=x*.001;
               case 2 % north velocity
                  data.adp.eng.v{ndive}=x*.001;
               case 3 % vertical velocity
                  data.adp.eng.w{ndive}=x*.001;
               case 4 % avg amp of last bin
                  data.adp.eng.amp{ndive}=x*0.43;
               case 5 % pitch
                  data.adp.eng.pitch{ndive}=x*0.4;
               case 6 % roll
                  data.adp.eng.roll{ndive}=x*0.4;
               case 7 % heading
                  data.adp.eng.head{ndive}=x*0.1;
               case 8 % ABS
                  data.adp.eng.abs{ndive}=x*0.1;
            end
      end
   end
end
fclose(fid);

data.time(ntot+1:end,:)=[];
data.lat(ntot+1:end,:)=[];
data.lon(ntot+1:end,:)=[];
data.p(ntot+1:end)=[];
data.t(ntot+1:end)=[];
data.s(ntot+1:end)=[];
data.theta(ntot+1:end)=[];
data.sigma(ntot+1:end)=[];
data.rho(ntot+1:end)=[];
data.depth(ntot+1:end)=[];

if data.eng.nsensor >= 4
   data.fl(ntot+1:end)=[];
   if strcmp('CDOM',data.eng.optsens)
      data.cdom=data.fl;
      data=rmfield(data,'fl');
   else
      data=rmfield(data,'cdom');
   end
else
   data=rmfield(data,'fl');
   data=rmfield(data,'cdom');
end
if data.eng.nsensor == 5
   data.ox(ntot+1:end)=[];
   data.oxconc(ntot+1:end)=[];
   data.oxumolkg(ntot+1:end)=[];
else
   data=rmfield(data,'ox');
   data=rmfield(data,'oxconc');
   data=rmfield(data,'oxumolkg');
end

if any(~isnan(data.adp.eng.ncell))
   data.adp.eng.ncell(ntot+1:end)=[];
   data.adp.eng.cellsize(ntot+1:end)=[];
   data.adp.eng.pulselength(ntot+1:end)=[];
   data.adp.eng.minsnr(ntot+1:end)=[];
   data.adp.eng.dp1(ntot+1:end)=[];
   data.adp.eng.voff(ntot+1:end)=[];
   data.adp.eng.absoff(ntot+1:end)=[];
   data.adp.eng.ampoff(ntot+1:end)=[];
   data.adp.eng.p(ntot+1:end)=[];
   data.adp.eng.u(ntot+1:end)=[];
   data.adp.eng.v(ntot+1:end)=[];
   data.adp.eng.w(ntot+1:end)=[];
   data.adp.eng.amp(ntot+1:end)=[];
   data.adp.eng.pitch(ntot+1:end)=[];
   data.adp.eng.roll(ntot+1:end)=[];
   data.adp.eng.head(ntot+1:end)=[];
   data.adp.eng.abs(ntot+1:end)=[];
   for ndive=1:ntot % calibrate adp pressures here b/c psurf may not be available when AT00 line read
      data.adp.eng.p{ndive}=data.eng.pcal(3)+data.eng.pcal(4)*(data.eng.pcal(2)*(data.adp.eng.p{ndive}-data.eng.ef.psurf(ndive)));
   end
else
   data=rmfield(data,'adp');
end

data.eng.gps.tfix(ntot+1:end,:)=[];
data.eng.gps.nsat(ntot+1:end,:)=[];
data.eng.gps.minsnr(ntot+1:end,:)=[];
data.eng.gps.meansnr(ntot+1:end,:)=[];
data.eng.gps.maxsnr(ntot+1:end,:)=[];
data.eng.gps.hdop(ntot+1:end,:)=[];
data.eng.gps.gpsstat(ntot+1:end,:)=[];
data.eng.gps.wingstat(ntot+1:end,:)=[];
data.eng.wpt.npts(ntot+1:end)=[];
data.eng.wpt.index(ntot+1:end)=[];
data.eng.wpt.lat(ntot+1:end)=[];
data.eng.wpt.lon(ntot+1:end)=[];
data.eng.rte.npts(ntot+1:end)=[];
data.eng.rte.next(ntot+1:end)=[];
data.eng.rte.endaction(ntot+1:end)=[];
data.eng.rte.dir(ntot+1:end)=[];
data.eng.rte.currentbuck(ntot+1:end)=[];
data.eng.rte.currentxangle(ntot+1:end)=[];
data.eng.rte.cbuckmaxdive(ntot+1:end)=[];
data.eng.rte.mansteer(ntot+1:end)=[];
data.eng.rte.manstrmaxdive(ntot+1:end)=[];
data.eng.rte.steerpt(ntot+1:end)=[];
data.eng.rte.strptmaxdive(ntot+1:end)=[];
data.eng.rte.mincorrangle(ntot+1:end)=[];
data.eng.rte.maxcorrangle(ntot+1:end)=[];
data.eng.rte.index(ntot+1:end)=[];
data.eng.rte.detectmode(ntot+1:end)=[];
data.eng.rte.wcradius(ntot+1:end)=[];
data.eng.rte.appangle(ntot+1:end)=[];
data.eng.ec.ntries(ntot+1:end)=[];
data.eng.ec.nsent(ntot+1:end)=[];
data.eng.ec.stat(ntot+1:end)=[];
data.eng.ec.shorestat(ntot+1:end)=[];
data.eng.ec.time(ntot+1:end)=[];
data.eng.ec.wing(ntot+1:end)=[];
data.eng.ed.pstart(ntot+1:end)=[];
data.eng.ed.pavg(ntot+1:end)=[];
data.eng.ed.pend(ntot+1:end)=[];
data.eng.ed.drifttime(ntot+1:end)=[];
data.eng.ed.numsamp(ntot+1:end)=[];
data.eng.ed.pumptime(ntot+1:end)=[];
data.eng.ef.navg(ntot+1:end)=[];
data.eng.ef.psurf(ntot+1:end)=[];
data.eng.ef.zmax(ntot+1:end)=[];
data.eng.ef.pitch(ntot+1:end)=[];
data.eng.ef.altz(ntot+1:end)=[];
data.eng.ef.altintensity(ntot+1:end)=[];
data.eng.ef.zatalt(ntot+1:end)=[];
data.eng.ef.rollerr(ntot+1:end)=[];
data.eng.ef.excstat(ntot+1:end)=[];
data.eng.en.drx(ntot+1:end)=[];
data.eng.en.dry(ntot+1:end)=[];
data.eng.en.wlat(ntot+1:end)=[];
data.eng.en.wlon(ntot+1:end)=[];
data.eng.en.tleave(ntot+1:end)=[];
data.eng.en.tend(ntot+1:end)=[];
data.eng.en.tslow(ntot+1:end)=[];
data.eng.en.deshead(ntot+1:end)=[];
data.eng.en.f(ntot+1:end)=[];
data.eng.ep.zmax(ntot+1:end)=[];
data.eng.ep.volt(ntot+1:end)=[];
data.eng.ep.amp(ntot+1:end)=[];
data.eng.ep.nbadamp(ntot+1:end)=[];
data.eng.ep.tmaxamp(ntot+1:end)=[];
data.eng.ep.maxamp(ntot+1:end)=[];
data.eng.ep.vacuum(ntot+1:end)=[];
data.eng.ep.tpump1(ntot+1:end)=[];
data.eng.ep.tpump2(ntot+1:end)=[];
data.eng.ep.venttm(ntot+1:end)=[];
data.eng.ep.airflag(ntot+1:end)=[];
data.eng.et.time(ntot+1:end)=[];
data.eng.et.p(ntot+1:end)=[];
data.eng.et.head(ntot+1:end)=[];
data.eng.et.pitch(ntot+1:end)=[];
data.eng.et.roll(ntot+1:end)=[];
data.eng.et.pitchpot(ntot+1:end)=[];
data.eng.et.rollpot(ntot+1:end)=[];
data.eng.command(ntot+1:end)=[];
data.eng.sbd.emailtime(ntot+1:end)=[];
data.eng.sbd.sbdtime(ntot+1:end)=[];
data.eng.sbd.spraysn(ntot+1:end)=[];
data.eng.sbd.imei(ntot+1:end)=[];
data.eng.sbd.flag(ntot+1:end)=[];
data.eng.sbd.momsn(ntot+1:end)=[];
data.eng.sbd.nbytes(ntot+1:end)=[];
data.eng.sbd.lat(ntot+1:end)=[];
data.eng.sbd.lon(ntot+1:end)=[];
data.eng.sbd.stdfix(ntot+1:end)=[];
data.eng.sbd.packetid(ntot+1:end)=[];
data.eng.sbd.timedelay(ntot+1:end)=[];
data.qual.gps(ntot+1:end,:)=[];
data.qual.t(ntot+1:end)=[];
data.qual.s(ntot+1:end)=[];
if data.eng.nsensor >= 4
   data.qual.fl(ntot+1:end)=[];
   if strcmp('CDOM',data.eng.optsens)
      data.qual.cdom=data.qual.fl;
      data.qual=rmfield(data.qual,'fl');
   else
      data.qual=rmfield(data.qual,'cdom');
   end
else
   data.qual=rmfield(data.qual,'fl');
   data.qual=rmfield(data.qual,'cdom');
end
if data.eng.nsensor == 5
   data.qual.ox(ntot+1:end)=[];
else
   data.qual=rmfield(data.qual,'ox');
   data.eng=rmfield(data.eng,'oxcal');
end
data.qual.changetime(ntot+1:end)=[];
data.qual.looktime(ntot+1:end)=[];

data.time=dn2ut(data.time);

latd=data.lat(:,1)+.75*(data.lat(:,2)-data.lat(:,1));
for n=1:ntot
   data.depth{n}=sw_dpth(data.p{n},latd(n));
end

kk=isnan(data.qual.gps);
jj=isnan(data.eng.ep.zmax);
jj=[jj jj];
ii=kk & jj;
data.qual.gps(ii)=Gps_No_Dive;
ii=kk & ~jj ;
data.qual.gps(ii)=Gps_No_Surfacing;

if isempty(data.eng.mod)
   data.eng=rmfield(data.eng,'mod');
end

if efver == 1
   data.eng.ef=rmfield(data.eng.ef,'zatalt');
end

if epver == 1
   data.eng.ep=rmfield(data.eng.ep,{'venttm','airflag'});
end

if all(isnan(data.eng.ed.pstart))
   data.eng=rmfield(data.eng,'ed');
end

data.qual.changetime=ones(ntot,1)*round(dn2ut(now));
data.qual.operator(1).closetime=round(dn2ut(now));
