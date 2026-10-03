cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0091 NEW)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
if(NOT CMAKE_GENERATOR MATCHES "^Ninja")
    message(FATAL_ERROR "Use the Ninja generator (-G Ninja) with the portable VC9 toolchain.")
endif()

# Select the ABI-compatible compiler before project() and compiler detection.
set(CIV5_VC9_ROOT "$ENV{CIV5_VC9_ROOT}" CACHE PATH
    "VC9 installation containing VC/bin, VC/include, VC/lib and WinSDK")
if(NOT EXISTS "${CIV5_VC9_ROOT}/VC/bin/cl.exe" OR
   NOT EXISTS "${CIV5_VC9_ROOT}/WinSDK/Include/windows.h")
    message(FATAL_ERROR
        "Set CIV5_VC9_ROOT to the Visual C++ 2008 SP1 x86 toolchain root containing VC and WinSDK. See cmake/README.md.")
endif()
file(TO_CMAKE_PATH "${CIV5_VC9_ROOT}" CIV5_VC9_ROOT)
set(CMAKE_CXX_COMPILER "${CIV5_VC9_ROOT}/VC/bin/cl.exe" CACHE FILEPATH "" FORCE)
set(CMAKE_LINKER "${CIV5_VC9_ROOT}/VC/bin/link.exe" CACHE FILEPATH "" FORCE)
set(CMAKE_RC_COMPILER "${CIV5_VC9_ROOT}/WinSDK/Bin/rc.exe" CACHE FILEPATH "" FORCE)
set(CMAKE_MT "${CIV5_VC9_ROOT}/WinSDK/Bin/mt.exe" CACHE FILEPATH "" FORCE)
set(ENV{INCLUDE} "${CIV5_VC9_ROOT}/VC/include;${CIV5_VC9_ROOT}/WinSDK/Include")
set(ENV{LIB} "${CIV5_VC9_ROOT}/VC/lib;${CIV5_VC9_ROOT}/WinSDK/Lib")
project(Civ5DLL LANGUAGES CXX)
if(NOT WIN32 OR NOT MSVC_VERSION EQUAL 1500 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "This reference build requires Windows and MSVC 2008 (VC9), x86. Use the Ninja generator.")
endif()
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build configuration" FORCE)
endif()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# The distributed SDK libraries use the release CRT and iterator ABI, even
# when CLion selects its default Debug profile. Keep symbols in both profiles.
set(CMAKE_CXX_FLAGS "/DWIN32 /D_WINDOWS /EHsc")
foreach(config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
    set(CMAKE_CXX_FLAGS_${config} "/O2 /Ob2 /Oy- /Z7 /MD /DNDEBUG")
endforeach()
set(CMAKE_CXX_STANDARD_LIBRARIES
    "\"/LIBPATH:${CIV5_VC9_ROOT}/VC/lib\" \"/LIBPATH:${CIV5_VC9_ROOT}/WinSDK/Lib\" kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib")

include(cmake/Dependencies.cmake)
set(support "${CMAKE_CURRENT_BINARY_DIR}/support")
set(components CvGameCoreDLLUtil CvGameDatabase CvLocalization CvWorldBuilderMap
    FirePlace Lua_51 ThirdPartyLibs)
# Preserve snapshot headers, then fill only missing files from dependencies.
foreach(component IN LISTS components)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${component}")
        file(GLOB_RECURSE snapshot_headers CONFIGURE_DEPENDS
            RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
            "${CMAKE_CURRENT_SOURCE_DIR}/${component}/*")
        foreach(relative IN LISTS snapshot_headers)
            get_filename_component(directory "${support}/${relative}" DIRECTORY)
            file(MAKE_DIRECTORY "${directory}")
            configure_file("${CMAKE_CURRENT_SOURCE_DIR}/${relative}" "${support}/${relative}" COPYONLY)
        endforeach()
    endif()
    file(GLOB_RECURSE supplements RELATIVE "${CIV5_DEPENDENCIES_DIR}"
        "${CIV5_DEPENDENCIES_DIR}/${component}/include/*"
        "${CIV5_DEPENDENCIES_DIR}/${component}/Lua51/include/*")
    foreach(relative IN LISTS supplements)
        if(NOT EXISTS "${support}/${relative}")
            get_filename_component(directory "${support}/${relative}" DIRECTORY)
            file(MAKE_DIRECTORY "${directory}")
            configure_file("${CIV5_DEPENDENCIES_DIR}/${relative}" "${support}/${relative}" COPYONLY)
        endif()
    endforeach()
endforeach()

set(libraries
    CvWorldBuilderMap/lib/CvWorldBuilderMapWin32.lib
    CvGameCoreDLLUtil/lib/CvGameCoreDLLUtilWin32.lib
    CvLocalization/lib/CvLocalizationWin32.lib
    CvGameDatabase/lib/CvGameDatabaseWin32.lib
    FirePlace/lib/FireWorksWin32.lib
    FirePlace/lib/FLuaWin32.lib
    ThirdPartyLibs/Lua51/lib/lua51_Win32.lib)
set(sdk_libraries)
foreach(library IN LISTS libraries)
    if(NOT EXISTS "${CIV5_DEPENDENCIES_DIR}/${library}")
        message(FATAL_ERROR "Missing dependency library: ${CIV5_DEPENDENCIES_DIR}/${library}")
    endif()
    list(APPEND sdk_libraries "${CIV5_DEPENDENCIES_DIR}/${library}")
endforeach()

foreach(variant CvGameCoreDLL CvGameCoreDLL_Expansion1 CvGameCoreDLL_Expansion2)
    set(source_dir "${CMAKE_CURRENT_SOURCE_DIR}/${variant}")
    file(GLOB_RECURSE sources CONFIGURE_DEPENDS "${source_dir}/*.cpp")
    # This obsolete file has no header or callers in the published snapshot.
    list(FILTER sources EXCLUDE REGEX "/CvHallOfFameInfo\\.cpp$")
    foreach(source IN LISTS sources)
        file(SIZE "${source}" size)
        if(size EQUAL 0)
            list(REMOVE_ITEM sources "${source}")
        endif()
    endforeach()
    file(GLOB_RECURSE headers CONFIGURE_DEPENDS "${source_dir}/*.h" "${support}/*.h" "${support}/*.inl")
    set(target "${variant}_reference")
    # Base game is the default; expansions are explicit targets.
    if(variant STREQUAL "CvGameCoreDLL")
        add_library(${target} SHARED ${sources} ${headers})
    else()
        add_library(${target} SHARED EXCLUDE_FROM_ALL ${sources} ${headers})
    endif()
    target_include_directories(${target} PRIVATE "${source_dir}" "${source_dir}/Lua"
        "${support}/CvGameCoreDLLUtil/include" "${support}/CvGameDatabase/include"
        "${support}/CvLocalization/include" "${support}/CvWorldBuilderMap/include"
        "${support}/FirePlace/include" "${support}/FirePlace/include/FireWorks"
        "${support}/ThirdPartyLibs/Lua51/include" "${support}/Lua_51/include"
        "${CIV5_VC9_ROOT}/VC/include" "${CIV5_VC9_ROOT}/WinSDK/Include")
    target_compile_definitions(${target} PRIVATE FXS_IS_DLL WIN32 _WINDOWS _USRDLL
        CVGAMECOREDLL_EXPORTS FINAL_RELEASE NDEBUG _CRT_SECURE_NO_WARNINGS
        _SECURE_SCL=0 _HAS_ITERATOR_DEBUGGING=0)
    target_compile_options(${target} PRIVATE /GR /fp:fast /Zm400 /W3)
    # PCH flags are source-specific so CLion's empty compiler probe stays clean.
    set(pch "${CMAKE_CURRENT_BINARY_DIR}/${target}.pch")
    set(pch_source "${source_dir}/_precompile.cpp")
    foreach(source IN LISTS sources)
        if(source STREQUAL pch_source)
            set_source_files_properties("${source}" PROPERTIES
                COMPILE_FLAGS "/YcCvGameCoreDLLPCH.h /Fp\"${pch}\""
                OBJECT_OUTPUTS "${pch}")
        else()
            set_source_files_properties("${source}" PROPERTIES
                COMPILE_FLAGS "/YuCvGameCoreDLLPCH.h /Fp\"${pch}\""
                OBJECT_DEPENDS "${pch}")
        endif()
    endforeach()
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${target}.def" "EXPORTS\n    DllGetGameContext\n")
    target_sources(${target} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target}.def")
    target_link_libraries(${target} PRIVATE ${sdk_libraries} winmm)
    target_link_options(${target} PRIVATE /MACHINE:X86 /DEBUG /INCREMENTAL:NO /OPT:REF /OPT:ICF)
    set_target_properties(${target} PROPERTIES PREFIX "" OUTPUT_NAME "${variant}Reference"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
        PDB_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")
endforeach()
