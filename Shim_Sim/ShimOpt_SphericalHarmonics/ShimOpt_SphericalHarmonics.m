classdef ShimOpt_SphericalHarmonics < ShimOpt
%SHIMOPTSHARMONICS - Shim optimization using spherical harmonic basis
% 
% ShimOpt_SphericalHarmonics is a ShimOpt subclass. See ShimOpt documentation
% for general usage.
%
% .......
% 
% Usage
%
%       Shim = ShimOpt_SphericalHarmonics( Field )
%       Shim = ShimOpt_SphericalHarmonics( Field, Params )
% 
%   As for other ShimOpt objects, Field is a MaRdI-type object representing the
%   Field to be shimmed. The only difference is the (optional) input struct
%   Params, for which 2 (mutually exclusive) fields are configurable:
%   
%   Params.ordersToGenerate : default = [1:2]
%       
%       If set, this generates arbitary/ideal spherical harmonics.
%
%       .ordersToGenerate is a linear sequence of non-negative integers
%       specifying the orders of spherical harmonics to be generated and placed
%       along the 4th dimension of the array Shim.img 
%
%       e.g. default of [1:2], Shim.img will have 8 shim terms (three
%       1st-order, five 2nd-order harmonics) with values defined at the
%       voxel positions of the input Field object. 
%
%       For more info, See doc
%       ShimOpt_SphericalHarmonics.generatebasisfields 
%
%
%   Params.systemName : default = []
%
%       If set to 'IUGM_Prisma_fit' or 'HGM_Prisma', the returned Shim object 
%       possesses analogous terms to the respective Prisma scanner, with identical 
%       ordering along the 4th dimension of Shim.img, i.e. increments along this
%       dimension correspond to X, Y, Z, Z2, ZX, ZY, X2-Y2, and XY terms
%       respectively. The difference between the resulting ShimOpt_SphericalHarmonics
%       object and the corresponding ShimOpt_x_PrismaX object is that the shim
%       terms of the former are *ideally* generated as opposed to empirically
%       mapped.
%
% .......
%
% NOTE
%   The essential method GENERATEBASISFIELDS() is based on
%   calc_spherical_harmonics_arb_points_cz.m by jaystock@nmr.mgh.harvard.edu
%     
% =========================================================================
% Author::ryan.topfer@polymtl.ca
% =========================================================================

properties  
end

% =========================================================================
% =========================================================================    
methods
% =========================================================================
function Shim = ShimOpt_SphericalHarmonics( varargin )
%SHIMOPTSHARMONICS - Shim Optimization with spherical harmonic basis set

Shim.img   = [] ;
Shim.Hdr   = [] ;
Shim.Field = [] ;       
Shim.Model = [] ;
Shim.Aux   = [] ;

[ Field, Params ] = ShimOpt.parseinput( varargin ) ;

Params = ShimOpt_SphericalHarmonics.assigndefaultparameters( Params ) ;

if myisfieldfilled( Params, 'systemName' )
    switch Params.systemName
        case 'IUGM_Prisma_fit'
            Shim.System.Specs = ShimSpecs_IUGM_Prisma_fit() ;
        case 'HGM_Prisma'
            Shim.System.Specs = ShimSpecs_HGM_Prisma() ;
        otherwise
            error('Unimplemented system: Params.systemName must either be "IUGM_Prisma_fit" or "HGM_Prisma"') ;
    end
else  
    % Define ShimSpecs for the virtual shim system:
    Specs.systemName           = [ 'SphericalHarmonics_' ...
        num2str(min(Params.ordersToGenerate)) '-' num2str(max(Params.ordersToGenerate)) ] ;

    Specs.nChannels            = 0 ;
    for iOrder = 1 : length( Params.ordersToGenerate )
        Specs.nChannels = Specs.nChannels + 2*Params.ordersToGenerate(iOrder) + 1 ;
    end
    Specs.nActiveChannels      = Specs.nChannels ;

    Specs.maxCurrentPerChannel = Inf*ones( Specs.nChannels, 1 ) ;
    Specs.staticChannels       = true( Specs.nChannels, 1 ) ;
    Specs.dynamicChannels      = true( Specs.nChannels, 1 ) ;

    Specs.channelNames = cell( Specs.nChannels, 1 ) ;
    Specs.channelUnits = cell( Specs.nChannels, 1 ) ;

    for iCh = 1 : Specs.nChannels
        Specs.channelNames(iCh) = { [ 'SH_' num2str(iCh) ]} ;
        Specs.channelNames(iCh) = { [ '[AU]' ]} ;
    end

    Shim.System.Specs = ShimSpecs_Sim( Specs ) ;
end

