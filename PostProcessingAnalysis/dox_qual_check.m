% load('G:\Shared drives\NOPPmCDR\locness_data\spray\tmp_20260115\2507020902.mat');
%%
tl = tiledlayout(1,2);
title(tl,'oxumol/kg')
nexttile
for prof = 1:length(data.dox.oxumolkg)
    plot(data.dox.oxumolkg{prof},data.dox.depth{prof})
    hold on
end
axis ij
title('No Flags')

nexttile
for prof = 1:length(data.dox.oxumolkg)
    iuse = data.qual.dox.ox{prof} == 0;
    plot(data.dox.oxumolkg{prof}(iuse),data.dox.depth{prof}(iuse));
    hold on
end
axis ij
title('Flags = 0')