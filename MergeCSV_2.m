%% MergeCSV_2.m
%Pré-requis : avoir les noms des colonnes dans le fichiers ALL (éxécuter le
%script CSVtitles.m avant) et la bonne date (script ChangeDate.m)
%Ce script écrit les bonnes dates et heures dans les fichiers .pstat à
%partir du ALL.csv
%% Workspace initialization
close all;
clear;
clc;

%% Sélection du dossier Size distributions
defaultPath = 'L:\03_Processed data';
selpath = uigetdir(defaultPath, 'Select the "Size distributions" folder for the campaign');
if selpath == 0
    return
end

% Extraire le dossier parent pour récupérer la date YYYYMMDD
[parentPath, folderName] = fileparts(selpath);
[~, dateFolder] = fileparts(parentPath);
if strlength(dateFolder) ~= 8
    warning('Parent folder does not look like YYYYMMDD. Dates will be used from Pstat folder.');
end

%% Lecture du fichier ALL.csv
ALLfilename = dir(fullfile(selpath,'*_All.csv'));
if isempty(ALLfilename)
    waitfor(msgbox("No ALL.csv file found.","Error","error"));
    return
end

ALLtable = readtable(fullfile(selpath,ALLfilename.name), 'VariableNamingRule','preserve');

% Trouver colonne ImageNumber dans ALL.csv de manière robuste
colImageNumber = find(contains(ALLtable.Properties.VariableNames,'Image Number','IgnoreCase',true),1);
if isempty(colImageNumber)
    error('No column containing "ImageNumber" found in ALL.csv');
end

%% Lecture des fichiers Pstat
ListPstatfiles = dir(fullfile(selpath,'*-pstat.csv'));
if isempty(ListPstatfiles)
    waitfor(msgbox("No '-pstat.csv' files found.","Error","error"));
    return
end

% Trier les fichiers pstat
[~, idxSort] = sort({ListPstatfiles.name});
ListPstatfiles = ListPstatfiles(idxSort);

%% Parcours et correction des fichiers Pstat
nCorrected = 0; % compteur de fichiers corrigés

for k = 1:length(ListPstatfiles)
    filePstat = ListPstatfiles(k).name;
    Pstat = readtable(fullfile(selpath, filePstat), 'VariableNamingRule','preserve');

    % Extraire le numéro d'image du fichier
    PstatImageNumber = extractBefore(filePstat,'-pstat');
    PstatImageNumber = extractAfter(PstatImageNumber,4);
    PstatImageNumber = str2double(PstatImageNumber);

    % Trouver la ligne correspondante dans ALL.csv si elle existe
    lineALL = find(ALLtable{:,colImageNumber} == PstatImageNumber, 1);

    nRows = height(Pstat);

    % Extraire date depuis le dossier parent
    if strlength(dateFolder) == 8
        yearStr  = extractBetween(dateFolder,1,4);
        monthStr = extractBetween(dateFolder,5,6);
        dayStr   = extractBetween(dateFolder,7,8);
    else
        yearStr = "YYYY"; monthStr="MM"; dayStr="DD";
    end

    % --- Colonnes date/heure ---
    dateCols = {'Year_YYYY_','Month_MM_','Day_DD_','Hour_HH_','Minute_MM_','Second_SS_'};
    defaultValues = {yearStr, monthStr, dayStr, "12", "00", "00"};

    for i = 1:length(dateCols)
        if ismember(dateCols{i}, Pstat.Properties.VariableNames)
            % Convertir en string si c'est un cell ou numeric
            if iscell(Pstat.(dateCols{i})) || isnumeric(Pstat.(dateCols{i}))
                Pstat.(dateCols{i}) = string(Pstat.(dateCols{i}));
            end
            % Remplacer uniquement les valeurs manquantes
            missingIdx = ismissing(Pstat.(dateCols{i}));
            Pstat.(dateCols{i})(missingIdx) = repmat(defaultValues{i}, sum(missingIdx), 1);
        else
            % Créer la colonne si elle n'existe pas
            Pstat.(dateCols{i}) = repmat(defaultValues{i}, nRows, 1);
        end
    end

    % --- Colonnes numériques ---
    numColsALL = {'Depth','Deployment ID','Number of Particles'};
    numColsPstat = {'Depth_m_','DeploymentID','TotalNumberOfParticles'};

    for i = 1:length(numColsALL)
        % Obtenir la valeur depuis ALL si possible
        if ~isempty(lineALL) && ismember(numColsALL{i}, ALLtable.Properties.VariableNames)
            val = ALLtable.(numColsALL{i})(lineALL);
            if isnumeric(val)
                val = string(val);
            elseif ismissing(val)
                val = "";
            else
                val = string(val);
            end
        else
            val = "";
        end

        % Créer ou remplacer la colonne dans Pstat
        if ismember(numColsPstat{i}, Pstat.Properties.VariableNames)
            if iscell(Pstat.(numColsPstat{i})) || isnumeric(Pstat.(numColsPstat{i}))
                Pstat.(numColsPstat{i}) = string(Pstat.(numColsPstat{i}));
            end
            Pstat.(numColsPstat{i})(:) = repmat(val, nRows, 1);
        else
            Pstat.(numColsPstat{i}) = repmat(val, nRows, 1);
        end
    end

    % Écrire le fichier corrigé
    writetable(Pstat, fullfile(selpath, filePstat), "WriteVariableNames", true);
    nCorrected = nCorrected + 1;
end

%% Message final
if strlength(dateFolder) == 8
    campaignDate = dateFolder;
else
    campaignDate = "unknown";
end
msg = sprintf('All Pstat files have been corrected and merged for campaign date %s.\nNumber of files processed: %d', campaignDate, nCorrected);
waitfor(msgbox(msg,'Done','help'));
