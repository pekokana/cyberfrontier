
## 1\. 📁 VFSコアの実装 (データ管理)

VFSの基盤であり、ファイルの「実体」と「階層」を管理するバックエンドコンポーネントです。Godotでは、シングルトン（AutoLoad）として実装するのが最も管理しやすいと考えます。

### 🔹 必要な要素

| 要素名 | 目的とデータ構造 |
| :--- | :--- |
| **`VFSCore.gd` (AutoLoad)** | VFS全体を管理するシングルトン。 |
| **`VFSNode` クラス** | ファイルまたはディレクトリを表すクラス。`type` (`FILE` or `DIR`), `name`, `path`, `content` (String/PackedByteArray), `children` (Dictionary/Array for directories) などのプロパティを持つ。 |
| **ルート構造** | `/home/user` をトップレベルとし、ツリー構造またはネストされた辞書でファイル階層を保持。 |
| **主要メソッド** | `load_mission_setup(initial_files)`: JSONから読み込んだファイルをVFSに配置（`setup.initial_files`に対応）。<br>`read_file(path)`: ファイルの内容を返す。<br>`write_file(path, content)`: ファイルを作成・更新する。<br>`get_children(path)`: ディレクトリ内の子ノードのリストを返す。 |

-----

## 2\. ⌨️ コマンドロジックの実装 (CLIとの連携)

Terminalからの入力を処理し、VFSコアと通信するロジック層です。これもシングルトン（例: `CommandProcessor.gd`）として実装し、VFSの操作権限を一元管理します。

### 🔹 必要な要素

| 要素名 | 目的 |
| :--- | :--- |
| **`CommandProcessor.gd`** | ユーザー入力（例: `"cat /home/user/log.txt"`) を解析し、適切な処理をディスパッチする。 |
| **コマンド定義** | `ls`, `cd`, `cat`, `grep`など、各コマンドを処理する関数（または専用クラス）の構造を定義する。 |
| **状態管理** | `current_path` (現在の作業ディレクトリ) を保持し、`cd`コマンドによって更新されるようにする。 |
| **出力処理** | コマンドの実行結果（成功メッセージ、ファイル内容、エラーメッセージなど）をTerminal UIへ返すためのシグナルまたはコールバック機構。 |

-----

## 3\. 🖥️ Terminalから実行できるコマンドの実装 (CLIの機能)

上記2層を基盤に、Terminalで直接入力される主要なコマンドを実装します。これらは`CommandProcessor`内の関数として実装されます。

| コマンド | 役割 | 連携するVFSコアメソッド |
| :--- | :--- | :--- |
| **`ls [path]`** | 指定された、または現在のディレクトリの内容一覧を表示する。 | `get_children(path)` |
| **`cd <path>`** | 現在の作業ディレクトリを変更する。 | 内部で `current_path` を更新。 |
| **`cat <file>`** | ファイルの内容をTerminalに出力する。 | `read_file(path)` |
| **`grep <pattern> <file>`**| ファイルの内容を読み込み、パターンに一致する行を抽出して出力する。 | `read_file(path)` (内容取得後、GDScript内で文字列処理) |
| **`submit <flag>`** | フラグ提出・判定ロジックを呼び出す（VFS操作ではないが、Terminal機能の一部）。 | `FlagProcessor.gd` (別途実装) |

-----

## 4\. 🖼️ MDI Window (GUI/UX) の実装

ユーザーが直接触れるインターフェース層、特にTerminal画面と補助的なGUIです。

### 🔹 必要な要素

| 要素名 | 目的 | Godotノード |
| :--- | :--- | :--- |
| **メインMDIコンテナ** | Terminalや各種ツールウィンドウを配置・管理するベースとなるシーン。 | `Control` / `Panel` |
| **Terminal UI** | ユーザーからの入力を受け付け、コマンドの出力を表示するコアなインターフェース。 | `LineEdit` (入力), `RichTextLabel` (出力) |
| **サイドバー** | `Firewall設定機能`や`NetworkMappingViewer`など、他のツールを起動するためのボタンを配置するナビゲーションパネル。 | `VBoxContainer` + `Button` |
| **補助UI** | オプションとして、`/home/user`の内容をツリービューなどで表示する簡易的な**ファイルブラウザウィンドウ**を実装することで、Terminalに慣れていないユーザーの補助とすることができます。 | `Tree` or `ItemList` |

