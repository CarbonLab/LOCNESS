% profile 120: 250 m
i = 120;
phase_ctd = data.ctd.phase{i} == 0;
t_ctd = data.ctd.t{i}(phase_ctd);
depth_ctd = data.ctd.depth{i}(phase_ctd);
time_ctd = data.ctd.time{i}(phase_ctd);

phase_dox = data.dox.phase{i} == 0;
t_dox = data.dox.thermt{i}(phase_dox);
depth_dox = data.dox.depth{i}(phase_dox);
time_dox = data.dox.time{i}(phase_dox);
%%
plot(t_ctd,depth_ctd)
hold on
plot(t_dox,depth_dox)
legend('ctd','dox')
axis ij

%%
%% Plot dox temp shifted by 5 samples
plot(t_ctd, depth_ctd)
hold on
plot(t_dox, depth_dox)
plot(t_dox(1:end-5), depth_dox(6:end))
legend('ctd', 'dox original', 'dox +5s')
axis ij

%% How does the 10% change in heat impact pH calculation
k0 = -.996868991849884;
k2_fp_c0 = 0.000326025;
fp_k1 = 1.067810e-5;
fp_k2 = -2.410230e-8;
fp_k3 = 3.012270e-11;
fp_k4 = -2.0155210e-14;
fp_k5 = 6.861560e-18;
fp_k6 = -9.322750e-22;
Pcoefs = [fp_k1,fp_k2,fp_k3,...
            fp_k4,fp_k5,fp_k6]';
k2 = k2_fp_c0;

%%
% interpolate t,s to p of pressure and compute ph
ndive = length(data.ph.p);
data.ph.ph = cell(ndive,1);
data.ph.ph_temp_shift_minus_10 = cell(ndive,1);
data.ph.ph_temp_shift_plus_10 = cell(ndive,1);

for n = 1:ndive

    if ~isempty(data.ph.Vrse{n})

        [~,iuse] = unique(data.ctd.time{n});
        if sum(iuse)>1
            ss = interp1(data.ctd.time{n}(iuse),data.ctd.s{n}(iuse),data.ph.time{n},'linear','extrap'); % interpolate in time rather than pressure since time is monotonic
            tt = interp1(data.ctd.time{n}(iuse),data.ctd.t{n}(iuse),data.ph.time{n},'linear','extrap');
            
            [~,data.ph.ph{n}] = phcalc_jp(data.ph.Vrse{n},data.ph.p{n},tt,ss,k0,k2,Pcoefs);
            [~,data.ph.ph_temp_shift_minus_10{n}] = phcalc_jp(data.ph.Vrse{n},data.ph.p{n},tt-.1,ss,k0,k2,Pcoefs);
            [~,data.ph.ph_temp_shift_plus_10{n}] = phcalc_jp(data.ph.Vrse{n},data.ph.p{n},tt+.1,ss,k0,k2,Pcoefs);
        else
            data.ph.ph{n} = nan(size(data.ph.Vrse{n}));
        end

    end

end
%%
phase_ph = data.ph.phase{i} == 0;
clf
plot(data.ph.ph{i}(phase_ph),data.ph.depth{i}(phase_ph))
hold on
plot(data.ph.ph_temp_shift_minus_10{i}(phase_ph),data.ph.depth{i}(phase_ph),Color='red')
plot(data.ph.ph_temp_shift_plus_10{i}(phase_ph),data.ph.depth{i}(phase_ph),Color='blue')
legend('pH','pH temp - 10%','pH temp + 10%')
axis ij