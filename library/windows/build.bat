call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
@echo off

setlocal
 
where cl >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (echo WARNING: cl is not in the path - please set up Visual Studio to do cl builds)

IF NOT EXIST build mkdir build
pushd build

set CommonCompilerFlagsNoLink= -c -TC -arch:AVX -GR- -MTd -nologo -fp:fast -Gm- -GR- -sdl- -EHa- -Od -Oi -WX -W4 -wd4457 -wd4018 -wd4459 -wd4389 -wd4312 -wd4245 -wd4996 -wd4201 -wd4100 -wd4506 -wd4127 -wd4189 -wd4505 -wd4577 -wd4101 -wd4702 -wd4456 -wd4238 -wd4244 -wd4366 -wd4700 -wd4701 -wd4703 -wd4805 -wd4091 -wd4706 -wd4197 -wd4324 -DWINDOWS=1 -FC -ZI
REM set CommonCompilerFlagsNoLink= -std:c++14 -EHsc -arch:AVX -GR- -MTd -nologo -fp:fast -Gm- -GR- -sdl- -EHa- -Od -Oi -WX -W4  -wd4018 -wd4459 -wd4389 -wd4312 -wd4245 -wd4996 -wd4201 -wd4100 -wd4506 -wd4127 -wd4189 -wd4505 -wd4577 -wd4101 -wd4702 -wd4238 -wd4244 -wd4366 -wd4700 -wd4701 -wd4703 -wd4805 -wd4091 -wd4706 -wd4197 -wd4324 -FC -ZI -DWINDOWS=1
cl %CommonCompilerFlagsNoLink%  ../win32_c.c -Fdwin32_c.pdb -Fmwin32_c.map /c

lib win32_c.obj Kernel32.lib user32.lib gdi32.lib winmm.lib Ws2_32.lib Ole32.lib Xinput9_1_0.lib DXGI.lib D3D12.lib D3DCompiler.lib ../../fmj/build/fmj.lib

popd

