# fiberQuant
Quantify probtrackx connections between regions

##### About

FSL's [Probtrackx](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide#Probtrackx) can take diffusion images and generate a probablistic map for all the white matter fiber connections that pass through an arbitrary region of the brain. For example, we can compute the connections for each of the 384 regions (192 for each hemisphere) of the AICHA atlas. The role of fiberQuant is to compute the connections **between** all the regions (1-2, 1-3...1-192; 2-3, 2-4,...2-192, .... 191-192). This little executable does this efficiently. 

While this is a standalone executable, it is used as a part of the diffusion analyses of [nii_preprocess](https://github.com/neurolabusc/nii_preprocess). specifically the script nii_fiber_quantify.m. That script will either call the fast executable fiberQuant, or if it can not find the executable it runs the slower Matlab function fiberQXSub(). Since the executable and fiberQXSub() do the same thing, you can examine the Matlab function to understand the function of fiberQuant. 

##### Compiling


You will need the [FreePascal](https://freepascal.org) compiler. For MacOS, you can install this with [Homebrew](https://formulae.brew.sh/formula/fpc) using `brew install fpc`. For Debian-based Linux you can use `sudo apt install fpc`. For other operating systems see [SourceForge](https://sourceforge.net/projects/freepascal/files/Linux/3.0.4/). Compiling this executable is simple:


```
fpc fq.pas
```
