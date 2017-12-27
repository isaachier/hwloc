cmake_minimum_required(VERSION 3.1)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain.cmake"
    CACHE FILEPATH
    "Toolchain to use for building this package and dependencies")

include(CheckCSourceCompiles)
include(CheckIncludeFile)
include(CheckSymbolExists)
include(CMakeDependentOption)

include(HunterGate)
HunterGate(
    URL "https://github.com/ruslo/hunter/archive/v0.19.213.tar.gz"
    SHA1 "59b2b880178bdc1e9cce83f279f1d88feefa07a2"
)

execute_process(COMMAND /bin/sh config/hwloc_get_version.sh VERSION --version
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                RESULT_VARIABLE version_result
                OUTPUT_VARIABLE version_output
                OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT version_result EQUAL 0)
  message(FATAL_ERROR
    "Cannot determine project version because an error occurred: "
    "${version_result}")
endif()

set(HWLOC_VERSION "${version_output}")

execute_process(
  COMMAND /bin/sh config/hwloc_get_version.sh VERSION --release-date
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  RESULT_VARIABLE release_date_result
  OUTPUT_VARIABLE release_date_output
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT release_date_result EQUAL 0)
  message(WARNING
    "Cannot determine project release date because an error occurred: "
    "${release_date_result}")
endif()

set(HWLOC_RELEASE_DATE "${release_date_output}")

string(REGEX MATCH "^[0-9.]+" numeric_version "${HWLOC_VERSION}")
project(hwloc VERSION "${numeric_version}")

hunter_add_package(autoutils)
find_package(autoutils CONFIG REQUIRED)

set(autoutils_config_path
    "${CMAKE_CURRENT_BINARY_DIR}/include/private/autogen/config.h"
    CACHE FILEPATH "Path to generated config.h")

include(AutoutilsCheckDecl)
include(AutoutilsCheckFunc)
include(AutoutilsCheckHeader)
include(AutoutilsCheckLib)
include(AutoutilsCheckType)
include(AutoutilsIncludesDefault)
include(AutoutilsWriteToConfigHeader)

autoutils_write_to_config_header("#define HWLOC_VERSION \"${HWLOC_VERSION}\"")

# Set default include headers in new list variable `includes_default`
autoutils_includes_default(includes_default)

set(HWLOC_MODE "standalone" CACHE STRING "Mode for building hwloc")
set_property(CACHE HWLOC_MODE PROPERTY STRINGS "embedded;standalone")
if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND HWLOC_MODE STREQUAL "embedded")
  message(FATAL_ERROR
          "Cannot use embedded mode for debug build, "
          "please set HWLOC_MODE to standalone or change CMAKE_BUILD_TYPE")
endif()

set(HWLOC_SYM_PREFIX "hwloc_" CACHE STRING "Prefix for hwloc symbols")

if(HWLOC_SYM_PREFIX STREQUAL "")
  message(FATAL_ERROR
    "HWLOC_SYM_PREFIX cannot be empty, use \"hwloc_\" instead")
endif()

autoutils_write_to_config_header(
  "#define HWLOC_SYM_PREFIX ${HWLOC_SYM_PREFIX}")

string(TOUPPER "${HWLOC_SYM_PREFIX}" HWLOC_SYM_PREFIX_CAPS)
autoutils_write_to_config_header(
  "#define HWLOC_SYM_PREFIX_CAPS ${HWLOC_SYM_PREFIX_CAPS}")

# TODO: Handle these options
if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(USING_GNU)
endif()
cmake_dependent_option(HWLOC_ENABLE_PICKY
  "Enable maximum compiler pickyness" ON
  "USING_GNU" OFF)
option(HWLOC_ENABLE_CAIRO ON)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.*86|x86_64|amd64)$")
  set(IS_X86 ON)
endif()
cmake_dependent_option(HWLOC_ENABLE_CPUID
  "Enable the cpuid-based architecture specific support (x86 component)" ON
  "IS_X86" OFF)