%% -----
if ~isempty( Field ) 
    Shim.setoriginalfield( Field, Params.ordersToGenerate ) ;
end

end
% =========================================================================
function [] = setoriginalfield( Shim, Field, ordersToGenerate )
%SETORIGINALFIELD 
%
% [] = SETORIGINALFIELD( Shim, Field, ordersToGenerate )
%
% Sets Shim.Field
%
% Field is a FieldEval type object with .img in Hz

if nargin < 3
    error('Not enough input arguments.') ;
end

Shim.Model.currents = zeros( Shim.System.Specs.Amp.nActiveChannels, 1 )  ;

Shim.Field = Field.copy() ;

[X,Y,Z]  = Field.getvoxelpositions();
dR = Field.isocenter() ;
% Voxel positons are in the patient coordinate system,
% shift along Z to account for possible table displacement:
Z  = Z - dR(3) ; 

switch Shim.System.Specs.Id.systemName
    case {'IUGM_Prisma_fit', 'HGM_Prisma'} 
        Shim.img = ShimOpt_SphericalHarmonics.generatebasisfields_siemens( X, Y, Z ) ;
    otherwise
        Shim.img = ShimOpt_SphericalHarmonics.generatebasisfields( ordersToGenerate, X, Y, Z ) ;
end


Shim.Hdr = Field.Hdr;

Shim.setshimvolumeofinterest( Field.Hdr.MaskingImage ) ;

end
% =========================================================================
function [Corrections] = optimizeshimcurrents( Shim, Params )
%OPTIMIZESHIMCURRENTS 
%
% Corrections = OPTIMIZESHIMCURRENTS( Shim, Params )

if nargin < 2 
    Params.dummy = [];
end

Corrections = optimizeshimcurrents@ShimOpt( Shim, Params ) ;

end
% =========================================================================
end

% =========================================================================
% =========================================================================
methods(Static)
% =========================================================================
function [ basisFields ]= generatebasisfields( orders, X, Y, Z )
%GENERATEBASISFIELDS
%  
% Generates orthonormal spherical harmonic (SH) basis set 
%
% .......
%  
% Usage
%
% [ basisFields ] = GENERATEBASISFIELDS( orders, X, Y, Z )
%
% Returns array of SH basis fields where the 4th dimension is the order/degree index
% e.g. if orders = [0:2],
%
%       basisFields(:,:,:,1) corresponds to the 0th order term,
%
%       basisFields(:,:,:,2:4) to 1st order terms
%         2 -> (y)  
%         3 -> (z)   
%         4 -> (x)   
%
%       basisFields(:,:,:,5:9) to 2nd orders
%         5 -> (xy)  
%         6 -> (zy)   
%         7 -> (z2)   
%         8 -> (zx) 
%         9 -> (x2y2)  
%
%       etc.
%
% Input
%
%   orders 
%       vector of non-negative integers orders to calculate (e.g. [0:3]).
%       Typically orders is specified as 0:1:N to obtain spherical harmonics
%       up to order N
%
%   X, Y, Z
%       3d arrays specifying voxel coordinates at which to calculate the harmonics 
%  
% .......
%
% Based on calc_spherical_harmonics_arb_points_cz.m by jaystock@nmr.mgh.harvard.edu


% set the orders_to_calculate as a vector of integers n with 0 < n < N. This 
% calculates accompanying spherical harmonic orders.  The first 2*n(1)+1 columns 
% of the output correspond to harmonics of order n(1), and the next
% 2*n(2)+1 columns correspond to harmonics of order n(2), etc.  %
% note that Hetherington refers to n as "degree" instead of "order"
%

assert( all( orders >=0 ) ) ;

switch ndims(X) 
    case 2
        gridSize = [ size(X) 1 ] ;
    case 3
        gridSize = size(X) ;
    otherwise 
        error('Input arrays X,Y, and Z must have 2 or 3 dimensions') ;
end

nVoxels  = numel(X);
nOrders  = numel(orders) ;

harm_all = zeros( nVoxels, 1 ) ;

ii=0;

for iOrder = 1 : nOrders 
   
    n = orders(iOrder);
    m = -orders(iOrder):1:orders(iOrder);

    for mm = 1 : numel(m)

        ii = ii+1;

        harm_all(:,ii) = leg_rec_harmonic_cz( n, m(mm), X(:), Y(:), Z(:));
    end
end

nBasisFields = size( harm_all, 2) ;
basisFields  = zeros( [gridSize nBasisFields] ) ;

for iBasisField = 1 : nBasisFields 
    basisFields(:,:,:, iBasisField) = reshape( harm_all(:, iBasisField), gridSize ) ;
end

