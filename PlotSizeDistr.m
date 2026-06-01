%% Workspace initialization

close all;                                                                 % close all figure
clear;                                                                     % remove all variables from the current workspace
clc;                                                                       % delete the command window


%% Initialisation

% Paths of the different folders
currentFolder = pwd;
baseFolder = fileparts(currentFolder);
rawdataFolder = fullfile(baseFolder,'01_Raw data');
processeddataFolder = fullfile(baseFolder, '03_Processed data');
analysisFolder = fullfile(baseFolder,'04_Data analysis');


%% Selection of the acqusition date

% Get a list of the dates of the LISST-Holo2 acquisition campaigns

% Get a list of all files and folders in this folder.
Listfiles = dir(processeddataFolder);
% Get a logical vector that tells which is a directory.
dirFlags = [Listfiles.isdir];
% Extract only those that are directories.
subFolders = Listfiles(dirFlags); % A structure with extra info.
% Get only the folder names into a cell array.
subFolderNames = string({subFolders(3:end).name}); % Start at 3 to skip . and ..


% Make user choose the campaign date

date_campaigns = datetime(subFolderNames,'InputFormat','yyyyMMdd');
[indx,tf] = listdlg('Name','Date Selection','PromptString','Select the acquisition date for which you want to clean the raw data:','SelectionMode','single','ListSize',[400,250],'ListString',date_campaigns);

% Print an error message if no date have been selected
while tf==0
    waitfor(msgbox("No acquisiton date has been selected.","Error","warn"));

    date_campaigns = datetime(subFolderNames,'InputFormat','yyyyMMdd');
    [indx,tf] = listdlg('Name','Date Selection','PromptString','Select the acquisition date for which you want to clean the raw data:','SelectionMode','single','ListSize',[400,250],'ListString',date_campaigns);
end
% Save the date selected
seldate = date_campaigns(indx);

%  Determine the path where the corresponding ALL csv is stored
selpath = fullfile(processeddataFolder,subFolderNames(indx),'Size distributions');
% Print an error message if the folder containing the raw data is not named
% correctly, saved in the correct folder or does not exist
if isfolder(selpath) ~= 1 
    waitfor(msgbox(["The folder 'Size distributions' containing the 'ALL' csv at the date selected does not exist, is not named correctly or is not saved in the folder E:\03_Processed data\yyyymmdd.";"The program will stop.";"Please check the raw data folder and start again."],"Error","error"))
    return
end    


%% Read the 'All' csv file

ALLfilename = dir(fullfile(selpath,'*_All.csv'));
ALLtable = readtable(fullfile(selpath,ALLfilename.name),"VariableNamingRule","modify");  

%% Read CTD csv

CTDfilename = dir(fullfile(rawdataFolder,subFolderNames(indx),"*_CTDprofile",'*.csv'));
CTDtable = readtable(fullfile(CTDfilename.folder,CTDfilename.name));

% Data extraction
CTDdepth = CTDtable.y1;
CTDturbidity = CTDtable.x3;

% Data cleaning
CTDdepth(CTDdepth<1) = NaN;
CTDturbidity(CTDdepth<1) = NaN;
max_CTDdepth = max(CTDdepth);
idx_max_CTDdepth = find(CTDdepth==max_CTDdepth,1,'first');
idx_CTDtokeep = true(length(CTDdepth),1);
idx_CTDtokeep(idx_max_CTDdepth +1 :end)=0;
CTDdepth = CTDdepth(idx_CTDtokeep);
CTDturbidity = CTDturbidity(idx_CTDtokeep);


%% Extraction of the data

% Depth
depth = ALLtable.Depth(5:end);
% Size class
size_class_midpoint = table2array(ALLtable(3,26:end));
size_class_min = table2array(ALLtable(2,26:end));
size_class_max = table2array(ALLtable(4,26:end));
size_class_width = size_class_max - size_class_min;

% Size distribution
size_distr = table2array(ALLtable(5:end,26:end));
size_distr(size_distr==0) = NaN;                                           % replace the 0s by NaNs so that it doesn'tatificially lower the means

% Volume
volume_tot = ALLtable.TotalVolume(5:end);
% Number of particles detected
NBparticles = ALLtable.NumberOfParticles(5:end);

