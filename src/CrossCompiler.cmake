include_guard()

macro(enable_cross_compiler)
  include("${ProjectOptions_SRC_DIR}/Utilities.cmake")
  detect_architecture(_arch)

  # detect_compiler()
  set(_cc ${CMAKE_C_COMPILER})
  if("${_cc}" STREQUAL "")
    set(_cc $ENV{CC})
  endif()
  set(_cxx ${CMAKE_CXX_COMPILER})
  if("${_cxx}" STREQUAL "")
    set(_cxx $ENV{CXX})
  endif()
  set(CMAKE_C_COMPILER ${_cc})
  set(CMAKE_CXX_COMPILER ${_cxx})

  if(NOT DEFINED TARGET_ARCHITECTURE)
    if(_cc MATCHES "x86_64(-w64)?-mingw32-[gc]..?" OR _cxx MATCHES "x86_64(-w64)?-mingw32-[gc]..?")
      set(TARGET_ARCHITECTURE "x64")
    elseif(_cc MATCHES "i686(-w64)?-mingw32-[gc]..?" OR _cxx MATCHES "i686(-w64)?-mingw32-[gc]..?")
      set(TARGET_ARCHITECTURE "x86")
    elseif(_cc MATCHES "emcc" OR _cxx MATCHES "em\\+\\+")
      set(TARGET_ARCHITECTURE "wasm32-emscripten")
    else()
      # TODO: check for arm compiler
      set(TARGET_ARCHITECTURE ${_arch})
    endif()
  endif()

  if(NOT DEFINED HOST_TRIPLET)
    if(WIN32)
      set(HOST_TRIPLET "${_arch}-windows")
    elseif(APPLE)
      set(HOST_TRIPLET "${_arch}-osx")
    elseif(UNIX AND NOT APPLE)
      set(HOST_TRIPLET "${_arch}-linux")
    endif()
  endif()

  set(USE_CROSSCOMPILER_MINGW)
  set(USE_CROSSCOMPILER_EMSCRIPTEN)
  if(_cc MATCHES "(x86_64|i686)(-w64)?-mingw32-[gc]..?" OR _cxx MATCHES "(x86_64|i686)(-w64)?-mingw32-[gc]..?")
    set(MINGW TRUE)
    set(USE_CROSSCOMPILER_MINGW TRUE)
  elseif(_cc MATCHES "emcc" OR _xx MATCHES "em\\+\\+")
    set(USE_CROSSCOMPILER_EMSCRIPTEN TRUE)
  endif()

  set(LIBRARY_LINKAGE)
  if(BUILD_SHARED_LIBS)
    set(LIBRARY_LINKAGE "dynamic")
  else()
    set(LIBRARY_LINKAGE "static")
  endif()

  if(NOT DEFINED CROSS_ROOT)
    if(_cc MATCHES "x86_64(-w64)?-mingw32-[gc]..?" OR _cxx MATCHES "x86_64(-w64)?-mingw32-[gc]..?")
      set(CROSS_ROOT "/usr/x86_64-w64-mingw32")
    elseif(_cc MATCHES "i686(-w64)?-mingw32-[gc]..?" OR _cxx MATCHES "i686(-w64)?-mingw32-[gc]..?")
      set(CROSS_ROOT "/usr/i686-w64-mingw32")
    endif()
    # TODO: check if path is right, check for header files or something
  endif()

  if(USE_CROSSCOMPILER_EMSCRIPTEN)
    if($ENV{EMSCRIPTEN})
      set(EMSCRIPTEN_ROOT $ENV{EMSCRIPTEN})
    else()
      if(NOT DEFINED EMSCRIPTEN_ROOT)
        include(FetchContent)
        FetchContent_Declare(
          emscripten
          GIT_REPOSITORY https://github.com/emscripten-core/emscripten
          GIT_TAG main)
        if(NOT emscripten_POPULATED)
          FetchContent_Populate(emscripten)
          set(EMSCRIPTEN_ROOT "${emscripten_SOURCE_DIR}")
        endif()
        if($ENV{EMSDK})
          set(EMSCRIPTEN_PREFIX "$ENV{EMSDK}/upstream/emscripten")
        endif()
      endif()
    endif()
    if(NOT DEFINED CMAKE_CROSSCOMPILING_EMULATOR)
      set(CMAKE_CROSSCOMPILING_EMULATOR "$ENV{EMSDK_NODE};--experimental-wasm-threads")
    endif()
  endif()

  set(_toolchain_file)
  get_toolchain_file(_toolchain_file)
  set(CMAKE_TOOLCHAIN_FILE ${_toolchain_file})
  set(CROSSCOMPILING TRUE)

  message(STATUS "enable cross-compiling")
  if(USE_CROSSCOMPILER_MINGW)
    message(STATUS "use MINGW cross-compiling")
    message(STATUS "use ROOT_PATH: ${CROSS_ROOT}")
  elseif(USE_CROSSCOMPILER_EMSCRIPTEN)
    message(STATUS "use emscripten cross-compiling")
    message(STATUS "use emscripten root: ${EMSCRIPTEN_ROOT}")
    #message(STATUS "EMSCRIPTEN: $ENV{EMSCRIPTEN}")
    #message(STATUS "EMSDK_NODE: $ENV{EMSDK_NODE}")
    message(STATUS "use emscripten cross-compiler emulator: ${CMAKE_CROSSCOMPILING_EMULATOR}")
  endif()
  message(STATUS "Target Architecture: ${TARGET_ARCHITECTURE}")
  message(STATUS "Host Triplet: ${HOST_TRIPLET}")
  message(STATUS "Toolchain File: ${CMAKE_TOOLCHAIN_FILE}")
endmacro()

function(get_toolchain_file value)
  include("${ProjectOptions_SRC_DIR}/Utilities.cmake")
  detect_architecture(_arch)
  if(DEFINED TARGET_ARCHITECTURE)
    set(_arch ${TARGET_ARCHITECTURE})
  endif()
  if("${_arch}" MATCHES "x64")
    set(_arch "x86_64")
  elseif("${_arch}" MATCHES "x86")
    set(_arch "x86_64")
  endif()

  if(MINGW)
    set(${value}
        ${ProjectOptions_SRC_DIR}/toolchains/${_arch}-w64-mingw32.toolchain.cmake
        PARENT_SCOPE)
  elseif(EMSCRIPTEN)
    if(EMSCRIPTEN_ROOT)
      set(${value}
          ${EMSCRIPTEN_ROOT}/cmake/Modules/Platform/Emscripten.cmake
          PARENT_SCOPE)
    else()
      message(ERROR "EMSCRIPTEN_ROOT is not set, please define EMSCRIPTEN_ROOT (emscripten repo)")
    endif()
  endif()
endfunction()
