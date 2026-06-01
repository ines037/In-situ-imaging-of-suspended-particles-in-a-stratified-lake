function cleaned_data_idx = FindRelevantRawHolograms(depth,seldate,nom_file,date_meas,answerNBprofiles, cleaneddataFolder,selpath,CurrentProfileNb,profile1_idx,profile2_idx)
% This function cleans the raw data and only keeps the data that was taken
% when the LISS-Holo2 was underwater and going downwards

%UNTITLED Summary of this function goes here
%   Detailed explanation goes here


%% Find the index of the 'cleaned' data
% 'Cleaned' data refers to holograms taken when the LISST-Holo2 was:
% - underwater (i.e. depth >1m)
% - going downwards (i.e. first part of the profile, until the LISST
% reaches the maximum depth)
% - acquired when the LISST was stopped at a depth level (the LISST was not
% moving)


if strcmp(answerNBprofiles,'1 profile')
    idx_holo_current_profile =true(1,size(depth,2));                     % Make logical array of ones
    depth_current_profile = depth;
elseif strcmp(answerNBprofiles,'2 profiles')
    idx_holo_current_profile =false(1,size(depth,2));
    if CurrentProfileNb==1
        idx_holo_current_profile(1,profile1_idx)=1;
    else
        idx_holo_current_profile(1,profile2_idx)=1;
    end
    depth_current_profile = depth;
    depth_current_profile(~idx_holo_current_profile)=NaN;
end

% Find the index of the last image taken at the maximum depth
max_depth = max(depth_current_profile);
idx_max_depth = find(depth_current_profile==max_depth,1,'last');

% Find the index of the first image taken at a depth >1m
idx_underwater = find(depth_current_profile>1,1,'first');

% Define a threshold for considering the depth as constant
threshold = 0.11;

% Find the indices where the depth is constant
constant_depth_indices = find(abs(diff(depth_current_profile(idx_underwater:idx_max_depth))) < threshold) + idx_underwater -1; % indices des plateaux (mais il manque l'indice de la dernière mesure du plateau!!!)

% Create an array to hold the indices of the constant depth segments
constant_segments = [];

% Loop through the constant indices and find contiguous segments
for i = 1:length(constant_depth_indices)-1
    if constant_depth_indices(i+1) - constant_depth_indices(i) == 1        % if the indices are successive
        if isempty(constant_segments) || constant_segments(end, 2) < constant_depth_indices(i) 
            constant_segments(end+1, :) = [constant_depth_indices(i), constant_depth_indices(i+1)];
        else
            constant_segments(end, 2) = constant_depth_indices(i+1);
        end
    end
end

constant_segments(:,2) = constant_segments(:,2)+1;

% Remove the moments when the Lisst holo was going slowly but was not
% stopped on purpose

% Create a logical index for rows to keep
keep_rows = true(size(constant_segments, 1), 1);

for k = 1:size(constant_segments,1)
    if constant_segments(k,2)- constant_segments(k,1) <9
         keep_rows(k) = false;  % Mark this row for removal
    end
end

% Filter the constant_segments based on the logical index
constant_segments = constant_segments(keep_rows, :);

% File names of the data taken when the LISST-Holo2 was underwater and
% going downwards
cleaned_data_idx = [];
for i= 1:size(constant_segments,1)
    a= constant_segments(i,1):constant_segments(i,2);
    cleaned_data_idx= [cleaned_data_idx a];
end    

end