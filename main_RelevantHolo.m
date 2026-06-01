%% Extract relevant LISST-Holo2 raw holograms

% This script aims at selecting relevant LISST-Holo2 raw holograms from 
% all the raw holograms acquired during a field campaign, to only extract 
% the relevant holograms for future reconstruction and analysis. 
% 
% Here, relevant
% raw data refers to the holograms that were done when the LISST-Holo2 was:
% - underwater (the LISST is considered to be underwater when the depth
% measured is bigger than 1 meter)
% - staying still when the hologram was taken (the LISST is considered to 
% be still when at least 10 holograms in a row were taken at
% approximatively same depth (depth difference<0,11m))
% - going downwards in the watercolumn (to have as much holograms as
% possible that were taken in an undisturbed watercolumn), an exception is
% made to this last rule for a few field campaigns during which the
% LISST-Holo2 is stopped a few minutes when it was going upwards to aquire
% data just below the turbidity peak, inside the turbidity peak and above 
% the turbidity peak.
% 
% This sorting is useful to reduce the number of holograms that need to be
% reconstructed. Reconstructing only the hologram that are relevant for a
% future analysis saves computation time and saves storage.

% This script takes as an input the raw holograms acquired during a field
% campaign using the LISST-Holo2 (Sequoia Scientific). These raw holograms
% must be stored on the hard drive "LISST_Holo_hd" , inside the folder 
% "01_Raw data\\yyyymmdd\\yyyymmdd_measures" where "yyyymmdd" correspond to
% the date of the field campaign. It is very important to respect this
% nomenclature in order for this script to work properly. The user is then
% ask to select the campagne date for which he wants to extract the 
% relevant holograms. For this script to work, a folder called 
% "02_Cleaned raw data" should arleady be created in the hard drive.

% The output from this script is that the relevant LISST-Holo2 raw 
% holograms are then saved on the hard drive, inside the folder
% "02_Cleaned raw data\\yyyymmdd", where "yyyymmdd" correspond to the date
% of the selected field campaign. This script also provides visual 
% representations of the data:
% - a plot of the depth of all the raw holograms from the campaign, called
% "yyyymmdd Raw data depth profile" and saved as a png in the folder 
% "01_Raw data\\yyyymmdd\\yyyymmdd_measures" where "yyyymmdd" correspond to
% the date of the field campaign,
% - a plot of the depth of all the raw holograms in which the holograms
% considered as relevant are highlighted, called 
% "yyyymmdd Cleaned raw data depth profile" and saved as a png in the
% folder "02_Cleaned raw data\\yyyymmdd", where "yyyymmdd" correspond to 
% the date of the selected field campaign.

% This script calls 2 Matlab functions to work:
% - FindRelevantRawHolograms.m
% - sortie_recherche.m

% Some parts of this script and these functions are based on Python scripts
% developped by Louise Noël du Payrat.

% Armelle BOUHALI, 01.10.2024


%% Workspace initialization

close all;                                                                 % close all figure
clear;                                                                     % remove all variables from the current workspace
clc;                                                                       % delete the command window


%% Script initialization

% Extraction of the paths of the useful folders

currentFolder = pwd;                                                       % path of the current folder
rawdataFolder = fullfile(extractBefore(currentFolder,'\00_Programs'),...   % path of the folder where the raw data from all the campaigns are stored
    '01_Raw data');
cleaneddataFolder= fullfile(extractBefore(currentFolder,'\00_Programs'),...% path of the folder where the relevant holograms from all the campaigns will be stored
    '02_Cleaned raw data');


%% Selection of the acqusition date 

% Get a list of the dates of the LISST-Holo2 field campaigns for which the
% raw holograms are stored in the folder "01_Raw data"

Listfiles = dir(rawdataFolder);                                            % List of all files and folders in the folder "01_Raw data"
dirFlags = [Listfiles.isdir];                                              % Logical vector that tells which file/folder is a directory
subFolders = Listfiles(dirFlags);                                          % Extraction of information about the directories only
subFolderNames = string({subFolders(3:end).name});                         % Extraction of the names of the directories (start at 3 to skip "." and "..")

