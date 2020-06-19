classdef ShimSpecs_revC < ShimSpecs
%ShimSpecs_revC Shim System Specifications for the 8ch. AC/DC 3T neck coil 
%     
%     Specs = ShimSpecs_revC(  )
%
% Specs contains fields
%           
%     .Amp    
%       relating to amplifcation
%
%     .Com
%       relating to communication (e.g. RS-232)
%
%     .Adc 
%       relating to analog-to-digital conversion
%
%     .Dac 
%       relating to digital-to-analog conversion
%   
% __ETC___
%
% See also
% ShimSpecs

properties
    Adc;
end

% =========================================================================
% =========================================================================
methods
% =========================================================================
function Shim = ShimSpecs_revC(  )
%SHIMSPECS - Shim System Specifications 

Shim.Id.systemName   = 'Greg' ;
Shim.Id.channelNames = cell(8,1) ;
Shim.Id.channelUnits = cell(8,1) ;

for iCh = 1 :8 
    Shim.Id.channelNames(iCh) = { ['Ch' num2str(iCh) ] } ; 
    Shim.Id.channelUnits(iCh) = { '[A]' } ; 
end
    
Shim.Com.baudRate    = 9600 ;
% Shim.Com.readTimeout = 500 ; %[units: ms]

Shim.Com.dataBits    = 8 ;
Shim.Com.stopBits    = 1 ;
Shim.Com.flowControl = 'NONE' ;
Shim.Com.parity      = 'NONE' ;
Shim.Com.byteOrder   = 'bigEndian' ;

% min delay (in seconds) between transmission and reception of data is 1 s
%
% UNTESTED
Shim.Com.txRxDelay       = 0.005 ; % [units: s]
Shim.Com.updatePeriod    = 0.1 ;

Shim.Amp.nChannels       = 8 ;  
Shim.Amp.nActiveChannels = 8 ;

Shim.Amp.maxCurrentPerChannel = 2.5 * ones( Shim.Amp.nActiveChannels, 1 ) ; ; % (absolute) [units: A]
Shim.Amp.maxVoltagePerChannel = 2500 ; % [units: mV]

Shim.Amp.staticChannels  = true( Shim.Amp.nActiveChannels, 1 ) ;  
Shim.Amp.dynamicChannels = true( Shim.Amp.nActiveChannels, 1 ) ;  

Shim.Adc.mVPerAdcCount = 2 ;

Shim.Dac.resolution       = 16 ; % [bits]
Shim.Dac.referenceVoltage = 1250 ; % [units: mV]
Shim.Dac.maximum          = 26214 ; 


end
% =========================================================================

end
% =========================================================================
% =========================================================================

end
