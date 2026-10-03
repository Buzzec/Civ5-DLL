# Standalone CMake build

This repository builds 32-bit reference DLLs with CMake and Ninja. It does not
depend on open_civ, a decompilation workspace, Python, or original SDK projects.
Missing support headers and prebuilt libraries are fetched automatically from
LoneGazebo/Community-Patch-DLL at commit
`aefacbf1b24a27aa42dc50b4283420a999f7fded`. Git and network access are needed
on the first configuration; subsequent configurations reuse the pinned checkout.

## Prerequisites

- Windows, CMake 3.20 or newer, Ninja, and Git.
- Microsoft Visual C++ 2008 SP1 (VC9), x86, with its Windows SDK. Modern MSVC
  uses a different C++ ABI from the prebuilt SDK libraries.

The portable Microsoft Visual C++ Compiler for Python 2.7 distribution contains
the required `VC` and `WinSDK` directories. Set `CIV5_VC9_ROOT` to the directory
containing those two folders (usually `Microsoft/Visual C++ for Python/9.0`
inside the extracted distribution). The compiler is an external prerequisite;
this repository does not download or install it.

```powershell
git clone https://github.com/Buzzec/Civ5-DLL.git
cd Civ5-DLL
cmake -S . -B build -G Ninja -DCIV5_VC9_ROOT="C:/toolchains/VC9"
cmake --build build --target CvGameCoreDLL_reference --parallel 8
```

Until merged, clone with `--branch codex/cmake-clion`.

Outputs are `build/bin/CvGameCoreDLLReference.dll` and its matching full PDB.
The base game is the default build. Expansion targets are
`CvGameCoreDLL_Expansion1_reference` and `CvGameCoreDLL_Expansion2_reference`.
Each target creates its own PCH and outputs. Sources remain in the repository;
support headers are merged in the build directory without overwriting snapshot
headers. The orphaned `CvHallOfFameInfo.cpp` and empty placeholders are omitted.

For an offline build, supply `-DCIV5_DEPENDENCIES_DIR="C:/path/to/Community-Patch-DLL"`
using the pinned revision above with the support folders and `.lib` files present.

## CLion

Open this repository's root CMakeLists.txt. Use a Windows toolchain and the Ninja
generator. In Settings > Build, Execution, Deployment > CMake, add
`-DCIV5_VC9_ROOT="C:/toolchains/VC9"` to CMake options. Reset the CMake cache
after switching from a modern compiler. CMake selects VC9 and supplies its
header and library paths; no Visual Studio environment shell is necessary.
Select a `*_reference` target and use Build. A DLL is not a standalone runnable
application, so Run requires a separate host application.

Both Debug and Release profiles use the release CRT and iterator ABI expected
by the support libraries, with optimized code and debug symbols. The support
libraries lack their original PDBs, so LNK4099 warnings are expected; game-core
source symbols are generated. These are reference builds, not game-tested
replacement DLLs.
