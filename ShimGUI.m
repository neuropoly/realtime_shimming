function varargout = ShimGUI(varargin)
% SHIMGUI MATLAB code for ShimGUI.fig
%      SHIMGUI, by itself, creates a new SHIMGUI or raises the existing
%      singleton*.
%
%      H = SHIMGUI returns the handle to a new SHIMGUI or the handle to
%      the existing singleton*.
%
%      SHIMGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SHIMGUI.M with the given input arguments.
%
%      SHIMGUI('Property','Value',...) creates a new SHIMGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ShimGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ShimGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ShimGUI

% Last Modified by GUIDE v2.5 25-Jan-2017 13:09:15

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ShimGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @ShimGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before ShimGUI is made visible.
function ShimGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ShimGUI (see VARARGIN)

% add misc to path

addpath misc;
savepath;

addpath misc/stoploop;
savepath;

addpath misc/NIFTI;
savepath;

addpath misc/dicm2nii;
savepath;

% Choose default command line output for ShimGUI
handles.output = hObject;

handles.Params = [];

% =========================================================================
% SETTING DEFAULT VALUES
% =========================================================================

% Field Filter default values

set(handles.fieldFiltering,'Value',1);
handles.Params.isFilteringField = true;

set(handles.maxfield,'String','600');
handles.Params.maxAbsField = 600;

set(handles.maxfielddiff,'String','150');
handles.Params.maxFieldDifference = 150;

set(handles.threshold,'String','0.01');
handles.Params.threshold = 0.01;

% Pressure Probe default values

set(handles.savingProbeData,'Value',1);
handles.RecParams.isSavingData = true;

set(handles.forcingOverwrite,'Value',1);
handles.RecParams.isForcingOverwrite = true;

set(handles.arduinoperiod,'String',10);
handles.Params.ProbeSpecs.arduinoPeriod = 10;

set(handles.nCalScan,'String',2);
handles.Params.nCalibrationScans = 2;

set(handles.runtime,'String','10');
handles.RecParams.runTime = 10;

% Update handles structure
guidata(hObject, handles);


% UIWAIT makes ShimGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = ShimGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pathtoshimref.
function pathtoshimref_Callback(hObject, eventdata, handles)
% hObject    handle to pathtoshimref (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[FileName,FilePath ]= uigetfile();
ShimRefPath = fullfile(FilePath, FileName);
handles.Params.pathToShimReferenceMaps = ShimRefPath;

guidata(hObject,handles);



% --- Executes on button press in folder.
function folder_Callback(hObject, eventdata, handles)
% hObject    handle to folder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
FilePath= uigetdir();
handles.Params.dataLoadDir = [FilePath, '/'];
% 
% % Inspired Path
% handles.Params.Path.Mag.echo1         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 5 ) 'echo_4.92' ] ;
% handles.Params.Path.Mag.echo2         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 5 ) 'echo_7.64' ] ;
% 
% handles.Params.Path.Phase.echo1       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 6 ) 'echo_4.92' ] ;
% handles.Params.Path.Phase.echo2       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 6 ) 'echo_7.64' ] ;
% 
% % -------
% % Expired Path
% handles.Params.Path.Mag.echo1         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 7 ) 'echo_4.92' ] ;
% handles.Params.Path.Mag.echo2         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 7 ) 'echo_7.64' ] ;
% 
% handles.Params.Path.Phase.echo1       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 8 ) 'echo_4.92' ] ;
% handles.Params.Path.Phase.echo2       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 8 ) 'echo_7.64' ] ;

guidata(hObject,handles);


% --- Executes on selection change in shimsystem.
function shimsystem_Callback(hObject, eventdata, handles)
% hObject    handle to shimsystem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns shimsystem contents as cell array
%        contents{get(hObject,'Value')} returns selected item from shimsystem
contents = cellstr(get(hObject,'String'));

shimSystem = contents{get(hObject,'Value')};
handles.Params.shimSystem = shimSystem;

set(handles.commandLine,'string',['Shim system changed to ',shimSystem]);

guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function shimsystem_CreateFcn(hObject, eventdata, handles)
% hObject    handle to shimsystem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String',{'Shim system selection', 'Rri', 'Acdc'});


