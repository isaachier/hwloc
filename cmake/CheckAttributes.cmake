if(__CHECK_ATTRIBUTES)
  return()
endif()
set(__CHECK_ATTRIBUTES 1)

include(AutoutilsWriteToConfigHeader)
include(CheckCSourceCompiles)

macro(check_attributes)
  check_c_source_compiles("
int square(int arg1 __attribute__ ((__unused__)), int arg2);
int square(int arg1, int arg2) { return arg2; }
int main() { return 0; }" _have_unused_attr)
  if(_have_unused_attr)
    autoutils_write_to_config_header("#define HWLOC_HAVE_ATTRIBUTE_UNUSED 1")
  endif()
endmacro()
