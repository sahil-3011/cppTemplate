include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cppTemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(cppTemplate_setup_options)
  option(cppTemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(cppTemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cppTemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cppTemplate_ENABLE_HARDENING
    OFF)

  cppTemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cppTemplate_PACKAGING_MAINTAINER_MODE)
    option(cppTemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cppTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cppTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cppTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cppTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cppTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cppTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cppTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cppTemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cppTemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cppTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cppTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cppTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cppTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cppTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cppTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cppTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cppTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cppTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cppTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cppTemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cppTemplate_ENABLE_IPO
      cppTemplate_WARNINGS_AS_ERRORS
      cppTemplate_ENABLE_USER_LINKER
      cppTemplate_ENABLE_SANITIZER_ADDRESS
      cppTemplate_ENABLE_SANITIZER_LEAK
      cppTemplate_ENABLE_SANITIZER_UNDEFINED
      cppTemplate_ENABLE_SANITIZER_THREAD
      cppTemplate_ENABLE_SANITIZER_MEMORY
      cppTemplate_ENABLE_UNITY_BUILD
      cppTemplate_ENABLE_CLANG_TIDY
      cppTemplate_ENABLE_CPPCHECK
      cppTemplate_ENABLE_COVERAGE
      cppTemplate_ENABLE_PCH
      cppTemplate_ENABLE_CACHE)
  endif()

  cppTemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cppTemplate_ENABLE_SANITIZER_ADDRESS OR cppTemplate_ENABLE_SANITIZER_THREAD OR cppTemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cppTemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cppTemplate_global_options)
  if(cppTemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cppTemplate_enable_ipo()
  endif()

  cppTemplate_supports_sanitizers()

  if(cppTemplate_ENABLE_HARDENING AND cppTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cppTemplate_ENABLE_SANITIZER_UNDEFINED
       OR cppTemplate_ENABLE_SANITIZER_ADDRESS
       OR cppTemplate_ENABLE_SANITIZER_THREAD
       OR cppTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cppTemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cppTemplate_ENABLE_SANITIZER_UNDEFINED}")
    cppTemplate_enable_hardening(cppTemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cppTemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cppTemplate_warnings INTERFACE)
  add_library(cppTemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cppTemplate_set_project_warnings(
    cppTemplate_warnings
    ${cppTemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cppTemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cppTemplate_configure_linker(cppTemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cppTemplate_enable_sanitizers(
    cppTemplate_options
    ${cppTemplate_ENABLE_SANITIZER_ADDRESS}
    ${cppTemplate_ENABLE_SANITIZER_LEAK}
    ${cppTemplate_ENABLE_SANITIZER_UNDEFINED}
    ${cppTemplate_ENABLE_SANITIZER_THREAD}
    ${cppTemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cppTemplate_options PROPERTIES UNITY_BUILD ${cppTemplate_ENABLE_UNITY_BUILD})

  if(cppTemplate_ENABLE_PCH)
    target_precompile_headers(
      cppTemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cppTemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cppTemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cppTemplate_ENABLE_CLANG_TIDY)
    cppTemplate_enable_clang_tidy(cppTemplate_options ${cppTemplate_WARNINGS_AS_ERRORS})
  endif()

  if(cppTemplate_ENABLE_CPPCHECK)
    cppTemplate_enable_cppcheck(${cppTemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cppTemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cppTemplate_enable_coverage(cppTemplate_options)
  endif()

  if(cppTemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cppTemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cppTemplate_ENABLE_HARDENING AND NOT cppTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cppTemplate_ENABLE_SANITIZER_UNDEFINED
       OR cppTemplate_ENABLE_SANITIZER_ADDRESS
       OR cppTemplate_ENABLE_SANITIZER_THREAD
       OR cppTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cppTemplate_enable_hardening(cppTemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
