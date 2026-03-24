% Correct Spray2 pH by recalculating k0 for each profile using 
% ESPER_PH_ADJUSTED based on the bias measured as the
% difference in SPEC_PH and ESPER_PH(CTD)
% ESPER_PH_ADJUSTED = ESPER_PH + BIAS
% BIAS = SPEC_PH - ESPER_PH(CTD_TEMP,CTD_PSAL,CTD_PRES,CTD_DOXY)
% k0 = k0frompH(Vrs, Press, Temp, Salt, pHtot, k2, Pcoefs);

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
title('ESPER ADJUSTED')
scatter(CTD.SPEC_ESPER_ADJUST_DIFFERENCE(3),CTD.Depth(3),'rx')
text(CTD.SPEC_ESPER_ADJUST_DIFFERENCE(3)+.1*CTD.SPEC_ESPER_DIFFERENCE(3),CTD.Depth(3),'QC: BAD','FontSize',6,'HorizontalAlignment','right')
xlim([-max(abs(CTD.SPEC_ESPER_DIFFERENCE)) max(abs(CTD.SPEC_ESPER_DIFFERENCE))])
xticks(floor(min(xlim)/0.01)*0.01:0.01:ceil(max(xlim)/0.01)*0.01)
% xtickangle(65)

linkaxes([n1 n2],'xy')
saveas(fig,'BIAS.png');
%% BIAS
BIAS = 0.012; % Rough estimate
%% Part 2
%% Calculate ESPER parameters for the raw spray2 glider values
% Interpolate everything onto the pH pressure grid
load('data.mat');
if isempty(data.ESPER.ph) % Check if data.mat already has ESPER struct
    ndive = length(data.ph.p);
    data.ESPER.ph = cell(ndive,1);
    data.ESPER.ph_corrected = cell(ndive,1);
    data.ESPER.s = cell(ndive,1);
    data.ESPER.t = cell(ndive,1);
    data.ESPER.oxumolkg = cell(ndive,1);
    data.ESPER.depth = data.ph.depth;
    data.ESPER.bias = BIAS;
    for n = 1:ndive
    
        if ~isempty(data.ph.Vrse{n})
    
            [~,iuse] = unique(data.ctd.time{n});
            dox_flag_good = data.qual.dox.ox{n} == 0;
            if sum(iuse)>1
                data.ESPER.s{n} = interp1(data.ctd.time{n}(iuse),data.ctd.s{n}(iuse),data.ph.time{n},'linear','extrap'); % interpolate in time rather than pressure since time is monotonic
                data.ESPER.t{n} = interp1(data.ctd.time{n}(iuse),data.ctd.t{n}(iuse),data.ph.time{n},'linear','extrap');
                data.ESPER.oxumolkg{n} = interp1(data.dox.time{n}(dox_flag_good),data.dox.oxumolkg{n}(dox_flag_good),data.ph.time{n},'linear','extrap');
            else
                % data.ph.ph{n} = nan(size(data.ph.Vrse{n}));
            end
    
        end
    
    end
    %% ESPER(TSO)
    for prof = 1:ndive
        iuse = data.ph.depth{prof} > 150 & data.ph.phase{prof} == 0;
        lat = repmat(data.lat(prof,1),length(data.ph.depth{prof}(iuse)),1);
        lon = repmat(data.lon(prof,1),length(data.ph.depth{prof}(iuse)),1);
        sdn = repmat(data.time(prof,1)/86400 + datenum(1970,1,1),length(data.ph.depth{prof}(iuse)),1);
        data.ESPER.ph{prof} = NaN(size(data.ESPER.s{prof})); % Save time by only calc esper for ascent dives below 150 m
        data.ESPER.ph_corrected{prof} = NaN(size(data.ESPER.s{prof}));
        if ~isempty(lat) && ~isempty(lon) && ~isempty(sdn)
            ESP = ESPER_TSO(lat,lon,data.ESPER.depth{prof}(iuse),data.ESPER.s{prof}(iuse),data.ESPER.t{prof}(iuse),data.ESPER.oxumolkg{prof}(iuse),sdn);
            data.ESPER.ph{prof}(iuse) = ESP.pH;
            data.ESPER.ph_corrected{prof}(iuse) = ESP.pH - abs(BIAS);
        else
            continue
        end
        disp(['Finished ',num2str(prof),' / ', num2str(ndive)])
    end
    % Add info tag
    data.ESPER.info =...
        {"ALGORITHM" , "ESPER_MIXED";...
        "BIAS", "MEAN BELOW 150M OF SPEC_INSITU - ESPER_PHIN (QC REMOVED VALUE AT 210 M)";...
        "PH_ADJUSTED", "ESPER_PH - |BIAS|"};
    %% Save data struct with new ESPER vars
    save("data.mat","data");
