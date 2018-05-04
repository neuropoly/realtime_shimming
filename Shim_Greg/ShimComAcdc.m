classdef ShimComAcdc < ShimCom 
%SHIMCOMACDC - Shim Communication for AC/DC neck coil 
%
% .......
%   
% Usage
%
%   Shims = ShimComAcdc(  )
%
%   Shims contains fields
%
%       .Cmd
%           
%       .ComPort    
%
%       .Data 
%
%       .Params
%
% =========================================================================
% Notes
%
%   Part of series of classes pertaining to shimming:
%
%    ProbeTracking
%    ShimCal
%    ShimCom
%    ShimEval
%    ShimOpt
%    ShimSpecs
%    ShimTest 
%    ShimUse
%     
%    ShimComAcdc is a ShimCom subclass.
%
% =========================================================================
% Updated::20180215::ryan.topfer@polymtl.ca
% =========================================================================

% =========================================================================
% =========================================================================
methods
% =========================================================================
function Shim = ShimComAcdc( Specs )
%SHIMCOM - Shim Communication

if nargin < 2 || isempty( Specs ) 
    Shim.Specs = ShimSpecsAcdc( );
end

Shim.ComPort = ShimComAcdc.initializecomport( Shim.Specs ) ;
Shim.Cmd     = ShimComAcdc.getcommands( ) ;

Shim.Data.output = uint8(0) ;
Shim.Data.input  = uint8(0) ;

Shim.Params.nBytesToRead     = [] ; % depends on cmd sent to system
Shim.Params.nSendAttemptsMax = 5; % # communication attempts before error

end
% =========================================================================
function [isAckReceived] = getsystemheartbeat( Shim ) ;
%GETSYSTEMHEARTBEAT
%
isAckReceived=true;
end
% =========================================================================
function [] = setandloadshim( Shim, channel,current,coeff1,coeff2)  ;
% setandloadshim :
%
% - Update one channel with a current (Both in arg)
%
%--------------------------------------------------------------------------

calibrationVal = (current - coeff2)/ coeff1;

% Variable used to convert currents into DAC value-------------------------

  DACvoltref = 1.25;
  preampresistance = 0.22;
  DACmaxvalue = 26214;
  
%Conversion----------------------------------------------------------------

  DACcurrent = num2str(((DACvoltref - calibrationVal * 0.001 * preampresistance) * DACmaxvalue));
  Channel=num2str(channel);
  
  
  command=strcat(Shim.Cmd.updateOneChannel,Channel,'_',DACcurrent);

fprintf(Shim.ComPort,'%s',command,'sync');  

end

% =========================================================================
function [] = setandloadallshims( Shim, currents )
% setandloadallshim :
%
% - Update all channels with currents (DAC value) in argument
%
%--------------------------------------------------------------------------

convertedCurrents=Shim.ampstodac(currents,Shim.Specs.Com.feedbackcalibrationcoeffx,Shim.Specs.Com.feedbackcalibrationcoeffy);
Currents=round(convertedCurrents);

command =strcat('o',num2str(Currents(1)),num2str(Currents(2)),num2str(Currents(3)),num2str(Currents(4)),...
num2str(Currents(5)),num2str(Currents(6)),num2str(Currents(7)),num2str(Currents(8)));

fprintf(Shim.ComPort,'%s',command,'sync'); 

%for i=1:(Shim.Specs.Amp.nChannels)    % To display feedback from querry
%a = fscanf(Shim.ComPort,'%s');
%disp(a);
%end

disp('Currents Updated');
fscanf(Shim.ComPort,'%s');

end
%==========================================================================
function [DACvaluetosend] = ampstodac(Shim,currents,coeff1,coeff2)
% ampstodac :
%
% - Convert currents from Amps to DAC value.
%
%--------------------------------------------------------------------------
 
  calibrationVal=zeros(Shim.Specs.Amp.nChannels,1);

  for i=1:Shim.Specs.Amp.nChannels
  calibrationVal(i) = (currents(i) - coeff2(i)) / coeff1(i);
  end
  
% Variable used to convert currents into DAC value-------------------------

  DACvoltref = 1.25;
  preampresistance = 0.22;
  DACmaxvalue = 26214;
  
%Conversion----------------------------------------------------------------

  DACvaluetosend = ((DACvoltref - calibrationVal * 0.001 * preampresistance) * DACmaxvalue);

end
% =========================================================================
function [] = resetallshims( Shim )
% resetallshims :
%
% - Reset all shim currents to 0 Amp
%
%--------------------------------------------------------------------------
   

% Send Command to set all channels to 0 Amp--------------------------------
fprintf(Shim.ComPort,'%s',Shim.Cmd.resetAllShims,'sync');

end


% =========================================================================
function [] = opencomport( Shim ) 
% opencomport :
% 
% - Open serial communication port
% - Reset arduino Board to make it ready to receive commands
%
%--------------------------------------------------------------------------

instrument = instrfind;
display(instrument);

if isempty(instrument)
    Shim.ComPort = ShimComAcdc.initializecomport( Shim.Specs ) ;
end

fopen(Shim.ComPort);

fprintf(Shim.ComPort,'%s',Shim.Cmd.resetArduino,'sync');


nlinesFeedback = 8 ; % Lines of feedback after opening serial communication

