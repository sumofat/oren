//TODO(Ray):when we are ready to autgen the bindings to FMJ start here.

import "bindgen"

main :: proc() {
    options : bindgen.GeneratorOptions;
    bindgen.generate(
        packageName = "vk",
        foreignLibrary = "system:vulkan",
        outputFile = "vulkan.odin",
        headerFiles = []string{"../vulkan.h"},
        options = options,
    );
