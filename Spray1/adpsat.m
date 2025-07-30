function data=adpsat(d,opname)

% data=adpsat(d,opname)
% Velocity and ABS processing for Iridium data.

% Robert Todd, 18 August 2010

data=d;

% parameters
Sample_Ok = 0;

% Version control
nop=length(data.qual.operator)+1;
data.qual.operator(nop).name=opname;
data.qual.operator(nop).function='adpsat';
data.qual.operator(nop).params.Sample_Ok=Sample_Ok;
data.qual.operator(nop).opentime=round(dn2ut(now));

% initialize new fields
ntot=length(data.p);
data.adp.depth=cell(ntot,1);
data.adp.u=cell(ntot,1);
data.adp.v=cell(ntot,1);
data.adp.w=cell(ntot,1);
data.adp.abs=cell(ntot,1);
data.adp.qual.u=cell(ntot,1);
data.adp.qual.abs=cell(ntot,1);

% loop through dives and do processing
latd=data.lat(:,1)+.75*(data.lat(:,2)-data.lat(:,1));
for ndive=1:ntot
    if ~isempty(data.adp.eng.p{ndive}) % skips empty/aborted dives
        nscan=length(data.adp.eng.p{ndive});
        nbin=nscan+data.adp.eng.ncell(ndive)-1;
        data.adp.depth{ndive}=nan(nbin,1);
        data.adp.u{ndive}=nan(nbin,1);
        data.adp.v{ndive}=nan(nbin,1);
        data.adp.w{ndive}=nan(nbin,1);
        data.adp.abs{ndive}=nan(nbin,1);
        data.adp.qual.u{ndive}=Sample_Ok*ones(nbin,1);
        data.adp.qual.abs{ndive}=Sample_Ok*ones(nbin,1);
        
        dspray=sw_dpth(data.adp.eng.p{ndive},latd(ndive));
        data.adp.depth{ndive}(1:nscan)=dspray+data.adp.eng.dp1(ndive);
        data.adp.depth{ndive}(nscan+1:end)=data.adp.depth{ndive}(nscan)+data.adp.eng.cellsize(ndive)*(1:data.adp.eng.ncell(ndive)-1)';
        
        nu=length(data.adp.eng.u{ndive});
        ubin1=1+data.adp.eng.voff(ndive);
        ubin2=ubin1+nu-1;
        data.adp.u{ndive}(ubin1:ubin2)=data.adp.eng.u{ndive};
        data.adp.v{ndive}(ubin1:ubin2)=data.adp.eng.v{ndive};
        % The following if statement is a bad workaround for sorting problem in
        % .sat file.
        if nu>nbin
            %         fprintf('u too long for dive %g, truncating...\n',ndive)
            data.adp.u{ndive} = data.adp.u{ndive}(1:nbin);
            data.adp.v{ndive} = data.adp.v{ndive}(1:nbin);
        end
        data.adp.u{ndive}=data.adp.u{ndive}-nanmean(data.adp.u{ndive})+data.u(ndive);
        data.adp.v{ndive}=data.adp.v{ndive}-nanmean(data.adp.v{ndive})+data.v(ndive);
        
        nabs = length(data.adp.eng.abs{ndive});
        data.adp.abs{ndive}(data.adp.eng.absoff(ndive):data.adp.eng.absoff(ndive)+nabs-1)=data.adp.eng.abs{ndive};
        % The following if statement is a bad workaround for sorting problem in
        % .sat file.
        if nabs>data.eng.dcal(2)+nscan-data.eng.dcal(1)
            %         fprintf('abs too long for dive %g, truncating...\n',ndive)
            data.adp.abs{ndive}(nscan+data.eng.dcal(2):end) = NaN;
        end
    end
end

data.qual.operator(nop).closetime=round(dn2ut(now));