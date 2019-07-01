classdef MaRdI < matlab.mixin.SetGet 
%MaRdI Ma(t)-R-dI(com)
%
%   Dicom into Matlab for Siemens MRI data
%
% .......
%   
% Usage
%
%   Img = MaRdI( imgPath )
% 
%   where imgPath is the path to a single .dcm image OR a directory containing
%   the .dcm or .IMA images.
%
% Img contains fields
%
%   .img
%       Array of images: 
%       If multi-echo, the echo index is along the 4th dimension;
%       If multiple volume repetitions, the measurement index is along the 5th dimension.
%
%   .Hdr
%       DICOM header 
%       
%   .Aux
%       Aux-objects: auxiliary measurements (e.g. respiratory ProbeTracking)
%
% .......
%
% NOTE
%
%   A number of MaRdI methods are deprecated and need to be either adapted
%   (if they might still be useful) or deleted entirely.
%
% =========================================================================
% Author: ryan.topfer@polymtl.ca
% =========================================================================

%% ========================================================================
% *** TODO
% ..... 
% CROPIMG
%   make compatible for odd-sized arrays
% ..... 
% RESLICEIMG()
%   griddata takes too long (possible solution: write interp function in cpp?)
%   Clean up 
% ..... 
% Saving as DICOM
%   (maybe better just to avoid and delete this for now?)
%
%   -> (do not save image type as phase)
%   -> must save proper ImagePositionPatient info
% 
% ..... 
% Write static comparegrid() function or something to ensure operations involving
% multiple images are valid (e.g. voxel positions are the same) 
%
% ..... 
% GETDIRECTIONCOSINES()
%   Weird flip-conditional for slice direction? Is this OK??
%   Siemens private header apprently contains field SliceNormalVector.
%
% ..... 
% WRITE()
%   Neither 'as dcm' nor 'as nii' functionalities work properly.
% 
% ..... 
% EXTRACTHARMONICFIELD()
%  Clean up 
% 
% .....
% ASSOCIATEAUX()
%  link Image to corresponding Auxiliary data
%%

% =========================================================================
% =========================================================================
properties
    img ;
    Hdr ;
    Hdrs ;
    Aux ;
end

% =========================================================================
% =========================================================================    
methods
% =========================================================================    
function Img = MaRdI( imgPath )

Img.img = [] ;
Img.Hdr = [] ;
Img.Aux = [] ;

if nargin == 1 
    
    if ~exist( imgPath )
        error( 'DICOM images not found. Check input path is valid.' ) ;
        return;
    
    elseif ( exist( imgPath ) == 2 ) % input is a single file (e.g. DICOM) 
        
        [~, ~, ext] = fileparts( imgPath ) ;
        
        assert( strcmp( ext, '.dcm' ) || strcmp( ext, '.IMA' ), ...
            'Input must be a path string leading to a single dicom image OR to a dicom-containing folder' )

        Img.img = double( dicomread( imgPath ) ) ;
        Img.Hdr = MaRdI.dicominfosiemens( imgPath ) ;

        %  Add/replace a few Hdr entries:
        Img.Hdr.NumberOfSlices = uint16( 1 ) ; 
        
        if ~myisfield( Img.Hdr, 'SpacingBetweenSlices' ) 
            Img.Hdr.SpacingBetweenSlices = Img.Hdr.SliceThickness ;
        end
       
        Img.setslicenormalvector() ;
    
    elseif ( exist( imgPath  ) == 7 ) % input is a directory (e.g. containing DICOMs)
        
        imgDir = [ imgPath '/' ] ; 

        imgList = MaRdI.findimages( imgDir ) ;
        nImages = length( imgList ) ;

        if ~nImages
            return;
        end
        
        % Read protocol info from 1st loaded image (arbitrary):
        SpecialHdr = MaRdI.dicominfosiemens( imgList{1} ) ;

        nRows      = SpecialHdr.Height ;
        nColumns   = SpecialHdr.Width ;
        
        if ~myisfield( SpecialHdr.MrProt, 'lRepetitions' ) 
            nVolumes = 1 ;
        else
            nVolumes = SpecialHdr.MrProt.lRepetitions + 1 ;
        end
        
        % containers for a few terms varying between dicoms:
        sliceLocations = zeros( nImages, 1 ) ; % [units: mm]
        echoTimes      = zeros( nImages, 1 ) ; % [units: ms]

        % Image headers, not yet organized:
        RawHdrs        = cell( nImages, 1 ) ; 
        
        % Read all the image headers and structure the MaRdI object accordingly:
        %
        % NOTE: It may well be possible to determine all the necessary info from
        % the complete Siemens header (e.g. SpecialHdr) of a single image;
        % practically, however, the following is easier since the header
        % information is abstrusely defined for some sequences.
        for iImg = 1 : nImages
            % using dicominfo() here as parse-siemens-shadow() takes much longer
            RawHdrs{ iImg }      = dicominfo( imgList{iImg} ) ;

            sliceLocations(iImg) = RawHdrs{ iImg }.SliceLocation ;
            echoTimes(iImg)      = RawHdrs{ iImg }.EchoTime ;
        end

        sliceLocations = sort( unique( sliceLocations ), 1, 'ascend' ) ; 
        nSlices        = length( sliceLocations ) ;
        
        echoTimes      = sort( unique( echoTimes ), 1, 'ascend' ) ; 
        nEchoes        = length( echoTimes ) ; 
        
        Img.img = zeros( nRows, nColumns, nSlices, nEchoes, nVolumes ) ;
        
        % copy of RawHdrs to be reorganized:
        Img.Hdrs = cell( nSlices, nEchoes, nVolumes ) ;
        
        for iImg = 1 : nImages

            iHdr    = RawHdrs{ iImg } ;

            iVolume = iHdr.AcquisitionNumber ;
            iSlice  = find( iHdr.SliceLocation == sliceLocations ) ;
            iEcho   = find( iHdr.EchoTime == echoTimes ) ;

            Img.Hdrs{ iSlice, iEcho, iVolume } = iHdr ;

            Img.img( :, :, iSlice, iEcho, iVolume ) = dicomread( imgList{iImg} ) ;

        end
        
        % Save the complete 1st Hdr
        Img.Hdr = MaRdI.dicominfosiemens( Img.Hdrs{1}.Filename ) ;
            
        Img.rescaleimg() ;

        Img.Hdr.NumberOfSlices = size( Img.img, 3 ) ; 

        if ~myisfield( Img.Hdr, 'SpacingBetweenSlices' ) 
            Img.Hdr.SpacingBetweenSlices = Img.Hdr.SliceThickness ;
        end
        
        if ~isempty( strfind( Img.Hdr.ImageType, 'MOSAIC' ) ) 
            Img = reshapemosaic( Img ) ;
        end

        Img.setslicenormalvector() ;

    end
end

end
% =========================================================================
function ImgCopy = copy(Img)
%COPY 
% 
% Make a copy of a MaRdI (i.e. handle) object.
% 
% ImgCopy = Copy( Img ) ;

ImgCopy     = MaRdI() ;

ImgCopy.img  = Img.img;
ImgCopy.Hdr  = Img.Hdr ;
ImgCopy.Hdrs = Img.Hdrs ;

if ~isempty( Img.Aux ) && myisfield( Img.Aux, 'Tracker' ) 
    ImgCopy.Aux.Tracker = Img.Aux.Tracker.copy() ;
end

end
% =========================================================================
function [] = filter( Img, weights, Params )
%FILTER
%
% 3D low-pass (weighted or unweighted) or median filtering.
% Wraps to smooth3() or medfilt3() accordingly.
%
% [] = FILTER( Img )
% [] = FILTER( Img, weights )
% [] = FILTER( Img, weights, Params )
%
% Img 
%   the MaRdI-type image volume.
%
% weights
%   an array of data weights (>=0) to penalize (for smooth3) or exclude (for
%   medfilt3()) identifiable outliers.  Dimensions of weights must be the
%   same as the image volume (i.e. Img.getgridsize() )
%
% Params
%   an optional struct for which the following Params.fields are supported
%
%   .kernelSize
%       in number of voxels
%       default = [3 3 3] 
%
%   .method
%       'gaussian' OR 'box' OR 'median'
%       default = 'gaussian'
%
% 
% TODO
%   Add support for 2d (single slice) images 

DEFAULT_KERNELSIZE = [3 3 3] ;
DEFAULT_METHOD     = 'gaussian' ;

if nargin < 3 || isempty(Params)
    Params.dummy = [] ;
end

if ~myisfield( Params, 'kernelSize' ) || isempty( Params.kernelSize )
    Params.kernelSize = DEFAULT_KERNELSIZE ;
end

if ~myisfield( Params, 'method' ) || isempty( Params.method )
    Params.method = DEFAULT_METHOD ;
end

if nargin < 2 || isempty( weights )
    weights = ones( Img.getgridsize() ) ;
else
    assert( all( size(weights) == Img.getgridsize() ), ...
        'weights and image volume must possess the same dimensions, i.e. Img.getgridsize()' ) ;
end

