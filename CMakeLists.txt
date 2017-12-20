cmake_minimum_required(VERSION 3.1)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain.cmake"
    CACHE FILEPATH
    "Toolchain to use for building this package and dependencies")

execute_process(COMMAND /bin/sh config/hwloc_get_version.sh VERSION --version
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                RESULT_VARIABLE version_result
                OUTPUT_VARIABLE HWLOC_VERSION
                OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT version_result EQUAL 0)
  message(FATAL_ERROR
    "Cannot determine project version because an error occurred: "
    "${version_result}")
endif()
string(REGEX MATCH "^[0-9.]+" numeric_version "${HWLOC_VERSION}")

execute_process(
  COMMAND /bin/sh config/hwloc_get_version.sh VERSION --release-date
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  RESULT_VARIABLE release_date_result
  OUTPUT_VARIABLE HWLOC_RELEASE_DATE
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT release_date_result EQUAL 0)
  message(WARNING
    "Cannot determine project release date because an error occurred: "
    "${release_date_result}")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(HWLOC_DEBUG ON)
endif()

set(HWLOC_SYM_PREFIX "hwloc_" CACHE STRING "Prefix for hwloc symbols")
if(NOT HWLOC_SYM_PREFIX)
  message(FATAL_ERROR
    "HWLOC_SYM_PREFIX cannot be empty, use \"hwloc_\" instead")
endif()
string(TOUPPER HWLOC_SYM_PREFIX_CAPS "${HWLOC_SYM_PREFIX}")

if(HWLOC_SYM_PREFIX STREQUAL "hwloc_")
  set(HWLOC_SYM_TRANSFORM OFF)
else()
  set(HWLOC_SYM_TRANSFORM ON)
endif()

if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wmissing-prototypes -Wundef")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wpointer-arith -Wcast-align")
endif()

include(CheckCSourceCompiles)
include(CheckIncludeFile)
include(CheckSymbolExists)

include(CheckDecl)
include(CheckFunc)
include(CheckHeader)
include(CheckLib)
include(CheckType)
include(IncludesDefault)
include(WriteToConfigHeader)

macro(_hwloc_check_decl decl)
  string(MAKE_C_IDENTIFIER "${decl}" _var)
  string(TOUPPER "${_var}" _var)
  if(NOT DEFINED _have_symbol_${_var})
    check_symbol_exists(${decl} "${ARGN}" _have_symbol_${_var})
  endif()

  if(_have_symbol_${_var})
    check_c_source_compiles(
      "int main() { ${decl}(1, 2, 3, 4, 5, 6, 7, 8, 9, 10); return 0; }"
      compiler_failed_to_check)
    if(compiler_failed_to_check)
      set(HAVE_DECL_${_var} 0)
    else()
      set(HAVE_DECL_${_var} 1)
    endif()
    write_to_config_header("#define HAVE_DECL_${_var} ${HWLOC_HAVE_${var}}")
  endif()
endmacro()

set(components noos xml synthetic xml_nolibxml)

check_symbol_exists("__bgq__" "" bgq)
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "powerpc" AND
   CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
   bgq)
  set(HWLOC_BGQ_SYS 1)
  list(APPEND components bgq)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(HWLOC_LINUX_SYS 1)
  set(HWLOC_HAVE_LINUXIO 1)
  set(HWLOC_HAVE_LINUXPCI 1)
  list(APPEND components linux linuxio)
elseif(CMAKE_SYSTEM_NAME STREQUAL "IRIX")
  set(HWLOC_IRIX_SYS 1)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(HWLOC_DARWIN_SYS 1)
  list(APPEND components darwin)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Solaris")
  set(HWLOC_SOLARIS_SYS 1)
  list(APPEND components solaris)
elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
  set(HWLOC_AIX_SYS 1)
  list(APPEND components aix)
elseif(CMAKE_SYSTEM_NAME STREQUAL "HPUX")
  set(HWLOC_HPUX_SYS 1)
  list(APPEND components hpux)
elseif(WIN32)
  set(HWLOC_WIN_SYS 1)
  list(APPEND components windows)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  set(HWLOC_FREEBSD_SYS 1)
  list(APPEND components freebsd)
elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
  set(HWLOC_NETBSD_SYS 1)
  list(APPEND components netbsd)