% Don't take contaminated holos into account in size distributions
indexes_contaminated_holos = find(NBparticles>=1000);
size_distr(indexes_contaminated_holos,:) = NaN;
volume_tot(indexes_contaminated_holos,:) = NaN;

% Computation of the percentage volume size distribution
SPMVC=zeros(size(size_distr));
for k=1:size(size_distr,1)
    SPMVC(k,:)=(size_distr(k,:)/volume_tot(k,1))*100;
end

%% Computation of the PSD

% The particulate volume concentration is normalized by the width of each 
% of the logarithmically-spaced classes. It gives the Particle Size 
% Distribution

PSD = zeros(size(SPMVC));
for k=1:size(SPMVC,2)
    PSD(:,k) = SPMVC(:,k)/size_class_width(1,k);
end


%% Data preprocessing

% Computation of the depth levels

% Create an array to hold the indices of the constant depth segments
constant_segments = [];

% Loop to find contiguous segments
for i=1:length(depth)-1
    if abs(depth(i+1)-depth(i))<1
        if isempty(constant_segments)|| constant_segments(end, 2) < i
            constant_segments(end+1, :) = [i,i+1];
        else
            constant_segments(end, 2) = i+1;
        end
    end
end    

depth_level = zeros(length(depth),1);
for i=1:size(constant_segments,1)
    mean_depth = mean(depth(constant_segments(i,1):constant_segments(i,2)));
    depth_level(constant_segments(i,1):constant_segments(i,2))=round(mean_depth);
end    


figure(1)
hold on
plot(depth,'Marker','.','MarkerSize',5,'LineStyle','none')
plot(depth_level,'Marker',".","LineStyle","none")
set(gca, 'YDir', 'reverse'); % Invert y-axis
xlabel('Image index')
ylabel('Depth level (m)')
title('Depth levels at which the LISST-Holo was stopped during the campaign')
saveas(gcf,fullfile(analysisFolder, 'Depth levels', strcat(string(seldate,"uuuuMMdd"),' Depth level.fig')))
saveas(gcf,fullfile(analysisFolder, 'Depth levels', strcat(string(seldate,"uuuuMMdd"),' Depth level.png')))


%% Plot

[depth_level_sorted,~, depth_categorie] = unique(depth_level);
% Correction of the depth level

NBparticles_mean = zeros(length(depth_level_sorted),1);
SPMVC_mean = zeros(length(depth_level_sorted),size(SPMVC,2));
for k=1:max(depth_categorie)
    indexes = find(depth_categorie == k);
    volume_categorie = sum(volume_tot(indexes,1),'omitnan');
    SPMVC_mean(k,:) = (sum(size_distr(indexes,:),1,'omitnan')/volume_categorie)*100;
    PSD_mean(k,:) = mean(PSD(indexes,:),1,"omitnan");
    NBparticles_mean(k,1)=mean(NBparticles(indexes));
end
SPMVC_mean(SPMVC_mean==0)=NaN;

NBimages_per_depth_level=zeros(length(depth_level_sorted),1);
for k=1:length(depth_level_sorted)
    NBimages_per_depth_level(k,1)=sum(depth_categorie==k);
end

CTDturbidity_mean_depth_level = zeros(length(depth_level_sorted),1);
for k=1:length(depth_level_sorted)
    idx_meanCTD = find(round(CTDdepth) == depth_level_sorted(k));
    CTDturbidity_mean_depth_level(k)=mean(CTDturbidity(idx_meanCTD),1,'omitnan');
end

figure(31)
plot(CTDturbidity_mean_depth_level,NBparticles_mean,'LineStyle','none','Marker','o')
xlabel('Mean turbidity measured with the CTD')
ylabel('Mean number of particles detected by the LISST')
xlim([0 15])
ylim([0 600])
title('Measured turbidity VS Number of particles')
saveas(gcf,fullfile(analysisFolder, 'Number of particules VS Turbidity','Mean', strcat(string(seldate,"uuuuMMdd"),' MeanCorrelationTurbidityNBparts.png')))
% % % 
save(fullfile(analysisFolder, 'Number of particules VS Turbidity','Median','Variables',strcat(string(seldate,"uuuuMMdd"),' TurbiditaParticles.mat')),"NBparticles_mean","CTDturbidity_mean_depth_level")



