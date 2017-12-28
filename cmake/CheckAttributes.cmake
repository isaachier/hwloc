if(__check_attributes)
  return()
endif()
set(__check_attributes 1)

include(AutoutilsWriteToConfigHeader)

include(CheckCSourceCompiles)

macro(_compile_test attr test code)
  file(WRITE
    "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/CMakeTmp/attribute_${test}.c"
    "${code}")
  file(READ
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/attribute_${test}.c.in"
    template_code)
  file(APPEND
    "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/CMakeTmp/attribute_${test}.c"
    "${template_code}")

  try_compile(
    ${attr}_${test}_compiled
    ${CMAKE_CURRENT_BINARY_DIR}
    SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/CMakeTmp/attribute_${test}.c"
    COMPILE_DEFINITIONS "${CMAKE_REQUIRED_FLAGS}"
    OUTPUT_VARIABLE ${attr}_${test}_output)
endmacro()

macro(_check_specific_attribute attr basic_test fail_test)
  _compile_test(${attr} basic_test "${basic_test}")
  if(NOT DEFINED have_${attr}_attribute)
    if(NOT CMAKE_REQUIRED_QUIET)
      message(STATUS "Checking for attribute ${attr}")
    endif()

    if(${attr}_basic_test_compiled AND
       NOT ${attr}_basic_test_output MATCHES "ignore|skip")
      set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -Werror")

      _compile_test(${attr} fail_test "${fail_test}")
      if(NOT ${attr}_fail_test_compiled AND
         NOT ${attr}_fail_test_output MATCHES "ignore|skip")
        set(have_${attr}_attribute ON CACHE INTERNAL
           "Supports attribute ${attr}")
      else()
        set(have_${attr}_attribute OFF CACHE INTERNAL
           "Supports attribute ${attr}")
      endif()
    else()
      set(have_${attr}_attribute OFF CACHE INTERNAL
         "Supports attribute ${attr}")
    endif()

    if(NOT CMAKE_REQUIRED_QUIET)
      if(have_${attr}_attribute)
        message(STATUS "Checking for attribute ${attr} - Success")
      else()
        message(STATUS "Checking for attribute ${attr} - Failed")
      endif()
    endif()
  endif()

  string(TOUPPER "${attr}" attr_caps)
  if(have_${attr}_attribute)
    autoutils_write_to_config_header(
      "#define HWLOC_HAVE_ATTRIBUTE_${attr_caps} 1")
  else()
    autoutils_write_to_config_header(
      "#define HWLOC_HAVE_ATTRIBUTE_${attr_caps} 0")
  endif()
endmacro()

macro(_check_have_unused_attribute)
  _check_specific_attribute(unused "
int square(int arg1 __attribute__((__unused__)), int arg2);
int square(int arg1, int arg2) { return arg2; }
" "")
endmacro()

macro(_check_have_format_attribute)
  if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    set(CMAKE_REQUIRED_FLAGS "-Wall")
  elseif(CMAKE_C_COMPILER_ID STREQUAL "Intel")
    set(CMAKE_REQUIRED_FLAGS "-we181")
  endif()

  _check_specific_attribute(format "
int this_printf(void *my_object, const char *my_format, ...)
__attribute__ ((__format__ (__printf__, 2, 3)));
" "
static int usage (int *argument);
extern int this_printf(int arg1, const char *my_format, ...)
__attribute__ ((__format__ (__printf__, 2, 3)));

int this_printf(int arg1, const char *my_format, ...)
{
    return 0;
}

static int usage(int *argument) {
    return this_printf(*argument, \"%d\", argument);
/* This should produce a format warning */
}
/* The generated main-function is int main(),
   which produces a warning by itself */
int main(void);
")

  set(CMAKE_REQUIRED_FLAGS)
endmacro()

macro(check_attributes)
  _check_have_unused_attribute()
  _check_have_format_attribute()
endmacro()