function out = leg_rec_harmonic_cz(n, m, pos_x, pos_y, pos_z)
% returns harmonic field for the required solid harmonic addressed by 
% n, m based on the iterative Legendre polynomial calculation
% Positive m values correspond to cosine component and negative to sine
%
% returned fields will eventually follow RRI's convention
% pos_... can be both value and vector/matrix

    r2=pos_x.^2+pos_y.^2+pos_z.^2;
    r=r2.^0.5;
    phi=atan2(pos_y, pos_x);
    cos_theta=cos(atan2((pos_x.^2+pos_y.^2).^0.5, pos_z));
    %cos_theta=pos_z./r;

    if m>=0,
        c=1;
    else
        c=0;
        m=-m;
    end

    Ymn=leg_rec(n,m,cos_theta);

    rri_norm=factorial(n+m+1)/factorial(n-m)/ffactorial(2*m);

    out=(n+m+1)*r.^(n).*(cos(m*phi)*c+sin(m*phi)*(1-c)).*Ymn/rri_norm;

function out = ffactorial(n)
%FFACTORIAL FFactorial (double factorial) function.

    N = n(:);
    if any(fix(N) ~= N) || any(N < 0) || ~isa(N,'double') || ~isreal(N)
      error('MATLAB:factorial:NNegativeInt', ...
            'N must be a matrix of non-negative integers.')
    end

    if n==0 || n==1
        out=1;
    else
        out=n*ffactorial(n-2);
    end

end

function out=leg_rec(n, m, u)
% compute legendre polynomial values for dat using recursive relations

    if m>0
        p_mm=(-1)^m*ffactorial(2*m-1)*(1-u.^2).^(m/2);
    else
        p_mm=1;
    end

    if (n==m)
        out=p_mm;
    else
        p_mm1=(2*m+1)*u.*p_mm;
        
        if (n==m+1)
            out=p_mm1;
        else
            % recursive calculation needed
            a=m+2;
            p_ma_2=p_mm;
            p_ma_1=p_mm1;
            
            while 1
                p_ma=((2*a-1)*u.*p_ma_1-(a+m-1)*p_ma_2)/(a-m);
                
                if a==n
                    break;
                end
                % prepare next iteration
                p_ma_2=p_ma_1;
                p_ma_1=p_ma;
                a=a+1;
            end
            
            out=p_ma;
        end
    end
end

end

end
% =========================================================================
function [ basisFields ] = generatebasisfields_siemens( X, Y, Z )
%GENERATEBASISFIELDS_SIEMENS
% 
% Wraps to ShimOpt_SphericalHarmonics.generatebasisfields(), reorders, and
% rescales the basis set to return ideal "shim reference maps" (in units of
% Hz/unit-shim) for the 1st and 2nd order spherical harmonic shims of the
% Siemens Prisma
%
% Usage
%
% [ basisFields ] = GENERATEBASISFIELDS_SIEMENS( X, Y, Z )
%
% X, Y, Z are 3d arrays of the voxel positions [units: mm] at which to generate
% the basis functions (e.g. X,Y,Z are generally returned from MaRdI.getvoxelpositions() )

assert( nargin == 3 )

sh = ShimOpt_SphericalHarmonics.generatebasisfields( [1:2], X, Y, Z ) ;
% Reorder terms along 4th array dim. in line with Siemens shims: X, Y, Z, Z2, ZX, ZY, X2-Y2, XY
sh = reordertosiemens( sh ) ; 

scalingFactors = computenormalizationfactors() ;
basisFields    = zeros( size( sh ) ) ; 

for iCh = 1 : size( sh, 4 ) 
   basisFields(:,:,:,iCh) = scalingFactors(iCh) * sh(:,:,:,iCh) ; 
end

return;

function [ sh1 ] = reordertosiemens( sh0 )
%REORDERTOSIEMENS
%
%   basisFields1 = REORDERTOSIEMENS( basisFields0 )
%
% basisFields returned from .GENERATEBASISFIELDS() are ordered (along the 4th
% array dimension) like: 
%   Y, Z, X, XY, ZY, Z2, ZX, X2-Y2
%
% REORDERTOSIEMENS orders them in line with Siemens shims: 
%   X, Y, Z, Z2, ZX, ZY, X2-Y2, XY

assert( ( nargin == 1 ) && ( size( sh0, 4 ) == 8 ) )

sh1(:,:,:,1) = sh0(:,:,:,3) ;
sh1(:,:,:,2) = sh0(:,:,:,1) ;
sh1(:,:,:,3) = sh0(:,:,:,2) ;
sh1(:,:,:,4) = sh0(:,:,:,6) ;
sh1(:,:,:,5) = sh0(:,:,:,7) ;
sh1(:,:,:,6) = sh0(:,:,:,5) ;
sh1(:,:,:,7) = sh0(:,:,:,8) ;
sh1(:,:,:,8) = sh0(:,:,:,4) ;

