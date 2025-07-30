function unixt = dn2ut(dn)
% DATENUM_TO_UNIXTIME Convert MATLAB datenum to Unix time (seconds since 1970-01-01 00:00:00 UTC)
%
%   unixt = datenum_to_unixtime(dn)
%
%   Input:
%       dn - MATLAB datenum (can be scalar, vector, or array)
%   Output:
%       unixt - Unix time in seconds

    % Unix epoch in datenum format
    epoch = datenum(1970,1,1,0,0,0);
    
    % Convert to Unix time
    unixt = (dn - epoch) * 86400;
end