else()
  message(WARNING "Unsupported! ${CMAKE_SYSTEM_NAME}")
  set(HWLOC_UNSUPPORTED_SYS 1)
  message(WARNING "hwloc does not support this system. "
    "hwloc will attempt to build (but it may not work). "
    "hwloc run-time results may be reduced to showing just one processor "
    "and binding will not be supported.")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.*86|x86_64|amd64)$")
  if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(HWLOC_X86_32_ARCH 1)
    set(HWLOC_MS_LIB_ARCH X86)
  else()
    if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
      message(STATUS "unknown -- assuming x86_64")
    endif()
    set(HWLOC_X86_64_ARCH 1)
    set(HWLOC_MS_LIB_ARCH X64)
  endif()
else()
  message("unknown processor ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(HWLOC_SIZEOF_UNSIGNED_LONG ${CMAKE_SIZEOF_UNSIGNED_LONG})
set(HWLOC_SIZEOF_UNSIGNED_INT ${CMAKE_SIZEOF_UNSIGNED_INT})

# TODO: Attributes
# TODO: Visibility

check_c_source_compiles("
int two_arg(int x, int y) { return 0; }
int foo(void) { return two_arg(3); }
int main() { return foo(); }" succeeds_on_incorrect_num_args)
if(NOT succeeds_on_incorrect_num_args)
  set(args_check ON)
endif()

check_symbol_exists("__IBMC__" "" ibm)
check_c_source_compiles("
#if defined(__INTEL_COMPILER) || defined(__ICC)
int main() { return 0; }
#endif" intel)

if(NOT args_check)
  message(WARNING
    "Your C compiler does not consider incorrect arguments to be a fatal "
    "error.")
  if(ibm)
    set(HWLOC_STRICT_ARGS_CFLAGS "-qhalt=e")
  elseif(intel)
    set(HWLOC_STRICT_ARGS_CFLAGS "-we140")
  else()
    message(WARNING
      "Please report this warning and configure using a different C compiler "
      "if possible")
  endif()

  if(HWLOC_STRICT_ARGS_CFLAGS)
    message(WARNING
      "CMake will append '${HWLOC_STRICT_ARGS_CFLAGS}' to the value of "
      "CMAKE_C_FLAGS when needed.")
  endif()
endif()

check_header("unistd.h")
check_header("dirent.h")
check_header("strings.h")
check_header("ctype.h")

check_func(strncasecmp)
if(HAVE_STRNCASECMP)
  _hwloc_check_decl(strncasecmp)
  if(HAVE_DECL_STRNCASECMP)
    set(HWLOC_HAVE_STRNCASECMP)
    write_to_config_header("#define HWLOC_HAVE_STRNCASECMP")
  endif()
endif(HAVE_STRNCASECMP)

check_func(strftime)
check_func(setlocale)

check_header("stdint.h")
if(HAVE_STDINT_H)
  set(HWLOC_HAVE_STDINT_H 1)
endif()

check_header("sys/mman.h")

set(types_to_check
  KAFFINITY
  PROCESSOR_CACHE_TYPE
  CACHE_DESCRIPTOR
  LOGICAL_PROCESSOR_RELATIONSHIP
  RelationProcessorPackage
  SYSTEM_LOGICAL_PROCESSOR_INFORMATION
  GROUP_AFFINITY
  PROCESSOR_RELATIONSHIP
  NUMA_NODE_RELATIONSHIP
  CACHE_RELATIONSHIP
  PROCESSOR_GROUP_INFO
  GROUP_RELATIONSHIP
  SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX
	PSAPI_WORKING_SET_EX_BLOCK
	PSAPI_WORKING_SET_EX_INFORMATION
	PROCESSOR_NUMBER)
set(CMAKE_REQUIRED_DEFINITIONS "-D_WIN32_WINNT=0x0601")
set(CMAKE_REQUIRED_INCLUDES "windows.h")
foreach(type ${types_to_check})
  check_type(${type})
endforeach()
set(CMAKE_REQUIRED_DEFINITIONS)
set(CMAKE_REQUIRED_INCLUDES)

check_lib(gdi32 main)
if(HAVE_LIBGDI32)
  list(APPEND libs gdi32)
endif()

check_lib(user32 PostQuitMessage)
if(HAVE_LIBUSER32)
  set(hwloc_have_user32 ON)
endif()

check_header("windows.h")

check_header("sys/lgrp_user.h")
if(HAVE_SYS_LGRP_USER_H)
  check_lib(lgrp lgrp_init)
  if(HAVE_LIBLGRP)
    list(APPEND libs lgrp)
  endif()
endif()

check_header("kstat.h")
if(HAVE_KSTAT_H)
  check_lib(kstat main)
  if(HAVE_LIBKSTAT)
    list(APPEND libs kstat)
  endif()
endif()

set(CMAKE_REQUIRED_LIBRARIES m)
check_decl(fabsf "math.h")
if(HAVE_DECL_FABSF)
  check_lib(m fabsf)
  if(HAVE_LIBM)
    list(APPEND libs m)
  endif()
endif()
set(CMAKE_REQUIRED_LIBRARIES)

check_header("picl.h")
if(HAVE_PICL_H)
  check_lib(picl picl_initialize)
  if(HAVE_LIBPICL)
    list(APPEND libs picl)
  endif()
endif()

foreach(decl _SC_NPROCESSORS_ONLN
         		 _SC_NPROCESSORS_CONF
         		 _SC_NPROC_ONLN
         		 _SC_NPROC_CONF
         		 _SC_PAGESIZE
         		 _SC_PAGE_SIZE
         		 _SC_LARGE_PAGESIZE)
  check_decl(${decl} "unistd.h")
endforeach()

check_header("mach/mach_host.h")

check_header("mach/mach_init.h")
if(HAVE_MACH_MACH_INIT_H)
  check_func(host_info)
endif()

check_header("sys/param.h")
check_header("sys/sysctl.h")
if(HAVE_SYS_SYSCTL_H)
  set(headers "sys/sysctl.h")
  if(HAVE_SYS_PARAM_H)
    list(APPEND headers "sys/param.h")
  endif()
  check_decl(CTL_HW "${headers}")
  check_decl(HW_NCPU "${headers}")
endif()

check_decl(strtoull "${includes_default}")
check_type(ssize_t "${includes_default}")
check_decl(snprintf "${includes_default}")
check_decl(strcasecmp "${includes_default}")
check_decl(_strdup "${includes_default}")
check_decl(_putenv "${includes_default}")

check_c_source_compiles("
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
int main() { return sysctl(NULL, 0, NULL, NULL, NULL, 0); }"
  HAVE_SYSCTL)
if(HAVE_SYSCTL)
  write_to_config_header("#define HAVE_SYSCTL 1")
else()
  write_to_config_header("/* #undef HAVE_SYSCTL */")
endif()

check_c_source_compiles("
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
int main() { return sysctlbyname(NULL, NULL, NULL, NULL, 0); }"
  HAVE_SYSCTLBYNAME)
if(HAVE_SYSCTLBYNAME)
  write_to_config_header("#define HAVE_SYSCTLBYNAME 1")
else()
  write_to_config_header("/* #undef HAVE_SYSCTLBYNAME */")
endif()

check_decl(getprogname "${includes_default}")
check_decl(getexecname "${includes_default}")
check_decl(GetModuleFileName "windows.h")

check_c_source_compiles("
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <errno.h>
#include <stdio.h>
extern char *program_invocation_name;
int main() { return printf(\"%s\", program_invocation_name); }"
  HAVE_PROGRAM_INVOCATION_NAME)
if(HAVE_PROGRAM_INVOCATION_NAME)
  write_to_config_header("#define HAVE_PROGRAM_INVOCATION_NAME 1")
else()
  write_to_config_header("/* #undef HAVE_PROGRAM_INVOCATION_NAME */")
endif()

check_c_source_compiles("
#include <stdio.h>
extern char *__progname;
int main() { return printf(\"%s\", __progname); }" HAVE___PROGNAME)
if(HAVE___PROGNAME)
  write_to_config_header("#define HAVE___PROGNAME 1")
else()
  write_to_config_header("/* #undef HAVE___PROGNAME */")
endif()

if(WIN32)
  set(hwloc_pid_t HANDLE)
  set(hwloc_thread_t HANDLE)
else()
  set(hwloc_pid_t pid_t)
  check_type(pthread_t "pthread.h")
  if(HAVE_PTHREAD_T)
    set(hwloc_thread_t pthread_t)
  endif()
endif()
write_to_config_header("#define hwloc_pid_t ${hwloc_pid_t}")
if(hwloc_thread_t)
  write_to_config_header("#define hwloc_thread_t ${hwloc_thread_t}")
endif()

set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")
if(NOT args_check AND NOT HWLOC_STRICT_ARGS_CFLAGS)
  message(FATAL_ERROR
          "Support for sched_setaffinity() requires a C compiler which "
          "considers incorrect argument counts to be a fatal error. "
          "Cannot continue.")
elseif(NOT args_check AND HWLOC_STRICT_ARGS_CFLAGS)
  set(CMAKE_REQUIRED_FLAGS ${HWLOC_STRICT_ARGS_CFLAGS})
endif()
_hwloc_check_decl(sched_setaffinity "sched.h")
set(CMAKE_REQUIRED_DEFINITIONS)
set(CMAKE_REQUIRED_FLAGS)
