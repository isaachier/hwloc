cmake_minimum_required(VERSION 3.1)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain.cmake"
    CACHE FILEPATH
    "Toolchain to use for building this package and dependencies")

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
write_to_config_header("#define HWLOC_VERSION \"${HWLOC_VERSION}\"")

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
  write_to_config_header("#define HWLOC_DEBUG")
else()
  write_to_config_header("/* #undef HWLOC_DEBUG */")
endif()


set(HWLOC_SYM_PREFIX "hwloc_" CACHE STRING "Prefix for hwloc symbols")
if(NOT HWLOC_SYM_PREFIX)
  message(FATAL_ERROR
    "HWLOC_SYM_PREFIX cannot be empty, use \"hwloc_\" instead")
endif()
write_to_config_header("#define HWLOC_SYM_PREFIX ${HWLOC_SYM_PREFIX}")
string(TOUPPER HWLOC_SYM_PREFIX_CAPS "${HWLOC_SYM_PREFIX}")
write_to_config_header("#define HWLOC_SYM_PREFIX_CAPS ${HWLOC_SYM_PREFIX_CAPS}")

if(HWLOC_SYM_PREFIX STREQUAL "hwloc_")
  set(HWLOC_SYM_TRANSFORM OFF)
  write_to_config_header("#define HWLOC_SYM_TRANSFORM 0")
else()
  set(HWLOC_SYM_TRANSFORM ON)
  write_to_config_header("#define HWLOC_SYM_TRANSFORM 1")
endif()

write_to_config_header("#ifndef _HPUX_SOURCE
#undef _HPUX_SOURCE
#endif
#define _HPUX_SOURCE 1")

write_to_config_header("#define SIZEOF_VOID_P ${CMAKE_SIZEOF_VOID_P}")

if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wmissing-prototypes -Wundef")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wpointer-arith -Wcast-align")
endif()

macro(_hwloc_check_decl decl)
  string(MAKE_C_IDENTIFIER "${decl}" _var)
  string(TOUPPER "${_var}" _var)
  if(NOT DEFINED _have_symbol_${_var})
    check_symbol_exists(${decl} "${ARGN}" _have_symbol_${_var})
  endif()

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
    write_to_config_header("#define HAVE_DECL_${_var} ${HAVE_DECL_${_var}}")
  endif()
endmacro()

set(components noos xml synthetic xml_nolibxml)

check_symbol_exists("__bgq__" "" bgq)
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "powerpc" AND
   CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
   bgq)
  write_to_config_header("#define HWLOC_BGQ_SYS 1")
  list(APPEND components bgq)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  write_to_config_header("#define HWLOC_LINUX_SYS 1")
  write_to_config_header("#define HWLOC_HAVE_LINUXIO 1")
  write_to_config_header("#define HWLOC_HAVE_LINUXPCI 1")
  list(APPEND components linux linuxio)
elseif(CMAKE_SYSTEM_NAME STREQUAL "IRIX")
  write_to_config_header("#define HWLOC_IRIX_SYS 1")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  write_to_config_header("#define HWLOC_DARWIN_SYS 1")
  list(APPEND components darwin)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Solaris")
  write_to_config_header("#define HWLOC_SOLARIS_SYS 1")
  list(APPEND components solaris)
elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
  write_to_config_header("#define HWLOC_AIX_SYS 1")
  list(APPEND components aix)
elseif(CMAKE_SYSTEM_NAME STREQUAL "HPUX")
  write_to_config_header("#define HWLOC_HPUX_SYS 1")
  list(APPEND components hpux)
elseif(WIN32)
  write_to_config_header("#define HWLOC_WIN_SYS 1")
  list(APPEND components windows)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  write_to_config_header("#define HWLOC_FREEBSD_SYS 1")
  list(APPEND components freebsd)
elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
  write_to_config_header("#define HWLOC_NETBSD_SYS 1")
  list(APPEND components netbsd)
else()
  message(WARNING "Unsupported! ${CMAKE_SYSTEM_NAME}")
  write_to_config_header("#define HWLOC_UNSUPPORTED_SYS 1")
  message(WARNING "hwloc does not support this system. "
    "hwloc will attempt to build (but it may not work). "
    "hwloc run-time results may be reduced to showing just one processor "
    "and binding will not be supported.")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.*86|x86_64|amd64)$")
  if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    write_to_config_header("#define HWLOC_X86_32_ARCH 1")
    set(HWLOC_MS_LIB_ARCH X86)
  else()
    if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
      message(STATUS "unknown -- assuming x86_64")
    endif()
    write_to_config_header("#define HWLOC_X86_64_ARCH 1")
    set(HWLOC_MS_LIB_ARCH X64)
  endif()
else()
  message("unknown processor ${CMAKE_SYSTEM_PROCESSOR}")
endif()

write_to_config_header(
  "#define HWLOC_SIZEOF_UNSIGNED_LONG ${CMAKE_SIZEOF_UNSIGNED_LONG}")