% Make user choose the campaign date for which he wants to extract the
% relevant holograms

date_campaigns = datetime(subFolderNames,'InputFormat','yyyyMMdd');        % Save the directory names in the Matlab datetime format
[indx,tf] = listdlg('Name','Date Selection','PromptString',...             % Make the user choose a date
    'Select the acquisition date for which you want to clean the raw data:',...
    'SelectionMode','single','ListSize',[400,250],'ListString',...
    date_campaigns);
while tf==0                                                                % Print an error message if no date have been selected
    waitfor(msgbox("No acquisiton date has been selected.","Error","warn"));
    [indx,tf] = listdlg('Name','Date Selection','PromptString',...         % Ask again to the user to select a campaign date
        'Select the acquisition date for which you want to clean the raw data:',...
        'SelectionMode','single','ListSize',[400,250],'ListString',...
        date_campaigns);
end
seldate = date_campaigns(indx);                                            % Save the date selected by the user
selpath = fullfile(rawdataFolder,subFolderNames(indx),...                  % Determine the path where the corresponding raw holograms are supposed to be stored
    strcat(subFolderNames(indx),'_measures'));
% Print an error message if the folder containing the raw data is not named
% correctly, saved in the correct folder or does not exist
if isfolder(selpath) ~= 1 
    waitfor(msgbox(["The folder containing the raw data at the date"...
        "selected does not exist, is not named correctly yyyymmdd_measures"...
        "or is not saved in the folder E:\01_Raw data\yyyymmdd.";...
        "The program will stop.";...
        "Please check the raw data folder and start again."],"Error",...
        "error"))
    return
end    


%% Extraction of holograms depths

% Initialization

files = dir(fullfile(selpath, '*.pgm'));                                   % return attributes (name, folder, date, bytes, isdir, datenum) about each of the pgm files contained in the raw data folder selected by the user
nom_file = {files.name};                                                   % list of the names of all the raw holograms of the selected campaign date
depth = zeros(1,length(files));                                            % initialization of the vector to store de depth of the holograms

% Extraction of the depth

for k = 1:length(files)                                                    % for each pgm file, the metadata are extracted
    file_name = files(k).name;                                             % temporary variable with the name of the file currently studied
    file_path = fullfile(selpath, file_name);                              % temporary save of the path of the current file
    fid = fopen(file_path, 'rb');
    copie = fread(fid, '*char')';                                          % read the current file as characters
    fclose(fid);
    depth(1,k) = str2double(sortie_recherche('Depth', 'meter', copie));    % store the depth of current file
end


%% Plotting the depth profile of LISST during image capture

% Plot the depth profile

figure(1)
hold on
plot(depth,'Marker',".",'MarkerEdgeColor',"k","LineStyle","--","Color","k");
yline(0,'Color', "#4DBEEE")
set(gca, 'YDir', 'reverse');                                               % Invert y-axis
grid on;
grid minor
xlabel('Image index');
ylabel('Depth (meter)');
title(['Depth Profile of LISST-Holo2 holograms on the ', string(seldate)]);
legend('LISST depth profile', 'Water level','Location','best')

% Save the depth profile in the folder '01_Raw data'