% --- Executes on button press in fieldFiltering.
function fieldFiltering_Callback(hObject, eventdata, handles)
% hObject    handle to fieldFiltering (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fieldFiltering
isFilteringField = get(hObject, 'Value');

handles.Params.isFilteringField = isFilteringField;

set(handles.commandLine,'string',['isFilteringField changed to ',isFilteringField]);

guidata(hObject,handles);



function maxfield_Callback(hObject, eventdata, handles)
% hObject    handle to maxfield (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of maxfield as text
%        str2double(get(hObject,'String')) returns contents of maxfield as a double
maxAbsField = str2double(get(hObject,'String'));
if isnan(maxAbsField)
    set(handles.commandLine,'string','Max absolute field entered is not a number, please enter a number to continue');
else
    handles.Params.maxAbsField = maxAbsField;

    set(handles.commandLine,'string',['Max absolute field changed to ',num2str(maxAbsField)]);
end
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function maxfield_CreateFcn(hObject, eventdata, handles)
% hObject    handle to maxfield (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function maxfielddiff_Callback(hObject, eventdata, handles)
% hObject    handle to maxfielddiff (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of maxfielddiff as text
%        str2double(get(hObject,'String')) returns contents of maxfielddiff as a double
maxFieldDifference = str2double(get(hObject,'String'));
if isnan(maxFieldDifference)
    set(handles.commandLine,'string','Max field difference entered is not a number, please enter a number to continue');
else
    handles.Params.maxFieldDifference = maxFieldDifference;


    set(handles.commandLine,'string',['Max field difference changed to ',num2str(maxFieldDifference)]);
end

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function maxfielddiff_CreateFcn(hObject, eventdata, handles)
% hObject    handle to maxfielddiff (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function threshold_Callback(hObject, eventdata, handles)
% hObject    handle to threshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of threshold as text
%        str2double(get(hObject,'String')) returns contents of threshold as a double
threshold = str2double(get(hObject,'String'));
if isnan(threshold)
    set(handles.commandLine,'string','Threshold entered is not a number, please enter a number to continue');
else
    handles.Params.threshold = threshold;
    set(handles.commandLine,'string',['Unwrapping threshold changed to ',num2str(threshold)]);
end

guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function threshold_CreateFcn(hObject, eventdata, handles)
% hObject    handle to threshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% =========================================================================
% FieldFilterButton has to be changed or put somewhere else (w ohter name)
% =========================================================================

% --- Executes on button press in FieldFilterButton.
function FieldFilterButton_Callback(hObject, eventdata, handles)
% hObject    handle to FieldFilterButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Prepare the Shimming object

Shims = ShimUse(handles.Params);


% =========================================================================
% Prepare the calibration maps
% =========================================================================

handles.Params.Path.Mag.echo1         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 5 ) 'echo_4.92' ] ;
handles.Params.Path.Mag.echo2         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 5 ) 'echo_7.64' ] ;

handles.Params.Path.Phase.echo1       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 6 ) 'echo_4.92' ] ;
handles.Params.Path.Phase.echo2       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 6 ) 'echo_7.64' ] ;

[FieldInspired,Extras] = ShimOpt.mapfield( handles.Params ) ;

handles.Params.Path.Mag.echo1         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 7 ) 'echo_4.92' ] ;
handles.Params.Path.Mag.echo2         = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 7 ) 'echo_7.64' ] ;

handles.Params.Path.Phase.echo1       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 8 ) 'echo_4.92' ] ;
handles.Params.Path.Phase.echo2       = [ MaRdI.getfulldir( handles.Params.dataLoadDir, 8 ) 'echo_7.64' ] ;

[FieldExpired,Extras] = ShimOpt.mapfield( handles.Params ) ;

% Interpolate the reference maps to the calibration maps grid

Shims.Opt.interpolatetoimggrid( FieldInspired ) ;

% Save the calibration maps

handles.FieldInspired = FieldInspired;
handles.FieldExpired = FieldExpired;

% Save the shimming objeect

handles.Shims = Shims;

guidata(hObject,handles);


