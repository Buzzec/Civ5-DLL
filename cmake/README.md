# Civ V reference in CLion

Open the root `CMakeLists.txt` in CLion. The three `*_reference` targets provide
source lists, include paths, and compile metadata for the base game and both
expansions. Select a target to browse its version of the game. Use a Windows
MSVC toolchain for the closest header parsing; these sources use Windows headers
and legacy Microsoft C++ extensions. The default build has no compilation steps.
The Rust application continues to build with Cargo.

## Building a game DLL

The upstream repository supplies no Visual Studio projects or `.lib` files.
The `*_reference` object targets are for IDE metadata, not supported standalone
builds. Building a usable game DLL requires the original Civilization V SDK
source tree with its `.vcxproj` files, libraries, Windows SDK, and compatible
32-bit Microsoft toolset. A modern CLion compiler alone does not supply these.

Set these CMake options in your CLion profile (use your actual paths):

```text
-DCIV5_SDK_DIR="C:/path/to/CvGameCoreSource"
-DCIV5_MSBUILD="C:/path/to/MSBuild.exe"
-DCIV5_SDK_CONFIGURATION=Release
```

The SDK directory must directly contain `CvGameCoreDLL`,
`CvGameCoreDLL_Expansion1`, and `CvGameCoreDLL_Expansion2` with their original
projects and sibling dependencies. Select `CvGameCoreDLL_Expansion2_dll` (or
the corresponding base/Expansion1 target) and build it in CLion. CMake copies
the SDK into the build directory, overlays the submodule sources, and invokes
the original project with `Platform=Win32`. Outputs are in that staged SDK's
original project output locations beneath `<build>/sdk/<variant>`.

This preserves the SDK's ABI, precompiled header, resource, and linker settings.
Native compilation requires a compatible SDK and has not been verified here.
The source overlays must match the installed SDK version; MSBuild reports
missing dependencies or incompatible project settings.

