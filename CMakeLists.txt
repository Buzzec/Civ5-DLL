cmake_minimum_required(VERSION 3.20)
project(Civ5DLL LANGUAGES CXX)

# Source-only reference project, with optional original SDK builds.
set(CIV5_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
if(NOT EXISTS "${CIV5_SOURCE_DIR}/CvGameCoreDLL_Expansion2/CvGameCoreDLLPCH.h")
    message(FATAL_ERROR "Missing Civ5-DLL sources in the project root.")
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CIV5_SDK_DIR "" CACHE PATH "Original Civilization V SDK source tree, including projects and libraries")
set(CIV5_SDK_CONFIGURATION "Release" CACHE STRING "Configuration in the original SDK projects")
set(CIV5_MSBUILD "" CACHE FILEPATH "MSBuild executable compatible with the installed Civ V SDK toolset")

set(shared_includes)
foreach(component CvGameCoreDLLUtil CvGameDatabase CvLocalization CvWorldBuilderMap
                  FirePlace Lua_51 ThirdPartyLibs/Lua51)
    list(APPEND shared_includes "${CIV5_SOURCE_DIR}/${component}/include")
endforeach()
file(GLOB_RECURSE shared_headers CONFIGURE_DEPENDS
    "${CIV5_SOURCE_DIR}/CvGameCoreDLLUtil/*.h"
    "${CIV5_SOURCE_DIR}/CvGameDatabase/*.h"
    "${CIV5_SOURCE_DIR}/CvLocalization/*.h"
    "${CIV5_SOURCE_DIR}/CvWorldBuilderMap/*.h"
    "${CIV5_SOURCE_DIR}/FirePlace/*.h"
    "${CIV5_SOURCE_DIR}/Lua_51/*.h"
    "${CIV5_SOURCE_DIR}/ThirdPartyLibs/*.h")

foreach(variant CvGameCoreDLL CvGameCoreDLL_Expansion1 CvGameCoreDLL_Expansion2)
    file(GLOB_RECURSE sources CONFIGURE_DEPENDS
        "${CIV5_SOURCE_DIR}/${variant}/*.cpp"
        "${CIV5_SOURCE_DIR}/${variant}/*.h")
    # Compile metadata for CLion navigation, separate for each game version.
    # Excluded from the default build: the source-only repository cannot link a DLL.
    add_library(${variant}_reference OBJECT EXCLUDE_FROM_ALL ${sources} ${shared_headers})
    target_include_directories(${variant}_reference PRIVATE
        "${CIV5_SOURCE_DIR}/${variant}" ${shared_includes})
    target_compile_definitions(${variant}_reference PRIVATE WIN32 _WINDOWS FINAL_RELEASE)
    if(MSVC)
        target_compile_options(${variant}_reference PRIVATE /FI CvGameCoreDLLPCH.h)
    endif()

    if(CIV5_SDK_DIR)
        if(NOT WIN32)
            message(FATAL_ERROR "The original Civ V SDK build requires Windows.")
        endif()
        if(NOT EXISTS "${CIV5_MSBUILD}")
            message(FATAL_ERROR "Set CIV5_MSBUILD to an MSBuild executable supporting the SDK's original toolset.")
        endif()
        if(NOT EXISTS "${CIV5_SDK_DIR}/${variant}/${variant}.vcxproj")
            message(FATAL_ERROR "Missing SDK project: ${CIV5_SDK_DIR}/${variant}/${variant}.vcxproj")
        endif()
        add_custom_target(${variant}_dll
            COMMAND "${CMAKE_COMMAND}"
                "-DSDK_DIR=${CIV5_SDK_DIR}"
                "-DSOURCE_DIR=${CIV5_SOURCE_DIR}"
                "-DSTAGE_DIR=${CMAKE_CURRENT_BINARY_DIR}/sdk/${variant}"
                "-DVARIANT=${variant}"
                "-DMSBUILD=${CIV5_MSBUILD}"
                "-DCONFIGURATION=${CIV5_SDK_CONFIGURATION}"
                -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/BuildCiv5SDK.cmake"
            USES_TERMINAL VERBATIM)
    endif()
endforeach()
message(STATUS "Civ5 reference targets loaded. Native DLL targets require CIV5_SDK_DIR and CIV5_MSBUILD.")

