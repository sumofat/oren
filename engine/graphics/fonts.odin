package graphics

/*
First fix sprites to be able to handle arbiturary meshes with uvs etc... similar
to what we did with sprite batching so that when we add a sprite it pushes the data to the 
buffer than draw with one call so long as the texture is the same.


eventually we would like to use indirect rendering but for now we do basics.

We need those to do reasonable dynamic font rendering.


*/

import stb_tt "vendor:stb/truetype"





