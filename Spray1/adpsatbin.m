function bindata = adpsatbin(data,zmin,zstep,zmax)

% bindata = adpsatbin(data,pmin,pstep,pmax,pd)
% Bins doppler data for Iridium into uniform bins in depth. data is
% structure doppler with U,V,W calculated, pmin is min depth,
% pstep is size of bins, pmax is max depth to bin.
%
% R. Todd, 2 July 2010

% Define flags
Sample_Ok = 0;

% set up depth bins
bindata.depth=(zmin:zstep:zmax)';
pstr1='depth';
pstr2='depth';

np=length(bindata.depth);
nt=length(data.abs);
bindata.abs=nan(np,nt);
bindata.u=nan(np,nt);
bindata.v=nan(np,nt);
%bindata.w=nan(np,nt);

maxflag = Sample_Ok;

% bin velocity
for n=1:nt
    if ~isempty(data.(pstr1){n}) % then there are data to bin
        ibin=round((data.(pstr1){n}-zmin)/zstep)+1;
        for m=1:np
            iiuv = (ibin == m) & data.qual.u{n} <= maxflag;
%             iiw = (ibin == m) & data.qual.w{n} <= maxflag;
            bindata.u(m,n)=nanmean(data.u{n}(iiuv));
            bindata.v(m,n)=nanmean(data.v{n}(iiuv));
%             bindata.w(m,n)=nanmean(data.w{n}(iiw));
        end
    end
end

% bin abs
for n=1:nt
    if ~isempty(data.(pstr2){n}) % then there are data to bin
        ibin=round((data.(pstr2){n}-zmin)/zstep)+1;
        for m=1:np
            iiabs = (ibin == m) & data.qual.abs{n} <= maxflag;
            bindata.abs(m,n)=nanmean(data.abs{n}(iiabs,1));
        end
    end
end