option(HWLOC_ENABLE_LIBXML2 ON)

option(HWLOC_ENABLE_IO
       "Enable I/O discovery (PCI, LinuxIO, CUDA, OpenCL, NVML, GL)"
       ON)
cmake_dependent_option(
  HWLOC_ENABLE_PCI "Enable the PCI device discovery" ON
  "HWLOC_ENABLE_IO" OFF)
cmake_dependent_option(
  HWLOC_ENABLE_OPENCL "Enable the OpenCL device discovery" ON
  "HWLOC_ENABLE_IO" OFF)
cmake_dependent_option(
  HWLOC_ENABLE_CUDA "Enable the CUDA device discovery" ON
  "HWLOC_ENABLE_IO" OFF)
cmake_dependent_option(
  HWLOC_ENABLE_NVML "Enable the nvml device discovery" ON
  "HWLOC_ENABLE_IO" OFF)
cmake_dependent_option(
  HWLOC_ENABLE_GL "Enable the gl device discovery" ON
  "HWLOC_ENABLE_IO" OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(LINUX ON)
endif()
cmake_dependent_option(
  HWLOC_ENABLE_LIBUDEV "Enable the Linux libudev support" ON "LINUX" OFF)
set(HWLOC_PLUGINS "" CACHE STRING
    "Build the given components as dynamically-loaded plugins")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(HWLOC_DEBUG ON CACHE BOOL INTERNAL "${_doc}")
  autoutils_write_to_config_header("#define HWLOC_DEBUG")
else()
  set(HWLOC_DEBUG OFF CACHE BOOL INTERNAL "${_doc}")
  autoutils_write_to_config_header("/* #undef HWLOC_DEBUG */")
endif()

set(_doc "whether or not to transform hwloc symbols")
if(HWLOC_SYM_PREFIX STREQUAL "hwloc_")
  set(HWLOC_SYM_TRANSFORM OFF)
  autoutils_write_to_config_header("/* #undef HWLOC_SYM_TRANSFORM */")
else()
  set(HWLOC_SYM_TRANSFORM ON)
  autoutils_write_to_config_header("#define HWLOC_SYM_TRANSFORM")
endif()

autoutils_write_to_config_header("#ifndef _HPUX_SOURCE
#undef _HPUX_SOURCE
#endif
#define _HPUX_SOURCE 1")

autoutils_write_to_config_header(
  "#define SIZEOF_VOID_P ${CMAKE_SIZEOF_VOID_P}")

if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wmissing-prototypes -Wundef")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wpointer-arith -Wcast-align")
endif()

macro(_hwloc_check_decl decl)
  string(MAKE_C_IDENTIFIER "${decl}" _var)
  string(TOUPPER "${_var}" _var)
  check_symbol_exists(${decl} "${ARGN}" _have_symbol_${_var})

  if(_have_symbol_${_var})
    set(_code)
    foreach(arg ${ARGN})
      set(_code "${_code}#include <${arg}>\n")
    endforeach()
    set(_code
        "${_code}int main() ")
    set(_code "${_code}{ ${decl}(1, 2, 3, 4, 5, 6, 7, 8, 9, 10); return 0; }\n")
    check_c_source_compiles("${_code}" compiler_failed_to_check_${_var})
    if(compiler_failed_to_check_${_var})
      set(HAVE_DECL_${_var} 0)
    else()
      set(HAVE_DECL_${_var} 1)
    endif()
    autoutils_write_to_config_header(
      "#define HAVE_DECL_${_var} ${HAVE_DECL_${_var}}")
  endif()
endmacro()

set(components noos xml synthetic xml_nolibxml)

check_symbol_exists("__bgq__" "" bgq)
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "powerpc" AND
   CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
   bgq)
  set(HWLOC_HAVE_BGQ 1)
  autoutils_write_to_config_header("#define HWLOC_BGQ_SYS 1")
  list(APPEND components bgq)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(HWLOC_LINUX_SYS ON)
  autoutils_write_to_config_header("#define HWLOC_LINUX_SYS 1")
  autoutils_write_to_config_header("#define HWLOC_HAVE_LINUXIO 1")
  autoutils_write_to_config_header("#define HWLOC_HAVE_LINUXPCI 1")
  list(APPEND components linux linuxio)
