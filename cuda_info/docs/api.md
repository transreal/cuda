# cuda パッケージ API リファレンス

このファイルは `ClaudeCode`Private`` コンテキスト内にロードされる CUDA 拡張モジュール (`cuda.wl`) のリファレンスである。直接ユーザーが呼び出すパブリック API は持たず、`claudecode.wl` の `ClaudeCreatePackage` / `ClaudeUpdatePackage` から内部的に利用される。

## 概要と用途

`cuda.wl` は CUDA を使うパッケージの作成・更新フローに以下の機能を注入する:

- LLM プロンプトへの CUDA 生成指示ブロックの付加
- LLM レスポンスからの `.cu` / `.cuh` ファイル抽出
- `<packageName>.cuda/src/` への CUDA ソース保存
- nvcc による自動コンパイルと `<packageName>.cuda/bin/` への出力
- セッションディレクトリへのバックアップ

## ディレクトリ構造規約

CUDA パッケージが使うディレクトリ構造:

```
$packageDirectory/
  <packageName>.cuda/
    src/          ← .cu / .cuh ソースファイル
    bin/          ← コンパイル済み共有ライブラリ (.dll/.so/.dylib)
  <packageName>.wl  ← Mathematica ラッパーパッケージ
```

## CUDA ファイルマーカープロトコル

LLM レスポンス内で CUDA ソースファイルを出力するためのマーカー形式:

```
===BEGIN_CUDA_FILE:<filename>===
<CUDAソースコード>
===END_CUDA_FILE===
```

- `.wl` 本体の終端マーカー**より後**に配置する
- `<filename>` には `kernels.cu` のようなファイル名のみ（パスなし）を指定する
- 複数ファイルは複数のマーカーブロックを順に並べる

## CUDA パッケージ (.wl) が持つべき実装規約

`ClaudeCreatePackage` で CUDA パッケージを生成するとき、LLM が出力する `.wl` に含めるべき要素:

| 要素 | 内容 |
|------|------|
| `$<packageName>CUDADir` | `.cuda` ディレクトリパスを保持する変数 |
| `i<packageName>FindNvcc[]` | nvcc を探してパスを返す関数 |
| `i<packageName>CompileCUDA[]` | nvcc でコンパイルし共有ライブラリを `bin/` に出力する関数 |
| LibraryFunctionLoad | コンパイル済みライブラリをロードして Mathematica 関数として公開 |
| フォールバック実装 | CUDA 非利用環境向けの純 Mathematica 実装 |

コンパイルコマンドパターン:

```
nvcc --shared -o output<ext> source.cu \
  -I"<$InstallationDirectory>/SystemFiles/IncludeFiles/C" \
  -L"<$InstallationDirectory>/SystemFiles/Libraries/<$SystemID>" \
  -lWolframRTL
```

Linux/macOS では `--compiler-options -fPIC` を追加する。Windows では `--compiler-options /utf-8` を使う。

## CUDA ソース (.cu) の LibraryLink インターフェース規約

LLM が出力する `.cu` ファイルに必要なインターフェース:

```c
#include "WolframLibrary.h"

DLLEXPORT mint WolframLibrary_getVersion() { return WolframLibraryVersion; }
DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) { return 0; }
DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {}

// エクスポート関数のシグネチャ
DLLEXPORT int functionName(
    WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);
```

引数アクセス: `MArgument_getInteger`, `MArgument_getReal`, `MArgument_getMTensor` 等。
戻り値設定: `MArgument_setInteger`, `MArgument_setReal`, `MArgument_setMTensor` 等。
CUDA エラー処理: `cudaGetLastError()` / `cudaGetErrorString()` を使う。

## 内部関数リファレンス (ClaudeCode`Private`)

### iCUDADir[packageName] → String
パッケージの `.cuda` ディレクトリの絶対パスを返す。ディレクトリの存在は保証しない。

