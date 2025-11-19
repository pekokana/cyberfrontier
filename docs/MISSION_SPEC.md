## 📄 CyberFrontier ミッション JSON 設計書 (v1.0)

このJSONファイルは、アプリがミッションの環境構築、実行、検証、フィードバックを行うための全ての情報を含みます。
この定義書は、ミッションクリエイターと開発チームが共通認識を持つための基盤となります。

---

### I. メタデータ (Metadata)

ミッションの基本情報と識別情報です。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`mission_id`** | String | 必須 | ミッションを一意に識別するID (例: `WF-E-005`)。 |
| **`version`** | String | 必須 | ミッション定義ファイルのバージョン。 |
| **`title`** | String | 必須 | ミッションのタイトル (例: `FTPパケット解析による機密情報特定`)。 |
| **`category`** | String | 必須 | 学習分野 (例: `Network`, `Web/SQL`, `Binary/Pwn`, `Forensics`)。 |
| **`difficulty`** | String | 必須 | 難易度 (例: `Easy`, `Medium`, `Hard`, `Expert`)。 |
| **`description`** | String | 必須 | ユーザー向けのミッション概要、背景、目標を記述。 |

---

### II. 環境設定 (Setup)

ミッション開始時の仮想環境を定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`setup`** | Object | 必須 | 環境設定を格納するルートオブジェクト。 |
| `setup.target_server` | String | 必須 | 主要な**標的サーバーの仮想IPアドレス**。 |
| `setup.required_tool` | Array of String | 任意 | 使用を推奨/想定しているアプリ内機能 (例: `Terminal`, `Browser`, `PortScan`) のリスト。 |
| `setup.initial_files` | Array of Object | 任意 | ユーザーの仮想ファイルシステム (VFS) に初期配置するファイル定義。 |
| `setup.initial_files[].path` | String | 必須 | VFS内の配置パス (例: `/home/user/evidence.pcap`)。 |
| `setup.initial_files[].type` | String | 必須 | ファイルの種類 (例: `pcap`, `binary`, `text`, `hosts`)。 |
| `setup.virtual_hosts` | Object | 任意 |  仮想ホスト利用時必須。仮想ホストの定義。ホストIDをキーとする。|

#### 2.1. 仮想ホスト定義（`virtual_hosts`）

ミッションでサーバなど仮想ホストを利用される構成情報です。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| `host_id` | String | 必須 | 仮想ホストを識別する一意な値。 |
| `ip_addresses` | Array of Object | 必須 | このホストに割り当てるすべての仮想IPアドレス。 |
| `services` | Array of Object | 必須 | このホスト上で稼働する仮想サービスリスト。 |
| `services[].type` | String | 必須 | サービスの種類 (ftp,web,sshなど)。 |
| `services[].bind_ip` | String | 必須 | サービスが待ち受けるホスト上のIPアドレス。0.0.0.0 を指定した場合、全てのNICでリッスンします。ホストのip_addressesに存在するIPでなければなりません。 |
| `services[].port` | Integer | 必須 | サービスが待ち受けるポート番号。 |
| `services[].config` | Object | 必須 | サービスタイプ固有の設定。 |


#### 2.2. ネットワーク定義 (`network_definition`)

ネットワークマッピングビューアで利用される構成情報です。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| `setup.network_definition` | Object | 任意 | 仮想ネットワークの構成情報。 |
| `network_definition.nodes` | Array of Object | 必須 | ネットワーク上のノード (サーバーなど) の定義。 |
| `nodes[].ip` | String | 必須 | ノードのIPアドレス (例: `192.168.1.10`)。 |
| `nodes[].role` | String | 必須 | ノードの役割 (例: `Target Web Server`)。 |
| `network_definition.connections` | Array of Object | 必須 | ノード間の論理的な繋がりを定義。 |

#### 2.3. データベース定義 (`database_definition`)

SQLインジェクションなど、DB関連ミッションの裏側を定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| `setup.database_definition` | Object | 任意 | ターゲットDBの構造情報。 |
| `database_definition.db_type` | String | 必須 | データベースの種類とバージョン (例: `MySQL 5.7`)。 |
| `database_definition.users` | Array of String | 任意 | データベース内のユーザー名リスト。 |
| `database_definition.tables` | Array of Object | 必須 | データベース内のテーブル名とそのカラムを定義。 |
| `tables[].name` | String | 必須 | テーブル名 (例: `user_secrets`)。 |
| `tables[].columns` | Array of String | 必須 | カラム名のリスト (例: `["id", "username", "flag"]`)。 |

---

### III. 制限時間設定 (Timing)

上級者ミッションの時間的制約を定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`timing`** | Object | 任意 | 時間制限に関する設定ルートオブジェクト。 |
| `timing.has_time_limit` | Boolean | 必須 | 制限時間を設けるか (`true`/`false`)。 |
| `timing.limit_seconds` | Integer | `has_time_limit: true`なら必須 | **制限時間（秒単位）** (例: `1800`秒 = 30分)。 |
| `timing.time_up_action` | String | 任意 | 時間切れ時の動作 (例: `RESTART_OR_PENALTY`, `AUTO_FAIL`)。 |
| `timing.display_countdown` | Boolean | 任意 | UI上に残り時間を表示するか。 |

---

### IV. 手順のヒント (hints)

ミッションの進行を助けるヒントと中間操作の検証を定義します。

hintboard画面に表示します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`hints`** | Array of Object | 任意 | 手順のヒントと検証ロジックのリスト。 |
| `hints[].type` | String | 必須 | `objective`:ミッションの目標、`hint`：ミッションクリアに向けたヒント、`note`:参考となる備考、`noise`:ヒント扱いだが、ミッション実行を惑わす備考 |
| `hints[].content` | String | 任意 | ヒント文字列 |

---

### V. クリア判定と解説 (Clear Condition)

ミッションの成否と学習内容のまとめを定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`clear_condition`** | Object | 必須 | クリアの最終判定ロジック。 |
| `clear_condition.type` | String | 必須 | 判定方法 (`solution_submission`、その他: `flag_submission`, `onfig_change`)。 |
| `clear_condition.solution_label` | String | 必須 | 事象報告画面に表示する回答を求める内容。|
| `clear_condition.required_solution` | String | `type`が`solution_submission`なら必須 | ユーザーが発見・提出すべき**秘密の文字列（フラグ）** (例: `cf_flag{FTPS3cr3tP4ss}`)。 |
| `clear_condition.case_sensitive`| Boolean | 必須 | `true`の場合回答文字列の大文字・小文字を判定する。 |

