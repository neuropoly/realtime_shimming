# shimming-toolbox

_Programs to perform [static](https://onlinelibrary.wiley.com/doi/full/10.1002/mrm.25587) and [real-time](https://doi.org/10.1002/mrm.27089) shimming for MRI applications._

- [Dependencies & Installation](#dependencies-and-installation)
- [Getting started](#getting-started)
- [SOP](#SOP)
- [Contributors](#contributors)
- [License](#license-and-warranty)

## Dependencies and Installation

Before running this software you will need to install the following dependencies:
- MATLAB version 2019B or later
  - Optimization toolbox
  - Image processing toolbox
- [dcm2niix](https://github.com/rordenlab/dcm2niix#install)
- [SCT v 4.0.0](https://github.com/neuropoly/spinalcordtoolbox)

To install, download (or `git clone`) this repository and add this folder (with sub-folders) to the Matlab path.

Create the folder '~/Matlab/shimming/' and copy into it the contents [here](https://drive.google.com/open?id=15mZNpsuuNweMUO6H2iWdf5DxA4sQ_aYR)

For certain features (e.g. recording from a respiratory sensor in "daemon mode"),
the Matlab path should be configured automatically at session start-up by adding the following lines to '~/startup.m'
(create the file if it does not exist):

```
% Change ~/Code/shimming-toolbox/ to wherever the repository was downloaded/cloned:
PATH_SHIMMINGTOOLBOX = '~/Code/shimming-toolbox/' ;
addpath( genpath( PATH_SHIMMINGTOOLBOX ) ) ;
```

For "daemon mode" to work, the MATLAB session must be started from the command line, and from the home folder, e.g.:

```
user@polymtl ~ $ matlab &
```

For the command line start, MATLAB also needs to exist within the system path, e.g. For MacOS, add the following lines (adapted to refer to your version of MATLAB) to ~/.bash_profile

```
# add MATLAB path
export PATH=$PATH:/Applications/MATLAB_R2020a.app/bin/
```

*For phase unwrapping:*

To use the optional Abdul-Rahman 3D phase unwrapper, binaries must be compiled from the source code found in /external/source/


## Getting started
**(from scratch)**

To use this library for optimizing a given shim system, that system needs to be defined. This definition occurs via two distinct classes:

1. **ShimSpecs( )**
*System specifications: This is essentially a struct container which defines system parameters concerning amplifier, DAC, etc.*

and

2. **ShimOpt( )**
*Shim optimization: This class contains a number of methods used to optimize the shim currents for a given field map*

Both are *abstract* classes, meaning they cannot, in themselves, be instantiated as objects. Rather, each specific shim system will require corresponding subclasses that inherit from these two templates. For example, *ShimSpecs_Greg* and *ShimOpt_Greg* refer to the 8-channel "AC/DC" 3T neck coil.

If you would like to register a new shim system, create a new folder Shim_MyNewShim. Within it, place and rename copies of the abstract classes in the folder **Shim_Template/**.

#### Shim reference (aka "calibration") maps

Prior to optimizing any shim currents, some experimental data is needed: These *reference maps* relate the longitudinal magnetic field (delta B0) generated by each shim element to the input current (in A).

TODO: Procedure for creating calibration maps. (Also see: Topfer et al. MRM 2016)

Once this experimental gradient-echo data is available, one need needs to provide the paths to the DICOM images and to define the corresponding experimental currents used in ShimOpt_MyNewShim.declarecalibrationparameters()...

TODO cont...

List of available maps:
- UNF: https://drive.google.com/drive/folders/1DSCTeh9qRCgS55fWLGtsNeYdq8DsRyMg

Download map and copy it under $PATH_SHIMMINGTOOLBOX/data/

### Interfacing with hardware: **ShimUse( )** and **ShimCom( )**

The class *ShimUse()* provides the generic user interface for the shim experiment and should not depend on the specific shim system. It does, however, require the prior definition of concrete ShimSpecs, ShimOpt, and ShimCom subclasses:

*ShimCom()* defines the lower-level communication methods with the shim hardware (e.g. *ShimCom.getchanneloutput()* and *ShimCom.setandloadallshims()*). It is another abstract class, and each shim system requires a corresponding subclass (e.g. *ShimCom_MyNewShim()* which both inherits from *ShimCom()*, and defines, for itself, the abstract methods of *ShimCom()*.

## SOP
**Experimental How-to**

- Control room
   - Connect sensor probe to station
  - Plug the optic-to-serial-to-usb (PICTURE) to the computer.
    - If you are running macOS, you might need to install [this driver](http://www.prolific.com.tw/US/ShowProduct.aspx?p_id=229&pcid=41).
  - In the terminal, change to the home directory and open matlab
  - Copy the file `shim_params_template.m` to `shim_params.m` and edit `shim_params.m` according to your setup.
  - Launch experiment by instantiating a ShimUse object with the desired parameters: Shims = ShimUse( shim_params )

- See example: shimming-toolbox/example/XXX

## Class definitions

Other classes pertaining to shimming:

**ProbeTracking( )**

*Dynamic tracking of resonance offsets (for now: only subject respiration vis-a-vis the respiratory probe...).*

For the documentation, in the Matlab command prompt type:
	doc [class name]

## Contributors

[List of contributors.](https://github.com/neuropoly/realtime_shimming/graphs/contributors)

## License and warranty

This software is distributed under the following [license](LICENSE). THIS SOFTWARE MAY NOT BE USED FOR MEDICAL DIAGNOSIS AS IT IS NOT SANCTIONED BY AUTHORITIES SUCH AS HEALTH CANADA AND THE FOOD AND DRUG ADMINISTRATION.

By using this software, you indemnify the General Hospital Corporation (Boston, MA) and Ecole Polytechnique (Montreal, QC) from any liability arising from use of this software. Installation and use of the software shall be construed as consent to waive any future right to take legal action against the above-mentioned parties for any damages related to the use of the software, whether for the software's intended applications or otherwise.