end
%% k0 calc
% g = Spray2Data('25720901');
g.pHcal.k0_seawater = -.996868991849884;
g.pHcal.k2_fp_c0 = 0.000326025;
g.pHcal.fp_k1 = 1.067810e-5;
g.pHcal.fp_k2 = -2.410230e-8;
g.pHcal.fp_k3 = 3.012270e-11;
g.pHcal.fp_k4 = -2.0155210e-14;
g.pHcal.fp_k5 = 6.861560e-18;
g.pHcal.fp_k6 = -9.322750e-22;
Pcoefs = [g.pHcal.fp_k1,g.pHcal.fp_k2,g.pHcal.fp_k3,...
            g.pHcal.fp_k4,g.pHcal.fp_k5,g.pHcal.fp_k6]';
k2 = g.pHcal.k2_fp_c0;
data.ph.k0_ESPER_ADJUSTED = cell(ndive,1);

for prof = 1:ndive
    if ~isempty(data.ESPER.ph_corrected{prof})
        data.ph.k0_ESPER_ADJUSTED{prof} = k0frompH(data.ph.Vrse{prof},...
            data.ph.p{prof},...
            data.ESPER.t{prof},...
            data.ESPER.s{prof},...
            data.ESPER.ph_corrected{prof},...
            k2, Pcoefs);
    else
        continue
    end
end
%% plot
for prof = 1:ndive
    k0_mean(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof},'omitmissing');
    k0_min(prof) = min(data.ph.k0_ESPER_ADJUSTED{prof});
    k0_max(prof) = max(data.ph.k0_ESPER_ADJUSTED{prof});
    iuse = data.ph.depth{prof} > 150 & data.ph.depth{prof} < 151;
    k0_mean_150(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof}(iuse),'omitmissing');
    iuse = data.ph.depth{prof} > 175 & data.ph.depth{prof} < 176;
    k0_mean_175(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof}(iuse),'omitmissing');
    iuse = data.ph.depth{prof} > 200 & data.ph.depth{prof} < 201;
    k0_mean_200(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof}(iuse),'omitmissing');
    iuse = data.ph.depth{prof} > 225 & data.ph.depth{prof} < 226;
    k0_mean_225(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof}(iuse),'omitmissing');
    iuse = data.ph.depth{prof} > 250 & data.ph.depth{prof} < 251;
    k0_mean_250(prof) = mean(data.ph.k0_ESPER_ADJUSTED{prof}(iuse),'omitmissing');
end
%%
fig = figure;
tl = tiledlayout(6,1);
title(tl,'SN209: k0_ESPER_ADJUSTED','Interpreter','none')
xlabel(tl,'profile')

nexttile
scatter(1:ndive,k0_mean_150,'.','MarkerEdgeColor',[0 0.4470 0.7410])
ylabel('150m','Interpreter','none')
nexttile
scatter(1:ndive,k0_mean_175,'.','MarkerEdgeColor',[0.8500 0.3250 0.0980])
ylabel('175m','Interpreter','none')
nexttile
scatter(1:ndive,k0_mean_200,'.','MarkerEdgeColor',[0.9290 0.6940 0.1250])
ylabel('200m','Interpreter','none')
nexttile
scatter(1:ndive,k0_mean_225,'.','MarkerEdgeColor',[0.4940 0.1840 0.5560])
ylabel('225m','Interpreter','none')
nexttile
scatter(1:ndive,k0_mean_250,'.','MarkerEdgeColor',[0.4660 0.6740 0.1880])
ylabel('250m','Interpreter','none')
nexttile
scatter(1:ndive,k0_mean,'k.')
ylabel('mean >150m','Interpreter','none')
saveas(fig,'SN209_k0_ESPER_ADJUSTED.png');
%%



fig = figure;
tl = tiledlayout(1,1);
title(tl,'SN209: k0_ESPER_ADJUSTED','Interpreter','none')
xlabel(tl,'profile')

nexttile
scatter(1:ndive,k0_mean,'.','MarkerEdgeColor',[0 0.4470 0.7410])
hold on
yline(g.pHcal.k0_seawater)
ylabel('150m','Interpreter','none')
%% Now recompute pH with a 16 second lag
% three permutations of lag response testing
    % nothing
    % just lag vrse
    % lag vrse and temperature
data.ph.time{prof};