figure(2)
bar(depth_level_sorted,NBimages_per_depth_level)
grid minor
xlabel('Depth level [m]')
ylabel('Number of holograms')
ylim([0 450])
title('Number of holograms per depth level')
saveas(gcf,fullfile(analysisFolder, 'Number of images per depth level', strcat(string(seldate,"uuuuMMdd"),' Images per depth level.png')))
% % % 
% % % 
figure(3)
hold on
boxplot(NBparticles,depth_level,'Positions',depth_level)
xlabel('Depth level (m)')
ylabel('Number of particles detected')
xtickangle(90)
xticks([5 10 15 20 24 30 34 39 44 49 53 58 63 68 73 78 83 88 93 98 103])
xticklabels({'5', '10', '15', '20', '24', '30', '34', '39', '44', '49', '53', '58', '63', '68', '73', '78', '83', '88', '93', '98', '103'})
% % % % % % 
yyaxis right
ax = gca;
ax.YAxis(2).Color = "#77AC30";
ax.YAxis(2).Limits = [0 3];
% % % % % % 
plot(CTDdepth,CTDturbidity,'Color',"#77AC30");
ylabel('Turbidity [FTU]')
title('Boxplots of the number of particles detected in an image at each depth level')
saveas(gcf,fullfile(analysisFolder, 'Number of particles per image of a depth level', strcat(string(seldate,"uuuuMMdd"),' Particles per image per depth level.png')))

%%

% Set color vector
color = turbo(111);

figure(5)
hold on
for k=1:size(SPMVC,1)
     plot(size_class_midpoint,SPMVC(k,:),'Color',color(depth_level(k)+1,:))
end    
set(gca,'XScale','log')
xlim([10 1000])
xlim([0 80])
xlabel('Diameter (um)')
ylabel('%SPMVC')
title('Particle size distribution for each depth level')
colormap(turbo(110))
cb = colorbar('Ticks',linspace(0,1,12),...
         'TickLabels',{'0','10','20','30','40','50','60','70','80','90','100','110'});
cb.Label.String = 'Depth (m)';
%saveas(gcf,fullfile(analysisFolder, 'Size distributions','SPMVC', strcat(string(seldate,"uuuuMMdd"),' SPMVC.png')))

sum(SPMVC_mean,2,'omitnan')
sum(SPMVC,2,'omitnan')

figure(7)
hold on
for k=1:size(SPMVC_mean,1)
     plot(size_class_midpoint,SPMVC_mean(k,:),'Color',color(depth_level_sorted(k)+1,:))
end    
set(gca,'XScale','log')
xlim([10 1000])
ylim([0 55])
xlabel('Diameter (um)')
ylabel('%SPMVC')
title('Mean particle size distribution for each depth level')
colormap(turbo(110))
cb = colorbar('Ticks',linspace(0,1,12),...
          'TickLabels',{'0','10','20','30','40','50','60','70','80','90','100','110'});
cb.Label.String = 'Depth (m)';
saveas(gcf,fullfile(analysisFolder, 'Size distributions','SPMVC mean', strcat(string(seldate,"uuuuMMdd"),' SPMVC mean.png')))

% Set color vector
color = turbo(111);

figure (10)
hold on
for k=1:size(PSD,1)
    plot(size_class_midpoint,PSD(k,:),'Color',color(depth_level(k)+1,:))
end    
set(gca,'XScale','log')
xlim([10 1000])
ylim([0 20])
xlabel('Diameter (um)')
ylabel('PSD')
title('Particle size distribution')
colormap(turbo(110))
cb = colorbar('Ticks',linspace(0,1,12),...
          'TickLabels',{'0','10','20','30','40','50','60','70','80','90','100','110'});
cb.Label.String = 'Depth (m)';
%saveas(gcf,fullfile(analysisFolder, 'Size distributions','PSD', strcat(string(seldate,"uuuuMMdd"),' PSD.png')))


%% Define the different parts of the flow

%% Infos about the turbidity peak

TPfilename = dir(fullfile(baseFolder, 'Armelle', 'Turbidity peaks.xlsx'));

if isempty(TPfilename)
    error('Fichier "Turbidity peaks.xlsx" introuvable.');
end

TPtable = readtable(fullfile(baseFolder, 'Armelle', TPfilename.name), ...
    "VariableNamingRule","modify");

% Convert the dates into datetimes
TPtable.AcquisitionDate = datetime(string(TPtable.AcquisitionDate),'InputFormat','yyyyMMdd');

