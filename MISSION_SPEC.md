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

#### 2.1. ネットワーク定義 (`network_definition`)

ネットワークマッピングビューアで利用される構成情報です。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| `setup.network_definition` | Object | 任意 | 仮想ネットワークの構成情報。 |
| `network_definition.nodes` | Array of Object | 必須 | ネットワーク上のノード (サーバーなど) の定義。 |
| `nodes[].ip` | String | 必須 | ノードのIPアドレス (例: `192.168.1.10`)。 |
| `nodes[].role` | String | 必須 | ノードの役割 (例: `Target Web Server`)。 |
| `network_definition.connections` | Array of Object | 必須 | ノード間の論理的な繋がりを定義。 |

#### 2.2. データベース定義 (`database_definition`)

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

### IV. 手順のヒント (Steps)

ミッションの進行を助けるヒントと中間操作の検証を定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`steps`** | Array of Object | 任意 | 手順のヒントと検証ロジックのリスト。 |
| `steps[].step_id` | Integer | 必須 | 手順の通し番号。 |
| `steps[].hint` | String | 必須 | ユーザーに次に取るべき行動を促すヒント文。 |
| `steps[].action` | String | 必須 | このステップでユーザーが取るべき主な操作 (例: `terminal_input`, `browser_access`)。 |
| `steps[].required_command` | String | 任意 | ターミナルで実行すべきコマンドの簡易的なチェック文字列。 |

---

### V. クリア判定と解説 (Clear Condition & Explanation)

ミッションの成否と学習内容のまとめを定義します。

| JSONキー | 型 | 必須/任意 | 説明 |
| :--- | :--- | :--- | :--- |
| **`clear_condition`** | Object | 必須 | クリアの最終判定ロジック。 |
| `clear_condition.type` | String | 必須 | 判定方法 (例: `flag_submission`, `config_change`)。 |
| `clear_condition.flag` | String | `type`が`flag_submission`なら必須 | ユーザーが発見・提出すべき**秘密の文字列（フラグ）** (例: `cf_flag{FTPS3cr3tP4ss}`)。 |
| `clear_condition.success_message`| String | 必須 | クリア時に表示するメッセージ。 |
| **`solution_explanation`**| Object | 任意 | クリア後に表示する詳細な解説コンテンツ。 |
| `solution_explanation.principle` | String | 必須 | 攻撃/解析の**原理**と脆弱性の説明。 |
| `solution_explanation.defense` | String | 必須 | 実際の環境で取るべき**防御策**の提案。 |

---

## 💡 今後対応したいミッション案 10選 (GitHub掲載用)

以下のミッションは、難易度と利用する主要なアプリ機能を考慮して提案します。

### Webアプリケーション分野 (Web/SQL)

| No. | タイトル | 難易度 | 概要と利用機能 |
| :--- | :--- | :--- | :--- |
| **1** | **クロスサイトスクリプティング (XSS) によるセッション情報の窃取** | Easy | 脆弱な掲示板機能に対し、`Browser`機能を使って悪意のあるJavaScriptコードを投稿し、管理者ユーザーの仮想セッション情報（Cookie）を窃取する。 |
| **2** | **SQLインジェクションと仮想SQLクライアントによるデータ窃取** | Medium | ターゲットサーバーのログインフォームにSQLインジェクションを仕掛け、脆弱性を突く。成功後、**仮想SQLクライアント**を用いて機密情報が格納されたテーブルからフラグを抽出する。 |
| **3** | **REST APIクライアントを用いた認証バイパス** | Medium | `REST APIクライアント`機能を用い、設計ミスのあるAPIエンドポイントに対し、不適切なパラメーターやヘッダーを送信することで、認証をバイパスし、機密データを取得する。 |

---

### ネットワーク・フォレンジック分野 (Network/Forensics)

| No. | タイトル | 難易度 | 概要と利用機能 |
| :--- | :--- | :--- | :--- |
| **4** | **不正アクセス後のログ改ざん痕跡の特定** | Medium | 攻撃後に回収された仮想**システムログファイル（VFS内）**に対し、`Terminal`の`grep`などのコマンドを使用して、**攻撃者が改ざんした痕跡**や意図的に削除したデータの差異を特定する。 |
| **5** | **ネットワークノード発見とサービス脆弱性の確認** | Easy | `PortScan`機能を用い、隠されたデータベースサーバーを発見し、その上で稼働しているサービスのバージョン情報を特定する（`network_definition`と連携）。 |
| **6** | **DNSクエリの異常検知と通信先の特定** | Hard | 大量の`evidence.pcap`ファイルを解析し、マルウェアが使用した**不審なDNSクエリ**を特定する。そのドメインが外部のC&Cサーバーであるかを確認し、通信の意図を解明する。 |

---

### システム・バイナリ分野 (Binary/Pwn)

| No. | タイトル | 難易度 | 概要と利用機能 |
| :--- | :--- | :--- | :--- |
| **7** | **マルウェアバイナリの静的解析と通信先特定** | Medium | VFS内に配置された**マルウェアのバイナリファイル**に対し、`Binary解析機能`を用い、表層解析（文字列検索）を行い、埋め込まれた通信先IPアドレスやパスワード文字列を抽出する。 |
| **8** | **バッファーオーバーフローによる秘密コードの実行** | Hard | 脆弱性のある仮想プログラムに対し、`Terminal`から意図的に**長すぎる入力**を行い、メモリ上のスタックを上書きすることで、内部に仕込まれた秘密のコードを実行させる（Pwnの基礎）。 |

---

### 防御・インシデント対応分野 (Defense/Incident Response)

| No. | タイトル | 難易度 | 概要と利用機能 |
| :--- | :--- | :--- | :--- |
| **9** | **初動対応：不審通信のファイアウォールによる封じ込め** | Easy | SIEMからのアラートに基づき、直ちに攻撃元IPアドレスを特定し、`Firewall設定機能`を用いて**外部への通信を遮断**（封じ込め）する。時間的制約 (`timing` 必須) を設けて初動の迅速性を評価する。 |
| **10** | **セキュリティインシデントのフォレンジック報告書の作成** | Hard | 一連の攻撃ミッション（複数ステップ）の操作ログを**`進捗トラッキング機能`**から抽出し、発見した脆弱性、攻撃手法、対応した防御策を`メモ機能`に整理して、**最終的な仮想報告書**を完成させる。 |