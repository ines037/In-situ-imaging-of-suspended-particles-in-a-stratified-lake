%% Workspace initialization
%%METTRE LES TITRES DU FICHIER ALL.CSV AVANT D'EXECUTER LE SCRIPT
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
    [indx,tf] = listdlg('Name','Date Selection','PromptString','Select the acquisition date for which you want to see the size distribution:','SelectionMode','single','ListSize',[400,250],'ListString',date_campaigns);
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
data = readtable(fullfile(selpath,ALLfilename.name),"VariableNamingRule","modify");  

% === EXTRAIRE PROFONDEUR ET DISTRIBUTION ===
depth = data.Depth;

% Trouver première colonne de distribution (à adapter selon ton fichier)
sizeDistStartCol = find(contains(data.Properties.VariableNames, 'SizeDistribution'), 1, 'first');
size_dist = data{:, sizeDistStartCol:end};

% --- Extraire les variables ---
depth = data.Depth;  
total_volume = data.TotalVolume; 


% --- Supprimer les lignes où volume total = 0 ---
valid_volume_idx = total_volume > 0;

depth = depth(valid_volume_idx);
size_dist = size_dist(valid_volume_idx, :);
total_volume = total_volume(valid_volume_idx);


% --- Calculer proportions par taille (en fraction) ---
prop_dist = size_dist ./ total_volume;


% Définition des tailles des classes
sizes_um = [... 
    1.475	1.741	2.054	2.424	2.861	3.376	3.983	4.701	5.547	6.546 ...
    7.725	9.116	10.757	12.694	14.98	17.678	20.861	24.617	29.05	34.281 ...
    40.454	47.738	56.335	66.479	78.449	92.576	109.246	128.917	152.131	179.525 ...
    211.852	250	297.302	353.553	420.448	500	594.604	707.107	840.896	1000 ...
    1189.207	1414.214	1681.793	2000	2378.414	2828.427	3363.586	4000	4756.828	5656.854];

% --- Filtrer les tailles supérieures à 250 µm ---
keep_idx = sizes_um <= 250;       % index des tailles à garder
sizes_um = sizes_um(keep_idx);    % filtrage du vecteur des tailles
size_dist = size_dist(:, keep_idx); % filtrage des colonnes correspondantes

% Index pour les intervalles
idx_8_20      = find(sizes_um >= 8   & sizes_um < 20);
idx_20_60     = find(sizes_um >= 20  & sizes_um < 60);
idx_60_125    = find(sizes_um >= 60  & sizes_um < 125);
idx_sup_125   = find(sizes_um >= 125);




%% === VOLUMIQUE ===

% Nettoyage et filtrage des données
depth_vol     = depth;
size_dist_vol = size_dist;

% Supprimer lignes NaN
valid_vol_idx = all(~isnan(size_dist_vol), 2);
depth_vol     = depth_vol(valid_vol_idx);
size_dist_vol = size_dist_vol(valid_vol_idx, :);

% Calcul volume total et proportion
total_vol = sum(size_dist_vol, 2);
prop_vol  = size_dist_vol ./ total_vol;

% Calcul des proportions par classe
% Calcul des proportions par classe
prop_8_20      = sum(prop_vol(:, idx_8_20), 2);
prop_20_60     = sum(prop_vol(:, idx_20_60), 2);
prop_60_125    = sum(prop_vol(:, idx_60_125), 2);
prop_sup_125   = sum(prop_vol(:, idx_sup_125), 2);


% Fusion des profondeurs proches (< 0.2 m)
depth_fused = [];
prop_fused  = [];

depths = depth_vol;
props  = [prop_8_20, prop_20_60, prop_60_125, prop_sup_125];

while ~isempty(depths)
    d0 = depths(1);
    idx = abs(depths - d0) < 0.2;

    depth_avg = mean(depths(idx));
    prop_avg  = mean(props(idx, :), 1);

    depth_fused(end+1,1) = depth_avg;
    prop_fused(end+1,:)  = prop_avg;

    depths(idx) = [];
    props(idx,:) = [];
end

% Lissage et normalisation
prop_smooth = smoothdata(prop_fused, 1, 'movmean', 5);
prop_smooth = (prop_smooth ./ sum(prop_smooth, 2))*100;

% Tri
[depth_sorted, sort_idx] = sort(depth_fused);
prop_sorted = prop_smooth(sort_idx, :);

% Info sur le pic de turbidité
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

% ----- Calcul du D50 -----
D50 = nan(size(size_dist_vol,1),1);

