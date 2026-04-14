# cuda パッケージ インストール手順書

macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください。

---

## 動作要件

| 項目 | 要件 |
|------|------|
| Mathematica | 13.0 以上 |
| GPU | NVIDIA GPU (Compute Capability 3.5 以上推奨) |
| CUDA Toolkit | 11.0 以上 (`nvcc` が PATH 上にあること) |
| C++ コンパイラ | Windows: Visual Studio 2019+ (MSVC) |
| 依存パッケージ | claudecode |

---

## 事前準備: CUDA Toolkit のインストール

1. NVIDIA 公式サイトから CUDA Toolkit をダウンロードしてインストールします。
2. インストール後、以下を PowerShell で確認します。

```powershell
nvcc --version
```

`release XX.X` が表示されれば正常です。

3. 環境変数 `PATH` に nvcc のディレクトリが含まれていることを確認します。
   標準インストール先: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\vXX.X\bin`

---

## パッケージの配置

`cuda.wl` は **claudecode パッケージの拡張として自動ロード** されます。
単独でロードする必要はありません。

`cuda.wl` を `$packageDirectory` 直下に配置してください。

```
$packageDirectory\
  claudecode.wl   ← claudecode 本体
  cuda.wl         ← 本パッケージ (ここに配置)
```

`claudecode.wl` のロード時に `Quiet@Get["cuda.wl"]` が自動実行されます。

---

## claudecode のロード

```mathematica
AppendTo[$Path, $packageDirectory];

Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

ロードが成功すると以下のようなメッセージが表示されます。

```
cuda.wl パッケージ — ClaudeCode CUDA 拡張
  CUDA 対応パッケージの作成・更新をサポート
  nvcc: detected (v12.x)   ← nvcc が見つかった場合
```

nvcc が見つからない場合は `nvcc: not found` と表示されますが、
claudecode 自体は正常に動作します。CUDA コンパイルは後から実行されます。

---

## ディレクトリ構造

`cuda.wl` は CUDA 対応パッケージを作成すると以下の構造を生成します。

```
$packageDirectory\
  <PackageName>.wl          ← Mathematica ラッパーパッケージ
  <PackageName>.cuda\
    src\                    ← .cu / .cuh ソースファイル
    bin\                    ← コンパイル済み .dll
```

---

## 動作確認

claudecode をロード後、以下を実行します。

```mathematica
(* nvcc の検出確認 *)
ClaudeCode`Private`iNvccAvailableQ[]
(* True または False *)

(* nvcc のパス確認 *)
ClaudeCode`Private`iNvccPath[]
(* "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.x\bin\nvcc.exe" など *)

(* nvcc バージョン確認 *)
ClaudeCode`Private`iNvccVersion[]
(* "12.x" など *)
```

---

## CUDA 対応パッケージの作成例

```mathematica
(* CUDA カーネルを含む新規パッケージを作成 *)
ClaudeCreatePackage["MyGPUPackage", "ベクトル加算を CUDA で実装するパッケージ"]
```

上記を実行すると:

1. AI が `.wl` ラッパーと `.cu` ソースを生成します。
2. `MyGPUPackage.cuda/src/` に `.cu` ファイルが保存されます。
3. nvcc が利用可能であれば自動コンパイルが実行されます。
4. コンパイル結果が `MyGPUPackage.cuda/bin/` に配置されます。

---

## よくあるエラーと対処法

| エラー | 原因 | 対処 |
|--------|------|------|
| `nvcc: not found` | PATH に nvcc がない | CUDA Toolkit 再インストール、PATH 確認 |
| コンパイル失敗 (MSVC) | Visual Studio が未インストール | Build Tools 2019+ をインストール |
| `WolframLibrary.h not found` | Mathematica インストール不完全 | Mathematica を再インストール |
| `.dll` ロード失敗 | CUDA ランタイム DLL が不足 | CUDA Toolkit を再インストール |

---

## 関連パッケージ

- [claudecode](https://github.com/transreal/claudecode) — 本パッケージの親パッケージ（必須）