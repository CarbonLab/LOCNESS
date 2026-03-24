%% Load CTD
fname = "LOC02_bottle_cast_info_downloaded20250114.xlsx";
fCTD = fullfile("G:","Shared drives","NOPPmCDR","locness_data","ctd",fname);
CTD = readtable(fCTD);
CTD.Silicate = str2double(CTD.Silicate);
CTD.Phoshpate = str2double(CTD.Phoshpate);
%% Calculate ESPER Params
CTD.sdn = datenum(CTD.Date + CTD.Time_UTC);
ESP = ESPER_TSO(CTD.Latitude,CTD.Longitude,CTD.Depth,CTD.CTDSAL,CTD.CTDTEMP_ITS90,CTD.CTDOXY,CTD.sdn);
CTD.ESPER_PH = ESP.pH;
%% Calc Spec pH Insitu
trex = CO2SYSv3(CTD.TA, CTD.Spec_pH, 1, 3, CTD.CTDSAL, 25, CTD.CTDTEMP_ITS90, 0, CTD.CTDPRES, CTD.Silicate, CTD.Phoshpate, 0, 0, 1, 10, 1, 2, 2);
trex = standardizeMissing(trex,-999);
CTD.Spec_pH_insitu = trex(:,20);
%% Calc difference
CTD.SPEC_ESPER_DIFFERENCE = CTD.Spec_pH_insitu - CTD.ESPER_PH;
%% BIAS Calc
iBIAS = CTD.Depth > 150;
CTD_BIAS_CALCULATION = CTD(iBIAS,:);
% Manual QC: Spec sample from rosette position 3 seems bad.
CTD_BIAS_CALCULATION(3,"Spec_pH") = {"NaN"};
CTD_BIAS_CALCULATION(3,"Spec_pH_insitu") = {"NaN"};
CTD_BIAS_CALCULATION(3,"SPEC_ESPER_DIFFERENCE") = {"NaN"};
% Calculate the bias in ESPER
BIAS = mean(CTD_BIAS_CALCULATION.SPEC_ESPER_DIFFERENCE,'omitmissing');
% Write to text file
fid = fopen('BIAS.txt', 'w');
fprintf(fid, '%f\n', BIAS);
fclose(fid);
% Apply the bias to original CTD cast
CTD.SPEC_ESPER_ADJUST_DIFFERENCE = CTD.Spec_pH_insitu - (ESP.pH - abs(BIAS));
%% Plots
fig = figure;
tl = tiledlayout(1,2);
title(tl,"FILE: " + fname,'Interpreter', 'none')
subtitle(tl,'ALGORITHM: ESPER MIXED')
n1 = nexttile;
scatter(CTD.SPEC_ESPER_DIFFERENCE,CTD.Depth,'k.')
hold on;
xline(BIAS,Label=num2str(BIAS),Color='red',LineStyle='--',LabelHorizontalAlignment='left',LabelVerticalAlignment='middle')
scatter(CTD.SPEC_ESPER_DIFFERENCE(3),CTD.Depth(3),'rx')
text(CTD.SPEC_ESPER_DIFFERENCE(3)+.1*CTD.SPEC_ESPER_DIFFERENCE(3),CTD.Depth(3),'QC: BAD','FontSize',6,'HorizontalAlignment','right')
axis ij
xlabel('Spec pH - ESPER PH')
title('Mean offset below 150 m')
xlim([-max(abs(CTD.SPEC_ESPER_DIFFERENCE)) max(abs(CTD.SPEC_ESPER_DIFFERENCE))])
xticks(floor(min(xlim)/0.01)*0.01:0.01:ceil(max(xlim)/0.01)*0.01)
% xtickangle(65)

n2 = nexttile;
scatter(CTD.SPEC_ESPER_ADJUST_DIFFERENCE,CTD.Depth,'k.')
hold on
xline(0,Color='red',LineStyle='--')
axis ij
xlabel(['Spec pH - (ESPER PH - | ',num2str(BIAS), ' |)'])
title('ESPER Corrected')
scatter(CTD.SPEC_ESPER_ADJUST_DIFFERENCE(3),CTD.Depth(3),'rx')
text(CTD.SPEC_ESPER_ADJUST_DIFFERENCE(3)+.1*CTD.SPEC_ESPER_DIFFERENCE(3),CTD.Depth(3),'QC: BAD','FontSize',6,'HorizontalAlignment','right')
xlim([-max(abs(CTD.SPEC_ESPER_DIFFERENCE)) max(abs(CTD.SPEC_ESPER_DIFFERENCE))])
xticks(floor(min(xlim)/0.01)*0.01:0.01:ceil(max(xlim)/0.01)*0.01)
% xtickangle(65)

linkaxes([n1 n2],'xy')

%% Output directory
outdir = fullfile("figures", "ESPER_BIAS");
if ~exist(outdir, 'dir'), mkdir(outdir); end
figname = fullfile(outdir, 'BIAS.png');
saveas(fig,figname);