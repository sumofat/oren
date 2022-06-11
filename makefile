
default:
	odin.exe build ../oren_demo/game_main.odin -file -debug -o:minimal

rel:
	odin.exe build ../oren_demo/game_main.odin -file
