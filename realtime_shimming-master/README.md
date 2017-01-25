# realtime_shimming

-------------------------------------------------------------------------
## Overview 

This library consists of programs to perform shimming (static and real-time).
First designed for use with the 24-channel spine shim (Topfer R, et al., MRM,
2016. http://onlinelibrary.wiley.com/resolve/doi?DOI=10.1002/mrm.26354)

Series of classes pertaining to shimming:

**ShimCom( )**

*Low-level communication with the amplifier/hardware.*

**ShimUse( )**

*Shim control via high-level commands.*

**ShimOpt( )**

*Optimization of shim currents. Subclass of MaRdI.*

**ShimEval( )**

*Evaluation of shim results. Subclass of ShimOpt.*

**ShimCal( )**

*Calibration - for creating shim reference maps used in optimization.
Subclass of MaRdI.*

**ProbeTracking( )**

*Recording pressure-sensing respiratory probe.*

**ShimSpecs( )**

*System specifications Re: amplifier, DAC, etc.*

**ShimTest( )**

*Miscellaneous functions to test hardware performance. Subclass of ShimUse.*



For the documentation, in the Matlab command prompt type: 
	doc [class name]

## Notes

When contributing to the library, for maintainability, please adhere to the 
Matlab programming guidelines outlined by Richard Johnson:
https://www.mathworks.com/matlabcentral/fileexchange/2529-matlab-programming-style-guidelines

For general information on OO-programming in Matlab:
http://www.cs.ubc.ca/~murphyk/Software/matlabTutorial/html/objectOriented.html

All classes are * handle * as opposed to * value * classes. 
For more info on this distinction:
https://www.mathworks.com/help/matlab/matlab_oop/comparing-handle-and-value-classes.html  


=========================================================================
###Updated::20161120::ryan.topfer@polymtl.ca

## Todo...