### iEnsureCUDADir[packageName] → String
`.cuda` ディレクトリおよび `src/`, `bin/` サブディレクトリを作成し、`.cuda` ディレクトリパスを返す。

### iNvccPath[] → String
nvcc 実行ファイルのパスを返す。見つからなければ `""` を返す。結果はメモ化される。

### iNvccAvailableQ[] → True | False
nvcc が利用可能かを返す。

### iNvccVersion[] → String
nvcc のバージョン文字列 (例: `"12.3"`) を返す。nvcc がなければ `""` を返す。

### iCUDALibExt[] → String
OS に応じた共有ライブラリ拡張子を返す: `".dll"` (Windows), `".dylib"` (macOS), `".so"` (Linux)。

### iCUDACreatePromptBlock[packageName] → String
`ClaudeCreatePackage` 用の CUDA 生成指示テキストブロックを返す。nvcc 検出状況、ディレクトリ構造、`.wl` 要件、`.cu` LibraryLink インターフェース仕様を含む。

### iCUDAUpdatePromptBlock[packageName] → String
`ClaudeUpdatePackage` 用の CUDA 更新指示テキストブロックを返す。既存 `.cu` ソース (最大5ファイル) をコンテキストとして含む。

### iCUDAExtractFiles[response] → {<|"filename" -> String, "content" -> String|>, ...}
LLM レスポンス文字列から CUDA ファイルマーカーを検出し、ファイル名とコンテンツの Association リストを返す。マーカーが存在しない場合は `{}` を返す。

### iCUDAPostProcessCreate[nb, response, packageName, sessionDir] → {String, ...}
`ClaudeCreatePackage` のポストプロセスとして実行される:
1. レスポンスから CUDA ファイルを抽出
2. `<packageName>.cuda/src/` に保存 (既存ファイルは `sessionDir` にバックアップ)
3. `sessionDir` にも `cuda_<filename>` としてコピー
4. `iCUDAAttemptCompile` でコンパイルを試行
保存されたファイルパスのリストを返す。

### iCUDAPostProcessUpdate[nb, response, packageName, sessionDir] → {String, ...}
`ClaudeUpdatePackage` のポストプロセス。CUDA ファイルが含まれない場合は `{}` を返して正常終了。含まれる場合は `iCUDAPostProcessCreate` と同じ処理を行う。

### iCUDAAttemptCompile[nb, packageName] → {String, ...} | $Failed
`<packageName>.cuda/src/` 内の全 `.cu` ファイルを nvcc でコンパイルし、`<packageName>.cuda/bin/` に共有ライブラリを出力する。コンパイル成功したライブラリパスのリストを返す。nvcc が見つからない場合や全ファイル失敗の場合は `$Failed` を返す。ノートブック `nb` に進捗とエラーを出力する。

### iCUDABackupSources[sessionDir, packageName] → {String, ...}
`<packageName>.cuda/src/` 内の `.cu` / `.cuh` ファイルを `sessionDir/cuda_src_backup/` にコピーする。コピーされたファイルパスのリストを返す。

### iIsCUDAPackage[packageName] → True | False
`<packageName>.cuda` ディレクトリが存在するかを返す。既存パッケージが CUDA を使用しているかの判定に使う。

## claudecode との統合ポイント

`claudecode.wl` は以下のタイミングで `cuda.wl` の関数を呼ぶ:

| タイミング | 呼び出す関数 |
|-----------|-------------|
| `ClaudeCreatePackage` プロンプト構築時 | `iCUDACreatePromptBlock` |
| `ClaudeUpdatePackage` プロンプト構築時 | `iCUDAUpdatePromptBlock` (CUDA パッケージのみ) |
| `ClaudeCreatePackage` レスポンス処理後 | `iCUDAPostProcessCreate` |
| `ClaudeUpdatePackage` レスポンス処理後 | `iCUDAPostProcessUpdate` |
| バックアップ処理時 | `iCUDABackupSources` |
| CUDA パッケージ判定 | `iIsCUDAPackage` |