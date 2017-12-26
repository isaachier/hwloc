set(sources
    topology.c
    traversal.c
    distances.c
    components.c
    bind.c
    bitmap.c
    pci-common.c
    diff.c
    shmem.c
    misc.c
    base64.c
    topology-noos.c
    topology-synthetic.c
    topology-xml.c
    topology-xml-nolibxml.c)

# TODO: Plugin support

if(HAVE_LIBXML2)
  list(APPEND sources topology-xml-libxml.c)
endif()

if(HAVE_LIBPCIACCESS)
  list(APPEND sources topology-pci.c)
endif()

if(HWLOC_HAVE_OPENCL)
  list(APPEND sources topology-opencl.c)
endif()

if(HWLOC_HAVE_CUDART)
  list(APPEND sources topology-cuda.c)
endif()

if(HWLOC_HAVE_NVML)
  list(APPEND sources topology-nvml.c)
endif()

if(HWLOC_HAVE_GL)
  list(APPEND sources topology-gl.c)
endif()

if(hwloc_have_solaris)
  list(APPEND sources topology-solaris.c topology-solaris-chiptype.c)
endif()

if(hwloc_have_linux)
  list(APPEND sources topology-linux.c topology-hardwired.c)
endif()

if(hwloc_have_bgq)
  list(APPEND sources topology-bgq.c)
endif()

if(hwloc_have_aix)
  list(APPEND sources topology-aix.c)
endif()

if(hwloc_have_hpux)
  list(APPEND sources topology-hpux.c)
endif()

if(hwloc_have_windows)
  list(APPEND sources topology-windows.c)
endif()

if(hwloc_have_darwin)
  list(APPEND sources topology-darwin.c)
endif()

if(hwloc_have_freebsd)
  list(APPEND sources topology-freebsd.c)
endif()

if(hwloc_have_netbsd)
  list(APPEND sources topology-aix.c)
endif()

if(hwloc_have_x86_cpuid)
  list(APPEND sources topology-x86.c)
endif()

if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_LD_FLAGS "${CMAKE_LD_FLAGS} -no-undefined")
endif()

add_library(hwloc ${sources})
target_include_directories(hwloc PUBLIC ${hwloc_include_dirs})
target_link_libraries(hwloc PUBLIC ${libs})
