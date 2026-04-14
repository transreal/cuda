# cuda パッケージ 使用例集

cuda パッケージは `ClaudeCode` の拡張として自動読み込まれます。以下の例はすべて Mathematica ノートブック上で実行できます。

---

## 例 1: CUDA 環境の確認

nvcc が利用可能かどうかをセッション開始時に確認します。

```mathematica
(* cuda.wl は claudecode.wl 読み込み時に自動ロードされます *)
Get["claudecode.wl"]

(* nvcc の検出状態はロード時のメッセージで確認できます *)
(* 出力例: nvcc: detected (v12.3) または nvcc: not found *)
```

期待される出力: `cuda.wl パッケージ — ClaudeCode CUDA 拡張`、`nvcc: detected (v12.3)`

---

## 例 2: CUDA 対応パッケージの新規作成

GPU アクセラレーションを使うパッケージを作成します。

```mathematica
ClaudeCreatePackage["VectorAdd",
  "2つのベクトルの要素ごとの加算をCUDAカーネルで実装する。
   VectorAddGPU[a_List, b_List] を公開関数として提供する。"]
```

期待される出力: `.cuda/src/kernels.cu` と `VectorAdd.wl` が生成され、nvcc でコンパイルが実行されます。

---

## 例 3: CUDA パッケージのディレクトリ構造確認

作成後のディレクトリ構成を確認します。

```mathematica
packageName = "VectorAdd";
cudaDir = FileNameJoin[{$packageDirectory, packageName <> ".cuda"}];

(* src と bin ディレクトリの内容を確認 *)
FileNames["*", cudaDir, Infinity]
```

期待される出力: `{".../VectorAdd.cuda/src/kernels.cu", ".../VectorAdd.cuda/bin/kernels.dll"}`

---

## 例 4: 既存 CUDA パッケージの機能追加

既存の CUDA パッケージにドット積カーネルを追加します。

```mathematica
ClaudeUpdatePackage["VectorAdd",
  "DotProductGPU[a_List, b_List] 関数を追加する。
   対応する __global__ カーネルを kernels.cu に実装し、
   LibraryLink 経由で Mathematica から呼び出せるようにする。"]
```

期待される出力: `kernels.cu` が更新され、再コンパイルが実行されます。

---

## 例 5: 行列積 CUDA パッケージの作成

大規模行列積を GPU で高速化するパッケージを作成します。

```mathematica
ClaudeCreatePackage["MatMulGPU",
  "行列積 C = A * B を CUDA で実装する。
   MatMulGPU[a_?MatrixQ, b_?MatrixQ] を公開する。
   cuBLAS は使わず、タイリングを用いた共有メモリ最適化カーネルで実装する。
   CUDA 未対応環境では Dot[] にフォールバックする。"]
```

期待される出力: `MatMulGPU.wl`、`MatMulGPU.cuda/src/matmul.cu` が生成されます。

---

## 例 6: GPU/CPU フォールバック付き関数の呼び出し

CUDA ライブラリがロードされているかどうかで処理が切り替わります。

```mathematica
Get[FileNameJoin[{$packageDirectory, "MatMulGPU.wl"}]]

a = RandomReal[{0, 1}, {512, 512}];
b = RandomReal[{0, 1}, {512, 512}];

(* GPU が使えれば GPU で、なければ CPU で実行 *)
result = MatMulGPU[a, b];
Dimensions[result]
```

期待される出力: `{512, 512}`

---

## 例 7: CUDA パッケージかどうかの判定

`$packageDirectory` 内のパッケージが CUDA 対応かを確認します。

```mathematica
(* .cuda ディレクトリの存在で判定できます *)
cudaPackages = Select[
  FileBaseName /@ FileNames["*.wl", $packageDirectory],
  DirectoryQ[FileNameJoin[{$packageDirectory, # <> ".cuda"}]] &
]
```

期待される出力: `{"VectorAdd", "MatMulGPU"}`（作成済みのパッケージ一覧）

---

## 例 8: ドキュメントの生成

CUDA パッケージのドキュメントを生成します。

```mathematica
ClaudeGenerateDocumentation["VectorAdd"]
(* 生成先: $packageDirectory/VectorAdd_info/docs/ *)
```

期待される出力: `VectorAdd_info/docs/` 以下に各関数のドキュメントと `README.md` が生成されます。