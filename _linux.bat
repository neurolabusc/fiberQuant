#!/bin/sh

#cd ~/Documents/pas/FiberQuant/


#compile Surfice as 64-bit Cocoa (OpenGL 4.1 Core)
#cp ./optsCore.inc ./opts.inc
#/Developer/lazarus/lazbuild ./surfice.lpr --cpu=x86_64 --ws=cocoa --compiler="/usr/local/bin/ppcx64"
#/Developer/lazarus/lazbuild ./surfice.lpr --ws=cocoa
#strip ./surfice
#cp surfice /Users/rorden/Desktop/Surf_Ice/surfice.app/Contents/MacOS/surfice

fpc fq.pas
strip ./fq
mv ./fq ./fiberQuantLX
rm *.bak
rm *.o
rm *.ppu
rm -rf lib
rm -rf backup


