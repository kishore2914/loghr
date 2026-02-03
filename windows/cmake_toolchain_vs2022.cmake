# CMake Toolchain to force Visual Studio 2022
# This file ensures CMake uses Visual Studio 2022 instead of auto-detecting VS 2019

# Force Visual Studio 2022 generator
if(NOT DEFINED CMAKE_GENERATOR)
  # Check for Visual Studio 2022 on D: drive first, then C:
  if(EXISTS "D:/Program Files/Microsoft Visual Studio/2022/Community")
    set(CMAKE_GENERATOR "Visual Studio 17 2022" CACHE STRING "Generator" FORCE)
    set(CMAKE_GENERATOR_PLATFORM "x64" CACHE STRING "Platform" FORCE)
  elseif(EXISTS "C:/Program Files/Microsoft Visual Studio/2022/Community")
    set(CMAKE_GENERATOR "Visual Studio 17 2022" CACHE STRING "Generator" FORCE)
    set(CMAKE_GENERATOR_PLATFORM "x64" CACHE STRING "Platform" FORCE)
  endif()
endif()

# Set Visual Studio toolset
if(CMAKE_GENERATOR MATCHES "Visual Studio 17 2022")
  set(CMAKE_VS_PLATFORM_NAME "x64")
endif()

















