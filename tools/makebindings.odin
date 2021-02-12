package main;

import "bindgen/bindgen"

main :: proc() {
    
    options : bindgen.GeneratorOptions;
    bindgen.generate(
        packageName = "cgltf",
	foreignLibrary = "library/cgltf/build/cgltf.lib",
//        foreignLibrary = "cgltf",	
        outputFile = "cgltf.odin",
        headerFiles = []string{"../library/cgltf/cgltf.h"},
        options = options,
    );
}