idx_currentdate_TPtable = (seldate==TPtable.AcquisitionDate);

% Depth limits of the turbidity peak
upperLimTP = TPtable.ShallowestBoundTPDepthRange_m_(idx_currentdate_TPtable);
lowerLimTP = TPtable.DeepestBoundTPDepthRange_m_(idx_currentdate_TPtable);

idx_aboveTP = find((depth<=upperLimTP) & (depth>=upperLimTP-2));
idx_TP = find((depth>=upperLimTP) & (depth<=lowerLimTP));
idx_belowTP = find((depth>=lowerLimTP) & (depth<lowerLimTP+10));
for k=1:length(idx_TP)
    idx_belowTP(idx_belowTP==idx_TP(k))=[];
end

%%
% Epilimion 0-15m deep

idx_epi = find(depth_level<=10);
SPMVC_mean_epi = (sum(size_distr(idx_epi,:),1,'omitnan')/sum(volume_tot(idx_epi,1),'omitnan'))*100;
SPMVC_mean_epi(SPMVC_mean_epi==0)=NaN;

% Hypolimnion 60-100m

idx_hypo = find((depth_level>=60) & (depth_level<=100));
SPMVC_mean_hypo = (sum(size_distr(idx_hypo,:),1,'omitnan')/sum(volume_tot(idx_hypo,1),'omitnan'))*100;
SPMVC_mean_hypo(SPMVC_mean_hypo==0) = NaN;

% Peak
SPMVC_mean_TP = (sum(size_distr(idx_TP,:),1,'omitnan')/sum(volume_tot(idx_TP,1),'omitnan'))*100;

% Above peak
SPMVC_mean_aboveTP = (sum(size_distr(idx_aboveTP,:),1,'omitnan')/sum(volume_tot(idx_aboveTP,1),'omitnan'))*100;

% Below peak
SPMVC_mean_belowTP = (sum(size_distr(idx_belowTP,:),1,'omitnan')/sum(volume_tot(idx_belowTP,1),'omitnan'))*100;


%% Plots


figure(15)
hold on
plot(size_class_midpoint,SPMVC_mean_epi,'Color',"#4DBEEE")
plot(size_class_midpoint,SPMVC_mean_TP,'Color',"#0072BD")
plot(size_class_midpoint,SPMVC_mean_belowTP,'Color',"#D95319")
plot(size_class_midpoint,SPMVC_mean_hypo,'Color',"#EDB120")
plot(size_class_midpoint,SPMVC_mean_aboveTP)
set(gca,'XScale','log')
xlim([10 1000])
ylim([0 30])
xlabel('Diameter (um)')
ylabel('%SPMVC')
title('SPMVC')
legend('Epilimnion','Hypolimnion','Turbidity peak','Below turbidity peak','Location','best')
saveas(gcf,fullfile(analysisFolder, 'Size distributions','SPMVC mean relevant depths', strcat(string(seldate,"uuuuMMdd"),' SPMVC mean depths.png')))

%%
%figure(16)
%hold on
%plot(size_class_midpoint,PSD_mean_epi)
%plot(size_class_midpoint,PSD_mean_hypo)
%plot(size_class_midpoint,PSD_mean_TP)
%plot(size_class_midpoint,PSD_mean_aboveTP)
%plot(size_class_midpoint,PSD_mean_belowTP)
%xscale log
%xlim([10 1000])
%xlabel('Diameter (um)')
%ylabel('PSD of SPMVC')
%title('PSD of SPMVC')
%legend('Epilimion 0-15m deep','Hypolimnion 60-100m','Turbidity peak','Above TP','Below TP')
%saveas(gcf,fullfile(analysisFolder, 'Size distributions','Divided by total volume', strcat(string(seldate,"uuuuMMdd"),' PSD SPMVC mean depths.png')))


%% Per depth range of 10m

SPMVC_mean_10m = zeros(11,50);
for k=1:11
    % SPMVC_mean_10m(k,:)=mean(SPMVC(find(depth_level>=(k-1)*10 & depth_level<k*10),:),1,"omitnan");
    indexes = find(depth_level>=(k-1)*10 & depth_level<k*10);
    volume_categorie = sum(volume_tot(indexes,1),'omitnan');
    SPMVC_mean_10m(k,:) = (sum(size_distr(indexes,:),1,'omitnan')/volume_categorie)*100;