end %reordertosiemens()

function [ scalingFactors ] = computenormalizationfactors()
%COMPUTENORMALIZATIONFACTORS
%
%  scalingFactors = computenormalizationfactors()
%
%  returns a vector of scalingFactors to apply to the (properly reordered)
%  ideal 1st+2nd order spherical harmonic basis returned from GENERATEBASISFIELD
%  to scale the terms as "shim reference maps" in units of Hz/unit-shim
% -----
% Gx, Gy, and Gz should yield 1 micro-T of field shift per metre
% equivalently, 0.042576 Hz/mm
%
% 2nd order terms should yield 1 micro-T of field shift per metre-squared
% equivalently, 0.000042576 Hz/mm^2

%% ------
% create basis on small 3x3x3 mm^3 isotropic grid
[XIso, YIso, ZIso] = meshgrid( [-1:1], [-1:1], [-1:1] ) ;

sh = ShimOpt_SphericalHarmonics.generatebasisfields( [1:2], XIso, YIso, ZIso ) ;
% Reorder terms along 4th array dim. in line with Siemens shims: X, Y, Z, Z2, ZX, ZY, X2-Y2, XY
sh = reordertosiemens( sh ) ; 

nChannels      = size( sh, 4) ; % = 8
scalingFactors = zeros( nChannels, 1 ) ;

% indices of reference positions for normalization: 
iX1   = find( ( XIso == 1 ) & ( YIso == 0 ) & ( ZIso == 0 ) ) ;
iY1   = find( ( XIso == 0 ) & ( YIso == 1 ) & ( ZIso == 0 ) ) ;
iZ1   = find( ( XIso == 0 ) & ( YIso == 0 ) & ( ZIso == 1 ) ) ;

iX1Z1 = find( ( XIso == 1 ) & ( YIso == 0 ) & ( ZIso == 1 ) ) ;
iY1Z1 = find( ( XIso == 0 ) & ( YIso == 1 ) & ( ZIso == 1 ) ) ;
iX1Y1 = find( ( XIso == 1 ) & ( YIso == 1 ) & ( ZIso == 0 ) ) ;

% order the reference indices like the sh field terms 
iRef = [iX1 iY1 iZ1 iZ1 iX1Z1 iY1Z1 iX1 iX1Y1]' ;

%% ------
% scaling:
% 1st order terms yield 1 micro-T of field shift per m (i.e 0.042576 Hz/mm )
% 2nd order terms yield 1 micro-T of field shift per m^2 (i.e 0.000042576 Hz/mm^2 )

% distance from iso/origin to adopted reference point [units: mm]
r = [1 1 1 1 sqrt(2) sqrt(2) 1 sqrt(2)] ;

% invert polarity of certain terms:
sh(:,:,:,[2,3,5,8]) = -sh(:,:,:,[2,3,5,8] ) ;

orders = [1 1 1 2 2 2 2 2] ;

for iCh = 1 : nChannels
    field = sh(:,:,:,iCh) ;
    scalingFactors(iCh) = 42.576*( ( r(iCh) * 0.001 )^orders(iCh) )/field( iRef( iCh ) ) ;
end

end %computenormalizationfactors()

end
% =========================================================================

end
% =========================================================================
% =========================================================================
methods(Static=true, Hidden=true)
% =========================================================================
function  [ Params ] = assigndefaultparameters( Params )
%ASSIGNDEFAULTPARAMETERS  
% 
% Params = ASSIGNDEFAULTPARAMETERS( Params )
% 
% DEFAULT_ORDERSTOGENERATE = [1:2] ;

DEFAULT_ORDERSTOGENERATE = [1:2] ;

if myisfieldfilled( Params, 'systemName' )
    assert( any(strcmp( Params.systemName, {'IUGM_Prisma_fit', 'HGM_Prisma'} )), ...
            'Unimplemented system: Params.systemName must either be "IUGM_Prisma_fit" or "HGM_Prisma"') ;
    
    if myisfieldfilled( Params, 'ordersToGenerate' )
        assert( all( Params.ordersToGenerate == [1:2] ), ...
            ['Incompatible Params.ordersToGenerate: The Prisma possesses 1st and 2nd order shims. ' ...
             'To simulate a higher order system, set Params.systemName = []'] ) ;
    end
end

if ~myisfieldfilled( Params, 'ordersToGenerate' ) 
   Params.ordersToGenerate = DEFAULT_ORDERSTOGENERATE ;
end

end
% =========================================================================

end
% =========================================================================
% =========================================================================

end