% Boucle sur chaque ligne (chaque profondeur)
for i = 1:size(size_dist_vol,1)
    dist = size_dist_vol(i,:);

    if sum(dist) > 0 && ~any(isnan(dist))
        vol_frac = dist / sum(dist);
        cum_frac = cumsum(vol_frac);
        idx = find(cum_frac >= 0.5, 1, 'first');

        if idx > 1
            % Interpolation linéaire
            x1 = sizes_um(idx-1); y1 = cum_frac(idx-1);
            x2 = sizes_um(idx);   y2 = cum_frac(idx);
            D50(i) = x1 + (0.5 - y1)*(x2 - x1)/(y2 - y1);
        else
            D50(i) = sizes_um(idx);
        end
    end
end

% Trier D50 selon l’index trié utilisé pour prop_sorted
D50_sorted = D50(sort_idx);

% Initialiser les vecteurs fusionnés
depth_fused = [];
D50_fused = [];

% Copie des vecteurs à compacter
depths = depth_sorted;
D50s = D50_sorted;

while ~isempty(depths)
    d0 = depths(1);
    d50_0 = D50s(1);

    close_idx = abs(depths - d0) < 0.5;

    depth_avg = mean(depths(close_idx));
    d50_avg   = mean(D50s(close_idx));

    depth_fused(end+1,1) = depth_avg;
    D50_fused(end+1,1)   = d50_avg;

    depths(close_idx) = [];
    D50s(close_idx) = [];
end

% Lissage
D50_fused_smooth = smooth(D50_fused, 3);


% === Création du graphique ===
figure;

% Axe principal : proportions empilées
ax1 = gca;
bottom = zeros(size(depth_sorted));
% Couleurs personnalisées
colors = [
    206, 106, 107;   % #CE6A6B
    235, 172, 162;   % #EBACA2
    190, 211, 195;   % #BED3C3
    74,  145, 158    % #4A919E
] / 255;

disp(max(sizes_um))


hold on;
fillHandles = gobjects(size(prop_sorted,2),1); % pré-allocation
for i = 1:size(prop_sorted, 2)
    top = bottom + prop_sorted(:, i);
    fillHandles(i) = fill([bottom; flipud(top)], [depth_sorted; flipud(depth_sorted)], ...
         colors(i,:), 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    bottom = top;
end
hold off;

% Axe principal config
set(ax1, 'YDir', 'reverse');
xlabel(ax1, '% SPMVC','FontSize', 10, 'FontWeight', 'bold');
ylabel(ax1, 'Depth (m)','FontSize', 10, 'FontWeight', 'bold');
xlim(ax1, [0 100]);
ylim(ax1, [min(depth_sorted), max(depth_sorted)]);

% Limites du TP (si disponibles)
if isnumeric(upperLimTP) && isnumeric(lowerLimTP) && ...
   ~isempty(upperLimTP) && ~isempty(lowerLimTP) && ...
   all(~isnan([upperLimTP, lowerLimTP])) && ...
   upperLimTP ~= 0 && lowerLimTP ~= 0

    % Sauvegarde des handles avec DisplayName
%    hLine1 = yline(upperLimTP, '--b', 'DisplayName', 'Turbidity peak range', ...
%          'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'bottom');
%    hLine2 = yline(lowerLimTP, '--b', 'HandleVisibility', 'off', ...
%          'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'bottom');
end

% Deuxième axe X pour D50
ax2 = axes('Position', get(ax1, 'Position'), ...
           'YAxisLocation', 'right', ...
           'XAxisLocation', 'top', ...
           'Color', 'none');

hold(ax2, 'on');
D50_handle = plot(ax2, D50_fused_smooth, depth_fused, ...
                  '-k', 'LineWidth', 1);  % D50 sans DisplayName ici
hold(ax2, 'off');

% Synchronisation des axes
set(ax2, 'YDir', 'reverse', ...
         'YLim', get(ax1, 'YLim'), ...
         'XColor', 'k', 'YColor', 'k');
set(ax2, 'YTick', [], 'YColor', 'none');
xlabel(ax2, 'median diameter D_{50} (µm)','FontSize', 10, 'FontWeight', 'bold');
xlim(ax2, [0, 200]);

set(ax1, 'FontSize', 10, 'FontWeight', 'bold');  % graduations axe 1
set(ax2, 'FontSize', 10, 'FontWeight', 'bold');  % graduations axe 2

% Légende combinée (sur ax1, mais contient aussi le D50 d’ax2)
legend([fillHandles; D50_handle], ...
       {'8–20 µm', '20–60 µm', '60–125 µm', '>125 µm', 'D_{50}'}, ...
      'Location', 'eastoutside');


% Positionnement pour laisser place à la légende
ax1.Position = [0.1, 0.15, 0.65, 0.65];
ax2.Position = ax1.Position;

% Titre et export
title(['Particle sizes in function of depth ' datestr(seldate, 'dd/mm/yyyy')]);
grid(ax1, 'on');

exportgraphics(gcf, fullfile(analysisFolder, 'Size function of depth\noLegend', ...
    strcat(string(seldate,"uuuuMMdd"),'size_depth.png')), ...
    'Resolution', 300);