elseif(CMAKE_SYSTEM_NAME STREQUAL "IRIX")
  autoutils_write_to_config_header("#define HWLOC_IRIX_SYS 1")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  autoutils_write_to_config_header("#define HWLOC_DARWIN_SYS 1")
  list(APPEND components darwin)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Solaris")
  autoutils_write_to_config_header("#define HWLOC_SOLARIS_SYS 1")
  list(APPEND components solaris)
elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
  autoutils_write_to_config_header("#define HWLOC_AIX_SYS 1")
  list(APPEND components aix)
elseif(CMAKE_SYSTEM_NAME STREQUAL "HPUX")
  autoutils_write_to_config_header("#define HWLOC_HPUX_SYS 1")
  list(APPEND components hpux)
elseif(WIN32)
  set(HWLOC_HAVE_WINDOWS ON)
  autoutils_write_to_config_header("#define HWLOC_WIN_SYS 1")
  list(APPEND components windows)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  autoutils_write_to_config_header("#define HWLOC_FREEBSD_SYS 1")
  list(APPEND components freebsd)
elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
  autoutils_write_to_config_header("#define HWLOC_NETBSD_SYS 1")
  list(APPEND components netbsd)
else()
  message(WARNING "Unsupported! ${CMAKE_SYSTEM_NAME}")
  autoutils_write_to_config_header("#define HWLOC_UNSUPPORTED_SYS 1")
  message(WARNING "hwloc does not support this system. "
    "hwloc will attempt to build (but it may not work). "
    "hwloc run-time results may be reduced to showing just one processor "
    "and binding will not be supported.")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.*86|x86_64|amd64)$")
  if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(hwloc_cpu_define "#define HWLOC_X86_32_ARCH 1")
    autoutils_write_to_config_header("${hwloc_cpu_define}")
    set(HWLOC_MS_LIB_ARCH X86)
  else()
    if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
      message(STATUS "unknown -- assuming x86_64")
    endif()
    set(hwloc_cpu_define "#define HWLOC_X86_64_ARCH 1")
    autoutils_write_to_config_header("${hwloc_cpu_define}")
    set(HWLOC_MS_LIB_ARCH X64)
  endif()
else()
  message("unknown processor ${CMAKE_SYSTEM_PROCESSOR}")
endif()

check_type_size("unsigned long" HWLOC_SIZEOF_UNSIGNED_LONG)
autoutils_write_to_config_header(
  "#define HWLOC_SIZEOF_UNSIGNED_LONG ${HWLOC_SIZEOF_UNSIGNED_LONG}")
check_type_size("unsigned int" HWLOC_SIZEOF_UNSIGNED_INT)
autoutils_write_to_config_header(
  "#define HWLOC_SIZEOF_UNSIGNED_INT ${HWLOC_SIZEOF_UNSIGNED_INT}")

include(CheckAttributes)
check_attributes()

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

autoutils_check_header("unistd.h")
autoutils_check_header("dirent.h")
autoutils_check_header("strings.h")
autoutils_check_header("ctype.h")

autoutils_check_func(strncasecmp)
if(HAVE_STRNCASECMP)
  _hwloc_check_decl(strncasecmp)
  if(HAVE_DECL_STRNCASECMP)
    autoutils_write_to_config_header("#define HWLOC_HAVE_STRNCASECMP")
  endif()
endif(HAVE_STRNCASECMP)

autoutils_check_func(strftime)
autoutils_check_func(setlocale)