% Read the Feedback from the arduino---------------------------------------
for i=1:nlinesFeedback
a = fscanf(Shim.ComPort,'%s');
disp(a);
end
end

% =========================================================================
function [] = closecomport( Shim ) 
% closecomport :
% 
% - Close serial communication port 
%
%--------------------------------------------------------------------------
display(Shim.ComPort.BytesAvailable);
%fread(Shim.ComPort, Shim.ComPort.BytesAvailable);
fclose(Shim.ComPort);
delete(Shim.ComPort);
clear Shim.ComPort;
end

% =========================================================================
function [ChannelOutput] = getchanneloutput( Shim ,~, Channel )
% getchanneloutput :
% 
% - Querry and display a current feedback for one channel
%
%--------------------------------------------------------------------------
 
%Command to querry the channel feedback------------------------------------
command = strcat(Shim.Cmd.getChannelFeedback,Channel);

fprintf(Shim.ComPort,'%s',command,'sync');

% Read the Feedback from the arduino---------------------------------------
ChannelOutput=fscanf(Shim.ComPort,'%s');
disp(ChannelOutput);
end

function [ChannelOutputs] = getallchanneloutputs( Shim )
% getallchanneloutput :
% 
% - Querry and display a current feedback for all channels
%
%--------------------------------------------------------------------------

%Command to querry the channels -------------------------------------------
fprintf(Shim.ComPort,'%s',Shim.Cmd.getallChannelFeedback,'sync');
ChannelOutputs =zeros(1,Shim.Specs.Amp.nChannels);

% Read Feedback from arduino-----------------------------------------------
for i=1:(Shim.Specs.Amp.nChannels)
a= fscanf(Shim.ComPort,'%s');
disp(a);
ChannelOutputs(i)=str2double(a); 
end
end

% =========================================================================
function [Shims, isSendOk]= sendcmd( Shim, command )
% sendcmd : 
%   
% - Transmits a command from client to shim microcontroller 
%
%--------------------------------------------------------------------------
isSendOk  = false ;

if strcmp( Shim.ComPort.Status, 'closed' ) ;
    fopen( Shim.ComPort ) ;
end 
    
fprintf( Shim.ComPort,'%s', command,'sync' ) ;
    
end
% =========================================================================

function [calibrationvalues]= getcalibrationcoefficient( Shim)
% getcalibrationcoefficient : 
%
% - Send a command to calibrate Adc feedback coefficients
% - Receive and save calibrationvalues to calculate the coefficients
%
%--------------------------------------------------------------------------

if strcmp( Shim.ComPort.Status, 'closed' ) ;
    fopen( Shim.ComPort ) ;
end 
    
fprintf( Shim.ComPort,'%s', Shim.Cmd.calibrateDacCurrent,'sync' ) ;

ncalibrationpoint = 5 ; %Number of calibration points to calculate coefficient
calibrationvalues = zeros(ncalibrationpoint,8);
display('Calibration in process, please wait')
pause(41);

% Read Feedback from the arduino-------------------------------------------
for j=1:(Shim.Specs.Amp.nChannels)
    for i=1:(ncalibrationpoint)  
        a = fscanf(Shim.ComPort,'%s');
        display(a);
        calibrationvalues(i,j) = str2double(a);
    end
end
display(calibrationvalues);
end
% =========================================================================

end
% =========================================================================
methods(Static)

    
function [Cmd] = getcommands( )
% getcommands :
%
% - Get shim system commands 
%
%--------------------------------------------------------------------------

% System commands (as strings)---------------------------------------------

Cmd.getChannelFeedback = 'f';
Cmd.getallChannelFeedback = 'e';
Cmd.calibrateDacCurrent='x';

Cmd.resetArduino='r';

Cmd.updateOneChannel = 'a';
Cmd.resetAllShims    = 'w' ;
Cmd.querry    = 'q' ;

end
% =========================================================================
function [ComPort] = initializecomport( Specs )
% initializecomport : 
%
% -  Initialize (RS-232) Communication Port
% 
%--------------------------------------------------------------------------

% Serial Port 

if ismac
   portName = '/dev/cu.usbserial' ;          % USB to serial adapter
  %  portName = '/dev/cu.usbmodem1421' ;        % Classical USB port
elseif isunix
    portName = '/dev/ttyUSB0' ;  % Can be different depending on the computer 
elseif ispc
    portName = 'COM4' ;
else
    error('Wtf kind of computer is this?')
end

ComPort = serial( portName,...
    'BaudRate', Specs.Com.baudRate,...
    'DataBits', Specs.Com.dataBits,...
    'StopBits', Specs.Com.stopBits,...
    'FlowControl', Specs.Com.flowControl,...
    'Parity', Specs.Com.parity,...
    'ByteOrder', Specs.Com.byteOrder ) ; 

end
% =========================================================================

% =========================================================================
function dacCount = voltstodac( Shims, current)
%VOLTSTODAC

%MAX_VOLTAGE = 2.5 ; % mV 

MAX_DIGI = (2^(Shims.Specs.Dac.resolution-1)) - 1 ; % Digital to Analog Converter max value

dacCount = int16( current*( MAX_DIGI/Shims.Specs.Dac.maxCurrent  ) ) ;

end
% =========================================================================


end
% =========================================================================

end