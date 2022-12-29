from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout


class Slob4MemoConan(ConanFile):
    # Binary configuration
    settings = "os", "compiler", "build_type", "arch"
    requires = "slob/0.1"
    #generators = "cmake"
    generators = "CMakeDeps", "CMakeToolchain"#, "VirtualBuildEnv", "VirtualRunEnv"

    def layout(self):
        cmake_layout(self)

    def build(self):
      cmake = CMake(self)
      cmake.configure()
      cmake.build()