date_meas = extractAfter(selpath,"01_Raw data\");
date_meas = extractBefore(date_meas,9);
saveas(gcf,fullfile(selpath, strcat(date_meas,' Raw data depth profile.png')))


%% Divide (if needed) 2 distinct profiles saved together in the same folder of raw data

% Ask the user the number of profiles contained in the raw data plotted

opts.Interpreter = 'tex';                                                  % Use the TeX interpreter to format the question
opts.Default = '1 profile';                                                % Desired default answer
quest = 'Does the raw data only contain 1 single LISST-Holo profile or does it contain 2 profiles?'; % Window to make the user tell the number of profiles
answerNBprofiles = questdlg(quest,'Number of LISST profiles?',...
                  '1 profile','2 profiles',opts);
% Error message if no answer has been selected
while strcmp(answerNBprofiles,'')
   waitfor(msgbox("No type of profile has been selected.","Error","warn"));
   answerNBprofiles = questdlg(quest,'Number of LISST profiles?',...
                  '1 profile','2 profiles',opts);
end

% If there is a single profile, nothing is done in this section
% If there are 2 distinct profiles, the are divided and the function
% FindRelevantRawHolograms.m is used on both profiles successively

% Find the 2 profiles

if strcmp(answerNBprofiles,'2 profiles')  
  
    underwater = depth(find(depth>=1,1,'first'):find(depth>=1,1,'last'));      % remove the images above water level at the beginning and the end of the raw data
    underwater_idx = find(depth>=1,1,'first'):find(depth>=1,1,'last');
    
    profile1_idx = underwater_idx(1:find(underwater<1,1,'first')-1);
    
    profile2_idx = underwater_idx(find(underwater<1,1,'last') +1 : end);
    
    % Plot the depth profile
    
    figure(2)
    hold on
    plot(depth,'Marker',".",'MarkerEdgeColor',"k","LineStyle","--","Color","k")
    set(gca, 'YDir', 'reverse'); % Invert y-axis
    yline(0,'Color', "#4DBEEE")
    plot(profile1_idx,depth(profile1_idx),'Marker',".",'MarkerEdgeColor',"#D95319","LineStyle","none")
    plot(profile2_idx,depth(profile2_idx),'Marker',".",'MarkerEdgeColor',"#77AC30","LineStyle","none")
    grid on;
    grid minor
    xlabel('Image index');
    ylabel('Depth (meter)');
    title(['Depth Profile of LISST-Holo2 holograms on the ', string(seldate)]);
    legend('LISST depth profile', 'Water level','Profile 1','Profile 2','Location','best')
    

end


%% Data cleaning

% If there is a single profile, the data is directly cleaned using the
% function FindRelevantRawHolograms
% If there are 2 distinct profiles, each of the profiles are studied
% separately and then cleaned using the function FindRelevantRawHolograms

if strcmp(answerNBprofiles,'1 profile')

    % Ask the user if all the data acquired when going upwards can be discarded

    opts.Interpreter = 'tex';
    % Include the desired Default answer
    opts.Default = 'No';
    % Use the TeX interpreter to format the question
    quest = 'In this profile, was the LISST-Holo2 stopped at some depth when it was going upwards?';
    answerStoppedUpwards = questdlg(quest,'LISST stopped when going upwards?',...
                  'Yes','No',opts);

    if strcmp(answerStoppedUpwards,'No')
        % Clean the data 
        cleaned_data_idx = FindRelevantRawHolograms(depth,seldate,nom_file,date_meas,answerNBprofiles,cleaneddataFolder,selpath,0,0,0);

    % elseif strcmp(answerStoppedUpwards,'Yes')
        % SAVE DATA GOING UPWARDS
        % Save the data when the LISST is going donwards
    end

elseif strcmp(answerNBprofiles,'2 profiles')
    cleaned_data_idx = [];
    
    for CurrentProfileNb=1:2
        if CurrentProfileNb==1
            indices = profile1_idx;
        elseif CurrentProfileNb==2
            indices = profile2_idx;
        end

        % Plot one of the depth profile

        figure('Name',['Profile ',num2str(CurrentProfileNb)],'NumberTitle','off');
        hold on
        plot(indices, depth(indices),'Marker',".",'MarkerEdgeColor',"k","LineStyle","--","Color","k")
        yline(0,'Color', "#4DBEEE")
        set(gca, 'YDir', 'reverse'); % Invert y-axis
        grid on;
        grid minor
        xlabel('Image index');
        ylabel('Depth (meter)');
        title(['Depth Profile',num2str(CurrentProfileNb),' of LISST-Holo2 holograms on the ', string(seldate)]);
        legend(['Profile ' ,num2str(CurrentProfileNb)], 'Water level','Location','best') 
        
        % Ask the user if all the data acquired when going upwards can be discarded

        opts.Interpreter = 'tex';
        % Include the desired Default answer
        opts.Default = 'No';
        % Use the TeX interpreter to format the question
        quest = 'In this profile, was the LISST-Holo2 stopped at some depth when it was going upwards?';
        answerStoppedUpwards = questdlg(quest,'LISST stopped when going upwards?',...
                          'Yes','No',opts);
        
        if strcmp(answerStoppedUpwards,'No')
            % Clean the data 
            cleaned_data_idx = [cleaned_data_idx FindRelevantRawHolograms(depth,seldate,nom_file,date_meas,answerNBprofiles,cleaneddataFolder,selpath,CurrentProfileNb,profile1_idx,profile2_idx)];
                                                                          
        % elseif strcmp(answerStoppedUpwards,'Yes')
            % SAVE DATA GOING UPWARDS
            % Save the data when the LISST is going donwards
        end

    end    

end  

%% Plot the clean raw data depth profile

figure(20)
hold on
plot(depth,'Marker',".",'MarkerEdgeColor',"k","LineStyle","none","Color","k");
plot(cleaned_data_idx,depth(cleaned_data_idx),'Marker',".",'MarkerEdgeColor',"#D95319",'MarkerSize',8,"LineStyle","none")
set(gca, 'YDir', 'reverse'); % Invert y-axis
yline(0,'Color', "#4DBEEE")
grid on;
grid minor
xlabel('Image index');
ylabel('Depth (meter)');
title(['Depth Profile of LISST-Holo2 holograms on the ', string(seldate)]);
legend('LISST depth profile','Cleaned raw data', 'Water level','Location','best')

cleaned_data_file_names = nom_file(cleaned_data_idx);

%% Make the user choose if he wants the cleaned data to be saved

opts.Interpreter = 'tex';
% Include the desired Default answer
opts.Default = 'Yes';
% Use the TeX interpreter to format the question
quest = ['There are ', num2str(length(cleaned_data_file_names)), ' .pgm files in the cleaned raw data (on ', num2str(length(nom_file)), ' raw holograms).', 'Do you want to copy the cleaned data and save them in a new folder?'];
answerSaveCleanedData = questdlg(quest,'Save the cleaned raw data?',...
                  'Yes','No',opts);
% Stop the function CleanRawData if the user don't want to save the cleaned
% data
if strcmp(answerSaveCleanedData,'No')
    return
end 


%% Copy the cleaned raw data in a new folder 

% if strcmp(answerNBprofiles,'2 profiles')
% 
%     % Create a directory to save cleaned data
%     if CurrentProfileNb==1
%         [~,msg] = mkdir(cleaneddataFolder,date_meas);
% 
%         if strcmp(msg,'Directory already exists.')
%             waitfor(msgbox(["The directory for cleaned data already exists.";"The program will stop."],"Error","error"));
%             return
%         end
%     end
% 
%     % Save the cleaned data in the folder created just before
%     for k=1:length(cleaned_data_file_names)
%         copyfile(strcat(selpath,"\",cleaned_data_file_names(k)),fullfile(cleaneddataFolder,num2str(date_meas)))
%     end
% 
%     % Save the depth profile in the folder '02_Cleaned raw data'
%     saveas(gcf,fullfile(cleaneddataFolder, num2str(date_meas), strcat(date_meas,' Cleaned raw data depth profile.png')))
% 
% 
% elseif strcmp(answerNBprofiles,'1 profile')
    % Create a directory to save the cleaned data
    [~,msg] = mkdir(cleaneddataFolder,date_meas);

    if strcmp(msg,'Directory already exists.')
        waitfor(msgbox(["The directory for cleaned data already exists.";"The program will stop."],"Error","error"));
        return
    end  

    % Save the cleaned data in the folder created just before
    for k=1:length(cleaned_data_file_names)
        copyfile(strcat(selpath,"\",cleaned_data_file_names(k)),fullfile(cleaneddataFolder,num2str(date_meas)))
    end

    % Save the depth profile in the folder '02_Cleaned raw data'
    saveas(gcf,fullfile(cleaneddataFolder, num2str(date_meas), strcat(date_meas,' Cleaned raw data depth profile.png')))

% end

