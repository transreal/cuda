(* ============================================================
   cuda.wl \[LongDash] ClaudeCode CUDA \:62e1\:5f35\:30d1\:30c3\:30b1\:30fc\:30b8
   
   ClaudeCode \:306e ClaudeCreatePackage / ClaudeUpdatePackage \:3067
   CUDA \:30b3\:30fc\:30c9\:3092\:542b\:3080\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:4f5c\:6210\:30fb\:66f4\:65b0\:3092\:30b5\:30dd\:30fc\:30c8\:3059\:308b\:3002
   
   - CUDA \:30bd\:30fc\:30b9 (.cu) \:306e\:62bd\:51fa\:30fb\:4fdd\:5b58
   - nvcc \:306b\:3088\:308b\:30b3\:30f3\:30d1\:30a4\:30eb
   - LibraryLink \:7d4c\:7531\:306e Mathematica \:9023\:643a
   - <<\:30d1\:30c3\:30b1\:30fc\:30b8\:540d>>.cuda/ \:30d5\:30a9\:30eb\:30c0\:306b\:30bd\:30fc\:30b9\:30fb\:30d0\:30a4\:30ca\:30ea\:3092\:683c\:7d0d
   
   \:30b3\:30f3\:30c6\:30ad\:30b9\:30c8: ClaudeCode` (\:5171\:7528)
   ============================================================ *)

(* ClaudeCode` \:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:5185\:306b\:30ed\:30fc\:30c9\:3055\:308c\:308b\:524d\:63d0 *)
(* claudecode.wl \:304c Quiet@Get["cuda.wl"] \:3067\:547c\:3073\:51fa\:3059 *)

(* \:30ed\:30fc\:30c9\:6e08\:307f\:30d5\:30e9\:30b0 *)
ClaudeCode`Private`$iCUDAExtensionLoaded = True;

Begin["ClaudeCode`Private`"];

(* ============================================================
   CUDA \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:7ba1\:7406
   ============================================================ *)

