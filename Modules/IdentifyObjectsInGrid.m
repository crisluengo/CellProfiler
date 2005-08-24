function handles = IdentifyObjectsInGrid(handles)

% Help for the Identify Objects In Grid module:
% Category: Object Identification and Modification
%
% Sorry, this module has not yet been fully documented.
%
%
% See also n/a.

% CellProfiler is distributed under the GNU General Public License.
% See the accompanying file LICENSE for details.
%
% Developed by the Whitehead Institute for Biomedical Research.
% Copyright 2003,2004,2005.
%
% Authors:
%   Anne Carpenter <carpenter@wi.mit.edu>
%   Thouis Jones   <thouis@csail.mit.edu>
%   In Han Kang    <inthek@mit.edu>
%
% $Revision$



%%%%%%%%%%%%%%%%
%%% VARIABLES %%%
%%%%%%%%%%%%%%%%


%%% Reads the current module number, because this is needed to find
%%% the variable values that the user entered.
CurrentModule = handles.Current.CurrentModuleNumber;
CurrentModuleNum = str2double(CurrentModule);

%textVAR01 = What is the already defined grid?
%infotypeVAR01 = gridgroup
GridName = char(handles.Settings.VariableValues{CurrentModuleNum,1});
%inputtypeVAR01 = popupmenu

%textVAR02 = What would you like to call the newly identified objects?
%defaultVAR02 = Spots
%infotypeVAR02 = objectgroup indep
NewObjectName = char(handles.Settings.VariableValues{CurrentModuleNum,2});

%textVAR03 = Would you like the object to retain their natural shape, be circles with a particular diameter, or rectangles that fill the entire grid?
%choiceVAR03 = Natural Shape
%choiceVAR03 = Circle
%choiceVAR03 = Rectangle
Shape = char(handles.Settings.VariableValues{CurrentModuleNum,3});
%inputtypeVAR03 = popupmenu

%textVAR04 = If you are using natural shape or using a circle with an automatically calculated diameter, what did you call the objects that were already identified?
%infotypeVAR04 = objectgroup
OldObjectName = char(handles.Settings.VariableValues{CurrentModuleNum,4});
%inputtypeVAR04 = popupmenu

%textVAR05 = If you selected the object to be circles, what is the diameter of each object (in pixels)?
%defaultVAR05 = Automatic
Diameter = char(handles.Settings.VariableValues{CurrentModuleNum,5});

%textVAR06 = Would you like to save the image of the outlines of the objects? and if so, what would you like to call them?
%defaultVAR06 = Do Not Save
%infotypeVAR06 = imagegroup indep
OutlineName = char(handles.Settings.VariableValues{CurrentModuleNum,6});

%textVAR07 = Would you like to save the label matrix image?  and if so, what would you like to call it?
%defaultVAR07 = Do Not Save
%infotypeVAR07 = imagegroup indep
LabelMatrixImageName = char(handles.Settings.VariableValues{CurrentModuleNum,7});

%textVAR08 = If you are saving the label matrix image, would you like to save it is RGB or grayscale?
%choiceVAR08 = RGB
%choiceVAR08 = grayscale
RGBorGray = char(handles.Settings.VariableValues{CurrentModuleNum,8});
%inputtypeVAR08 = popupmenu

%%%VariableRevisionNumber = 1

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PRELIMINARY CALCULATIONS & FILE HANDLING %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow

Grid = handles.Pipeline.(['Grid_' GridName]);

TotalHeight = Grid.TotalHeight;
TotalWidth = Grid.TotalWidth;
Cols = Grid.Cols;
Rows = Grid.Rows;
YDiv = Grid.YDiv;
XDiv = Grid.XDiv;
Topmost = Grid.Topmost;
Leftmost = Grid.Leftmost;
SpotTable = Grid.SpotTable;
VertLinesX = Grid.VertLinesX;
VertLinesY = Grid.VertLinesY;
HorizLinesX = Grid.HorizLinesX;
HorizLinesY = Grid.HorizLinesY;


if strcmp(Shape,'Natural Shape') || strcmp(Shape,'Circle') && strcmp(Diameter,'Automatic')
    Image = handles.Pipeline.(['Segmented' OldObjectName]);
end

if strcmp(Diameter,'Automatic')
    tmp = regionprops(Image,'Area');
    Area = cat(1,tmp.Area);
   
    radius = floor(sqrt(median(Area)/pi));
else
    radius = floor(str2num(Diameter)/2); 
end

FinalLabelMatrixImage = zeros(TotalHeight,TotalWidth);