write_to_config_header(
  "#define HWLOC_SIZEOF_UNSIGNED_INT ${CMAKE_SIZEOF_UNSIGNED_INT}")

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
    write_to_config_header("#define HWLOC_HAVE_STRNCASECMP")
  endif()
endif(HAVE_STRNCASECMP)

check_func(strftime)
check_func(setlocale)

check_header("stdint.h")
if(HAVE_STDINT_H)
  write_to_config_header("#define HWLOC_HAVE_STDINT_H 1")
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
  write_to_config_header("#define HWLOC_HAVE_SCHED_SETAFFINITY 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_SCHED_SETAFFINITY */")
endif()

check_c_source_compiles("
#include <sched.h>
static unsigned long mask;
int main() { sched_setaffinity(0, (void*) &mask); return 0; }"
  HWLOC_HAVE_OLD_SCHED_SETAFFINITY)
if(HWLOC_HAVE_OLD_SCHED_SETAFFINITY)
  write_to_config_header("#define HWLOC_HAVE_OLD_SCHED_SETAFFINITY 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_OLD_SCHED_SETAFFINITY */")
endif()
set(CMAKE_REQUIRED_FLAGS)

check_c_source_compiles("
#include <sched.h>
cpu_set_t set;
int main() { CPU_ZERO(&set); CPU_SET(0, &set); return 0; }"
  HWLOC_HAVE_CPU_SET)
if(HWLOC_HAVE_CPU_SET)
  write_to_config_header("#define HWLOC_HAVE_CPU_SET 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_CPU_SET */")
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
  write_to_config_header("#define HWLOC_HAVE_CPU_SET_S 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_CPU_SET_S */")
endif()

check_c_source_compiles("
#include <unistd.h>
#include <sys/syscall.h>
int main() { syscall(0, 1, 2, 3, 4, 5, 6); return 0; }" HWLOC_HAVE_SYSCALL)
if(HWLOC_HAVE_SYSCALL)
  write_to_config_header("#define HWLOC_HAVE_SYSCALL 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_SYSCALL */")
endif()

check_func(ffs)
if(HAVE_FFS)
  _hwloc_check_decl(ffs)
  if(HAVE_DECL_FFS)
    write_to_config_header("#define HWLOC_HAVE_DECL_FFS 1")
    # TODO: Detect gccfss
  else()
    write_to_config_header("/* #undef HWLOC_HAVE_DECL_FFS */")
  endif()
  write_to_config_header("#define HWLOC_HAVE_FFS 1")
endif()

foreach(func ffsl fls flsl clz clzl)
  check_func(${func})
  string(TOUPPER ${func} func_name)
  if(HAVE_${func_name})
    _hwloc_check_decl(${func})
    if(HAVE_DECL_${func_name})
      write_to_config_header("#define HWLOC_HAVE_DECL_${func_name} 1")
    else()
      write_to_config_header("/* #undef HWLOC_HAVE_DECL_${func_name} */")
    endif()
    write_to_config_header("#define HWLOC_HAVE_${func_name} 1")
  endif()
endforeach()

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
  check_func(openat)
  if(HAVE_OPENAT)
    set(hwloc_have_openat 1)
  endif()
endif()

check_header("malloc.h")
check_func(getpagesize)
check_func(memalign)
check_func(posix_memalign)

check_header("sys/utsname.h")
check_func(uname)

# TODO: embedded mode
if(HWLOC_MODE STREQUAL "embedded")
  set(HAVE_DECL_RUNNING_ON_VALGRIND 0)
  write_to_config_header("#define HAVE_DECL_RUNNING_ON_VALGRIND 0")
else()
  check_header("valgrind/valgrind.h")
  if(HAVE_VALGRIND_VALGRIND_H)
    check_decl(RUNNING_ON_VALGRIND "valgrind/valgrind.h")
  endif()
endif()

check_header("pthread_np.h")
set(headers "pthread.h")
if(HAVE_PTHREAD_NP_H)
  list(APPEND headers "pthread_np.h")
endif()
check_decl(pthread_setaffinity_np ${headers})
check_decl(pthread_getaffinity_np ${headers})
check_func(sched_setaffinity)

if(HAVE_SCHED_SETAFFINITY)
  set(hwloc_have_sched_setaffinity ON)
endif()

check_header("sys/cpuset.h")
check_func(cpuset_setaffinity)
set(CMAKE_REQUIRED_LIBRARIES pthread)
check_func(pthread_getthrds_np)
if(HAVE_PTHREAD_GETTHRDS_NP)
  write_to_config_header("#define HWLOC_HAVE_PTHREAD_GETTHRDS_NP 1")
else()
  write_to_config_header("/* #undef HWLOC_HAVE_PTHREAD_GETTHRDS_NP */")
endif()
set(CMAKE_REQUIRED_LIBRARIES)