% --- Executes on button press in savingProbeData.
function savingProbeData_Callback(hObject, eventdata, handles)
% hObject    handle to savingProbeData (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of savingProbeData
isSavingData = get(hObject, 'Value');

handles.RecParams.isSavingData = isSavingData;

set(handles.commandLine,'string',['isSavingData changed to ',string(isSavingData)]);

guidata(hObject,handles);



% --- Executes on button press in forcingOverwrite.
function forcingOverwrite_Callback(hObject, eventdata, handles)
% hObject    handle to forcingOverwrite (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of forcingOverwrite
isForcingOverwrite = get(hObject, 'Value');

handles.RecParams.isForcingOverwrite = isForcingOverwrite;

set(handles.commandLine,'string',['isForcingOverwrite changed to ',string(isForcingOverwrite)]);

guidata(hObject,handles);


function arduinoperiod_Callback(hObject, eventdata, handles)
% hObject    handle to arduinoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of arduinoperiod as text
%        str2double(get(hObject,'String')) returns contents of arduinoperiod as a double
arduinoPeriod = str2double(get(hObject,'String'));
if isnan(arduinoPeriod)
    set(handles.commandLine,'string','Probe period entered is not a number, please enter a number to continue');
else
    handles.Params.ProbeSpecs.arduinoPeriod = arduinoPeriod;
    set(handles.commandLine,'string',['Probe period changed to ',num2str(arduinoPeriod)]);
end

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function arduinoperiod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to arduinoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function nCalScan_Callback(hObject, eventdata, handles)
% hObject    handle to nCalScan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nCalScan as text
%        str2double(get(hObject,'String')) returns contents of nCalScan as a double
nCalibrationScans = str2double(get(hObject,'String'));
if isnan(nCalibrationScans)
    set(handles.commandLine,'string','Number of calibration scans entered is not a number, please enter a number to continue');
else
    handles.Params.nCalibrationScans = nCalibrationScans;
    set(handles.commandLine,'string',['Number of calibration scans changed to ',num2str(nCalibrationScans)]);
end

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function nCalScan_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nCalScan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in filterPressure.
function filterPressure_Callback(hObject, eventdata, handles)
% hObject    handle to filterPressure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of filterPressure
isFilterPressure = get(hObject, 'Value');

handles.Params.isFilteringPressure = isFilterPressure;

set(handles.commandLine,'string',['isFilteringPressure changed to ',string(isFilterPressure)]);

guidata(hObject,handles);


function runtime_Callback(hObject, eventdata, handles)
% hObject    handle to runtime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of runtime as text
%        str2double(get(hObject,'String')) returns contents of runtime as a double
runTime = str2double(get(hObject,'String'));
if isnan(runTime)
    set(handles.commandLine,'string','Run time entered is not a number, please enter a number to continue');
else
    handles.RecParams.runTime = runTime;
    set(handles.commandLine,'string',['Run time changed to ',num2str(runTime)]);
end

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function runtime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to runtime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in staticshim.
function staticshim_Callback(hObject, eventdata, handles)
% hObject    handle to staticshim (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if myisfield(handles, 'Shims')
    Shims = handles.Shims;
    % =========================================================================
    % DEFINE SHIM VOI
    % =========================================================================
    mask = Shims.Opt.getvaliditymask( handles.Params, handles.FieldInspired, handles.FieldExpired ) ;
    
    % =========================================================================
    % STATIC OPTIMIZATION
    % =========================================================================
    
    % -------
    % Inspired
    Shims.Opt.setoriginalfield( handles.FieldInspired ) ;
    Shims.Opt.setshimvolumeofinterest( mask ) ;
    
    Shims.Opt.optimizeshimcurrents( handles.Params ) ;
    
    handles.Params.Inspired.currents = Shims.Opt.Model.currents ;
    
    % -------
    % Expired
    Shims.Opt.setoriginalfield( handles.FieldExpired ) ;
    Shims.Opt.setshimvolumeofinterest( mask ) ;
    
    Shims.Opt.optimizeshimcurrents( handles.Params ) ;
    
    handles.Params.Expired.currents = Shims.Opt.Model.currents ;
    
    
    % =========================================================================
    % STATIC SHIMMING
    % =========================================================================
    
    % -------
    % Inspired
    Shims.Com.setandloadallshims( handles.Params.Inspired.currents ) ;
    % Params.pressureLogFilename = [Params.dataLoadDir datestr(now,30) '-pressureLog-INS-ShimOn.bin'] ;
    % Params.sampleTimesFilename = [Params.dataLoadDir datestr(now,30) '-sampleTimes-INS-ShimOn.bin'] ;
    % [pressureLog, sampleTimes] =Shims.Opt.Probe.recordandplotpressurelog( Params ) ;
    
    Shims.Com.resetallshims() ;
    
    % -------
    % Expired
    Shims.Com.setandloadallshims( handles.Params.Expired.currents ) ;
    % Params.pressureLogFilename = [Params.dataLoadDir datestr(now,30) '-pressureLog-EXP-ShimOn.bin'] ;
    % Params.sampleTimesFilename = [Params.dataLoadDir datestr(now,30) '-sampleTimes-EXP-ShimOn.bin'] ;
    % [pressureLog, sampleTimes] =Shims.Opt.Probe.recordandplotpressurelog( Params ) ;
    
    Shims.Com.resetallshims() ;
end



function commandLine_Callback(hObject, eventdata, handles)
% hObject    handle to commandLine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of commandLine as text
%        str2double(get(hObject,'String')) returns contents of commandLine as a double


% --- Executes during object creation, after setting all properties.
function commandLine_CreateFcn(hObject, eventdata, handles)
% hObject    handle to commandLine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in normalBreathingRecord.
function normalBreathingRecord_Callback(hObject, eventdata, handles)
% hObject    handle to normalBreathingRecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Probe = ProbeTracking(handles.Params.ProbeSpecs);

handles.RecParams.axes = handles.pressureAxes;

handles.RecParams.pressureLogFilename = [handles.Params.dataLoadDir datestr(now,30) '-pressureLog-Breathing-ShimOff.bin'] ;
handles.RecParams.sampleTimesFilename = [handles.Params.dataLoadDir datestr(now,30) '-sampleTimes-Breathing-ShimOff.bin'] ;

[pressureLog, sampleTimes] = Probe.recordandplotpressurelog( handles.RecParams ) ;

% --- Executes on button press in inspiredStateRecord.
function inspiredStateRecord_Callback(hObject, eventdata, handles)
% hObject    handle to inspiredStateRecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in expiredStateRecord.
function expiredStateRecord_Callback(hObject, eventdata, handles)
% hObject    handle to expiredStateRecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on slider movement.
function sliceSelector_Callback(hObject, eventdata, handles)
% hObject    handle to sliceSelector (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function sliceSelector_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sliceSelector (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on selection change in viewSelector.
function viewSelector_Callback(hObject, eventdata, handles)
% hObject    handle to viewSelector (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns viewSelector contents as cell array
%        contents{get(hObject,'Value')} returns selected item from viewSelector
contents = cellstr(get(hObject,'String'));

viewSelected = contents{get(hObject,'Value')};
handles.viewSelected = viewSelected;

image = handles.imageToPlot;
sliceSelected = handles.sliceSelected;

switch viewSelected
    case 'Sagittal'
        if sliceSelected > size(image,3)
            sliceSelected = 1;
        end
        imshow(image(:,:,sliceSelected),'parent',handles.imageFromScan);
    case 'Coronal'
        if sliceSelected > size(image,2)
            sliceSelected = 1;
        end
        imshow(image(:,sliceSelected,:),'parent',handles.imageFromScan);
    case 'Axial'
        if sliceSelected > size(image,1)
            sliceSelected = 1;
        end
        imshow(image(sliceSelected,:,:),'parent',handles.imageFromScan);
end

set(handles.commandLine,'string',['Shim system changed to ',viewSelected]);

guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function viewSelector_CreateFcn(hObject, eventdata, handles)
% hObject    handle to viewSelector (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

set(hObject,'String',{'Sagittal', 'Coronal', 'Axial'});


% --- Executes on button press in realTimeShimming.
function realTimeShimming_Callback(hObject, eventdata, handles)
% hObject    handle to realTimeShimming (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% =========================================================================
% Calibrate real-time updates
% =========================================================================
Shims = handles.Shims;

Shims.Opt.calibraterealtimeupdates( handlesParams ) ;

% =========================================================================
% Run real time shimming
% =========================================================================

handles.Params.maxCurrents = max( [handles.Params.Inspired.currents handles.Params.Expired.currents], [],2) ; 
handles.Params.minCurrents = min( [handles.Params.Inspired.currents handles.Params.Expired.currents], [],2) ; 
handles.Params.isFilteringPressure = false ;
handles.Params.isClippingPressure  = true ;
handles.Params.minClippingPressure = 210 ;
handles.Params.maxClippingPressure = 260 ;
handles.Params.pressureLogFilename = [handles.Params.dataLoadDir datestr(now,30) '-pressureLog-Breathing-ShimOn-RT.bin'] ;
handles.Params.sampleTimesFilename = [handles.Params.dataLoadDir datestr(now,30) '-sampleTimes-Breathing-ShimOn-RT.bin'] ;
Shims.runrealtimeshim( handles.Params ) ;