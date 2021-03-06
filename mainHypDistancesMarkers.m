%% main hypoMarkers distance measurements

pathFolders = dir('**/*.xls');
addpath(genpath('src'))

for nFolder = size(pathFolders,1):-1:1
    
    T = readtable([pathFolders(nFolder).folder '\' pathFolders(nFolder).name],'Sheet','Quantities - Raw');
    pathRois = dir([pathFolders(nFolder).folder '\*.csv']);
    
    namesROIs = {pathRois(:).name};
    majorROI = namesROIs(cellfun(@(x) contains(lower(x),'major'),namesROIs));
    tableMajorROI = readtable([pathFolders(nFolder).folder '\' majorROI{1}]);
    
    imgInfo = imfinfo([pathFolders(nFolder).folder '\Image.tif']);
    img = imread([pathFolders(nFolder).folder '\Image.tif']);
    resolution = imgInfo.XResolution; % X inches -> 1 pixel
    % 1 inch -> 25400 micrometers
    convertInch2Micr = 25400/1;
    %pixels * inches/pixels * micrometers/inches
    sizeXmicrons = imgInfo.Width * (1/resolution) * convertInch2Micr;
    sizeYmicrons = imgInfo.Height * (1/resolution) * convertInch2Micr;

    
    %% Draw image for Maribel's matching
    if ~exist([pathFolders(nFolder).folder '\markers.tiff'],'file')
        drawMarkersOverImage(img,T,convertInch2Micr,resolution,pathFolders,nFolder)
    end
    
    %% Read matched Markers & images from Maribel
    fileName = pathFolders(nFolder).folder;
    imgMovMarkers = imread([pathFolders(nFolder).folder '\markersMovedFinal_Hyp' fileName(end-2:end) '.tif']);
    redMarkers = imgMovMarkers(:,:,1)>0;
    [row1,col1] = find(redMarkers);
    coordMark1 = [row1,col1];
    blueMarkers = imgMovMarkers(:,:,3)>0;
    [row2,col2] = find(blueMarkers);
    coordMark2 = [row2,col2];
    
    
    
    %% Define ROI (and invalid ROI)
    if ~exist([pathFolders(nFolder).folder '\validROI.tiff'],'file')
        invalidROIs = namesROIs(cellfun(@(x) contains(lower(x),'invalid'),namesROIs));

        tablesInvalidROI = cell(length(invalidROIs),1);
        for nInvROIs = 1:length(invalidROIs)
           tablesInvalidROI{nInvROIs} = readtable([pathFolders(nFolder).folder '\' invalidROIs{nInvROIs}]);
        end

        ROIpolyCoord = [tableMajorROI.X,tableMajorROI.Y];
        ROIpolyCoordPixels = [[ROIpolyCoord(:,1);ROIpolyCoord(1,1)]*resolution,[ROIpolyCoord(:,2);ROIpolyCoord(1,2)]*resolution];

        maskROIpoly = false(size(rgb2gray(img)));
        [allX,allY]=find(maskROIpoly==0);
        inRoi = inpolygon(allY,allX,ROIpolyCoordPixels(:,1),ROIpolyCoordPixels(:,2));
        maskROIpoly(inRoi)=1;
        for nNoValidRois = 1 : length(tablesInvalidROI)
            tableAux = tablesInvalidROI{nNoValidRois};
            ROIpolyCoordAux = [tableAux.X,tableAux.Y];
            ROIpolyCoordPixelsAux = [[ROIpolyCoordAux(:,1);ROIpolyCoordAux(1,1)]*resolution,[ROIpolyCoordAux(:,2);ROIpolyCoordAux(1,2)]*resolution];
            inRoi = inpolygon(allY,allX,ROIpolyCoordPixelsAux(:,1),ROIpolyCoordPixelsAux(:,2));
            maskROIpoly(inRoi) = 0;
        end
        imwrite(maskROIpoly,[pathFolders(nFolder).folder '\validROI.tiff']) 
    else
        maskROIpoly = imread([pathFolders(nFolder).folder '\validROI.tiff']);
        maskROIpoly = imbinarize(rgb2gray(maskROIpoly));
    end
    
    

    
    %delete markers out from the valid mask
    idCoord1 = sub2ind(size(maskROIpoly),coordMark1(:,1),coordMark1(:,2));
    coordMark1(maskROIpoly(idCoord1)==0,:) = [];
    idCoord2 = sub2ind(size(maskROIpoly),coordMark2(:,1),coordMark2(:,2));
    coordMark2(maskROIpoly(idCoord2)==0,:) = [];
%     figure;imshow(maskROIpoly);hold on
%     plot(coordMark1(:,2),coordMark1(:,1),'.r')
%     plot(coordMark2(:,2),coordMark2(:,1),'.b')
    

    %% calculate geodesic distances in raw images
    path2save1 = [pathFolders(nFolder).folder,'\markerDistancesRaw.mat'];
    if  ~exist(path2save1,'file')
        [cellDistances1_1_raw,cellDistances1_2_raw,cellDistances2_1_raw,cellDistances2_2_raw] = measureGeodesicDistances(coordMark1,coordMark2,maskROIpoly,'shit');
        save(path2save1,'cellDistances1_1_raw','cellDistances1_2_raw','cellDistances2_1_raw','cellDistances2_2_raw')
    end
    
    %% make randomization for the marker 1 (integrin), with the marker 2 fixed
    clearvars -except pathFolders nFolder maskROIpoly coordMark1 coordMark2

    posibleInd = find(maskROIpoly(:)>0);
    totalRandom = 250;
    cellDistances1rand_1rand = cell(totalRandom,1);
    cellDistances1rand_2fixed = cell(totalRandom,1);
    cellDistances2fixed_1rand = cell(totalRandom,1);
    cellDistances2fixed_2fixed = cell(totalRandom,1);

    path2save2 = [pathFolders(nFolder).folder,'\markerDistancesRandom1Fixed2.mat'];
    
    if ~exist(path2save2,'file')
        for nRand = 1:totalRandom
            randPos = randperm(length(posibleInd));
            selectedId = posibleInd(randPos(1:size(coordMark1,1)));
            [randCoord1x, randCoord1y] = ind2sub(size(maskROIpoly),selectedId);
            randCoordMark1 = [randCoord1x,randCoord1y];
            
            [cellDistances1rand_1rand{nRand},cellDistances1rand_2fixed{nRand},cellDistances2fixed_1rand{nRand},cellDistances2fixed_2fixed{nRand},~,~] = measureGeodesicDistances(randCoordMark1,coordMark2,maskROIpoly,[],'no rand');
            if rem(nRand,20)==0
                save(path2save2,'cellDistances1rand_1rand','cellDistances1rand_2fixed','cellDistances2fixed_1rand','cellDistances2fixed_2fixed','-v7.3')
            end
        end    
%     end
    
        %% make randomization for the marker 2 (plaques), fixing the marker 1. In addition, compare random markers 1 and 2
        path2save3 = [pathFolders(nFolder).folder,'\markerDistancesFixed1Random2.mat'];
        path2save4 = [pathFolders(nFolder).folder,'\markerDistancesRandom1Random2.mat'];

        cellDistances1fixed_1fixed = cell(totalRandom, 1);
        cellDistances1fixed_2rand = cell(totalRandom, 1);
        cellDistances2rand_1fixed = cell(totalRandom, 1);
        cellDistances2rand_2rand = cell(totalRandom, 1);   
        cellDistances1rand_2rand = cell(totalRandom, 1);
        cellDistances2rand_1rand = cell(totalRandom, 1);

        if ~exist(path2save3,'file')
            for nRand = 1:totalRandom

                randPos = randperm(length(posibleInd));
                selectedId = posibleInd(randPos(1:size(coordMark2,1)));
                [randCoord2x, randCoord2y] = ind2sub(size(maskROIpoly),selectedId);
                randCoordMark2 = [randCoord2x,randCoord2y];

                randPos = randperm(length(posibleInd));
                selectedId = posibleInd(randPos(1:size(coordMark1,1)));
                [randCoord1x, randCoord1y] = ind2sub(size(maskROIpoly),selectedId);
                randCoordMark1 = [randCoord1x,randCoord1y];

                [cellDistances1fixed_1fixed{nRand},cellDistances1fixed_2rand{nRand},cellDistances2rand_1fixed{nRand},cellDistances2rand_2rand{nRand},cellDistances1rand_2rand{nRand},cellDistances2rand_1rand{nRand}] = measureGeodesicDistances(coordMark1,randCoordMark2,maskROIpoly,randCoordMark1,'2 randoms');
                if rem(nRand,20)==0
                    save(path2save3,'cellDistances1fixed_1fixed','cellDistances1fixed_2rand','cellDistances2rand_1fixed','cellDistances2rand_2rand','-v7.3')
                    save(path2save4,'cellDistances1rand_2rand','cellDistances2rand_1rand','-v7.3')
                end
            end  
        end

        clearvars -except pathFolders nFolder
    end
end