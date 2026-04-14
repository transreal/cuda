# cuda パッケージ ユーザーマニュアル

## 概要

`cuda` パッケージは ClaudeCode の CUDA 拡張モジュールです。`ClaudeCreatePackage` および `ClaudeUpdatePackage` に CUDA GPU 対応機能を追加し、CUDA C/C++ ソースの生成・保存・コンパイルと LibraryLink 経由の Mathematica 連携を自動化します。

このパッケージは `claudecode.wl` から自動ロードされます。ユーザーが直接 `Get` する必要はありません。

---

## 基本的な使い方

### CUDA 対応パッケージの新規作成

`ClaudeCreatePackage` に CUDA 機能を含む仕様を記述するだけで、Claude が Mathematica ラッパー（`.wl`）と CUDA ソース（`.cu`）を同時に生成します。

```mathematica
ClaudeCreatePackage["VectorAdd",
  "2つのベクトルをGPUで加算するCUDAパッケージ。AddVectors[a, b]を公開する。"]
```

生成後のディレクトリ構造：

```
$packageDirectory/
  VectorAdd.wl          ← Mathematica ラッパー
  VectorAdd.cuda/
    src/
      kernels.cu        ← CUDA カーネルソース
    bin/
      kernels.dll       ← コンパイル済みライブラリ（Windows）
```

### CUDA 対応パッケージの更新

既存の CUDA パッケージを更新する場合も通常どおり `ClaudeUpdatePackage` を使用します。CUDA ソースを変更する必要がある場合、Claude が自動的に `.cu` ファイルも更新します。

```mathematica
ClaudeUpdatePackage["VectorAdd",
  "行列積 MatMul[a, b] を追加する。CUBLASを使用すること。"]
```

CUDA ファイルが変更された場合は自動的に再コンパイルが実行されます。

---

## CUDA 環境の確認

パッケージロード時に nvcc の有無が自動検出され、ノートブックに状態が表示されます。

| 状態 | 表示 |
|------|------|
| nvcc 検出済み | `nvcc: detected (v12.x.x)` |
| nvcc 未検出 | `nvcc: not found` |

nvcc が見つからない場合、CUDA コンパイルはスキップされます。パッケージ初回ロード時に改めて自動コンパイルを試みます。

---

## ディレクトリ構造の詳細

CUDA 対応パッケージは `<パッケージ名>.cuda/` フォルダを使用します。

```
<パッケージ名>.cuda/
  src/    ← .cu / .cuh ソースファイル（ClaudeCode が管理）
  bin/    ← コンパイル済み共有ライブラリ（自動生成）
```

| サブフォルダ | 内容 |
|------------|------|
| `src/` | CUDA C/C++ ソースファイル |
| `bin/` | `.dll`（Windows）/ `.so`（Linux）/ `.dylib`（macOS） |

---

## 生成されるパッケージの構成要素

Claude が生成する `.wl` ファイルには以下が含まれます。

### CUDA ディレクトリパス変数

```mathematica
$VectorAddCUDADir  (* パッケージ名.cuda/ への絶対パス *)
```

### コンパイル関数（テンプレート）

```mathematica
(* 自動生成されるコンパイルヘルパー *)
iVectorAddCompileCUDA[] := Module[
  {cudaDir, srcFile, outFile, nvcc, wlIncDir, wlLibDir, cmd, result},
  cudaDir = $VectorAddCUDADir;
  srcFile = FileNameJoin[{cudaDir, "src", "kernels.cu"}];
  outFile = FileNameJoin[{cudaDir, "bin", "kernels.dll"}];
  (* バイナリがソースより新しければスキップ *)
  If[FileExistsQ[outFile] &&
     FileDate[outFile, "Modification"] > FileDate[srcFile, "Modification"],
    Return[outFile]];
  (* nvcc でコンパイル *)
  ...
]
```

### LibraryLink によるカーネル呼び出し

```mathematica
(* 生成される公開関数の例 *)
AddVectors[a_List, b_List] := iVectorAddLib["add_vectors", ...]
```

---

## CUDA ソースファイルの要件

Claude が生成する `.cu` ファイルは以下の LibraryLink インターフェースを含みます。

```c
#include "WolframLibrary.h"

DLLEXPORT mint WolframLibrary_getVersion() {
    return WolframLibraryVersion;
}
DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    return 0;
}
DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {}

/* 公開カーネル関数の例 */
DLLEXPORT int add_vectors(
    WolframLibraryData libData,
    mint Argc, MArgument *Args, MArgument Res) {
    /* CUDA カーネル呼び出し */
    ...
    return LIBRARY_NO_ERROR;
}
```

---

## コンパイルコマンドの詳細

内部的に以下の nvcc コマンドが実行されます。

**Windows:**
```
nvcc --shared -o kernels.dll kernels.cu
  -I"<Mathematica>/SystemFiles/IncludeFiles/C"
  -L"<Mathematica>/SystemFiles/Libraries/<SystemID>"
  -lWolframRTL --compiler-options /utf-8
```

**Linux / macOS:**
```
nvcc --shared --compiler-options -fPIC
  -o kernels.so kernels.cu
  -I"<Mathematica>/SystemFiles/IncludeFiles/C"
  -L"<Mathematica>/SystemFiles/Libraries/<SystemID>"
  -lWolframRTL
```

---

## CUDA 未使用時のフォールバック

nvcc が利用できない環境向けに、Claude が生成するパッケージは純粋な Mathematica 実装によるフォールバックを含みます。

```mathematica
(* 生成パッケージ内のフォールバック例 *)
AddVectors[a_List, b_List] :=
  If[$VectorAddCUDAAvailable,
    iAddVectorsCUDA[a, b],   (* GPU 実装 *)
    a + b                    (* CPU フォールバック *)
  ]
```

---

## バックアップ

`ClaudeUpdatePackage` 実行時、既存の CUDA ソースファイルはセッションディレクトリに自動バックアップされます。

```
<セッションディレクトリ>/
  cuda_src_backup/
    kernels.cu    ← 更新前のソース
```

---

## トラブルシューティング

### nvcc が見つからない

CUDA Toolkit をインストール後、システムの `PATH` に nvcc のディレクトリを追加してください。

- Windows: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\<version>\bin`
- Linux / macOS: `/usr/local/cuda/bin`

Mathematica を再起動後、パッケージをリロードしてください。

```mathematica
Needs["VectorAdd`"]  (* 再ロードで自動コンパイルを試みる *)
```

### コンパイルエラー

ノートブックにエラーメッセージが表示されます。`StandardError` の内容を確認し、`ClaudeUpdatePackage` で修正を依頼してください。

```mathematica
ClaudeUpdatePackage["VectorAdd",
  "コンパイルエラーを修正: <エラーメッセージを貼り付け>"]
```

### CUDA ディレクトリが存在しない

`<パッケージ名>.cuda/` フォルダが存在しない場合、そのパッケージは CUDA 非対応と判定されます。CUDA 機能を追加するには `ClaudeUpdatePackage` で CUDA カーネルの追加を指示してください。

---

## 関連パッケージ

- [claudecode](https://github.com/transreal/claudecode) — このパッケージをロードする ClaudeCode 本体