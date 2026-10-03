# Build in a private SDK copy so neither the installed SDK nor the submodule
# is modified. Preserve the original SDK projects, toolset, and linker settings.
file(MAKE_DIRECTORY "${STAGE_DIR}")
file(COPY "${SDK_DIR}/" DESTINATION "${STAGE_DIR}")
foreach(component CvGameCoreDLL CvGameCoreDLL_Expansion1 CvGameCoreDLL_Expansion2
                  CvGameCoreDLLUtil CvGameDatabase CvLocalization CvWorldBuilderMap
                  FirePlace Lua_51 ThirdPartyLibs)
    file(COPY "${SOURCE_DIR}/${component}" DESTINATION "${STAGE_DIR}")
endforeach()
execute_process(
    COMMAND "${MSBUILD}" "${STAGE_DIR}/${VARIANT}/${VARIANT}.vcxproj"
        /t:Rebuild "/p:Configuration=${CONFIGURATION}" /p:Platform=Win32
    WORKING_DIRECTORY "${STAGE_DIR}"
    RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Civ V SDK build failed (${result}); see MSBuild diagnostics above.")
endif()