autoutils_check_header("stdint.h")
if(HAVE_STDINT_H)
  set(HWLOC_HAVE_STDINT_H ON)
  autoutils_write_to_config_header("#define HWLOC_HAVE_STDINT_H 1")
endif()

autoutils_check_header("sys/mman.h")

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
  autoutils_check_type(${type})
endforeach()
set(CMAKE_REQUIRED_DEFINITIONS)
set(CMAKE_REQUIRED_INCLUDES)

autoutils_check_lib(gdi32 main)
if(HAVE_LIBGDI32)
  list(APPEND libs gdi32)
endif()

autoutils_check_lib(user32 PostQuitMessage)
if(HAVE_LIBUSER32)
  set(hwloc_have_user32 ON)
endif()

autoutils_check_header("windows.h")
if(HAVE_WINDOWS_H)
  set(HWLOC_HAVE_WINDOWS_H ON)
endif()

autoutils_check_header("sys/lgrp_user.h")
if(HAVE_SYS_LGRP_USER_H)
  autoutils_check_lib(lgrp lgrp_init)
  if(HAVE_LIBLGRP)
    list(APPEND libs lgrp)
  endif()
endif()

autoutils_check_header("kstat.h")
if(HAVE_KSTAT_H)
  autoutils_check_lib(kstat main)
  if(HAVE_LIBKSTAT)
    list(APPEND libs kstat)
  endif()
endif()

set(CMAKE_REQUIRED_LIBRARIES m)
autoutils_check_decl(fabsf "math.h")
if(HAVE_DECL_FABSF)
  autoutils_check_lib(m fabsf)
  if(HAVE_LIBM)
    list(APPEND libs m)
  endif()
endif()
set(CMAKE_REQUIRED_LIBRARIES)

autoutils_check_header("picl.h")
if(HAVE_PICL_H)
  autoutils_check_lib(picl picl_initialize)
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
  autoutils_check_decl(${decl} "unistd.h")
endforeach()

autoutils_check_header("mach/mach_host.h")

autoutils_check_header("mach/mach_init.h")
if(HAVE_MACH_MACH_INIT_H)
  autoutils_check_func(host_info)
endif()

autoutils_check_header("sys/param.h")
autoutils_check_header("sys/sysctl.h")
if(HAVE_SYS_SYSCTL_H)
  set(headers "sys/sysctl.h")
  if(HAVE_SYS_PARAM_H)
    list(APPEND headers "sys/param.h")
  endif()
  autoutils_check_decl(CTL_HW "${headers}")
  autoutils_check_decl(HW_NCPU "${headers}")
endif()

autoutils_check_decl(strtoull "${includes_default}")
autoutils_check_type(ssize_t "${includes_default}")
autoutils_check_decl(snprintf "${includes_default}")
autoutils_check_decl(strcasecmp "${includes_default}")
autoutils_check_decl(_strdup "${includes_default}")
autoutils_check_decl(_putenv "${includes_default}")

check_c_source_compiles("
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
int main() { return sysctl(NULL, 0, NULL, NULL, NULL, 0); }"
  HAVE_SYSCTL)
if(HAVE_SYSCTL)
  autoutils_write_to_config_header("#define HAVE_SYSCTL 1")
else()
  autoutils_write_to_config_header("/* #undef HAVE_SYSCTL */")
endif()

check_c_source_compiles("
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
int main() { return sysctlbyname(NULL, NULL, NULL, NULL, 0); }"
  HAVE_SYSCTLBYNAME)
if(HAVE_SYSCTLBYNAME)
  autoutils_write_to_config_header("#define HAVE_SYSCTLBYNAME 1")
else()
  autoutils_write_to_config_header("/* #undef HAVE_SYSCTLBYNAME */")
endif()

autoutils_check_decl(getprogname "${includes_default}")
autoutils_check_decl(getexecname "${includes_default}")
autoutils_check_decl(GetModuleFileName "windows.h")

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
  autoutils_write_to_config_header("#define HAVE_PROGRAM_INVOCATION_NAME 1")
