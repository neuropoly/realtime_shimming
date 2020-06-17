classdef NumericalModel < handle
    %NUMERICALMODEL Numerical Model for B0 data generation.
    
    properties
        gamma = 42.58 * 10^6; % Hz/Tesla
        fieldStrength = 3.0; % Tesla
        
        % properties
        starting_volume
        volume
        measurement
        
        % Default times in seconds @ 3T
        T2star = struct('WM', 0.053, 'GM', 0.066, 'CSF', 0.10)
        
        % Default proton density in percentage
        protonDensity = struct('WM', 70, 'GM', 82, 'CSF', 100)
        
        % deltaB0 in Hz
        deltaB0
    end
   
    methods
    	function obj = NumericalModel(model)
            % NumericalModel class
            % model: string with the label of the model desired.
 
            switch nargin
                case 0
                    obj.starting_volume = zeros(128, 128);
                case 1
                    if strcmp(model, 'Shepp-Logan')
                        obj.shepp_logan([128, 128]);
                        
                    else
                        error('Unknown volume model.')
                    end
                otherwise
                    error('Too many input arguments for class.')
            end
            
            % Define background field
            obj.deltaB0 = obj.starting_volume * 0;
        end
        
        
        function obj = shepp_logan(obj, dims)       
            % Create a 2D Shepp_Logan volume for the 
            % dims: [x, y] number of voxels.
            obj.starting_volume = phantom(dims(1), dims(2));
            
            obj.volume = struct('magn', [], 'phase', [], 'T2star', []);

            obj.volume.protonDensity = obj.customize_shepp_logan(obj.starting_volume, obj.protonDensity.WM, obj.protonDensity.GM, obj.protonDensity.CSF);
            obj.volume.T2star = obj.customize_shepp_logan(obj.starting_volume, obj.T2star.WM, obj.T2star.GM, obj.T2star.CSF);
        end

        function obj = simulate_measurement(obj, FA, TE, SNR)          
            % FA: flip angle value in degrees.
            % TE: Single or array TE value in seconds.
            % SNR: Signal-to-noise ratio
            
            % Get dimensions
            numTE = length(TE);
            volDims = size(obj.starting_volume);
               
            % Pre-allocate measurement variables
            if volDims == 2
                obj.measurement = zeros(volDims(1), volDims(2), 1, numTE);
            elseif volDims == 3
                obj.measurement = zeros(volDims(1), volDims(2), volDims(3), numTE);
            end
            
            % Simulate
            for ii = 1:numTE
                obj.measurement(:,:,:,ii) = NumericalModel.generate_signal(obj.volume.protonDensity, obj.volume.T2star, FA, TE(ii), obj.deltaB0, obj.gamma);
            end
            
            if exist('SNR','var')
                obj.measurement = NumericalModel.addNoise(obj.measurement, SNR);
            end
        end
        
        function vol = getMagnitude(obj)
            % Get magnitude data
            vol = abs(obj.measurement);
        end
        
        function vol = getPhase(obj)
            % Get phase data
            vol = angle(obj.measurement);
        end
  
        function vol = getReal(obj)
            % Get real data
            vol = real(obj.measurement);
        end
        
        function vol = getImaginary(obj)
            % Get imaginary data
            vol = imag(obj.measurement);
        end
        
        function obj = generate_deltaB0(obj, fieldType, params)       
            % type: 'linear' or ???
            % params: 
            %    'linear': [m, b, ang] where y = mx + b, and the center of the
            %              volume is the origin. m is Hz per voxel. b is
            %              Hz. ang is the angle against the x axis of the
            %              volume
            
            
            switch fieldType
                case 'linear'
                    m = params(1);
                    b = params(2);

                    dims = size(obj.starting_volume);

                    % Create coordinates
                    [X, Y] = meshgrid(linspace(-dims(1), dims(1), dims(1)), linspace(-dims(2), dims(2), dims(2)));

                    obj.deltaB0 = m*X+b;
                otherwise
                    error('Undefined deltaB0 field type')
            end
        end
    end
    
    methods (Static)
        function signal = generate_signal(protonDensity, T2star, FA, TE, deltaB0, gamma)
            % FA = flip angle in degrees
            % T2star in seconds
            % TE in seconds
            % B0 in tesla
            % gamma in Hz/Tesla
            signal = protonDensity.*sind(FA).*exp(-TE./T2star-1i*gamma*deltaB0.*TE);
        end
        
        function noisyVolume = addNoise(volume, SNR)
            % volume: measurement volume of signals
            % SNR: Signal-to-noise ratio
            
            noiseSTD = max(volume(:))/SNR;
            noisyReal =      real(volume) + randn(size(volume)) * noiseSTD;
            noisyImaginary = imag(volume) + randn(size(volume)) * noiseSTD;

            noisyVolume = noisyReal + 1i*noisyImaginary;
        end
    end
    
    methods (Access = protected)
        function customVolume = customize_shepp_logan(obj, volume, class1, class2, class3)
            customVolume = volume;
            
            % Set regions to T2
            customVolume(abs(volume-0.2)<0.001) = class1;
            customVolume(abs(volume-0.3)<0.001) = class2;
            customVolume(abs(volume-1)<0.001) = class3;

            customVolume((abs(volume)<0.0001)&volume~=0) = class1/2;
            customVolume(abs(volume-0.1)<0.001) = (class2 - class1/2)/2;
            customVolume(abs(volume-0.4)<0.001) = class2*1.5;
        end
    end

end
