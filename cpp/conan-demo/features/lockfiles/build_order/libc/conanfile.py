from conans import ConanFile

required_conan_version = ">=1.28"

class LibCConan(ConanFile):
    requires = "liba/[>0.0 <1.0]@user/testing"
