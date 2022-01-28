REM odin run main.odin -out:main.exe -subsystem:windows -debug
REM odin build main.odin -out:oren.dll -subsystem:windows -debug -opt:0
REM odin build oren.odin -out:oren.dll -build-mode=dll -debug -opt:0
odin build ../oren_demo/game_main.odin -out:game_main.exe -subsystem:console -debug -opt:0