switch Params.method

    case 'median'

        Img.img( ~weights ) = NaN ; % medfilt3() will ignore these values
        Img.img = medfilt3( Img.img, Params.kernelSize ) ; 
        Img.img( ~weights ) = 0 ;
    
    otherwise
        
        weightsSmoothed = smooth3( weights, Params.method, Params.kernelSize ) ;
        Img.img = smooth3( weights .* Img.img, Params.method, Params.kernelSize ) ./ weightsSmoothed ; 

end

end
% =========================================================================
function [t] = getacquisitiontime( Img ) 
% GETACQUISITIONTIME
% 
% t = GETACQUISITIONTIME( Img )
%
% Returns the value of AcquisitionTime from the Siemens DICOM header as a
% double in units of seconds. t is a vector if Img is a time series
% acquisition, in which case, t - t(1) yields the time elapsed since the first
% acquisition. 

nSlices = Img.Hdr.NumberOfSlices ;

if myisfield( Img.Hdr.MrProt, 'lRepetitions' ) 
    nVolumes = ( Img.Hdr.MrProt.lRepetitions + 1) ;
else
    nVolumes = 1;
end

assert( ( nSlices == size( Img.img, 3 ) ) & ( nVolumes == size( Img.img, 5 ) ), 'Invalid .Hdr' ) ;

t = zeros( nSlices, nVolumes ) ;

for iSlice = 1 : nSlices
    for iVolume = 1 : nVolumes
        t_iAcq = Img.Hdrs{iSlice,1,iVolume}.AcquisitionTime ;
        t(iSlice, iVolume) = str2double( t_iAcq(1:2) )*60*60 + str2double( t_iAcq(3:4) )*60 + str2double( t_iAcq(5:end) ) ;
    end
end

end
% =========================================================================
function [echoTime] = echotime( Img, iEcho ) 
%ECHOTIME
% 
% TE = ECHOTIME( Img )
% TE = ECHOTIME( Img, iEcho )
%
% Returns vector of echo times in units of ms.
% If 2nd argument (echo index iEcho) is provided, ECHOTIME returns the TE of
% the corresponding echo.

