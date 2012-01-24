@echo off

setlocal
set curr=%CD%

cd ../sourcemod-compiler
set compdir=%CD%
cd %curr%
"%compdir%/spcomp.exe" Randomizer.sp -oRandomizer.smx

cd %curr%
endlocal
