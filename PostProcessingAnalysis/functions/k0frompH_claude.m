function k0 = k0frompH_claude(Vrs, Press, Temp, Salt, pHtot, k2, Pcoefs)
%
% Algebraic inverse of phcalc.m.  All constants and thermodynamic
% expressions are copied verbatim from phcalc.m (verified against the
% Argo pH processing document, https://doi.org/10.13155/57195, on 1/15/19).
%
% Given a known pHtot, solves for k0 by reversing each step of phcalc.m
% in order.
%
% INPUTS:
%   Vrs     = Voltage between reference electrode and ISFET source
%   Press   = Pressure in decibars
%   Temp    = Temperature in degrees C
%   Salt    = Salinity (PSS)
%   pHtot   = pH on total scale, mol/kg-seawater (in situ)
%   k2      = constant or pressure-dependent temperature response (slope)
%   Pcoefs  = sensor-dependent pressure coefficients (column vector,
%             ascending polynomial order, same convention as phcalc.m)
%             OPTIONAL: if omitted, Pcoefs defaults to [0 0 0 0 0 0]'
%             (no pressure correction applied)
%
% OUTPUT:
%   k0      = Sensor reference potential (intercept at Temp = 0C)

% ************************************************************************
%  HANDLE OPTIONAL Pcoefs ARGUMENT
% ************************************************************************
narginchk(6, 7);
if nargin < 7 || isempty(Pcoefs)
    Pcoefs = [0; 0; 0; 0; 0; 0]; % no pressure correction
    disp('No Pcoefs supplied — pressure correction set to zero.')
end

% ************************************************************************
%  SET SOME CONSTANTS  — copied verbatim from phcalc.m
% ************************************************************************
if max(size(k2)) > 1
    disp('K2 input has pressure dependent terms!')
end
R    = 8.31446; % J/(mol K)
F    = 96485;   % Faraday constant, Coulomb/mol
Tk   = 273.15 + Temp; % degrees Kelvin
ln10 = log(10);

% ************************************************************************
% CALCULATE PHYSICAL AND THERMODYNAMIC DATA — copied verbatim from phcalc.m
% Dickson, A. G., Sabine, C. L., & Christian, J. R. (2007). Guide to best
% practices for ocean CO2 measurements.
% ************************************************************************

% IONIC STRENGTH OF SEAWATER (mol / kg H2O)
% Dickson et al. 2007: Chap 5, p13 Eq 34
IonS = 19.924 .* Salt ./ (1000 - 1.005 * Salt);

% MEAN SEAWATER SULFATE CONCENTRATION (mol / kg solution)
% Dickson et al. 2007: Chap 5, p10 Table 2
Stotal = (0.14 / 96.062) .* (Salt / 1.80655);

% MEAN SEAWATER CHLORIDE CONCENTRATION (mol / kg H2O)
% Dickson et al. 2007: Chap 5, p10 Table 2
Cltotal = 0.99889 / 35.453 .* Salt / 1.80655; % (mol / kg solution)
Cltotal = Cltotal ./ (1 - 0.001005 .* Salt);  % (mol / kg H2O)

% BISULFATE DISSOCIATION CONSTANT AT T,S AND IONIC STRENGTH (mol/kg solution)
% Dickson et al. 2007: Chap 5, p12 Eq 33
Khso4 = exp(-4276.1 ./ Tk + 141.328 - 23.093 .* log(Tk) + ...
        (-13856 ./ Tk + 324.57 - 47.986 .* log(Tk)) .* IonS .^ 0.5 + ...
        (35474 ./ Tk - 771.54 + 114.723 .* log(Tk)) .* IonS - ...
        2698 ./ Tk .* IonS .^ 1.5 + 1776 ./ Tk .* IonS .^ 2 + ...
        log(1 - 0.001005 .* Salt));

% Millero 1983 Chemical Oceanography vol 8
% Partial molar volume and compressibility of HSO4 in seawater.
deltaVHSO4 = -18.03 + 0.0466 .* Temp + 0.000316 .* Temp .^ 2;
KappaHSO4  = (-4.53 + 0.09 .* Temp) / 1000;

%%%%%%% Press changed from dbar to bar here by / 10
lnKhso4fac = (-deltaVHSO4 + 0.5 .* KappaHSO4 .* (Press / 10)) .* ...
             (Press / 10) ./ (R * 10 .* Tk);

% Bisulfate association constant at T, S, P
Khso4TPS = Khso4 .* exp(lnKhso4fac);

% GAMMA +/- HCl, activity coefficient of HCl at T/S
% ADH is the Debye-Huckel constant, polynomial fit to Khoo et al. 1977
% doi:10.1021/ac50009a016. See Martz et al. 2010, DOI 10.4319/lom.2010.8.172
% Typo in paper: 2nd term should be e-4 not e-6
ADH = (3.4286e-6 .* Temp .^ 2 + 6.7524e-4 .* Temp + 0.49172143);

log10gammaHCl = -ADH .* sqrt(IonS) ./ (1 + 1.394 .* sqrt(IonS)) + ...
                (0.08885 - 0.000111 .* Temp) .* IonS;

% Millero 1983: partial molar volume of HCl in seawater
% Effect of pressure on activity coefficient of HCl.
% (Divide by 10 for cm3-to-F unit conversion; divide by 2 following the
%  power rule of logs for gammaHCl as in Argo processing document Eq 10.)
deltaVHCl = 17.85 + 0.1044 .* Temp - 0.001316 .* Temp .^ 2;
log10gammaHCLtP = log10gammaHCl + deltaVHCl .* (Press ./ 10) ./ (R .* Tk .* ln10) ./ 2 ./ 10;

% ************************************************************************
% INVERT: pHtot -> k0
% Each step below reverses the corresponding step in phcalc.m.
% ************************************************************************

% phcalc.m step 3 (reversed): phtot -> phfree on mol/kg-seawater scale
%   phcalc forward:  phtot  = phfree - log10(1 + Stotal ./ Khso4TPS)
phfree_sw  = pHtot + log10(1 + Stotal ./ Khso4TPS);

% phcalc.m step 2 (reversed): phfree mol/kg-sw -> phfree mol/kg-H2O
%   phcalc forward:  phfree_sw = phfree_H2O - log10(1 - 0.001005 .* Salt)
phfree_H2O = phfree_sw + log10(1 - 0.001005 .* Salt);

% phcalc.m step 1 (reversed): phfree mol/kg-H2O -> k0TP
%   phcalc forward:  phfree_H2O = (Vrs - k0TP)./(R.*Tk./F.*ln10)
%                                  + log(Cltotal)./ln10 + 2.*log10gammaHCLtP
k0TP = Vrs - (phfree_H2O - log(Cltotal) ./ ln10 - 2 .* log10gammaHCLtP) ...
           .* (R .* Tk ./ F .* ln10);

% Remove pressure correction (polynomial fP) — same as phcalc.m
%   phcalc forward:  k0TP = k0T + pcorr
pc    = [flipud(Pcoefs); 0]; % Matlab wants descending powers & n+1 (add 0)
pcorr = polyval(pc, Press);
k0T   = k0TP - pcorr;

% Remove temperature dependence (k2) to recover k0 — same logic as phcalc.m
%   phcalc forward:  k0T = k0 + k2 * Temp  (scalar)
%                    k0T = k0 + polyval(k2pc,Press) .* Temp  (poly)
if max(size(k2)) == 1
    k0 = k0T - k2 .* Temp;
elseif max(size(k2)) > 1
    k2pc = [flipud(k2)];
    k0   = k0T - polyval(k2pc, Press) .* Temp;
else
    disp('Max size should be >= 1 : Check k2 input!')
    return
end

% ************************************************************************
% VERIFICATION (uncomment to test round-trip against phcalc.m)
% ************************************************************************
% Vrs    = [-0.953799; -0.953799];
% Press  = [4.71; 1000];
% Salt   = [33.6131; 33.6131];
% Temp   = [16.3902; 5.0];
% k0_true = -1.4131;
% k2      = -0.0011416;
% Pcoefs  = [0 0 0 0 0 0]';
% [~, pHtot] = phcalc(Vrs, Press, Temp, Salt, k0_true, k2, Pcoefs);
% k0_recovered = k0frompH(Vrs, Press, Temp, Salt, pHtot, k2, Pcoefs);
% disp(k0_recovered - k0_true)  % should be zero (or machine epsilon)