if nargin == 1
    if strcmp( Img.Hdr.SequenceName, '*fm2d2' ) && ~isempty( strfind( Img.Hdr.ImageType, '\P\' ) )
        echoTime = ( Img.Hdr.MrProt.alTE(2) - Img.Hdr.MrProt.alTE(1) )/1000  ;
    else
        nEchoes  = size( Img.img, 4 ) ;
        echoTime = Img.Hdr.MrProt.alTE(1:nEchoes)/1000 ;
    end
else
    echoTime = Img.Hdr.MrProt.alTE(iEcho)/1000 ;
end 

end
% =========================================================================
function fieldOfView = getfieldofview( Img )
%GETFIELDOFVIEW
% 
% fov = getfieldofview( Img ) ;
%
% Returns field of view in units of mm : [Row Column Slice] dimensions
fieldOfView = [ Img.Hdr.PixelSpacing(1) * double( Img.Hdr.Rows ), ...
                Img.Hdr.PixelSpacing(2) * double( Img.Hdr.Columns ), ...
                Img.Hdr.SpacingBetweenSlices * double( Img.Hdr.NumberOfSlices ) ] ;
end
% =========================================================================
function gridSize = getgridsize( Img )
%GETGRIDSIZE
gridSize = double( [ Img.Hdr.Rows, Img.Hdr.Columns, Img.Hdr.NumberOfSlices ] ) ;
end
% =========================================================================
function GYRO = getgyromagneticratio( Img )
%GETGYROMAGNETICRATIO
%
% Gyro = getgyromagneticratio( Img )
%
% Examines .Hdr of MaRdI-type Img for .ImagedNucleus and returns gyromagnetic
% ratio in units of rad/s/T.

switch Img.Hdr.ImagedNucleus 
    case '1H' 
        GYRO = 267.513E6 ; 
    otherwise
        error('Not implemented.') ;
end

end
% =========================================================================
function nVoxels = getnumberofvoxels( Img )
%GETNUMBEROFVOXELS
nVoxels = prod( Img.getgridsize( ) ) ;
end
% =========================================================================
function [f0, g0, s0] = adjvalidateshim( Img )
%ADJVALIDATESHIM
% 
% [f0, g0, s0] = ADJVALIDATESHIM( Img )
% 
% ADJVALIDATESHIM is not a particularly revealing name for a function; however,
% it is based on the Siemens AdjValidate commandline tool, with a "-shim" input
% argument.
%
% f0 = scalar Larmor (Tx) freq. [ units : Hz ]
% g0 = 3-element vector of the linear gradient offsets (gX, gY, gZ) [units : DAC bits]
% s0 = 5-element vector of 2nd order shim currents [units : mA] 
%
% To convert to the units of the 3D Shim card on the Siemens (Prisma) console,
% see ShimOpt_IUGM_Prisma_fit.converttomultipole( )

% Larmor (Tx) freq.
f0 = Img.Hdr.MrProt.sTXSPEC.asNucleusInfo.lFrequency ; 

% linear gradients
g0 = [ Img.Hdr.MrProt.sGRADSPEC.asGPAData.lOffsetX ; ...
       Img.Hdr.MrProt.sGRADSPEC.asGPAData.lOffsetY ; ...
       Img.Hdr.MrProt.sGRADSPEC.asGPAData.lOffsetZ ] ;

% -------
% 2nd order shims (5-element vector)
s0 = Img.Hdr.MrProt.sGRADSPEC.alShimCurrent ;

end
% =========================================================================
function [X,Y,Z] = getvoxelpositions( Img )
% GETVOXELPOSITIONS
% 
% [X,Y,Z] = GETVOXELPOSITIONS( Img ) 
%
%   Returns three 3D arrays of doubles, each element containing the
%   location [units: mm] of the corresponding voxel with respect to 
%   DICOM's 'Reference Coordinate System'.

% from DICOM standard: https://www.dabsoft.ch/dicom/3/C.7.6.2.1.1/
%
% If Anatomical Orientation Type (0010,2210) is absent or has a value of
% BIPED, the x-axis is increasing to the left hand side of the patient. The
% y-axis is increasing to the posterior side of the patient. The z-axis is
% increasing toward the head of the patient.
%
% Arrays containing row, column, and slice indices of each voxel
assert( ~myisfield( Img.Hdr, 'AnatomicalOrientationType' ) || ...
        strcmp( Img.Hdr.AnatomicalOrientationType, 'BIPED' ), ...
        'Error: AnatomicalOrientationType not supported.' ) ;
        
[iRows,iColumns,iSlices] = ndgrid( [0:1:Img.Hdr.Rows-1], ...
                  [0:1:Img.Hdr.Columns-1], ...
                  [0:1:(Img.Hdr.NumberOfSlices-1)] ) ; 

iRows    = double(iRows);
iColumns = double(iColumns);
iSlices  = double(iSlices);

%-------
% Rotation matrix: R
[r, c, s] = Img.getdirectioncosines ;
R = [r c s] ; 
                  
%-------
% Scaling matrix: S  
voxelSize = Img.getvoxelspacing() ;
S = diag(voxelSize); 

RS = R*S ;

%-------
% Scale and rotate to align row direction with x-axis, 
% column direction with y-axis, slice with z-axis
X1 = RS(1,1)*iRows + RS(1,2)*iColumns + RS(1,3)*iSlices;
Y1 = RS(2,1)*iRows + RS(2,2)*iColumns + RS(2,3)*iSlices;
Z1 = RS(3,1)*iRows + RS(3,2)*iColumns + RS(3,3)*iSlices;

%-------
% TRANSLATE w.r.t. origin (i.e. location of 1st element: .img(1,1,1))
X = Img.Hdr.ImagePositionPatient(1) + X1 ; 
Y = Img.Hdr.ImagePositionPatient(2) + Y1 ; 
Z = Img.Hdr.ImagePositionPatient(3) + Z1 ; 

end
% =========================================================================
function h = getvoxelspacing( Img )
%GETVOXELSPACING
% 
% h = GETVOXELSPACING( Img )
%       
% Returns 3-component grid-spacing vector [units: mm]:
%
%   h(1) : row spacing (between centers of adjacent rows, i.e. vertical spacing). 
%
%   h(2) : column spacing (between the centers of adjacent columns,
%   i.e. horizontal spacing).    
%
%   h(3) : slice spacing (between the centers of adjacent slices, i.e.
%   from the DICOM hdr, this is Hdr.SpacingBetweenSlices - for a 2D acquisition
%   this not necessarily the same as Hdr.SliceThickness).    

h = [ Img.Hdr.PixelSpacing(1) Img.Hdr.PixelSpacing(2) Img.Hdr.SpacingBetweenSlices ] ;

end
% =========================================================================
function xyzIso = isocenter( Img )
%ISOCENTER
% 
% xyzIso = ISOCENTER( Img ) 
%
% Returns the 3-element vector of the x, y and z coordinates of the magnet
% isocenter in the patient coordinate system

xyzIso = Img.Hdr.Img.ImaRelTablePosition()' ;

assert( xyzIso(1) == 0, 'Table shifted in L/R direction?' ) ;
assert( xyzIso(2) == 0, 'Table shifted in A/P direction?' ) ;

end
% =========================================================================
function [F] = resliceimg( Img, X_1, Y_1, Z_1, varargin ) 
%RESLICEIMG
% 
%   Interpolate Img using 'scatteredInterpolant' class; updates Img.Hdr accordingly.
%
%   [F] = RESLICEIMG( Img, X, Y, Z )
%   [F] = RESLICEIMG( Img, X, Y, Z, interpolationMethod ) 
%   [F] = RESLICEIMG( Img, X, Y, Z, F ) 
%   
%   X, Y, Z MUST refer to X, Y, Z patient coordinates (i.e. of the DICOM
%   reference coordinate system)
%   
%   Optional interpolationMethod is a string supported by the scatteredInterpolant constructor.
%   F is the object of type 'scatteredInterpolant' used for interpolation.

DEFAULT_INTERPOLATIONMETHOD  = 'linear' ;
DEFAULT_ISFORMINGINTERPOLANT = true ;

if nargin < 5

    interpolationMethod  = DEFAULT_INTERPOLATIONMETHOD ;
    isFormingInterpolant = DEFAULT_ISFORMINGINTERPOLANT ;

elseif nargin == 5

    if ischar( varargin{1} )

        interpolationMethod = varargin{1} ;

    elseif isa( varargin{1}, 'scatteredInterpolant' ) ;

        F = varargin{1} ;

        isFormingInterpolant = false ; 
    
    else
        error( 'Unknown input.' ) ;
    end

end

nImgStacks = size(Img.img, 4) ;

[X_0, Y_0, Z_0] = Img.getvoxelpositions( ) ;

if length( size(X_1) ) == 2 
    % interpolating volume down to a single slice:
    gridSizeInterpolated = [ size(X_1) 1 nImgStacks ] ;
elseif length( size(X_1) ) == 3
    gridSizeInterpolated = [ size(X_1) nImgStacks ] ;
end

imgInterpolated  = zeros( gridSizeInterpolated ) ;

img0 = Img.img( :,:,:, 1 ) ;

tic

if isFormingInterpolant 
    disp( ['Forming interpolant (may take ~1 min)...']) ;
    F    = scatteredInterpolant( [X_0(:) Y_0(:) Z_0(:)], img0(:), interpolationMethod, 'none'  ) ;
end

img1 = F( [X_1(:) Y_1(:) Z_1(:)] ) ;

if length( size(X_1) ) == 2
    imgInterpolated(:,:,1, 1 ) = reshape( img1, [ size(X_1) 1] ) ;
elseif length( size(X_1) ) == 3
    imgInterpolated(:,:,:, 1 ) = reshape( img1, size(X_1) ) ;
end


for iImgStack = 2 : nImgStacks     
    disp( ['Reslicing image stack...' num2str(iImgStack) ' of ' num2str(nImgStacks) ]) ;
    
    % replace samples with those of the next img stack 
    img0     = Img.img(:,:,:, iImgStack ) ;

    F.Values = img0(:) ;
   
    img1  = F( [X_1(:) Y_1(:) Z_1(:)] ) ;
    
    if length( size(X_1) ) == 2
        imgInterpolated(:,:,1, iImgStack ) = reshape( img1, [ size(X_1) 1] ) ;
    elseif length( size(X_1) ) == 3
        imgInterpolated(:,:,:, iImgStack ) = reshape( img1, size(X_1) ) ;
    end

end

toc

Img.img = imgInterpolated ; 
% if new positions are outside the range of the original, 
% interp3/griddata replaces array entries with NaN
Img.img( isnan( Img.img ) ) = 0 ; 

% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Update header
Img.Hdr.ImageType = 'DERIVED\SECONDARY\REFORMATTED' ;


Img.Hdr.ImagePositionPatient( 1 ) = X_1(1) ; 
Img.Hdr.ImagePositionPatient( 2 ) = Y_1(1) ;
Img.Hdr.ImagePositionPatient( 3 ) = Z_1(1) ;

%-------
% Rows 
Img.Hdr.Rows = size(Img.img, 1) ;

dx = X_1(2,1,1) - X_1(1,1,1) ;
dy = Y_1(2,1,1) - Y_1(1,1,1) ;
dz = Z_1(2,1,1) - Z_1(1,1,1) ;  

% vertical (row) spacing
Img.Hdr.PixelSpacing(1) = ( dx^2 + dy^2 + dz^2 )^0.5 ; 

% column direction cosine (expressing angle btw column direction and X,Y,Z axes)
Img.Hdr.ImageOrientationPatient(4) = dx/Img.Hdr.PixelSpacing(1) ;
Img.Hdr.ImageOrientationPatient(5) = dy/Img.Hdr.PixelSpacing(1) ;
Img.Hdr.ImageOrientationPatient(6) = dz/Img.Hdr.PixelSpacing(1) ;

%-------
% Columns 
Img.Hdr.Columns = size(Img.img, 2) ;       

dx = X_1(1,2,1) - X_1(1,1,1) ;
dy = Y_1(1,2,1) - Y_1(1,1,1) ;
dz = Z_1(1,2,1) - Z_1(1,1,1) ;  

% horizontal (column) spacing
Img.Hdr.PixelSpacing(2) = ( dx^2 + dy^2 + dz^2 )^0.5 ;

% row direction cosine (expressing angle btw column direction and X,Y,Z axes)
Img.Hdr.ImageOrientationPatient(1) = dx/Img.Hdr.PixelSpacing(2) ;
Img.Hdr.ImageOrientationPatient(2) = dy/Img.Hdr.PixelSpacing(2) ;
Img.Hdr.ImageOrientationPatient(3) = dz/Img.Hdr.PixelSpacing(2) ;

%-------
% Slices
Img.Hdr.NumberOfSlices       = size(Img.img, 3) ;

if Img.Hdr.NumberOfSlices > 1
    Img.Hdr.SpacingBetweenSlices = ( (X_1(1,1,2) - X_1(1,1,1))^2 + ...
                                     (Y_1(1,1,2) - Y_1(1,1,1))^2 + ...
                                     (Z_1(1,1,2) - Z_1(1,1,1))^2 ) ^(0.5) ;
else
    Img.Hdr.SpacingBetweenSlices = 0 ;
end

[rHat, cHat, sHat] = Img.getdirectioncosines( ) ;  

Img.Hdr.SliceLocation = dot( Img.Hdr.ImagePositionPatient, sHat ) ;

end
% =========================================================================
function [mask, weights] = segmentspinalcanal( Img, Params )
%SEGMENTSPINALCANAL
% 
% segment T2* multiecho data using the Spinal Cord Toolbox (must be installed + in path)
%
% [ mask, weights ] = SEGMENTSPINALCANAL( Img, Params )
%
% Params
%
%   .dataLoadDir 
%       DICOM folder
%   
%   .dataSaveDir 
%
%   .isUsingPropsegCsf
%       [default = false]
%
% NOTE
%   The protocol is basically that of Topfer R, et al. Magn Reson Med, 2018. 
%   It hasn't been tested extensively for different acquisition prtocols/systems

mask = false ;

if nargin < 2 || isempty(Params)
    disp('Default parameters will be used')
    Params.dummy = [] ;
end

if  ~myisfield( Params, 'dataLoadDir' ) || isempty(Params.dataLoadDir)
    [Params.dataLoadDir,~,~] = fileparts( Img.Hdr.Filename ) ;
end

[mask, weights] = MaRdI.segmentspinalcanal_s( Params ) ;

end
% =========================================================================
function timeAverage = timeaverage( Img )
%TIMEAVERAGE
% 
% Img = TIMEAVERAGE( Img) 
% 
% Assumes 5th dimension of Img.img corresponds to time:
%   
%   timeAverage = mean( Img.img, 5 ) ;

timeAverage = mean( Img.img, 5 ) ;

end
% =========================================================================
function timeStd = timestd( Img )
%TIMESTD
% 
% standardDeviation = TIMESTD( Img ) 
% 
% Assumes 5th dimension of Img.img corresponds to time:
%   
%   standardDeviation = std( Img.img, 0, 5 ) ;

timeStd = std( Img.img, 0, 5 ) ;

end
% =========================================================================
function Phase = unwrapphase( Phase, Mag, Options )
%UNWRAPPHASE
%
% Interface to SUNWRAP, to FSL prelude, or to Abdul-Rahman's path-based phase unwrapper
%
%   Phase = UNWRAPPHASE( Phase )
%   Phase = UNWRAPPHASE( Phase, Mag )
%   Phase = UNWRAPPHASE( Phase, Mag, Options )
%   
%   Phase and Mag are objects of type MaRdI.
%
%    .......................
%    To call SUNWRAP [default if nargin ==2 ]
%    
%    Options.unwrapper = 'Sunwrap'
%
%       See HELP SUNWRAP for more details.
% 
%       Maier F, et al. Robust Phase Unwrapping for MR Temperature Imaging
%       Using a Magnitude-Sorted List, Multi-Clustering Algorithm. Magn Reson
%       Med, 73:1662-1668,2015.
%
%    .......................
%    To call FSL Prelude   
% 
%    Options.unwrapper = 'FslPrelude'
%
%       See HELP PRELUDE for description of Options 
%   
%    .......................
%    To call the Abdul-Rahman unwrapper [default if ( nargin == 1) && size(Phase.img,3) > 1] 
% 
%    Options.unwrapper = 'AbdulRahman_2007'
%
%       Phase is an object of type MaRdI and must have defined Phase.Hdr.MaskingImage
%       See HELP UNWRAP3D for description of Options 
%
%       Abdul-Rahman H, et al. Fast and robust three-dimensional best path
%       phase unwrapping algorithm. Applied Optics, Vol. 46, No. 26, pp.
%       6623-6635, 2007.
%
%    .......................

assert( strcmp( Phase.Hdr.PixelComponentPhysicalUnits, '0000H' ), 'SCALEPHASE2RAD() before unwrapping.' ) ;

DEFAULT_UNWRAPPER = 'Sunwrap' ;
DEFAULT_THRESHOLD = 0.0 ;

Options.dummy     = [];

if nargin < 2 
    if ( size( Phase.img, 3 ) > 1 )
        Options.unwrapper = 'AbdulRahman_2007' ;    

        assert( myisfield( Phase.Hdr, 'MaskingImage') && ~isempty(Phase.Hdr.MaskingImage), ...
            'No Magnitude data provided: Options.unwrapper = AbdulRahman_2007. Logical masking array must be defined in Phase.Hdr.MaskingImage ' ) ;
    else
        error('See help MaRdI.unwrapphase()') ;
    end
end

if nargin == 2 || ~myisfield( Options, 'unwrapper') || isempty(Options.unwrapper)
    Options.unwrapper = DEFAULT_UNWRAPPER ;
end

if ~myisfield( Options, 'threshold') || isempty(Options.threshold)
    Options.threshold = DEFAULT_THRESHOLD ;
end


if myisfield( Phase.Hdr.MrProt, 'lRepetitions' ) 
    nVolumes = (Phase.Hdr.MrProt.lRepetitions + 1) ;
else
    nVolumes = 1;
end

assert( nVolumes == size( Phase.img, 5 ) ) ;

for iVolume = 1 : nVolumes

    display(['Unwrapping volume ' num2str(iVolume) ' of ' num2str(nVolumes) ] ) ;    

    switch Options.unwrapper

        case 'AbdulRahman_2007'
            
            Phase.img(:,:,:,1, iVolume) = unwrap3d( Phase.img(:,:,:,1, iVolume), logical(Phase.Hdr.MaskingImage(:,:,:,1, iVolume)), Options ) ;

        case 'FslPrelude'

            if myisfield( Phase.Hdr, 'MaskingImage') && ~isempty(Phase.Hdr.MaskingImage)
                Options.mask = single( Phase.Hdr.MaskingImage(:,:,:,1,iVolume) ) ;
            end
            
            Options.voxelSize = Phase.getvoxelspacing() ;   

            Phase.img(:,:,:,1, iVolume) = prelude( Phase.img(:,:,:,1, iVolume), Mag.img(:,:,:,1, iVolume), Options ) ;

        case {'Sunwrap', 'sunwrap'}
            
            iMag      = Mag.img(:,:,:,1,iVolume) ;
            iMag      = iMag./max(iMag(:)) ;
            Phase.img(:,:,:,1, iVolume) = sunwrap( iMag .* exp( 1i* Phase.img(:,:,:,1,iVolume) ), Options.threshold ) ;

        otherwise
            error('Unrecognized "Options.unwrapper" input') ;
    end

end

Phase.img = double( Phase.img ) ;

% update header
Img.Hdr.ImageType         = 'DERIVED\SECONDARY' ; 
Img.Hdr.SeriesDescription = ['phase_unwrapped_' Options.unwrapper ] ; 

end
% =========================================================================
function [] = write( Img, saveDirectory, imgFormat )
%WRITE Ma(t)-R-dI(com)
% 
% Write MaRdI image object to DICOM and/or NifTI
%
%.....
%
%   Usage 
%
%   WRITE( Img )
%   WRITE( Img, saveDirectory )
%   WRITE( Img, saveDirectory, imgFormat ) 
%
%   Inputs
%
%   default saveDirectory = './tmp'
%   
%   imgFormat can be:
%       'dcm' [default]
%       'nii' (creating temporary DICOMs which are deleted after the system call to dcm2niix)
%       'both' (does not delete the DICOMs)
%
%.....
%
% Adapted from dicom_write_volume.m (D.Kroon, University of Twente, 2009)
% https://www.mathworks.com/matlabcentral/fileexchange/27941-dicom-toolbox?focused=5189263&tab=function

DEFAULT_SAVEDIRECTORY = './tmp' ;
DEFAULT_IMGFORMAT     = 'dcm' ;

if nargin < 2 || isempty(saveDirectory)
    saveDirectory = DEFAULT_SAVEDIRECTORY ;
end

if nargin < 3 || isempty(imgFormat)
    imgFormat = DEFAULT_IMGFORMAT ;
end

fprintf(['\n Writing images to: ' saveDirectory ' ... \n'])

[~,~,~] = mkdir( saveDirectory ) ;

Img = rescaleimg( Img, true ) ;

[X,Y,Z] = Img.getvoxelpositions() ;

%-------
% write Hdr

% Make random series number
SN                          = round(rand(1)*1000);
% Get date of today
today                       = [datestr(now,'yyyy') datestr(now,'mm') datestr(now,'dd')];
Hdr.SeriesNumber            = SN;
Hdr.AcquisitionNumber       = SN;
Hdr.StudyDate               = today;
Hdr.StudyID                 = num2str(SN);
Hdr.PatientID               = num2str(SN);
Hdr.AccessionNumber         = num2str(SN);

% copy from original
Hdr.ImageType               = Img.Hdr.ImageType ; 

Hdr.StudyDescription        = Img.Hdr.StudyDescription ;
Hdr.SeriesDescription       = Img.Hdr.SeriesDescription ;
Hdr.Manufacturer            = Img.Hdr.Manufacturer ;
Hdr.ScanningSequence        = Img.Hdr.ScanningSequence ;
Hdr.SequenceVariant         = Img.Hdr.SequenceVariant ;
Hdr.ScanOptions             = Img.Hdr.ScanOptions ;
Hdr.MRAcquisitionType       = Img.Hdr.MRAcquisitionType ;
Hdr.SliceThickness          = Img.Hdr.SliceThickness ;
Hdr.SpacingBetweenSlices    = Img.Hdr.SpacingBetweenSlices ;
Hdr.PatientPosition         = Img.Hdr.PatientPosition ;
Hdr.PixelSpacing            = Img.Hdr.PixelSpacing ;

Hdr.ImageOrientationPatient = Img.Hdr.ImageOrientationPatient ;
Hdr.SliceLocation           = Img.Hdr.SliceLocation ; 
Hdr.NumberOfSlices          = Img.Hdr.NumberOfSlices ; 

Hdr.AcquisitionMatrix       = Img.Hdr.AcquisitionMatrix ; 
Hdr.RepetitionTime          = Img.Hdr.RepetitionTime ; 
Hdr.NumberOfAverages        = Img.Hdr.NumberOfAverages ; 
Hdr.PercentSampling         = Img.Hdr.PercentSampling ; 
Hdr.PercentPhaseFieldOfView = Img.Hdr.PercentPhaseFieldOfView ; 
Hdr.InPlanePhaseEncodingDirection  = Img.Hdr.InPlanePhaseEncodingDirection ; 

[rHat, cHat, sHat] = Img.getdirectioncosines( ) ;  

nSlices       = Img.Hdr.NumberOfSlices ;
nEchoes       = numel( Img.echotime ) ;
nAcquisitions = numel( Img.getacquisitiontime ) ;

nImg = nSlices*nEchoes*nAcquisitions ;

for iSlice = 1 : nSlices 
    for iEcho  = 1 : nEchoes 
        for iAcq = 1 : nAcquisitions  

            iImg = iSlice*iEcho*iAcq ;

            disp( [num2str(100*iImg/nImg) '% ...'] ) ;
    
            %-------
            % filename 
            sliceSuffix = '000000' ;
            sliceSuffix = [ sliceSuffix( length(iSlice) : end ) num2str(iSlice) '-' num2str(iEcho) '-' num2str(iAcq) ] ;
            sliceSuffix = ['-' sliceSuffix '.dcm'] ;
            filename    = [saveDirectory '/' Img.Hdr.PatientName.FamilyName sliceSuffix] ;

            %-------
            % image specific hdr info 
            Hdr.ImageNumber          = iSlice*iEcho*iAcq ;
            Hdr.InstanceNumber       = iSlice*iEcho*iAcq ;
            Hdr.AcquisitionTime      = Img.Hdrs{iSlice,iEcho,iAcq}.AcquisitionTime ;
            
            Hdr.ImagePositionPatient = [(X(1,1,iSlice)) (Y(1,1,iSlice)) (Z(1,1,iSlice))] ;

            Hdr.SliceLocation        = dot( Hdr.ImagePositionPatient, sHat ) ;
           
            dicomwrite( Img.img(:,:,iSlice,iEcho, iAcq) , filename, 'ObjectType', 'MR Image Storage', Hdr ) ;
            
            if( iSlice==1 )
                info                  = dicominfo( filename ) ;
                Hdr.StudyInstanceUID  = info.StudyInstanceUID ;
                Hdr.SeriesInstanceUID = info.SeriesInstanceUID ;
            end

        end
    end
end

%-------
if ~strcmp( imgFormat, 'dcm' )
    system(['dcm2niix ' saveDirectory]) ;
    
    if strcmp( imgFormat, 'nii' )
        delete( [saveDirectory '/*.dcm'] ) ;
    end
end

end
% =========================================================================

end
% =========================================================================
% =========================================================================
methods(Access=protected)
% =========================================================================
function [] = scalephasetofrequency( Img, undoFlag )
%SCALEPHASETOFREQUENCY
%
% Converts unwrapped phase [units:rad] to field [units: Hz]
% 
%   Field = scalephasetofrequency( UnwrappedPhase )
%   Phase = scalephasetofrequency( Field, -1 )
%   
%   The 'undo' mode with -1 as the 2nd argument scales from Hz back to rad
% .....
%
% UnwrappedPhase.Hdr.EchoTime              [units: ms]

scalingFactor = 1/( 2*pi*Img.Hdr.EchoTime*(1E-3)  ) ;

if (nargin < 2) || (undoFlag ~= -1)
    assert( strcmp( Img.Hdr.PixelComponentPhysicalUnits, '0000H' ) )

    Img.img       = scalingFactor * Img.img ;
    Img.Hdr.PixelComponentPhysicalUnits = '0005H' ; % i.e. Hz

elseif (undoFlag == -1)
    assert( strcmp( Img.Hdr.PixelComponentPhysicalUnits, '0005H' ) )

    Img.img       = (scalingFactor^-1 )* Img.img ;
    Img.Hdr.PixelComponentPhysicalUnits = '0000H' ; % i.e. none
end

end
% =========================================================================

end
% =========================================================================
% =========================================================================
methods(Access=private)
% =========================================================================
function [r,c,s] = getdirectioncosines( Img ) 
% GETDIRECTIONALCOSINES
% 
%   "The direction cosines of a vector are the cosines of the angles between
%   the vector and the three coordinate axes. Equivalently, they are the
%   contributions of each component of the basis to a unit vector in that
%   direction." 
%   https://en.wikipedia.org/wiki/Direction_cosine
%
% [r,c,s] = GETDIRECTIONALCOSINES( Img ) 
%   r: row *index* direction cosine
%   c: column index " "
%   s: slice index " "
%
%   NB: the *index* term. r & c may be defined obstrusely:
%   i.e. r is not the row direction cosine (c is!), it is the direction cosine
%   of the vector that points along the direction of increasing row indices
%   (i.e. it's in the column direction!)
      
% " To make a full rotation matrix, we can generate the last column from
% the cross product of the first two. However, Siemens defines, in its
% private CSA header, a SliceNormalVector which gives the third column, but
% possibly with a z flip, so that R is orthogonal, but not a rotation
% matrix (it has a determinant of < 0)."
%  -From http://nipy.org/nibabel/dicom/dicom_mosaic.html 
%
% NOTE: Hdr.Img.SliceNormalVector gets defined in the MaRdI constructor

c = Img.Hdr.ImageOrientationPatient(1:3) ; 
r = Img.Hdr.ImageOrientationPatient(4:6) ; 
s = Img.Hdr.Img.SliceNormalVector ;

end 
% =========================================================================
function Img = rescaleimg( Img, isUndoing )
%RESCALEIMG
%
% []=RESCALEIMG( Img ) 
% []=RESCALEIMG( Img, isUndoing ) 
%
% Currently only alters phase images (+ Hdr) by rescaling to radians. Mag. is unaffected.

if isempty( strfind( Img.Hdr.ImageType, '\P\' ) )
    % not a phase image
    return;
end

DEFAULT_ISUNDOING        = false ;
DEFAULT_RESCALEINTERCEPT = -(2^12) ;
DEFAULT_RESCALESLOPE     = 2 ;

if (nargin < 2) || isempty( isUndoing ) 
   isUndoing = DEFAULT_ISUNDOING ; 
end 

if ~isUndoing
    
    if  ~myisfield( Img.Hdr, 'RescaleIntercept' ) || isempty( Img.Hdr.RescaleIntercept )
        Img.Hdr.RescaleIntercept = DEFAULT_RESCALEINTERCEPT ;
    end

    if ~myisfield( Img.Hdr, 'RescaleSlope' ) || isempty( Img.Hdr.RescaleSlope )
        Img.Hdr.RescaleSlope = DEFAULT_RESCALESLOPE ;
    end

    % rescale to rad:
    Img.img = pi*(Img.Hdr.RescaleSlope .* double( Img.img ) ...
                + Img.Hdr.RescaleIntercept)/double(2^Img.Hdr.BitsStored) ;

    % update Hdr:
    Img.Hdr.ImageType  = 'ORIGINAL\SECONDARY\P\' ; 
    Img.Hdr.PixelRepresentation = uint8(1) ; % i.e. signed 
    Img.Hdr.PixelComponentPhysicalUnits = '0000H' ; % i.e. none

else
    
    Img.Hdr.RescaleIntercept = min( Img.img(:) ) ;
    Img.img                  = Img.img - Img.Hdr.RescaleIntercept ;
    Img.Hdr.RescaleSlope     = max( Img.img(:) )/double( 2^Img.Hdr.BitsStored ) ;
    Img.img                  = uint16( Img.img / Img.Hdr.RescaleSlope ) ;

end

end
% =========================================================================
function Img = reshapemosaic( Img )
%RESHAPEMOSAIC
% 
% Reshape Siemens mosaic into volume and remove padded zeros
%
% Adapted from dicm2nii by
% xiangrui.li@gmail.com 
% http://www.mathworks.com/matlabcentral/fileexchange/42997

assert( ~isempty(strfind( Img.Hdr.ImageType, 'MOSAIC' ) ), 'Corrupt image header?' ) ;       

Img.Hdr.NumberOfSlices = Img.Hdr.Private_0019_100a ;

nImgPerLine = ceil( sqrt( double(Img.Hdr.NumberOfSlices) ) ); % always nImgPerLine x nImgPerLine tiles

nRows    = size(Img.img, 1) / nImgPerLine; 
nColumns = size(Img.img, 2) / nImgPerLine; 
nEchoes  = size(Img.img, 4) ;  
nVolumes = size(Img.img, 5) ;

img = zeros([nRows nColumns Img.Hdr.NumberOfSlices nEchoes nVolumes], class(Img.img));

for iImg = 1 : double(Img.Hdr.NumberOfSlices)

    % 2nd slice is tile(1,2)
    r = floor((iImg-1)/nImgPerLine) * nRows + (1:nRows);     
    c = mod(iImg-1, nImgPerLine) * nColumns + (1:nColumns);

    img(:, :, iImg, :) = Img.img(r, c, :);
end

Img.img = img ;


% -----
% Update header

% -----
% Correct Hdr.ImagePositionPatient 
%   see: http://nipy.org/nibabel/dicom/dicom_mosaic.html

%-------
% Rotation matrix: R
[r, c, s] = Img.getdirectioncosines ;
R = [r c s] ; 
                  
%-------
% Scaling matrix: S  
voxelSize = Img.getvoxelspacing() ;
S = diag(voxelSize); 

RS = R*S ;

Img.Hdr.ImagePositionPatient = Img.Hdr.ImagePositionPatient + ...
    RS(:,1)*(double(Img.Hdr.Rows) - nRows)/2 + ...
    RS(:,2)*(double(Img.Hdr.Columns) - nColumns)/2 ;


Img.Hdr.Rows    = uint16(nRows) ;
Img.Hdr.Columns = uint16(nColumns) ;

tmp = strfind( Img.Hdr.ImageType, '\MOSAIC' ) ;

if ~isempty(tmp) && (tmp > 1)
    Img.Hdr.ImageType = Img.Hdr.ImageType(1:tmp-1) ;
else
    Img.Hdr.ImageType = '' ;    
end

end
% =========================================================================
function [] = setslicenormalvector( Img )
%SETSLICENORMALVECTOR
%
% For determining voxel positions in 3d slice-stack
    
r = Img.Hdr.ImageOrientationPatient(4:6) ; 
c = Img.Hdr.ImageOrientationPatient(1:3) ; 
    
Img.Hdr.Img.SliceNormalVector = cross( c, r ) ;  

if size( Img.img, 3 ) > 1
% Determine: ascending or descending slices?

    % Estimate positions of last slice based on the 1st image:
    % 1. using
    [X1,Y1,Z1] = Img.getvoxelpositions() ;     

    % 2. using the reverse
    Img.Hdr.Img.SliceNormalVector = cross( r, c ) ;  
    [X2,Y2,Z2] = Img.getvoxelpositions() ; % estimate positions based on the 1st loaded image in the directory. 

    % Actual position corresponding to the slice direction can be increasing or
    % decreasing with slice/image number. So, which estimate is closer: 1 or 2? 
    if norm( Img.Hdrs{end,1,1}.ImagePositionPatient' - [ X1(1,1,end) Y1(1,1,end) Z1(1,1,end) ] ) < ...
            norm( Img.Hdrs{end,1,1}.ImagePositionPatient' - [ X2(1,1,end) Y2(1,1,end) Z2(1,1,end) ] ) 
        % if true, then 1. corresponds to the correct orientation
        Img.Hdr.Img.SliceNormalVector = cross( c, r ) ;
    end
end

end
% =========================================================================

end
% =========================================================================
% =========================================================================
methods(Hidden=true)
% =========================================================================
% NOTE
%   Temporarily placing cropimg(), nii(), and zeropad() here since these methods
%   1) might be deprecated
%   2) may or may not be useful to a typical user
% =========================================================================
function Img = cropimg( Img, gridSizeImgCropped, centralPoint )
%CROPIMG
%
% Img = CROPIMG( Img, croppedDims )
% Img = CROPIMG( Img, croppedDims, centralPoint )
% 
% centralPoint are the indices of the original img voxel to become the centralPoint of 
% the cropped array.
%
% default  (nargin == 2)
%   centralPoint = round( size(Img.img)/2 );
% 
% note: 
% if centralPoint +/- croppedDims/2 exceeds the original bounds, the array is cropped at the bound (as opposed to zero filling)
% -------
    
gridSizeImgOriginal = size(Img.img) ;

if (nargin == 2) || isempty(centralPoint)
    centralPoint = round( gridSizeImgOriginal/2 ) ;
end

low  = centralPoint - round(gridSizeImgCropped/2) + [1 1 1] ;
high = low + gridSizeImgCropped - [1 1 1] ;  

for dim = 1: 3
   if low(dim) < 1
      low(dim) = 1 ;
   end
   if high(dim) > gridSizeImgOriginal(dim)
      high(dim) = gridSizeImgOriginal(dim) ;
  end
end
    
% Update header
[X, Y, Z] = Img.getvoxelpositions( ); 
x0        = X(low(1),low(2),low(3)) ;
y0        = Y(low(1),low(2),low(3)) ;
z0        = Z(low(1),low(2),low(3)) ;

Img.Hdr.ImagePositionPatient = [x0 y0 z0] ;

[rHat, cHat, sHat] = Img.getdirectioncosines( ) ;  

Img.Hdr.SliceLocation = dot( Img.Hdr.ImagePositionPatient, sHat ) ;

% crop img
Img.img = Img.img( low(1):high(1), low(2):high(2), low(3):high(3) ) ; 

if myisfield( Img.Hdr, 'MaskingImage' )  && ~isempty( Img.Hdr.MaskingImage ) 
    
   Img.Hdr.MaskingImage = Img.Hdr.MaskingImage( low(1):high(1), low(2):high(2), low(3):high(3) ) ; 

end

% Update header
Img.Hdr.Rows                 = size(Img.img, 1) ;
Img.Hdr.Columns              = size(Img.img, 2) ;       
Img.Hdr.NumberOfSlices       = size(Img.img, 3) ;

end
% =========================================================================
function [] = nii( Img )
%NII - Write MaRdI image to NiFtI file
%
% Wraps to NII( ) (which wraps to the NiFtI toolbox)   
%
%.....
%   Syntax
%
%   nii( Img ) 
%.....
%
% WARNING
%
%   nii() function is convenient for quickly writing a file to throw
%   into an external viewing application (e.g. ImageJ). 
%   The nifti Hdr info (i.e. orientation) is probably all wrong. 
%
%   To save NifTI's properly (takes longer) use Img.write() 

workingDir       = [ pwd '/' ] ;
Params.filename  = [ workingDir Img.Hdr.PatientName.FamilyName '_' num2str( Img.Hdr.SeriesNumber ) '_' Img.Hdr.SeriesDescription  ] ;
Params.voxelSize = Img.getvoxelspacing() ;

nii( squeeze(Img.img), Params )  ;

end
% =========================================================================
function Img = zeropad( Img, padSize, padDirection )
%ZEROPAD
% Img = ZEROPAD( Img, padSize, padDirection )
%
% padSize = [ nZerosRows nZerosColumns nZerosSlices ] 
%
% padDirection == 'post' || 'pre' || 'both'
%
% -------
%   See also PADARRAY()
    
gridSizeOriginalImg = size(Img.img) ;

Img.img = padarray( Img.img, padSize, 0, padDirection ) ; 

if myisfield( Img.Hdr, 'MaskingImage' )  && ~isempty( Img.Hdr.MaskingImage ) 
    
   Img.Hdr.MaskingImage = padarray( Img.Hdr.MaskingImage, padSize, 0, padDirection ) ; 

end

% Update header
Img.Hdr.Rows                 = size(Img.img, 1) ;
Img.Hdr.Columns              = size(Img.img, 2) ;       
Img.Hdr.NumberOfSlices       = size(Img.img, 3) ;

if ~strcmp( padDirection, 'post' )
% update image position 
% (i.e. location in DICOM RCS of 1st voxel in data array (.img))
    
    voxelSize = Img.getvoxelspacing() ;

    dr = voxelSize(1) ; % spacing btwn rows 
    dc = voxelSize(2) ; % spacing btwn columns
    ds = voxelSize(3) ;
    
    nr = padSize(1) ;
    nc = padSize(2) ;
    ns = padSize(3) ;
    
    [r, c, s] = Img.getdirectioncosines( ) ;

    % -1 because the zeros are padded before ('pre') 1st element (origin)        
    dx = -1*( r(1)*dr*nr + c(1)*dc*nc + s(1)*ds*ns ) ; 
    dy = -1*( r(2)*dr*nr + c(2)*dc*nc + s(2)*ds*ns ) ;
    dz = -1*( r(3)*dr*nr + c(3)*dc*nc + s(3)*ds*ns ) ;

    x1 = Img.Hdr.ImagePositionPatient(1) + dx ;
    y1 = Img.Hdr.ImagePositionPatient(2) + dy ;
    z1 = Img.Hdr.ImagePositionPatient(3) + dz ;

    Img.Hdr.ImagePositionPatient = [x1 y1 z1] ;

    Img.Hdr.SliceLocation = dot( Img.Hdr.ImagePositionPatient, s ) ;
end

end
% =========================================================================

end
% =========================================================================
% =========================================================================
methods(Static)
% =========================================================================
function list = findimages( imgDir )
%FINDIMAGES
% 
% list = FINDIMAGES( imageDirectory ) 
%
% Calls dir() to return list of .dcm OR .IMA files in imageDirectory and its echo_* subdirectories

imgDir       = [ imgDir '/' ] ;

ListSubdirs  = dir( [ imgDir 'echo*'] );
nEchoSubdirs = length( ListSubdirs ) ;

if nEchoSubdirs > 0 
    
    List = finddcmorima( [imgDir ListSubdirs(1).name] ) ;
    nImgPerEcho = length(List) ;

    list = cell( nImgPerEcho*nEchoSubdirs, 1 ) ;

    for iImg = 1 : nImgPerEcho 
        list{iImg} = [ imgDir ListSubdirs(1).name '/' List(iImg).name ] ;
    end

    for iEcho = 2 : nEchoSubdirs
        ListiSubdir = finddcmorima( [imgDir ListSubdirs(iEcho).name] ) ;
        assert( length(ListiSubdir) == nImgPerEcho, 'Each echo subdirectory should contain the same number of images' ) ; 

        for iImg = 1 : nImgPerEcho
            list{ (iEcho-1)*nImgPerEcho + iImg} = [ imgDir ListSubdirs(iEcho).name '/' ListiSubdir(iImg).name ] ;
        end
    end

else
    List = finddcmorima( imgDir ) ;
    nImg = length(List) ;
    list = cell( nImg, 1 ) ;

    for iImg = 1 : nImg
        list{iImg} = [ imgDir List(iImg).name ] ;
    end
end


function List = finddcmorima( imgDir ) 
%Find .dcm OR .IMA files in imgDir
List   = dir( [ imgDir '/*.dcm'] );

if length(List) == 0 % try .IMA
    List = dir( [imgDir '/*.IMA'] ) ;
end

nImages = length( List ) ; 
assert( nImages ~= 0, 'No .dcm or .IMA files found in given directory' ) ;

end

end
% =========================================================================
function fullDir = getfulldir( dataLoadDir, iDir )
%GETFULLDIR
% 
% fullDir = GETFULLDIR( parentDir, index ) 
%
%   Searches parentDir[ectory] for subdirectory beginning with index- (e.g.
%   .../dataLoadDir/[index]-* ) to return its full path.
%
%   (Useful for rapidly initializing MaRdI with a dicom folder.)

if nargin < 2
    error('Function requires 2 input arguments: parent directory and index.')
end

if isnumeric(iDir)
    iDir = num2str( iDir ) ;
end

if length( iDir ) == 1
    iDir = ['0' iDir] ;
end

if ~strcmp( dataLoadDir(end), '/' )
    dataLoadDir(end+1) = '/' ;
end

Tmp = dir( [ dataLoadDir iDir '-*'] ) ;
fldrName = Tmp.name ;

[fullDir,~,~] = fileparts( [dataLoadDir fldrName '/'] ) ;

fullDir(end+1) = '/' ;

end
% =========================================================================
function [mask, weights] = segmentspinalcanal_s( Params )
%SEGMENTSPINALCANAL_S
% 
% segment T2* multiecho data using the Spinal Cord Toolbox
%
% [ mask, weights ] = SEGMENTSPINALCANAL_S( Params )
%
% Params
%
%   .dataLoadDir 
%       DICOM folder
%   
%   .dataSaveDir
%       [default = './gre_seg/'] 
%
%   .isUsingPropsegCsf
%       [default = false]
%
% NOTE
%   The protocol is basically that of Topfer R, et al. Magn Reson Med, 2018. 
%   It hasn't been tested extensively for different acquisition protocols or systems 
%
% TODO
% SEGMENTSPINALCANAL_S
%   is the static form of MaRdI.segmentspinalcanal( Img, Params )
%
%   I (RT) was hoping Matlab would allow the 2 identically named methods (as in C)
%   given that the static form takes only 1 arg, and the other form requires 2...
%
%   --> either rectify this if pos. or change the method names or another alt.

%   .isForcingOverwrite
%       if .nii or .gz files exist already in dataSaveDir they will be deleted
%       [default = false]
%

mask = false ;

DEFAULT_DATALOADDIR        = [] ; % path to dicom folder
DEFAULT_DATASAVEDIR        = './gre_seg/'
DEFAULT_ISFORCINGOVERWRITE = false ;
DEFAULT_ISUSINGPROPSEGCSF  = true ; %use the propseg -CSF option

DEFAULT_CYLINDERSIZE       = 40 ;
DEFAULT_GAUSSIANSIZE       = 20 ;

if nargin < 1 || isempty(Params) || ~myisfield( Params, 'dataLoadDir' ) || isempty(Params.dataLoadDir)
    error('Function requires struct Params. with Params.dataLoadDir defined. See documentation.')
end

if  ~myisfield( Params, 'dataSaveDir' ) || isempty(Params.dataSaveDir)
    Params.dataSaveDir = DEFAULT_DATASAVEDIR ;
elseif ( Params.dataSaveDir(end) ~= '/' )
    Params.dataSaveDir(end+1) = '/';
end

if  ~myisfield( Params, 'isForcingOverwrite' ) || isempty(Params.isForcingOverwrite)
    Params.isForcingOverwrite = DEFAULT_ISFORCINGOVERWRITE ;
end

if  ~myisfield( Params, 'cylinderSize' ) || isempty(Params.cylinderSize)
    Params.cylinderSize = DEFAULT_CYLINDERSIZE ;
end

if  ~myisfield( Params, 'gaussianSize' ) || isempty(Params.gaussianSize)
    Params.gaussianSize = DEFAULT_GAUSSIANSIZE ;
end

Params.tmpSaveDir = [ Params.dataSaveDir 'tmp_sct_' datestr(now, 30) '/'] ;
mkdir( Params.tmpSaveDir )

% if ~Params.isForcingOverwrite & exist( Params.dataSaveDir )
%     error('Params.dataSaveDir should not exist, or use input option Params.isForcingOverwrite == true')
% end

if  ~myisfield( Params, 'isUsingPropsegCsf' ) || isempty(Params.isUsingPropsegCsf)
    Params.isUsingPropsegCsf = DEFAULT_ISUSINGPROPSEGCSF ;
end

if ~exist( Params.dataSaveDir )
    mkdir( Params.dataSaveDir ) ;
end

dicm2nii( Params.dataLoadDir, Params.tmpSaveDir )

% rename
system( ['mv ' Params.tmpSaveDir '*.nii.gz ' Params.tmpSaveDir 't2s_allEchoes.nii.gz'] ) ;

% average across echoes
system( ['sct_maths -i ' Params.tmpSaveDir 't2s_allEchoes.nii.gz -mean t -o ' Params.tmpSaveDir 't2s.nii.gz'] ) ;

% get centerline 
system( ['sct_get_centerline -i ' Params.tmpSaveDir 't2s.nii.gz -c t2 -o ' Params.tmpSaveDir 't2s_centerline'] ) ;

system( ['sct_create_mask -i ' Params.tmpSaveDir 't2s.nii.gz -p centerline,' ...
    Params.tmpSaveDir 't2s_centerline.nii.gz -size ' ...
    num2str(Params.cylinderSize) 'mm -f cylinder -o ' ...
    Params.tmpSaveDir 't2s_seg.nii.gz' ] ) ;

system( ['sct_create_mask -i ' Params.tmpSaveDir 't2s.nii.gz -p centerline,' ...
    Params.tmpSaveDir 't2s_centerline.nii.gz -size ' ...
    num2str(Params.gaussianSize) 'mm -f gaussian -o ' ...
    Params.tmpSaveDir 't2s_weights.nii.gz' ] ) ;

% unzip the image volumes we wish to keep
system( ['gunzip ' Params.tmpSaveDir 't2s_seg.nii.gz -df'] ) ;
system( ['gunzip ' Params.tmpSaveDir 't2s_weights.nii.gz -df'] ) ;

% delete the other images
system( ['rm ' Params.tmpSaveDir '*.nii.gz'] ) ;

% move segmentation + weights
system( ['mv ' Params.tmpSaveDir 't2s_seg.nii ' Params.dataSaveDir 'gre_seg.nii'] ) ;  
system( ['mv ' Params.tmpSaveDir 't2s_weights.nii ' Params.dataSaveDir 'gre_weights.nii'] ) ;  
system( ['rm -r ' Params.tmpSaveDir] ) ;

Mask = load_untouch_nii( [ Params.dataSaveDir 'gre_seg.nii' ] );
mask = Mask.img ;
mask = logical(permute( mask, [2 1 3] )) ;
mask = flipdim( mask, 1 ) ;

Weights = load_untouch_nii( [ Params.dataSaveDir 'gre_weights.nii' ] );
weights = Weights.img ;
weights = double(permute( weights, [2 1 3] )) ;
weights = flipdim( weights, 1 ) ;
% normalize
weights = weights - min(weights(:)) ;
weights = weights/max(weights(:)) ;

end
% =========================================================================
function [ Hdr ] = dicominfosiemens( filename )
%DICOMINFOSIEMENS
%
% Hdr = DICOMINFOSIEMENS
%
% Wraps to Matlab's DICOMINFO to return the standard DICOM Hdr, but also
% add fields returned by PARSE_SIEMENS_SHADOW.
%
% (Also replaces original Hdr. fields with more precise values should they
% be available in Hdr.MrProt., e.g. In the case of Siemens socket-delivered
% images, some fields are missing, & others are simply of reduced precision, 
% e.g. Hdr.ImagingFrequency is rounded to kHz)
%
% See also DICOMINFO, PARSE_SIEMENS_SHADOW

Hdr = dicominfo( filename ) ;

% parses additional info (e.g. "MrProt" (re: protocol))
[ Hdr.Img, Hdr.Ser, Hdr.MrProt ] = parse_siemens_shadow( Hdr ) ;
fprintf('\n') ;

% parse_mrprot produces many, many warning messages (at least for DICOMs from the Prisma).
% This should suppress all but the 1st instance:
[ lastMsg, lastWarnId ] = lastwarn( ) ;
warning( 'off', lastWarnId ) ;

% for some reason (?) Img.Hdr.MrProt.sTXSPEC.asNucleusInfo.lFrequency appears
% to have multiple elements, only the first is non-empty and it contains the
% Larmor freq., but, explicitly/manually trying to access it produces an error.
% +for some reason (?) the error is avoided by first copying the value to the
% temporary variable (f0), hence:
f0 = Hdr.MrProt.sTXSPEC.asNucleusInfo.lFrequency  ;
Hdr.ImagingFrequency = f0 * 1E-6 ; % [units : MHz]

% absolute table position (.Hdr field doesn't exist for the socket-delivered .dcm images)
if ~myisfield( Hdr.Img, 'Private_0019_1013' ) && ~isempty( Hdr.Img.ImaAbsTablePosition )
    Img.Hdr.Private_0019_1013 = Hdr.Img.ImaAbsTablePosition ; % [units : mm?]
end

end
% =========================================================================
function [] = sortimages( unsortedDicomDir, sortedDicomDir, isCopying )
%SORTIMAGES 
%
% Arrange unsorted DICOMs (e.g. as delivered via Siemens socket) into organized 
% subdirectories.
% 
% [] = SORTDATA( unsortedDicomDir ) 
% [] = SORTDATA( unsortedDicomDir, sortedDicomDir ) 
% [] = SORTDATA( unsortedDicomDir, sortedDicomDir, isCopying ) 
% 
% If sortedDicomDir is unspecified, a subdirectory ('sorted') is created
% within unsortedDicomDir to contain the sorted images.
%
% isCopying (Boolean) is TRUE by default. Set to 0 to move the files instead
% of copying. Note that the files will still be renamed.

DEFAULT_SORTEDDICOMDIR = [ unsortedDicomDir '/sorted/' ] ;
DEFAULT_ISCOPYING      = true ;

%Dicom files inside the directory -----------------------------------------
listOfImages = dir( [ unsortedDicomDir '/*.dcm'] );

if length(listOfImages) == 0
    % try .IMA
    listOfImages = dir( [imgDirectory '/*.IMA'] ) ;
end

nImages = length( listOfImages ) ;

assert( nImages~=0, 'No .dcm or .IMA files found in given directory' ) ;

if nargin < 2 || isempty( sortedDicomDir )
    sortedDicomDir = DEFAULT_SORTEDDICOMDIR ;
end

if ~exist( sortedDicomDir, 'dir') 
    mkdir( sortedDicomDir ); 
end

if nargin < 3 || isempty( isCopying )
    isCopying = DEFAULT_ISCOPYING ;
end

%Read Dicom files header and extract series names and numbers -------------
for iImage = 1 : nImages

    display( ['Sorting... ' num2str(100*iImage/nImages) ' %)' ])
    
    Hdr       = dicominfo( [unsortedDicomDir '/' listOfImages(iImage).name] );
    Hdr.Img   = parse_siemens_shadow( Hdr ) ;
    seriesDir = [ num2str(Hdr.SeriesNumber) '_' Hdr.SeriesDescription '/' ];

    if ( Hdr.SeriesNumber < 10)
        seriesDir = [ '0' seriesDir ] ;
    end
    
    % Create directories for each series
    if ~exist( [ sortedDicomDir seriesDir ], 'dir' )
        mkdir( [ sortedDicomDir seriesDir ] );
    end
    
    echoDir = [ sortedDicomDir seriesDir 'echo_' num2str( Hdr.EchoTime, 3 ) ] ;
         
    if ~exist( echoDir, 'dir' )
        mkdir( echoDir ) ;
    end
    
    iSlice   = Hdr.Img.ProtocolSliceNumber + 1 ;
    sliceStr = num2str( iSlice ) ;

    acqStr   = num2str( Hdr.AcquisitionNumber ) ;

    for ord = 3 : -1 : 1
        if iSlice < 10^ord
            sliceStr = [ '0' sliceStr ] ;
             acqStr  = [ '0' acqStr ] ;
        end
    end

    [~, ~, ext]    = fileparts( Hdr.Filename ) ;
    sortedFilename = fullfile( echoDir, strcat( Hdr.PatientName.FamilyName, '-', ...
                Hdr.Img.ImaCoilString, '-', sliceStr, '-', acqStr, ext ) ) ;
    
    if isCopying
        copyfile( Hdr.Filename, sortedFilename{1} ) ;
    else
        movefile( Hdr.Filename, sortedFilename{1} ) ;
    end

end
    
end
% =========================================================================
function [ studyDirs ] = tablestudy( sortedDicomDir )
%TABLESTUDY 
%
% Returns a cell array ( studyDirs ) pertaining to the study directory input
% ( sortedDicomDir ) where each element in the second column is a MaRdI-loadable 
% images series. (The 1st column is merely the row index.)
%
% e.g. Protocol to load MaRdI-object :
%
%   % omit semi-colon to display the full cell array (i.e. with the row indices)
%   [ studyDirs ] = MaRdI.tablestudy( sortedDicomDir ) 
%
%   % determine the row index of the series you want to load (e.g. 10):
%   Img = MaRdI( studyDirs{ 10, 2 } ) ;

assert( nargin == 1, 'Function requires sortedDicomDirectory as input argument.' ) ;

if ~strcmp( sortedDicomDir(end), '/' ) 
    sortedDicomDir(end+1) = '/' ;
end

studyDirs = cell( 0 ) ;

Tmp      = dir( [ sortedDicomDir ] );
Tmp      = Tmp( 3:end ) ; % ignore self ('.') and parent ('..') dirs
nEntries = length( Tmp ) ;

for iEntry = 1 : nEntries 

   if Tmp( iEntry ).isdir
   
       tmpSeriesSubdir = [ Tmp( iEntry ).name '/'] ;
    
        TmpEchoSubdirs = dir( [ sortedDicomDir tmpSeriesSubdir 'echo*' ] ) ;
        nEchoSubdirs   = length( TmpEchoSubdirs ) ;

        if nEchoSubdirs ~= 0

            for iEchoSubdir = 1 : nEchoSubdirs

                studyDirs{end+1, 2} = strcat( sortedDicomDir, tmpSeriesSubdir, TmpEchoSubdirs(iEchoSubdir).name )  ;
                iSeries = size( studyDirs, 1 ) ;
                studyDirs{ iSeries, 1 } = iSeries ;
            end

        % check if tmpSeriesSubdir itself contains images
        elseif length( dir( [ sortedDicomDir tmpSeriesSubdir '/*.dcm'] ) ) ~= 0 || ...
                length( dir( [ sortedDicomDir tmpSeriesSubdir '/*.IMA'] ) ) ~= 0 

           studyDirs{end+1, 2} = strcat( sortedDicomDir,tmpSeriesSubdir )  ;
            iSeries = size( studyDirs, 1 ) ;
            studyDirs{ iSeries, 1 } = iSeries ;

        end

   end
   
end

end
% =========================================================================
function [Params] = savefigure( img, Params )
%SAVEFIGURE
%
%   Description
%   
%   Write .png image to file using the 'export_fig' tool
%
%    .......................
%
%   Syntax
%
%   Parameters = SAVEFIGURE( img, Parameters )
%   
%   Returns employed Parameters struct.
%
%    .......................
%   
%   The following Parameter.fields are supported
%
%   .filename
%       default = './tmp'
%
%   .colormap
%       default = 'gray'
%
%   .scaling
%       default = [min(img) max(img)]
%
%   .magnification
%       default = 1
%
%   .isColorbar
%       default = false
%
%   .isBackgroundTransparent
%       default = false

DEFAULT_FILENAME      = './tmp.bin' ;
DEFAULT_COLORMAP      = 'gray' ;
DEFAULT_MAGNIFICATION = 1 ;
DEFAULT_ISCOLORBAR    = false ;
DEFAULT_ISBACKGROUNDTRANSPARENT = false ;
% =========================================================================
% Check inputs
% =========================================================================
if nargin < 1 || isempty(img)
    disp('Error: function requires at least 1 argument (2D image-matrix)')
    help(mfilename);
    return;  
end

if nargin < 2 || isempty(Params)
    disp('Default parameters will be used')
    Params.dummy = [] ;
end

if  ~myisfield( Params, 'filename' ) || isempty(Params.filename)
    Params.filename = DEFAULT_FILENAME ;
end

if  ~myisfield( Params, 'colormap' ) || isempty(Params.colormap)
    Params.colormap = DEFAULT_COLORMAP ;
end

if  ~myisfield( Params, 'magnification' ) || isempty(Params.magnification)
    Params.magnification = DEFAULT_MAGNIFICATION ;
end

if  ~myisfield( Params, 'isColorbar' ) || isempty(Params.isColorbar)
    Params.isColorbar = DEFAULT_ISCOLORBAR ;
end

if  ~myisfield( Params, 'isBackgroundTransparent' ) || isempty(Params.isBackgroundTransparent)
    Params.isBackgroundTransparent = DEFAULT_ISBACKGROUNDTRANSPARENT ;
end

if  ~myisfield( Params, 'scaling' ) || isempty(Params.scaling)
    Params.scaling = [min(img(:)) max(img(:))] ;
    if ( Params.scaling(2) == Params.scaling(1) )
        Params.scaling(2) = Inf ;
    end
end

[~,~,extension] = fileparts( Params.filename ) ;

if ~strcmp( extension, '.png' )
    Params.filename = [Params.filename '.png' ] ;
end

% =========================================================================
% Create figure
% =========================================================================

figure('units','normalized','outerposition',[0 0 1 1])

imagesc( img, Params.scaling ) ; 
colormap(Params.colormap); 
axis image ;

if Params.isColorbar
    colorbar;
    hcb=colorbar;
    set(hcb,'YTick',[])
end

set(gca,'XTick',[]) % Remove the ticks in the x axis
set(gca,'YTick',[]) % Remove the ticks in the y axis
set(gca,'Position',[0 0 1 1]) % Make the axes occupy the hole figure

if Params.isBackgroundTransparent
    export_fig(Params.filename, '-png', '-transparent', ['-m' num2str(Params.magnification)]) 
else
    export_fig(Params.filename, '-png', ['-m' num2str(Params.magnification)]) 
end

% close gcf

% crop out border voxels ?
img = imread( Params.filename, 'png' ) ;
imwrite( img( 5:end-3, 5:end-3, : ), Params.filename, 'png' ) ;

end
% =========================================================================

   
end
% =========================================================================
% =========================================================================


end
