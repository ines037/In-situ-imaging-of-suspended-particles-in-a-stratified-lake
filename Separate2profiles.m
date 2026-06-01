function [profile1_idx,profile2_idx] = Separate2profiles(nom_file,depth,seldate)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here


%% Find the 2 profiles

underwater = depth(find(depth>=1,1,'first'):find(depth>=1,1,'last'));      % remove the images above water level at the beginning and the end of the raw data
    underwater_idx = find(depth>=1,1,'first'):find(depth>=1,1,'last');
    
    profile1_idx = underwater_idx(1:find(underwater<1,1,'first')-1);
    
    profile2_idx = underwater_idx(find(underwater<1,1,'last') +1 : end);
    
    % Plot the depth profile
    
    figure(2)
    hold on
    % plot(depth,'Color',"#D95319",'LineWidth', 2);
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
    
    [~,msg] = mkdir(cleaneddataFolder,date_meas);

    if strcmp(msg,'Directory already exists.')
        waitfor(msgbox(["The directory for cleaned data already exists.";"The program will stop."],"Error","error"));
        return
    end   