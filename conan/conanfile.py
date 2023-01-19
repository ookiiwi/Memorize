from conan import ConanFile
from conan.tools.files import copy
import os

androidArchMap = {
    'x86': 'x86',
    'x86_64': 'x86_64',
    'armv8': 'arm64-v8a',
    'armv7': 'armeabi-v7a',
}


class DicoConan(ConanFile):
    requires = "dico/0.2",
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False]}
    default_options = {"shared": True}

    def generate(self):
        for dep in self.dependencies.values():
            arch = str(self.settings.arch)
            wd = os.path.dirname(os.path.realpath(__file__))
            dst = os.path.realpath(wd + "/../android/app/src/main/jniLibs/" + androidArchMap[arch])

            copy(self, "*.so", dep.cpp_info.libdirs[0], dst)