end
SPMVC_mean_10m(SPMVC_mean_10m==0) = NaN;

sum(SPMVC_mean_10m,2,'omitnan')


figure(18)
hold on
for k=1:size(SPMVC_mean_10m,1)
    plot(size_class_midpoint,SPMVC_mean_10m(k,:),'Color',color(k*10-1,:))
end
ha = area([100 1000], [50 50], 'FaceColor','k','EdgeColor','none');
alpha(ha,0.1)
set(gca,'XScale','log')
xlim([10 1000])
ylim([0 50])
xlabel('Diameter (um)')
ylabel('Mean %SPMVC')
title('Particle size distribution for each depth level')
colormap(turbo(110))
cb = colorbar('Ticks',linspace(0,1,12),...
        'TickLabels',{'0','10','20','30','40','50','60','70','80','90','100','110'});
cb.Label.String = 'Depth (m)';
%saveas(gcf,fullfile(analysisFolder, 'Size distributions','SPMVC mean 10m layers', strcat(string(seldate,"uuuuMMdd"),' Size distr mean 10m depth layer.png')))


mode(SPMVC_mean_10m(1,:))
Locmax = islocalmax(SPMVC_mean_10m(1,:));

SPMVC_mean_epi_smooth = smoothdata(SPMVC_mean_epi.','movmean',3,'omitnan');
SPMVC_mean_hypo_smooth = smoothdata(SPMVC_mean_hypo.','movmean',3,'omitnan');
SPMVC_mean_TP_smooth = smoothdata(SPMVC_mean_TP.','movmean',3,'omitnan');
SPMVC_mean_belowTP_smooth = smoothdata(SPMVC_mean_belowTP.','movmean',3,'omitnan');

SPMVC_mean_epi_smooth = smoothdata(SPMVC_mean_epi.','rloess',6,'omitnan');
SPMVC_mean_hypo_smooth = smoothdata(SPMVC_mean_hypo.','rloess',6,'omitnan');
SPMVC_mean_TP_smooth = smoothdata(SPMVC_mean_TP.','rloess',6,'omitnan');
SPMVC_mean_belowTP_smooth = smoothdata(SPMVC_mean_belowTP.','rloess',6,'omitnan');

SPMVC_mean_epi_smooth = smooth(size_class_midpoint,SPMVC_mean_epi,0.2,'loess');
SPMVC_mean_hypo_smooth = smooth(size_class_midpoint,SPMVC_mean_hypo,0.2,'loess');
SPMVC_mean_TP_smooth = smooth(size_class_midpoint,SPMVC_mean_TP,0.2,'loess');
SPMVC_mean_aboveTP_smooth = smooth(size_class_midpoint,SPMVC_mean_aboveTP,0.2,'loess');
SPMVC_mean_belowTP_smooth = smooth(size_class_midpoint,SPMVC_mean_belowTP,0.2,'loess');

[pks_epi,locs_epi] = findpeaks(SPMVC_mean_epi_smooth,'NPeaks',1,'SortStr','descend');
[pks_hypo,locs_hypo] = findpeaks(SPMVC_mean_hypo_smooth,'NPeaks',1,'SortStr','descend');
[pks_TP,locs_TP] = findpeaks(SPMVC_mean_TP_smooth,'NPeaks',2,'SortStr','descend');
[pks_belowTP,locs_belowTP] = findpeaks(SPMVC_mean_belowTP_smooth,'NPeaks',1,'SortStr','descend');

figure(19)
hold on
plot(size_class_midpoint,SPMVC_mean_epi,'LineStyle','--','Color',"#4DBEEE")
p1 = plot(size_class_midpoint,SPMVC_mean_epi_smooth,'Color',"#4DBEEE");
plot(size_class_midpoint,SPMVC_mean_hypo,'LineStyle','--','Color',"#EDB120")
p2 = plot(size_class_midpoint,SPMVC_mean_hypo_smooth,'Color',"#EDB120");
plot(size_class_midpoint,SPMVC_mean_TP,'LineStyle','--','Color',"#0072BD")
p3 = plot(size_class_midpoint,SPMVC_mean_TP_smooth,'Color',"#0072BD");
plot(size_class_midpoint,SPMVC_mean_aboveTP,'LineStyle','--','Color','k')
plot(size_class_midpoint,SPMVC_mean_aboveTP_smooth,'Color','k')
plot(size_class_midpoint,SPMVC_mean_belowTP,'LineStyle','--','Color',"#D95319")
p4 = plot(size_class_midpoint,SPMVC_mean_belowTP_smooth,'Color',"#D95319");
plot(size_class_midpoint(1,locs_epi),SPMVC_mean_epi_smooth(locs_epi,1),'LineStyle','none','Marker','o','Color',"#4DBEEE",'MarkerFaceColor',"#4DBEEE",'MarkerSize',8)
plot(size_class_midpoint(1,locs_hypo),SPMVC_mean_hypo_smooth(locs_hypo,1),'LineStyle','none','Marker','o','Color',"#EDB120",'MarkerFaceColor',"#EDB120",'MarkerSize',8)
plot(size_class_midpoint(1,locs_TP),SPMVC_mean_TP_smooth(locs_TP,1),'LineStyle','none','Marker','o','Color',"#0072BD",'MarkerFaceColor',"#0072BD",'MarkerSize',8)
%plot(size_class_midpoint(1,locs_aboveTP),SPMVC_mean_aboveTP_smooth(locs_aboveTP,1),'LineStyle','none','Marker','o','Color','r')
%plot(size_class_midpoint(1,locs_belowTP),SPMVC_mean_belowTP_smooth(locs_belowTP,1),'LineStyle','none','Marker','o','Color',"#D95319",'MarkerFaceColor',"#D95319",'MarkerSize',8)
plot(size_class_midpoint(Locmax),SPMVC_mean_10m(1,Locmax),'LineStyle','none','Marker','*')
%plot(xf,f)
legend('epi','epi smopth','hypo','hypo smooth','TP','TP smooth','above TP','above TP smooth','below TP','below TP smooth','Location','bestoutside')
legend([p1,p3,p4,p2],'Epilimnion','Turbidity peak','Below turbidity peak','Hypolimnion','Location','best')
set(gca,'XScale','log')
xlim([10 1000])
ylim([0 30])
xlabel('Diameter (um)')
ylabel('Mean %SPMVC')
title('Particle size distribution')
saveas(gcf,fullfile(analysisFolder, 'Size distributions','Modes', strcat(string(seldate,"uuuuMMdd"),' Modes.png')))
saveas(gcf,fullfile(analysisFolder, 'Size distributions','Modes', strcat(string(seldate,"uuuuMMdd"),' Modes.fig')))

save(fullfile(analysisFolder, 'Size distributions','Modes', 'Variables',strcat(string(seldate,"uuuuMMdd"),'.mat')),"idx_epi",'idx_hypo','idx_TP','pks_belowTP','-mat')


figure(1)
hold on
plot(depth_level,'Marker',".","LineStyle","none",'Color','k')
p2 = plot(idx_epi,depth_level(idx_epi),'Marker',".","LineStyle","none",'Color',"#4DBEEE");
p1 = plot(idx_TP,depth_level(idx_TP),'Marker',".","LineStyle","none",'Color',"#0072BD");
p3 = plot(idx_belowTP,depth_level(idx_belowTP),'Marker',".","LineStyle","none",'Color',"#D95319");
p4 = plot(idx_hypo,depth_level(idx_hypo),'Marker',".","LineStyle","none",'Color',"#EDB120");
yline(TPtable.ShallowestBoundTPDepthRange_m_(idx_currentdate_TPtable),'Color', "k")
yline(TPtable.DeepestBoundTPDepthRange_m_(idx_currentdate_TPtable),'Color', "k")
set(gca, 'YDir', 'reverse'); % Invert y-axis
xlabel('Image index')
ylabel('Depth level (m)')
legend([p2,p1,p3,p4],'Epilimnion','Turbidity peak','Below turbidity peak','Hypolimnion','Location','northeast')
title('Depth levels at which the LISST-Holo was stopped during the campaign')
saveas(gcf,fullfile(analysisFolder, 'Size distributions','Depth ranges for size distr', strcat(string(seldate,"uuuuMMdd"),' .fig')))
saveas(gcf,fullfile(analysisFolder, 'Size distributions','Depth ranges for size distr', strcat(string(seldate,"uuuuMMdd"),' .png')))
saveas(gcf,fullfile(analysisFolder, 'Depth levels', strcat(string(seldate,"uuuuMMdd"),' Depth level.png')))