(* \:30d1\:30c3\:30b1\:30fc\:30b8\:306e .cuda \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:30d1\:30b9\:3092\:8fd4\:3059 *)
iCUDADir[packageName_String] :=
  FileNameJoin[{Global`$packageDirectory, packageName <> ".cuda"}];

(* .cuda \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:3092\:4f5c\:6210\:3057\:3001\:30d1\:30b9\:3092\:8fd4\:3059 *)
iEnsureCUDADir[packageName_String] :=
  Module[{dir = iCUDADir[packageName]},
    If[!DirectoryQ[dir],
      CreateDirectory[dir, CreateIntermediateDirectories -> True]];
    (* src / bin \:30b5\:30d6\:30c7\:30a3\:30ec\:30af\:30c8\:30ea *)
    Quiet @ CreateDirectory[FileNameJoin[{dir, "src"}],
      CreateIntermediateDirectories -> True];
    Quiet @ CreateDirectory[FileNameJoin[{dir, "bin"}],
      CreateIntermediateDirectories -> True];
    dir
  ];

(* ============================================================
   CUDA \:74b0\:5883\:691c\:51fa
   ============================================================ *)

(* nvcc \:306e\:30d1\:30b9\:3092\:691c\:7d22\:3057\:3066\:8fd4\:3059\:3002\:898b\:3064\:304b\:3089\:306a\:3051\:308c\:3070 "" *)
iNvccPath[] := iNvccPath[] =
  Module[{candidates, found},
    candidates = Switch[$OperatingSystem,
      "Windows",
        Join[
          FileNames["nvcc.exe",
            FileNameJoin[{#, "NVIDIA GPU Computing Toolkit", "CUDA", "*", "bin"}] & /@
            {Environment["ProgramFiles"],
             "C:\\Program Files"},
            Infinity],
          {"nvcc.exe"}  (* PATH \:4e0a *)
        ],
      "MacOSX",
        {"/usr/local/cuda/bin/nvcc", "/opt/cuda/bin/nvcc", "nvcc"},
      _,  (* Linux *)
        {"/usr/local/cuda/bin/nvcc", "/opt/cuda/bin/nvcc", "nvcc"}
    ];
    candidates = DeleteDuplicates[Flatten[candidates]];
    found = SelectFirst[candidates,
      Quiet @ Check[
        StringContainsQ[
          RunProcess[{#, "--version"}, "StandardOutput"], "release"],
        False] &,
      ""];
    found
  ];

(* nvcc \:304c\:5229\:7528\:53ef\:80fd\:304b *)
iNvccAvailableQ[] := iNvccPath[] =!= "";

(* CUDA Toolkit \:30d0\:30fc\:30b8\:30e7\:30f3\:60c5\:5831 *)
iNvccVersion[] := Module[{nvcc = iNvccPath[], out},
  If[nvcc === "", Return[""]];
  out = Quiet @ Check[RunProcess[{nvcc, "--version"}, "StandardOutput"], ""];
  First[StringCases[out,
    RegularExpression["release ([\\d\\.]+)"] :> "$1"], ""]
];

(* ============================================================
   \:30d7\:30ed\:30f3\:30d7\:30c8\:30d6\:30ed\:30c3\:30af\:751f\:6210: ClaudeCreatePackage \:7528
   ============================================================ *)

iCUDACreatePromptBlock[packageName_String] :=
  Module[{cudaDir, nvccInfo},
    cudaDir = packageName <> ".cuda";
    nvccInfo = If[iNvccAvailableQ[],
      "CUDA Toolkit detected: nvcc " <> iNvccVersion[] <> "\n",
      "WARNING: nvcc not found on this system. Generate code that handles missing CUDA gracefully.\n"
    ];
    "\n\n" <>
    "===== CUDA PACKAGE GENERATION INSTRUCTIONS =====\n" <>
    nvccInfo <>
    "This package MUST use CUDA for GPU-accelerated computation.\n" <>
    "You must generate TWO types of output:\n\n" <>
    "1. The Mathematica package (.wl) - output between the normal markers.\n" <>
    "2. CUDA source files (.cu/.cuh) - output EACH file between special CUDA markers.\n\n" <>
    "CUDA FILE OUTPUT FORMAT (for each .cu/.cuh file):\n" <>
    "===BEGIN_CUDA_FILE:<filename>===\n" <>
    "<cuda source code>\n" <>
    "===END_CUDA_FILE===\n\n" <>
    "Place CUDA file markers AFTER the package end marker.\n\n" <>
    "CUDA SOURCE REQUIREMENTS:\n" <>
    "- Write standard CUDA C/C++ code (.cu) with __global__ kernels.\n" <>
    "- Include a LibraryLink-compatible C interface:\n" <>
    "    #include \"WolframLibrary.h\"\n" <>
    "    DLLEXPORT mint WolframLibrary_getVersion() { return WolframLibraryVersion; }\n" <>
    "    DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) { return 0; }\n" <>
    "    DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) { return; }\n" <>
    "- Each exported function must follow LibraryLink signature:\n" <>
    "    DLLEXPORT int functionName(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)\n" <>
    "- Use MArgument_getInteger, MArgument_getReal, MArgument_getMTensor etc. for arguments.\n" <>
    "- Use MArgument_setInteger, MArgument_setReal, MArgument_setMTensor etc. for results.\n" <>
    "- Handle CUDA errors with cudaGetLastError() / cudaGetErrorString().\n\n" <>
    "MATHEMATICA PACKAGE (.wl) REQUIREMENTS:\n" <>
    "- Store CUDA directory path: $" <> packageName <> "CUDADir\n" <>
    "- On package load, check if compiled library exists in `" <> cudaDir <> "/bin/`.\n" <>
    "- If not compiled or source is newer, call compilation function.\n" <>
    "- Compilation function:\n" <>
    "  1. Find nvcc (check common paths + PATH).\n" <>
    "  2. Find WolframLibrary.h via $InstallationDirectory.\n" <>
    "  3. Run nvcc to compile .cu to shared library (.dll/.so/.dylib).\n" <>
    "  4. Place output in `" <> cudaDir <> "/bin/`.\n" <>
    "- Load compiled library via LibraryFunctionLoad.\n" <>
    "- Provide clean Mathematica wrapper functions for each CUDA kernel.\n" <>
    "- Handle graceful fallback if CUDA is unavailable (pure Mathematica implementation).\n" <>
    "- The compilation command pattern:\n" <>
    "  nvcc --shared -o output" <> iCUDALibExt[] <> " source.cu " <>
    "-I\"<WolframLibraryDir>\" -L\"<WolframLibraryDir>\" -lWolframRTL\n\n" <>
    "DIRECTORY STRUCTURE:\n" <>
    "  " <> cudaDir <> "/\n" <>
    "    src/          <- .cu and .cuh source files\n" <>
    "    bin/          <- compiled shared libraries\n" <>
    "  " <> packageName <> ".wl   <- Mathematica wrapper package\n\n" <>
    "COMPILATION HELPER PATTERN (include in .wl):\n" <>
    "```mathematica\n" <>
    "(* CUDA compilation helper - include in package *)\n" <>
    "i" <> packageName <> "CompileCUDA[] := Module[\n" <>
    "  {cudaDir, srcFile, outFile, nvcc, wlIncDir, wlLibDir, cmd, result},\n" <>
    "  cudaDir = $" <> packageName <> "CUDADir;\n" <>
    "  srcFile = FileNameJoin[{cudaDir, \"src\", \"kernels.cu\"}];\n" <>
    "  outFile = FileNameJoin[{cudaDir, \"bin\", \"kernels" <> iCUDALibExt[] <> "\"}];\n" <>
    "  If[!FileExistsQ[srcFile], Return[$Failed]];\n" <>
    "  (* Skip if binary is newer than source *)\n" <>
    "  If[FileExistsQ[outFile] && \n" <>
    "     FileDate[outFile, \"Modification\"] > FileDate[srcFile, \"Modification\"],\n" <>
    "    Return[outFile]];\n" <>
    "  nvcc = i" <> packageName <> "FindNvcc[];\n" <>
    "  If[nvcc === \"\", Print[\"\\:26a0 nvcc not found. CUDA compilation skipped.\"]; Return[$Failed]];\n" <>
    "  wlIncDir = FileNameJoin[{$InstallationDirectory, \"SystemFiles\", \"IncludeFiles\", \"C\"}];\n" <>
    "  wlLibDir = FileNameJoin[{$InstallationDirectory, \"SystemFiles\", \"Libraries\", $SystemID}];\n" <>
    "  cmd = {nvcc, \"--shared\", \"-o\", outFile, srcFile,\n" <>
    "    \"-I\" <> wlIncDir, \"-L\" <> wlLibDir, \"-lWolframRTL\"};\n" <>
    "  result = RunProcess[cmd];\n" <>
    "  If[result[\"ExitCode\"] === 0, outFile, \n" <>
    "    Print[\"\\:274c CUDA compilation failed:\\n\", result[\"StandardError\"]]; $Failed]\n" <>
    "];\n" <>
    "```\n\n" <>
    "===== END CUDA INSTRUCTIONS =====\n"
  ];

(* ============================================================
   \:30d7\:30ed\:30f3\:30d7\:30c8\:30d6\:30ed\:30c3\:30af\:751f\:6210: ClaudeUpdatePackage \:7528
   ============================================================ *)

iCUDAUpdatePromptBlock[packageName_String] :=
  Module[{cudaDir, srcDir, existingCU, nvccInfo, srcContext},
    cudaDir = iCUDADir[packageName];
    srcDir = FileNameJoin[{cudaDir, "src"}];
    existingCU = If[DirectoryQ[srcDir],
      FileNames["*.cu" | "*.cuh", srcDir], {}];
    nvccInfo = If[iNvccAvailableQ[],
      "CUDA Toolkit detected: nvcc " <> iNvccVersion[] <> "\n",
      "WARNING: nvcc not found. Generate code that handles missing CUDA gracefully.\n"
    ];
    (* \:65e2\:5b58 CUDA \:30bd\:30fc\:30b9\:3092\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:306b\:542b\:3081\:308b *)
    srcContext = If[Length[existingCU] > 0,
      "\nEXISTING CUDA SOURCE FILES in " <> packageName <> ".cuda/src/:\n" <>
      StringJoin[
        Function[f,
          "--- " <> FileNameTake[f] <> " ---\n" <>
          Quiet @ Check[Import[f, "Text"], "(read error)"] <> "\n\n"
        ] /@ Take[existingCU, UpTo[5]]],
      ""];
    "\n\n" <>
    "===== CUDA UPDATE INSTRUCTIONS =====\n" <>
    nvccInfo <>
    "This package uses CUDA. When modifying CUDA-related functionality:\n\n" <>
    "If you need to modify CUDA source files, output each modified file:\n" <>
    "===BEGIN_CUDA_FILE:<filename>===\n" <>
    "<complete cuda source>\n" <>
    "===END_CUDA_FILE===\n\n" <>
    "Place CUDA file markers AFTER the function end marker.\n" <>
    "Only output CUDA files if you actually need to change them.\n" <>
    "The .cu files reside in " <> packageName <> ".cuda/src/\n" <>
    "Compiled binaries go to " <> packageName <> ".cuda/bin/\n" <>
    srcContext <>
    "===== END CUDA UPDATE INSTRUCTIONS =====\n"
  ];

(* OS \:306b\:5fdc\:3058\:305f\:5171\:6709\:30e9\:30a4\:30d6\:30e9\:30ea\:62e1\:5f35\:5b50 *)
iCUDALibExt[] := Switch[$OperatingSystem,
  "Windows", ".dll",
  "MacOSX", ".dylib",
  _, ".so"
];

(* ============================================================
   \:30ec\:30b9\:30dd\:30f3\:30b9\:304b\:3089 CUDA \:30d5\:30a1\:30a4\:30eb\:3092\:62bd\:51fa
   ============================================================ *)

(* \:30ec\:30b9\:30dd\:30f3\:30b9\:304b\:3089\:5168\:3066\:306e CUDA \:30d5\:30a1\:30a4\:30eb\:3092\:62bd\:51fa\:3002
   \:623b\:308a\:5024: {<|"filename" -> "xxx.cu", "content" -> "..."| >, ...} *)
iCUDAExtractFiles[response_String] :=
  Module[{pattern, matches},
    pattern = RegularExpression[
      "===BEGIN_CUDA_FILE:([^=]+)===\\n([\\s\\S]*?)===END_CUDA_FILE==="];
    matches = StringCases[response,
      pattern :> <|"filename" -> StringTrim["$1"],
                   "content"  -> StringTrim["$2"]|>];
    matches
  ];

(* ============================================================
   CUDA \:30dd\:30b9\:30c8\:30d7\:30ed\:30bb\:30b9: ClaudeCreatePackage \:7528
   
   \:30ec\:30b9\:30dd\:30f3\:30b9\:304b\:3089 .cu \:30d5\:30a1\:30a4\:30eb\:3092\:62bd\:51fa\:3057\:3001
   .cuda/src/ \:306b\:4fdd\:5b58\:3057\:3001\:30b3\:30f3\:30d1\:30a4\:30eb\:3092\:8a66\:884c\:3059\:308b\:3002
   ============================================================ *)

iCUDAPostProcessCreate[nb_NotebookObject, response_String,
    packageName_String, sessionDir_String] :=
  Module[{cudaFiles, cudaDir, savedFiles = {}},
    cudaFiles = iCUDAExtractFiles[response];
    If[Length[cudaFiles] === 0,
      nbPrint[nb, iL[
        "\:26a0 CUDA \:30bd\:30fc\:30b9\:30d5\:30a1\:30a4\:30eb\:304c\:30ec\:30b9\:30dd\:30f3\:30b9\:306b\:542b\:307e\:308c\:3066\:3044\:307e\:305b\:3093\:3002",
        "\:26a0 No CUDA source files found in response."]];
      Return[{}]];
    
    cudaDir = iEnsureCUDADir[packageName];
    
    (* \:5404 CUDA \:30d5\:30a1\:30a4\:30eb\:3092\:4fdd\:5b58 *)
    Scan[Function[cf,
      Module[{destFile, strm, backupFile},
        destFile = FileNameJoin[{cudaDir, "src", cf["filename"]}];
        (* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7 *)
        If[FileExistsQ[destFile],
          backupFile = FileNameJoin[{sessionDir,
            "cuda_backup_" <> cf["filename"]}];
          Quiet @ CopyFile[destFile, backupFile, OverwriteTarget -> True]];
        (* UTF-8 \:30d0\:30a4\:30ca\:30ea\:66f8\:304d\:8fbc\:307f *)
        strm = OpenWrite[destFile, BinaryFormat -> True];
        BinaryWrite[strm, ToCharacterCode[cf["content"], "UTF-8"]];
        Close[strm];
        AppendTo[savedFiles, destFile];
        nbPrint[nb, iL[
          "  CUDA \:30bd\:30fc\:30b9\:4fdd\:5b58: ", "  CUDA source saved: "] <> destFile]
      ]],
      cudaFiles];
    
    (* \:30bb\:30c3\:30b7\:30e7\:30f3\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306b\:3082 CUDA \:30d5\:30a1\:30a4\:30eb\:3092\:4fdd\:5b58 *)
    Scan[Function[cf,
      Module[{sf, strm},
        sf = FileNameJoin[{sessionDir, "cuda_" <> cf["filename"]}];
        strm = OpenWrite[sf, BinaryFormat -> True];
        BinaryWrite[strm, ToCharacterCode[cf["content"], "UTF-8"]];
        Close[strm]]],
      cudaFiles];
    
    (* \:30b3\:30f3\:30d1\:30a4\:30eb\:8a66\:884c *)
    iCUDAAttemptCompile[nb, packageName];
    
    savedFiles
  ];

(* ============================================================
   CUDA \:30dd\:30b9\:30c8\:30d7\:30ed\:30bb\:30b9: ClaudeUpdatePackage \:7528
   ============================================================ *)

iCUDAPostProcessUpdate[nb_NotebookObject, response_String,
    packageName_String, sessionDir_String] :=
  Module[{cudaFiles},
    cudaFiles = iCUDAExtractFiles[response];
    If[Length[cudaFiles] === 0,
      (* CUDA \:30d5\:30a1\:30a4\:30eb\:306e\:5909\:66f4\:306a\:3057 \[LongDash] \:6b63\:5e38 *)
      Return[{}]];
    
    (* Create \:3068\:540c\:3058\:51e6\:7406 *)
    iCUDAPostProcessCreate[nb, response, packageName, sessionDir]
  ];

(* ============================================================
   CUDA \:30b3\:30f3\:30d1\:30a4\:30eb
   ============================================================ *)

iCUDAAttemptCompile[nb_NotebookObject, packageName_String] :=
  Module[{cudaDir, srcDir, binDir, cuFiles, nvcc, wlIncDir, wlLibDir,
          compiled = {}, failed = {}},
    cudaDir = iCUDADir[packageName];
    srcDir = FileNameJoin[{cudaDir, "src"}];
    binDir = FileNameJoin[{cudaDir, "bin"}];
    
    If[!DirectoryQ[srcDir],
      nbPrint[nb, iL[
        "\:26a0 CUDA src \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093\:3002",
        "\:26a0 CUDA src directory not found."]];
      Return[$Failed]];
    
    cuFiles = FileNames["*.cu", srcDir];
    If[Length[cuFiles] === 0,
      nbPrint[nb, iL[
        "\:26a0 \:30b3\:30f3\:30d1\:30a4\:30eb\:5bfe\:8c61\:306e .cu \:30d5\:30a1\:30a4\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002",
        "\:26a0 No .cu files to compile."]];
      Return[$Failed]];
    
    nvcc = iNvccPath[];
    If[nvcc === "",
      nbPrint[nb, Style[iL[
        "\:26a0 nvcc \:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002CUDA Toolkit \:3092\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
        "  \:30b3\:30f3\:30d1\:30a4\:30eb\:306f\:30b9\:30ad\:30c3\:30d7\:3055\:308c\:307e\:3057\:305f\:3002\:30d1\:30c3\:30b1\:30fc\:30b8\:521d\:56de\:30ed\:30fc\:30c9\:6642\:306b\:81ea\:52d5\:30b3\:30f3\:30d1\:30a4\:30eb\:3055\:308c\:307e\:3059\:3002",
        "\:26a0 nvcc not found. Install CUDA Toolkit.\n" <>
        "  Compilation skipped. Will auto-compile on first package load."],
        FontColor -> RGBColor[0.8, 0.5, 0]]];
      Return[$Failed]];
    
    wlIncDir = FileNameJoin[{$InstallationDirectory,
      "SystemFiles", "IncludeFiles", "C"}];
    wlLibDir = FileNameJoin[{$InstallationDirectory,
      "SystemFiles", "Libraries", $SystemID}];
    
    Quiet @ CreateDirectory[binDir, CreateIntermediateDirectories -> True];
    
    nbPrint[nb, iL[
      "\:1f680 CUDA \:30b3\:30f3\:30d1\:30a4\:30eb\:958b\:59cb...",
      "\:1f680 Starting CUDA compilation..."]];
    
    Scan[Function[cuFile,
      Module[{outFile, baseName, cmd, result},
        baseName = FileBaseName[cuFile];
        outFile = FileNameJoin[{binDir, baseName <> iCUDALibExt[]}];
        cmd = Switch[$OperatingSystem,
          "Windows",
            {nvcc, "--shared", "-o", outFile, cuFile,
              "-I" <> wlIncDir,
              "-L" <> wlLibDir, "-lWolframRTL",
              "--compiler-options", "/utf-8"},
          _, (* Linux / macOS *)
            {nvcc, "--shared", "--compiler-options", "-fPIC",
              "-o", outFile, cuFile,
              "-I" <> wlIncDir,
              "-L" <> wlLibDir, "-lWolframRTL"}
        ];
        nbPrint[nb, "  nvcc " <> FileNameTake[cuFile] <> " \[RightArrow] " <>
          FileNameTake[outFile]];
        result = Quiet @ Check[RunProcess[cmd], <|"ExitCode" -> -1,
          "StandardError" -> "RunProcess failed"|>];
        If[result["ExitCode"] === 0,
          AppendTo[compiled, outFile];
          nbPrint[nb, Style["  \:2714 " <> FileNameTake[outFile],
            FontColor -> Darker[Green]]],
          AppendTo[failed, cuFile];
          nbPrint[nb, Style[
            "  \:274c " <> FileNameTake[cuFile] <> ": " <>
            StringTake[result["StandardError"], UpTo[200]],
            FontColor -> RGBColor[0.8, 0, 0]]]
        ]
      ]],
      cuFiles];
    
    If[Length[failed] > 0,
      nbPrint[nb, Style[iL[
        "\:26a0 " <> ToString[Length[failed]] <>
        " \:500b\:306e\:30d5\:30a1\:30a4\:30eb\:306e\:30b3\:30f3\:30d1\:30a4\:30eb\:304c\:5931\:6557\:3057\:307e\:3057\:305f\:3002",
        "\:26a0 " <> ToString[Length[failed]] <>
        " file(s) failed to compile."],
        FontColor -> RGBColor[0.8, 0.4, 0]]],
      If[Length[compiled] > 0,
        nbPrint[nb, Style[iL[
          "\:2714 CUDA \:30b3\:30f3\:30d1\:30a4\:30eb\:5b8c\:4e86: " <>
          ToString[Length[compiled]] <> " \:500b\:306e\:30e9\:30a4\:30d6\:30e9\:30ea",
          "\:2714 CUDA compilation done: " <>
          ToString[Length[compiled]] <> " library(ies)"],
          FontColor -> Darker[Green]]]]
    ];
    
    If[Length[compiled] > 0, compiled, $Failed]
  ];

(* ============================================================
   \:30e6\:30fc\:30c6\:30a3\:30ea\:30c6\:30a3: CUDA \:30d0\:30c3\:30af\:30a2\:30c3\:30d7
   ============================================================ *)

(* CUDA \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:3082\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5bfe\:8c61\:306b\:542b\:3081\:308b *)
iCUDABackupSources[sessionDir_String, packageName_String] :=
  Module[{cudaDir, srcDir, cuFiles, destDir},
    cudaDir = iCUDADir[packageName];
    srcDir = FileNameJoin[{cudaDir, "src"}];
    If[!DirectoryQ[srcDir], Return[{}]];
    cuFiles = FileNames["*.cu" | "*.cuh", srcDir];
    If[Length[cuFiles] === 0, Return[{}]];
    destDir = FileNameJoin[{sessionDir, "cuda_src_backup"}];
    Quiet @ CreateDirectory[destDir, CreateIntermediateDirectories -> True];
    Function[f,
      Quiet @ CopyFile[f,
        FileNameJoin[{destDir, FileNameTake[f]}],
        OverwriteTarget -> True]
    ] /@ cuFiles
  ];

(* ============================================================
   CUDA \:30d1\:30c3\:30b1\:30fc\:30b8\:304b\:3069\:3046\:304b\:306e\:5224\:5b9a
   ============================================================ *)

(* \:65e2\:5b58\:30d1\:30c3\:30b1\:30fc\:30b8\:304c CUDA \:3092\:4f7f\:7528\:3057\:3066\:3044\:308b\:304b\:5224\:5b9a *)
iIsCUDAPackage[packageName_String] :=
  DirectoryQ[iCUDADir[packageName]];

End[];

Print[Style["cuda.wl \:30d1\:30c3\:30b1\:30fc\:30b8 \[LongDash] ClaudeCode CUDA \:62e1\:5f35", Bold]];
Print["  CUDA \:5bfe\:5fdc\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:4f5c\:6210\:30fb\:66f4\:65b0\:3092\:30b5\:30dd\:30fc\:30c8"];
Print["  nvcc: " <> If[ClaudeCode`Private`iNvccAvailableQ[],
  "detected (v" <> ClaudeCode`Private`iNvccVersion[] <> ")",
  "not found"]];
