# cuda

ClaudeCode の CUDA 拡張モジュール — GPU アクセラレーション付きパッケージの生成・コンパイル・LibraryLink 連携を自動化します。

## 設計思想と実装の概要

`cuda` パッケージは、[claudecode](https://github.com/transreal/claudecode) の拡張として設計された CUDA サポートモジュールです。単独で使用するパブリック API を持たず、`ClaudeCreatePackage` / `ClaudeUpdatePackage` のワークフローに透過的に組み込まれることで、ユーザーが CUDA の詳細を意識することなく GPU アクセラレーション付きパッケージを作成できるようにするという設計思想に基づいています。

### なぜこのように設計されているか

従来、Mathematica から CUDA カーネルを利用するには、LibraryLink インターフェースの記述・nvcc によるコンパイル・`LibraryFunctionLoad` による関数公開という複数の手順を手動で行う必要がありました。`cuda.wl` はこの一連の作業を LLM プロンプトへの指示注入とポストプロセス処理によって完全に自動化し、開発者がアルゴリズムの仕様を記述するだけで GPU 対応パッケージが生成されるフローを実現しています。

### 実装の概要

パッケージは以下の 4 つの責務を担います。

**1. プロンプト拡張**
`ClaudeCreatePackage` / `ClaudeUpdatePackage` の呼び出し時に、LLM へのプロンプトに CUDA 生成指示ブロック（`iCUDACreatePromptBlock` / `iCUDAUpdatePromptBlock`）を自動付加します。このブロックには nvcc の検出状況、ディレクトリ構造規約、LibraryLink インターフェース要件が含まれ、LLM が適切な `.wl` と `.cu` を生成できるよう誘導します。

**2. CUDA ファイルマーカープロトコル**
LLM レスポンス内で CUDA ソースファイルを識別するための独自マーカー形式を定義しています。

```
===BEGIN_CUDA_FILE:<filename>===
<CUDAソースコード>
===END_CUDA_FILE===
```

`iCUDAExtractFiles` がレスポンス文字列から正規表現でこのブロックを抽出し、ファイル名とコンテンツに分離します。

**3. ソース保存と自動コンパイル**
抽出した `.cu` / `.cuh` ファイルを `<パッケージ名>.cuda/src/` へ UTF-8 バイナリとして保存し、`iCUDAAttemptCompile` が nvcc を呼び出してコンパイルします。コンパイルコマンドは OS ごとに自動切替されます（Windows: `/utf-8` オプション、Linux/macOS: `-fPIC` オプション）。バイナリはソースより新しければ再コンパイルをスキップするタイムスタンプ比較も実装されています。

**4. nvcc 検出のメモ化**
`iNvccPath[]` は実行結果をメモ化し、同一セッション内で複数回 nvcc を探索しないよう最適化されています。Windows・macOS・Linux それぞれの標準インストールパスを網羅的にサーチし、PATH 上の nvcc もフォールバックとして検索します。

生成される `.wl` パッケージには、CUDA ディレクトリパス変数・コンパイルヘルパー・LibraryLink ロード処理・CUDA 非利用環境向けの純 Mathematica フォールバック実装が含まれることを LLM に要求しており、CUDA 環境がないマシンでもパッケージが動作するロバスト性を担保しています。

## 詳細説明

### 動作環境

| 項目 | 要件 |
|------|------|
| Mathematica | 13.0 以上 |
| GPU | NVIDIA GPU（Compute Capability 3.5 以上推奨） |
| CUDA Toolkit | 11.0 以上（`nvcc` が PATH 上にあること） |
| C++ コンパイラ | Windows: Visual Studio 2019+ (MSVC) |
| OS | Windows 11（主要検証環境）、macOS / Linux（生成 AI による対応） |
| 依存パッケージ | claudecode |

### インストール

`cuda.wl` は `claudecode.wl` の拡張として自動ロードされます。単独でロードする必要はありません。`cuda.wl` を `$packageDirectory` 直下に配置してください。

```
$packageDirectory\
  claudecode.wl   ← claudecode 本体
  cuda.wl         ← 本パッケージ（ここに配置）
```

`claudecode.wl` をロードすることで `cuda.wl` も自動的に読み込まれます。

```mathematica
AppendTo[$Path, $packageDirectory];

Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

ロード成功時には以下のようなメッセージが表示されます。

```
cuda.wl パッケージ — ClaudeCode CUDA 拡張
  CUDA 対応パッケージの作成・更新をサポート
  nvcc: detected (v12.x)
```

nvcc が見つからない場合は `nvcc: not found` と表示されますが、claudecode 本体は正常に動作します。CUDA コンパイルはパッケージ初回ロード時に改めて試みられます。

#### 事前準備: CUDA Toolkit のインストール

NVIDIA 公式サイトから CUDA Toolkit をダウンロードしてインストールしてください。インストール後、以下で確認できます。

```powershell
nvcc --version
```

`release XX.X` が表示されれば正常です。Windows 標準インストール先: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\vXX.X\bin`

### クイックスタート

`claudecode` をロード後、以下の手順で CUDA 対応パッケージを作成できます。

```mathematica
(* 1. claudecode をロード（cuda.wl も自動ロードされます） *)
AppendTo[$Path, $packageDirectory];
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];

(* 2. nvcc の検出確認 *)
ClaudeCode`Private`iNvccAvailableQ[]
(* => True または False *)

(* 3. CUDA 対応パッケージを新規作成 *)
ClaudeCreatePackage["VectorAdd",
  "2つのベクトルの要素ごとの加算をCUDAカーネルで実装する。
   VectorAddGPU[a_List, b_List] を公開関数として提供する。
   CUDA 未対応環境では純 Mathematica でフォールバックする。"]

(* 生成結果:
   $packageDirectory/VectorAdd.wl
   $packageDirectory/VectorAdd.cuda/src/kernels.cu
   $packageDirectory/VectorAdd.cuda/bin/kernels.dll  ← 自動コンパイル *)

(* 4. 生成されたパッケージを使用 *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["VectorAdd`", "VectorAdd.wl"]];

a = {1.0, 2.0, 3.0};
b = {4.0, 5.0, 6.0};
VectorAddGPU[a, b]
(* => {5.0, 7.0, 9.0} *)
```

既存の CUDA パッケージに機能を追加する場合は `ClaudeUpdatePackage` を使用します。

```mathematica
ClaudeUpdatePackage["VectorAdd",
  "DotProductGPU[a_List, b_List] 関数を追加する。
   対応する __global__ カーネルを kernels.cu に実装し、
   LibraryLink 経由で Mathematica から呼び出せるようにする。"]
(* CUDA ファイルが変更されると自動的に再コンパイルが実行されます *)
```

### 主な機能

**CUDA 対応パッケージの自動生成**
`ClaudeCreatePackage` に CUDA を含む仕様を記述するだけで、Mathematica ラッパー（`.wl`）と CUDA ソース（`.cu`）を同時に生成します。nvcc による自動コンパイルまでを一括処理します。

**CUDA 対応パッケージの自動更新**
`ClaudeUpdatePackage` で既存 CUDA パッケージを更新する際、CUDA ソースを変更する必要がある場合は `.cu` ファイルも自動更新・再コンパイルします。変更がなければコンパイルはスキップされます。

**nvcc 自動検出とメモ化**
Windows・macOS・Linux の標準インストールパスを網羅的に検索し、最初に見つかった nvcc パスをメモ化します。セッション内で重複探索しません。

**OS 対応コンパイルコマンド生成**
Windows（`--compiler-options /utf-8`）・Linux/macOS（`--compiler-options -fPIC`）それぞれの適切なコンパイルオプションを自動選択します。

**タイムスタンプによる再コンパイルスキップ**
バイナリがソースより新しい場合はコンパイルをスキップし、不要なビルド時間を削減します。

**GPU/CPU フォールバック実装の要求**
生成される `.wl` パッケージに CUDA 非対応環境向けの純 Mathematica フォールバック実装を含めるよう LLM に指示し、CUDA 環境がないマシンでもパッケージが動作するようにします。

**セッションバックアップ**
CUDA ソースファイルの更新前にセッションディレクトリへバックアップを自動作成します。

**ディレクトリ構造の自動管理**
`<パッケージ名>.cuda/src/` および `<パッケージ名>.cuda/bin/` を自動作成・管理します。

### ドキュメント一覧

| ファイル | 内容 |
|----------|------|
| `api.md` | 内部関数リファレンス・CUDA ファイルマーカープロトコル・LibraryLink インターフェース規約 |
| `user_manual.md` | 基本的な使い方・ディレクトリ構造詳細・生成パッケージの構成要素 |
| `setup.md` | インストール手順・CUDA Toolkit セットアップ・よくあるエラーと対処法 |
| `example.md` | 使用例集（環境確認・パッケージ作成・更新・CUDA 判定など） |

## 使用例・デモ

### 例 1: CUDA 環境の確認

```mathematica
(* claudecode ロード後に nvcc 検出状況を確認 *)
ClaudeCode`Private`iNvccAvailableQ[]
(* => True *)

ClaudeCode`Private`iNvccPath[]
(* => "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.x\bin\nvcc.exe" *)

ClaudeCode`Private`iNvccVersion[]
(* => "12.x" *)
```

### 例 2: 行列積 CUDA パッケージの作成

```mathematica
ClaudeCreatePackage["MatMulGPU",
  "行列積 C = A * B を CUDA で実装する。
   MatMulGPU[a_?MatrixQ, b_?MatrixQ] を公開する。
   cuBLAS は使わず、タイリングを用いた共有メモリ最適化カーネルで実装する。
   CUDA 未対応環境では Dot[] にフォールバックする。"]

(* 生成後に実行 *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["MatMulGPU`", "MatMulGPU.wl"]];

a = RandomReal[{0, 1}, {512, 512}];
b = RandomReal[{0, 1}, {512, 512}];
result = MatMulGPU[a, b];
Dimensions[result]
(* => {512, 512} *)
```

### 例 3: CUDA 対応パッケージの一覧取得

```mathematica
(* .cuda ディレクトリの存在で CUDA 対応パッケージを判定 *)
cudaPackages = Select[
  FileBaseName /@ FileNames["*.wl", $packageDirectory],
  DirectoryQ[FileNameJoin[{$packageDirectory, # <> ".cuda"}]] &
]
(* => {"VectorAdd", "MatMulGPU"} *)
```

### 例 4: ドキュメントの生成

```mathematica
ClaudeGenerateDocumentation["VectorAdd"]
(* 生成先: $packageDirectory/VectorAdd_info/docs/ *)
```

## 免責事項

本ソフトウェアは "as is"（現状有姿）で提供されており、明示・黙示を問わずいかなる保証もありません。
本ソフトウェアの使用または使用不能から生じるいかなる損害についても責任を負いません。
今後の動作保証のための更新が行われるとは限りません。
本ソフトウェアとドキュメントはほぼすべてが生成AIによって生成されたものです。
Windows 11上での実行を想定しており、MacOS, LinuxのMathematicaでの動作検証は一切していません(生成AIの処理で対応可能と想定されます)。

## ライセンス

```
MIT License

Copyright (c) 2026 Katsunobu Imai

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.