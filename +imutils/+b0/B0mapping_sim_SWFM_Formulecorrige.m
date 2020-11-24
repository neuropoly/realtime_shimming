% generate a "Shepp-Logan" phantom (ie; shape) in 2D
SheppLogan2d_vol = NumericalModel('Shepp-Logan2d',256);
figure; imagesc(SheppLogan2d_vol.starting_volume)
% generate a deltaB0 (B0 inhomogeneity) distribution in 2D (it will be in
% units of Hz)
SheppLogan2d_vol.generate_deltaB0('2d_linearIP', [5 0]); 
% plot it to see how it looks
figure; imagesc(SheppLogan2d_vol.deltaB0)

% simulate MRI magnitude and phase data for your Shepp-Logan phantom in the
% presence of the deltaB0 field you generated
% indice = 1 ;
deltaTE=0.0001;
 TE=[0.00100 0.00115 0.00120 0.00125 0.00130 0.00135 0.00140]
%  for t=0:1
%      TE(indice) = 0.001 + t*0.0005;
%      indice = indice + 1 ;
%  end
% echo times
SheppLogan2d_vol.simulate_measurement(15, TE, 100);

% get magnitude and phase data
magn = SheppLogan2d_vol.getMagnitude;
phase = SheppLogan2d_vol.getPhase;

% save the magnitude and phase data as a nifti file
SheppLogan2d_vol.save('Phase', 'SheppLogan2d_simulated_phase.nii');
SheppLogan2d_vol.save('Magnitude', 'SheppLogan2d_simulated_magnitude.nii');

% generate a complex data set from your magnitude and phase data
compl_vol = magn.*exp(1i*phase);

% calculate the deltaB0 map from the magnitude and phase data using the
% SWFM method (it will be in units of Hz)
[SWFM_delf] = +imutils.b0.SWFM_Formulecorrige(compl_vol(:,:,:,:), TE);
% plot it, it should look the same as the deltaB0 you simulated!
figure('Name','Champ magn�tique inhomog�ne'); imagesc(SWFM_delf)

% save your deltaB0 map as a nifti file
nii_vol = make_nii(SWFM_delf);
save_nii(nii_vol, ['dualechoB0_SheppLogan2d' '.nii'])