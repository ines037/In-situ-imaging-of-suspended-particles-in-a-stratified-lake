%% Function used in the CleanRawData script

function result = sortie_recherche(borne_dep, borne_fin, copie)
% This function takes as an input a string 'borne_dep', a string 
% 'a borne_fin' and characters 'copie'. It returns the first captured group
% in the characters 'copie' that is captured by the expression:
% "borne_dep (.*) borne_fin"
    rechercher = strcat(borne_dep, '(.*)', borne_fin);                     % create a string of what we want to search by concatenating borne_dep, (.*) and borne_fin 
    result = regexp(copie, rechercher, 'tokens');                          % return the text in the string copie captured by the expression rechercher
    if isempty(result)                                                     % return an empty string if no match is found
        result = '';
    else
        result = strtrim(result{1}{1});                                    % return the first captured group and remove leading and trailing whitespace from this captured string
    end
end