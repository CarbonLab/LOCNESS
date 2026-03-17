function k0 = k0frompH(Vrs, Press, Temp, Salt, pHtot, k2, Pcoefs)


% k0 = k0frompH(s, cal)
% 
% calculates k0 (constant in Durafet calibration coefficient) from pH
% measurement in seawater. A lot of the function has been taken from 
% phcalc.m, written by Josh Plant. Inputs:
%
% ********* Variables in this section must be the same size **************
% Vrs:      pH raw voltage (scalar or array)
% Press:    pressure in decibar (scalar or array)
% Temp:     temperature in Celsius (scalar or array)
% Salt:     salinity in practical salinity scale (scalar or array)
% pHtot:    pH on the total scale under in situ conditions (scalar or array)
% ************************************************************************
% k2:       temperature coefficient of the DuraFET (scalar)
% Pcoefs:   Coefficients for the fP of the sensor (typically 6th order 
%           polynomial, but Pcomp may be a linear function). The polynomial
%           order is expected to be fP_1, fP_2, ... etc. So opposite of
%           what polyval expects. Do not include fP_0 (intercept), and this
%           should be a column array. 
%
% Yui Takeshita
% MBARI
% Created: 1/26/2022


% /* Taken from phcalc.m

% ************************************************************************
%  SET SOME CONSTANTS
% ************************************************************************
%Universal gas constant, (R) , http://physics.nist.gov/cgi-bin/cuu/Value?r
%R    = 8.31451;
R    = 8.31446; % J/(mol K) jp 
F    = 96485; %Faraday constant Coulomb / mol
Tk   = 273.15 + Temp; % degrees Kelvin
ln10 = log(10); % natural log of 10
    
% ************************************************************************
% CALCULATE PHYSICAL AND THERMODYNAMIC DATA
% Dickson, A. G., Sabine, C. L., & Christian, J. R. (2007). Guide to best
% practices for ocean CO2 measurements.
% ************************************************************************

% IONIC STRENGTH OF SEAWATER (mol / kg H2O)
% Varified units by comparing to Dickson et al. 2007: Chap 5, p10 Table 2
% Dickson et al. 2007: Chap 5, p13 Eq 34
IonS = 19.924 .* Salt ./ (1000 - 1.005 * Salt);

% MEAN SEAWATER SULFATE CONCENTRATION (mol / kg solution)
% This wants to be mol/kg sw  as KHSO4 is on that scale
% Dickson et al. 2007: Chap 5, p10 Table 2
% Edited by KJ to correct units 11/17/2015
Stotal = (0.14 / 96.062) .* (Salt / 1.80655);

% MEAN SEAWATER CHLORIDE CONCENTRATION  (mol / kg H20)
% this wants to be mol/kg H2O as activity is on mol/kg H2O scale
% Dickson et al. 2007: Chap 5, p10 Table 2
Cltotal = 0.99889 / 35.453 .* Salt / 1.80655; %(mol / kg solution)
Cltotal = Cltotal ./(1 - 0.001005 .* Salt);  % (mol / kg H20)
% Where does the  (1 - xxx/S) come form?

% BISULFIDE DISSCIATION CONSTANT AT T,S AND IONIC STRENGTH(mol/kg solution)
% Dickson et al. 2007: Chap 5, p12 Eq 33
Khso4 = exp(-4276.1 ./ Tk + 141.328 - 23.093 .* log(Tk) + ...
        (-13856 ./ Tk + 324.57 - 47.986 .* log(Tk)) .* IonS .^ 0.5 + ...
        (35474 ./ Tk - 771.54 + 114.723 .* log(Tk)) .* IonS - ...
        2698 ./ Tk .* IonS .^ 1.5 + 1776 ./ Tk .* IonS .^ 2 + ...
        log(1 - 0.001005 .* Salt));

% WHERE DO THESE APROXIMATIONS COME FROM???
% Millero 1983 Chemical Oceanography vol 8
deltaVHSO4 = -18.03 + 0.0466 .* Temp + 0.000316 .* Temp .^ 2;
KappaHSO4 = (-4.53 + 0.09 .* Temp) / 1000;
%%%%%%%  per Yui Press changed from dbar to bar here by / 10
lnKhso4fac = (-deltaVHSO4 + 0.5 .* KappaHSO4 .* (Press / 10)) .* ...
             (Press / 10) ./ (R * 10 .* Tk);
%  bisulfate association constant at T, S, P
Khso4TPS = Khso4 .* exp(lnKhso4fac);


% GAMMA +/- HCl AT T AND S
% Polynomial fit to Khoo et al. 1977, doi:10.1021/ac50009a016
% See Matrz et al. 2010, DOI 10.4319/lom.2010.8.172, p175
% Typo in paper 2nd term should be e-4 not e-6
%  Debye Huckel constant A
ADH = (3.4286e-6 .* Temp .^ 2 + 6.7524e-4 .* Temp + 0.49172143); % jp
%ADH = (0.00000343 .* Temp .^ 2 + 0.00067524 .* Temp + 0.49172143);

log10gammaHCl = -ADH .* sqrt(IonS) ./ (1 + 1.394 .* sqrt(IonS)) + ...
                (0.08885 - 0.000111 .* Temp) .* IonS;
% Millero
deltaVHcl = 17.85 + 0.1044 .* Temp - 0.001316 .* Temp .^ 2;

ThermoPress = -deltaVHcl .* 0.0242 ./ (23061 * 1.01) .* Press ./ 10;
%%%%%%%%%%%%% per Yui comment original line modified so ThermoPress
% (in units of volts is added to E0 not to log10gammaHCL
%   log10gammaHCLtP = log10gammaHCl + ThermoPress
log10gammaHCLtP = log10gammaHCl;

% */ phcalc ends here

% ============ pH conversions =================

% Need to convert pHtot to pHfree on molality scale, since this is what the
% sensor technically measures due to thermodynamics. 

% Convert from pHtot on molinity scale to pHfree molinity (mol/kg-sw)
pHfree_molinity = pHtot + log10(1 + Stotal ./ Khso4TPS); 
% convert pHfree from molinity (mol/kg-sw) to molality (mol/kg-H2O)
pHfree_molal = pHfree_molinity + log10(1 - 0.00105 .* Salt); 

% calculate ktp, the calibration coefficient at in situ TP
ktp = Vrs - ThermoPress ...
    - pHfree_molal .* (R .* Tk .*ln10 ./ F) ...
    + (R .*Tk ./F) .* log(Cltotal) ... % yes this term is missing ln10
    + (2.* R .* Tk .* ln10 ./ F) .* log10gammaHCLtP; 

% subtract out temp (k2) and pressure (fP) components
pc    = [flipud(Pcoefs);0]; % Matlab wants descending powers & n+1 (add 0)
pcorr = polyval(pc,Press); % voltage change due to fP
kt_1atm = ktp - pcorr; % calibration coefficient at 1 atm, 

% calculate k0 by subtracting out k2
k0 = kt_1atm - k2 .* Temp; 

return; 