else()
  autoutils_write_to_config_header("/* #undef HAVE_PROGRAM_INVOCATION_NAME */")
endif()

check_c_source_compiles("
#include <stdio.h>
extern char *__progname;
int main() { return printf(\"%s\", __progname); }" HAVE___PROGNAME)
if(HAVE___PROGNAME)
  autoutils_write_to_config_header("#define HAVE___PROGNAME 1")
else()
  autoutils_write_to_config_header("/* #undef HAVE___PROGNAME */")
endif()

if(WIN32)
  set(hwloc_pid_t HANDLE)
  set(hwloc_thread_t HANDLE)
else()
  set(hwloc_pid_t pid_t)
  autoutils_check_type(pthread_t "pthread.h")
  if(HAVE_PTHREAD_T)
    set(hwloc_thread_t pthread_t)
  endif()
endif()
autoutils_write_to_config_header("#define hwloc_pid_t ${hwloc_pid_t}")
if(hwloc_thread_t)
  autoutils_write_to_config_header("#define hwloc_thread_t ${hwloc_thread_t}")
endif()

if(NOT args_check AND NOT HWLOC_STRICT_ARGS_CFLAGS)
  message(FATAL_ERROR
          "Support for sched_setaffinity() requires a C compiler which "
          "considers incorrect argument counts to be a fatal error. "
          "Cannot continue.")
elseif(NOT args_check AND HWLOC_STRICT_ARGS_CFLAGS)
  set(CMAKE_REQUIRED_FLAGS ${HWLOC_STRICT_ARGS_CFLAGS})
endif()
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")
_hwloc_check_decl(sched_setaffinity "sched.h")
if(HAVE_DECL_SCHED_SETAFFINITY)
  autoutils_write_to_config_header("#define HWLOC_HAVE_SCHED_SETAFFINITY 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_SCHED_SETAFFINITY */")
endif()

check_c_source_compiles("
#include <sched.h>
static unsigned long mask;
int main() { sched_setaffinity(0, (void*) &mask); return 0; }"
  HWLOC_HAVE_OLD_SCHED_SETAFFINITY)
if(HWLOC_HAVE_OLD_SCHED_SETAFFINITY)
  autoutils_write_to_config_header("#define HWLOC_HAVE_OLD_SCHED_SETAFFINITY 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_OLD_SCHED_SETAFFINITY */")
endif()
set(CMAKE_REQUIRED_FLAGS)

check_c_source_compiles("
#include <sched.h>
cpu_set_t set;
int main() { CPU_ZERO(&set); CPU_SET(0, &set); return 0; }"
  HWLOC_HAVE_CPU_SET)
if(HWLOC_HAVE_CPU_SET)
  autoutils_write_to_config_header("#define HWLOC_HAVE_CPU_SET 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_CPU_SET */")
endif()

check_c_source_compiles("
#include <sched.h>
cpu_set_t *set;
int main()
{
  set = CPU_ALLOC(1024);
  CPU_ZERO_S(CPU_ALLOC_SIZE(1024), set);
  CPU_SET_S(CPU_ALLOC_SIZE(1024), 0, set);
  CPU_FREE(set);
  return 0;
  }" HWLOC_HAVE_CPU_SET_S)
if(HWLOC_HAVE_CPU_SET_S)
  autoutils_write_to_config_header("#define HWLOC_HAVE_CPU_SET_S 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_CPU_SET_S */")
endif()

check_c_source_compiles("
#include <unistd.h>
#include <sys/syscall.h>
int main() { syscall(0, 1, 2, 3, 4, 5, 6); return 0; }" HWLOC_HAVE_SYSCALL)
if(HWLOC_HAVE_SYSCALL)
  autoutils_write_to_config_header("#define HWLOC_HAVE_SYSCALL 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_SYSCALL */")
endif()

autoutils_check_func(ffs)
if(HAVE_FFS)
  _hwloc_check_decl(ffs)
  if(HAVE_DECL_FFS)
    autoutils_write_to_config_header("#define HWLOC_HAVE_DECL_FFS 1")
    # TODO: Detect gccfss
  else()
    autoutils_write_to_config_header("/* #undef HWLOC_HAVE_DECL_FFS */")
  endif()
  autoutils_write_to_config_header("#define HWLOC_HAVE_FFS 1")
endif()

foreach(func ffsl fls flsl clz clzl)
  autoutils_check_func(${func})
  string(TOUPPER ${func} func_name)
  if(HAVE_${func_name})
    _hwloc_check_decl(${func})
    if(HAVE_DECL_${func_name})
      autoutils_write_to_config_header("#define HWLOC_HAVE_DECL_${func_name} 1")
    else()
      autoutils_write_to_config_header("/* #undef HWLOC_HAVE_DECL_${func_name} */")
    endif()
    autoutils_write_to_config_header("#define HWLOC_HAVE_${func_name} 1")
  endif()
endforeach()

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
  autoutils_check_func(openat)
  if(HAVE_OPENAT)
    set(hwloc_have_openat 1)
  endif()
endif()

autoutils_check_header("malloc.h")
autoutils_check_func(getpagesize)
autoutils_check_func(memalign)
autoutils_check_func(posix_memalign)

autoutils_check_header("sys/utsname.h")
autoutils_check_func(uname)

# TODO: embedded mode
if(HWLOC_MODE STREQUAL "embedded")
  set(HAVE_DECL_RUNNING_ON_VALGRIND 0)
  autoutils_write_to_config_header("#define HAVE_DECL_RUNNING_ON_VALGRIND 0")
else()
  autoutils_check_header("valgrind/valgrind.h")
  if(HAVE_VALGRIND_VALGRIND_H)
    autoutils_check_decl(RUNNING_ON_VALGRIND "valgrind/valgrind.h")
  endif()
endif()

autoutils_check_header("pthread_np.h")
set(headers "pthread.h")
if(HAVE_PTHREAD_NP_H)
  list(APPEND headers "pthread_np.h")
endif()
autoutils_check_decl(pthread_setaffinity_np ${headers})
autoutils_check_decl(pthread_getaffinity_np ${headers})
autoutils_check_func(sched_setaffinity)

if(HAVE_SCHED_SETAFFINITY)
  set(hwloc_have_sched_setaffinity ON)
endif()

autoutils_check_header("sys/cpuset.h")
autoutils_check_func(cpuset_setaffinity)
set(CMAKE_REQUIRED_LIBRARIES pthread)
autoutils_check_func(pthread_getthrds_np)
if(HAVE_PTHREAD_GETTHRDS_NP)
  autoutils_write_to_config_header("#define HWLOC_HAVE_PTHREAD_GETTHRDS_NP 1")
else()
  autoutils_write_to_config_header("/* #undef HWLOC_HAVE_PTHREAD_GETTHRDS_NP */")
endif()
set(CMAKE_REQUIRED_LIBRARIES)
autoutils_check_func(cpuset_setid)

if(HWLOC_ENABLE_LIBUDEV)
  autoutils_check_header("libudev.h")
  if(HAVE_LIBUDEV_H)
    autoutils_check_lib(udev udev_device_new_from_subsystem_sysname)
    if(HAVE_LIBUDEV)
      list(APPEND libs libudev)
      autoutils_write_to_config_header("#define HWLOC_HAVE_LIBUDEV 1")
    else()
      autoutils_write_to_config_header("/* #undef HWLOC_HAVE_LIBUDEV */")
    endif()
  endif()
endif()

if(HWLOC_ENABLE_PCI)
  autoutils_check_header("pciaccess.h")
  if(HAVE_PCIACCESS_H)
    autoutils_check_lib(pciaccess pci_slot_match_iterator_create)
    if(HAVE_LIBPCIACCESS)
      list(APPEND libs pciaccess)
      list(APPEND components pci)
    endif()
  endif()
endif()

if(HWLOC_ENABLE_OPENCL)
  autoutils_check_header("CL/cl_ext.h")
  if(HAVE_CL_CL_EXT_H)
    autoutils_check_lib(OpenCL clGetDeviceIDs)
    if(HAVE_LIBOPENCL)
      autoutils_check_decl(CL_DEVICE_TOPOLOGY_AMD "CL/cl_ext.h")
      if(HAVE_DECL_CL_DEVICE_TOPOLOGY_AMD)
        list(APPEND libs OpenCL)
        list(APPEND components opencl)
        set(HWLOC_HAVE_OPENCL 1)
        autoutils_write_to_config_header("#define HWLOC_HAVE_OPENCL ${HWLOC_HAVE_OPENCL}")
      endif()
    endif()
  endif()
endif()

if(HWLOC_ENABLE_CUDA)
  autoutils_check_header("cuda.h")
  if(HAVE_CUDA_H)
    check_c_source_compiles("
#include <cuda.h>
#ifndef CUDA_VERSION
#error CUDA_VERSION undefined
#elif CUDA_VERSION < 3020
#error CUDA_VERSION too old
#endif
int main() { return 0; }" _have_cuda)
    if(_have_cuda)
      autoutils_check_lib(cuda cuInit)
      if(HAVE_LIBCUDA)
        set(HWLOC_HAVE_CUDA 1)
        autoutils_write_to_config_header("#define HWLOC_HAVE_CUDA ${HWLOC_HAVE_CUDA}")
      endif()
    endif()
  endif()

  autoutils_check_header("cuda_runtime_api.h")
  if(HAVE_CUDA_RUNTIME_API_H)
    check_c_source_compiles("
#include <cuda_runtime_api.h>
#ifndef CUDART_VERSION
#error CUDART_VERSION undefined
#elif CUDART_VERSION < 3020
#error CUDART_VERSION too old
#endif
int main() { return 0; }" _have_cudart)
    if(_have_cudart)
      autoutils_check_lib(cudart cudaGetDeviceProperties)
      if(HAVE_LIBCUDART)
        list(APPEND components cuda)
        set(HWLOC_HAVE_CUDART 1)
        autoutils_write_to_config_header("#define HWLOC_HAVE_CUDART ${HWLOC_HAVE_CUDART}")
      endif()
    endif()
  endif()
endif()

if(HWLOC_ENABLE_NVML)
  autoutils_check_header("nvml.h")
  if(HAVE_NVML_H)
    autoutils_check_lib("nvidia-ml" nvmlInit)
    if(HAVE_LIBNVIDIA_ML)
      autoutils_check_decl(nvmlDeviceGetMaxPcieLinkGeneration "nvml.h")
      list(APPEND libs "nvidia-ml")
      list(APPEND components nvml)
      set(HWLOC_HAVE_NVML 1)
      autoutils_write_to_config_header("#define HWLOC_HAVE_NVML ${HWLOC_HAVE_NVML}")
    endif()
  endif()
endif()

autoutils_check_header("X11/Xlib.h")
if(HAVE_X11_XLIB_H)
  autoutils_check_lib(X11 XOpenDisplay)
  if(HAVE_LIBX11)
    autoutils_check_header("X11/Xutil.h")
    if(HAVE_X11_XUTIL_H)
      autoutils_check_header("X11/keysym.h")
      if(HAVE_X11_KEYSYM_H)
        autoutils_write_to_config_header("#define HWLOC_HAVE_X11_KEYSYM 1")
        list(APPEND libs X11)
      endif()
    endif()
  endif()
endif()

if(HWLOC_ENABLE_GL)
  autoutils_check_header("NVCtrl/NVCtrl.h")
  if(HAVE_NVCTRL_NVCTRL_H)
    autoutils_check_lib(XNVCtrl XNVCTRLQueryTargetAttribute)
    if(HAVE_LIBXNVCTRL)
      list(APPEND components gl)
      set(HWLOC_HAVE_GL 1)
      autoutils_write_to_config_header("#define HWLOC_HAVE_GL ${HWLOC_HAVE_GL}")
    endif()
  endif()
endif()

if(HWLOC_ENABLE_LIBXML2)
  autoutils_check_header("libxml/parser.h")
  if(HAVE_LIBXML_PARSER_H)
    autoutils_check_lib(xml2 xmlNewDoc)
    if(HAVE_LIBXML2)
      list(APPEND xml_libxml)
      autoutils_write_to_config_header("#define HWLOC_HAVE_LIBXML2 1")
    endif()
  endif()
endif()

if(HWLOC_ENABLE_CPUID)
  if(WIN32)
    set(x86_cpuid_check_include "#include <windows.h>")
    set(x86_cpuid_check_define "#define hwloc_uint64_t DWORDLONG")
  else()
    if(HAVE_STDINT_H)
      set(x86_cpuid_check_include "#include <stdint.h>")
    endif()
    set(x86_cpuid_check_define "#define hwloc_uint64_t uint64_t")
  endif()
  set(CMAKE_REQUIRED_INCLUDES "${CMAKE_CURRENT_SOURCE_DIR}/include")
  check_c_source_compiles("
#include <stdio.h>
${hwloc_cpu_define}
${x86_cpuid_check_include}
${x86_cpuid_check_define}
#define __hwloc_inline
#include <private/cpuid-x86.h>
int main()
{
    if (hwloc_have_x86_cpuid()) {
        unsigned eax = 0;
        unsigned ebx = 0;
        unsigned ecx = 0;
        unsigned edx = 0;
        hwloc_x86_cpuid(&eax, &ebx, &ecx, &edx);
    }
    return 0;
}" _have_x86_cpuid)
  if(_have_x86_cpuid)
    set(hwloc_have_x86_cpuid)
    list(APPEND components x86)
    autoutils_write_to_config_header("#define HWLOC_HAVE_X86_CPUID 1")
  endif()
endif()

find_package(Threads REQUIRED)
set(CMAKE_REQUIRED_LIBRARIES Threads::Threads)
autoutils_check_func(pthread_mutex_lock)
set(CMAKE_REQUIRED_LIBRARIES)
if(HAVE_PTHREAD_MUTEX_LOCK)
  list(APPEND libs Threads::Threads)
  autoutils_write_to_config_header("#define HWLOC_HAVE_PTHREAD_MUTEX")
elseif(NOT WIN32)
  message(FATAL_ERROR
    "pthread_mutex_lock not available, required for thread-safe initialization "
    "on non-Windows platforms.")
endif()

if(HWLOC_PLUGINS)
  if(CMAKE_SYSTEM_NAME STREQUAL "AIX")
    message(FATAL_ERROR
      "libltdl does not work on AIX, plugins support cannot be enabled.")
  endif()
  if(WIN32)
    message(FATAL_ERROR
      "Plugins not supported on non-native Windows build, "
      "plugins support cannot be enabled.")
  endif()

  autoutils_check_header("ltdl.h")
  if(NOT HAVE_LTDL_H)
    message(FATAL_ERROR
      "Plugin support requested, but could not find ltdl.h.")
  endif()
  autoutils_check_lib(ltdl lt_dlopennext)
  if(NOT HAVE_LIBLTDL)
    message(FATAL_ERROR
      "Plugin support requested, but could not find libltdl.")
  endif()
  list(APPEND libs ltdl)
endif()

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/config.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/include/hwloc/autogen/config.h")

set(hwloc_include_dirs
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>)
add_subdirectory(hwloc)
