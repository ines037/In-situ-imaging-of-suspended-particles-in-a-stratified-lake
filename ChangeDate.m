%% ChangeDate_safe.m
% - Sélection directe d’un fichier ALL (csv, xlsx ou mat)
% - Ne modifie QUE les colonnes de date, lignes 6:end
% - Ne crée jamais de NaN : tout est traité comme du texte
% - Reconstruit le fichier à l’identique sauf les colonnes date

clear; clc; close all;

%% ========= Sélection directe du fichier "ALL" ==========
defaultDir = 'L:\03_Processed data';

[file, path] = uigetfile( ...
    {'*.csv;*.xlsx;*.mat','Fichiers ALL (*.csv, *.xlsx, *.mat)'}, ...
    'Sélectionnez le fichier ALL à corriger', ...
    defaultDir);

if isequal(file,0)
    error('Aucun fichier sélectionné.');
end

fullFile = fullfile(path, file);
fprintf('\n=== Fichier sélectionné : %s ===\n', fullFile);

%% ========= Extraire la date à partir du dossier ==========
% Exemple : L:\03_Processed data\20250327\Size distributions\ALL.csv
folderName = regexp(path, '(?<date>\d{8})', 'match', 'once');

if isempty(folderName)
    error('Impossible de détecter une date (format YYYYMMDD) dans le chemin.');
end

yearStr  = folderName(1:4);
monthStr = folderName(5:6);
dayStr   = folderName(7:8);

fprintf('Date détectée : %s-%s-%s\n', yearStr, monthStr, dayStr);

%% ========= Lire le fichier en fonction de son extension ==========
[~, ~, ext] = fileparts(fullFile);

if strcmpi(ext, '.mat')
    error('Les fichiers MAT ne contiennent pas des colonnes date modifiables. Utilisez un CSV/Excel.');
end

% Lecture brute du fichier CSV/Excel comme texte :
if strcmpi(ext, '.xlsx')
    tmpCSV = [tempname '.csv'];
    writetable(readtable(fullFile), tmpCSV); % convertit en CSV propre
    fileText = fileread(tmpCSV);
    delete(tmpCSV);
else
    fileText = fileread(fullFile);
end

lines = splitlines(fileText);
if numel(lines) < 6
    error('Fichier trop court pour être un fichier ALL valide.');
end

%% ========= Parse chaque ligne ==========
data = cellfun(@(x) split(x,','), lines, 'UniformOutput', false);
header = data{1};

% Trouver colonnes date
colYear   = find(strcmpi(header, "Year (YYYY)"));
colMonth  = find(strcmpi(header, "Month (MM)"));
colDay    = find(strcmpi(header, "Day (DD)"));
colHour   = find(strcmpi(header, "Hour (HH)"));
colMinute = find(strcmpi(header, "Minute (MM)"));
colSecond = find(strcmpi(header, "Second (SS)"));

%% ========= Modifier uniquement lignes 6:end ==========
for r = 6:numel(data)

    row = data{r};

    % Si ligne trop courte → compléter
    if length(row) < length(header)
        row(end+1:length(header)) = {''};
    end

    if ~isempty(colYear),   row{colYear}   = yearStr;  end
    if ~isempty(colMonth),  row{colMonth}  = monthStr; end
    if ~isempty(colDay),    row{colDay}    = dayStr;   end
    if ~isempty(colHour),   row{colHour}   = "12";     end
    if ~isempty(colMinute), row{colMinute} = "00";     end
    if ~isempty(colSecond), row{colSecond} = "00";     end

    data{r} = row;
end

%% ========= Reconstruction EXACTE du CSV ==========
outLines = strings(numel(data),1);

for r = 1:numel(data)
    rowCells = cellfun(@(x) char(string(x)), data{r}, 'UniformOutput', false);
    outLines(r) = strjoin(rowCells, ',');
end

fileOut = strjoin(outLines, newline);

fid = fopen(fullFile, 'w');
fwrite(fid, fileOut);
fclose(fid);

fprintf('\n=== MODIFICATION TERMINÉE ===\n');
fprintf('Colonnes de dates mises à jour.\n');
fprintf('Fichier sauvegardé : %s\n', fullFile);