for i=1:Cols
    for j=1:Rows
        subregion = FinalLabelMatrixImage(max(1,Topmost - floor(YDiv/2) + (j-1)*YDiv+1):min(Topmost - floor(YDiv/2) + j*YDiv,end),max(1,Leftmost - floor(XDiv/2) + (i-1)*XDiv+1):min(Leftmost - floor(XDiv/2) + i*XDiv,end));
        if strcmp(Shape,'Natural Shape')
            subregion = Image(max(1,Topmost - floor(YDiv/2) + (j-1)*YDiv+1):min(Topmost - floor(YDiv/2) + j*YDiv,end),max(1,Leftmost - floor(XDiv/2) + (i-1)*XDiv+1):min(Leftmost - floor(XDiv/2) + i*XDiv,end));
            subregion=bwlabel(subregion>0);
            props = regionprops(subregion,'Centroid');
            loc = cat(1,props.Centroid);
            for k = [1:size(loc,1)]
                if loc(k,1) < size(subregion,2)*.1 || loc(k,1) > size(subregion,2)*.9 || loc(k,2) < size(subregion,1)*.1 || loc(k,2) > size(subregion,1)*.9
                    subregion(subregion == subregion(floor(loc(k,2)),floor(loc(k,1)))) = 0;
                end
            end
            if max(max(subregion))==0
                subregion(floor(end/2),floor(end/2)) = SpotTable(j,i);
            else
                subregion(subregion>0) = SpotTable(j,i);
            end
        elseif strcmp(Shape,'Circle') 
            subregion(floor(end/2)-radius:floor(end/2)+radius,floor(end/2)-radius:floor(end/2)+radius)=SpotTable(j,i)*getnhood(strel('disk',radius,0));
        elseif strcmp(Shape,'Rectangle')
            subregion(:,:) = SpotTable(j,i);
        else
            error('The value of Shape is not recognized');
        end
        FinalLabelMatrixImage(max(1,Topmost - floor(YDiv/2) + (j-1)*YDiv+1):min(Topmost - floor(YDiv/2) + j*YDiv,end),max(1,Leftmost - floor(XDiv/2) + (i-1)*XDiv+1):min(Leftmost - floor(XDiv/2) + i*XDiv,end))=subregion;
    end
end


    
%%% Indicate objects in original image and color excluded objects in red
OutlinedObjects1 = bwperim(mod(FinalLabelMatrixImage,2));
OutlinedObjects2 = bwperim(mod(floor(FinalLabelMatrixImage/Rows),2));
OutlinedObjects3 = bwperim(mod(floor(FinalLabelMatrixImage/Cols),2));
OutlinedObjects4 = bwperim(FinalLabelMatrixImage>0);
OutlinedObjects = OutlinedObjects1 + OutlinedObjects2 + OutlinedObjects3 + OutlinedObjects4;
OutlinedObjects = OutlinedObjects>0;

%%%%%%%%%%%%%%%%%%%%%%
%%% DISPLAY RESULTS %%%
%%%%%%%%%%%%%%%%%%%%%%


fieldname = ['FigureNumberForModule',CurrentModule];
ThisModuleFigureNumber = handles.Current.(fieldname);

if any(findobj == ThisModuleFigureNumber)
    
    drawnow
    CPfigure(handles,ThisModuleFigureNumber);

    subplot(2,1,1)
    %%% This method of calculating a colormap to use prevented some
    %%% errors relating to colormaps. For one thing, the label2rgb
    %%% function fails if there are no objects in the label matrix
    %%% image. Also, there is a bug for some of the colormaps that
    %%% fails when there are only 1 or 2 objects in the image, I
    %%% think.
    cmap = jet(max(64,max(FinalLabelMatrixImage(:))));
    im = label2rgb(FinalLabelMatrixImage, cmap, 'k', 'shuffle');
    ImageHandle = imagesc(im);
        
    line(VertLinesX,VertLinesY);
    line(HorizLinesX,HorizLinesY);

    title(sprintf('Segmented %s',NewObjectName),'fontsize',8);

    
    subplot(2,1,2); 
    imagesc(OutlinedObjects);
    colormap(gray);
        
    line(VertLinesX,VertLinesY);
    line(HorizLinesX,HorizLinesY);
    
    title('Outlined objects','fontsize',8);  
       
    set(findobj('type','line'), 'color',[.15 .15 .15]) 
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAVE DATA TO HANDLES STRUCTURE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

handles.Pipeline.(['Segmented' NewObjectName]) = FinalLabelMatrixImage;

if ~strcmp(LabelMatrixImageName,'Do Not Save')
    if strcmp(RGBorGray,'RGB')
        if sum(sum(FinalLabelMatrixImage)) >= 1
            ColoredLabelMatrixImage = label2rgb(FinalLabelMatrixImage, 'jet', 'k', 'shuffle');
        else
            ColoredLabelMatrixImage = FinalLabelMatrixImage;
        end
        handles.Pipeline.(LabelMatrixImageName) = ColoredLabelMatrixImage;
    else
        handles.Pipeline.(LabelMatrixImageName) = FinalLabelMatrixImage;
    end
end

if ~strcmp(OutlineName,'Do Not Save')
    handles.Pipeline.(OutlineName) = OutlinedObjects;
end