現在のGodotプロジェクトと今後の拡張性を考慮し、機能と種別で明確に分割するフォルダ構成案を提案します。

-----

## 📂 推奨フォルダ構成案

Godotでは、`res://`ルート直下を整理することが推奨されます。

```text
res://
├── assets/                  # 🎨 画像、フォント、アイコン、サウンドなどの静的アセット
│   ├── fonts/
│   ├── icons/
│   ├── images/
│   └── audio/
|
├── missions/                # 🧩 ミッションデータ（ゲームのコンテンツ）
│   ├── mission_01.json
│   ├── mission_02.json
│   └── mission_templates/   # テンプレートや共通定義など
|
├── scenes/                  # 💻 Godotで作成するシーンファイル（.tscn）
│   ├── ui/                  # メニューや選択画面といった排他的UI
│   │   ├── MainMenuUI.tscn
│   │   ├── MissionSelectUI.tscn
│   │   └── settings_ui/     # (設定画面など、複雑なUIはサブフォルダ)
│   ├── windows/             # MDIウィンドウとして使用されるコンテンツ
│   │   ├── MDIWindow.tscn
│   │   ├── TerminalUI.tscn
│   │   └── NetworkMapUI.tscn
│   └── main/                # RootSceneなど、アプリケーションの根幹となるシーン
│       └── RootScene.tscn
|
├── scripts/                 # ⚙️ スクリプトファイル（.gd）
│   ├── core/                # アプリケーションの根幹となるロジック
│   │   ├── root_scene.gd
│   │   └── Global.gd (AutoLoad)
│   ├── managers/            # シングルトン/AutoLoadで利用される管理クラス
│   │   └── MissionManager.gd (AutoLoad)
│   ├── ui/                  # UI固有のロジック
│   │   ├── MainMenuUI.gd
│   │   └── sidebar.gd
│   └── components/          # 汎用的なカスタムクラスやコンポーネント
|
├── tests/                   # ✅ テストコード（GUTやGdUnit4用）
│   ├── core_tests.gd        # Global.gd や RootSceneの基本機能テスト
│   ├── manager_tests.gd     # MissionManagerのデータロードテスト
│   └── ui_tests.gd          # Sidebarの開閉ロジックなどのテスト
|
├── docs/                    # 📄 ドキュメント、設計書、リソース編集用ファイル
│   ├── design_doc.md        # 設計ドキュメント
│   ├── source_files/        # リソース編集用の**元ファイル**
│   │   ├── icon_source.ai   # (Illustratorファイルなど)
│   │   └── original_font.ttf
│   └── build_info.md
|
└── (その他のフォルダ)
```

-----

## 📝 フォルダ構成の設計意図

この構成の主なメリットは、\*\*「使用するタイミング」**と**「アセットの種別」\*\*による明確な分離です。

### 1\. **種別による分離（水平分割）**

  * **`scenes/` と `scripts/` の分離:**
	  * Godotではシーンとスクリプトを一緒に配置する開発者も多いですが、大規模プロジェクトでは、\*\*シーン（見た目）**と**スクリプト（振る舞い）\*\*を分けることで、スクリプトの再利用性や見通しが良くなります。
  * **`assets/` の集約:**
	  * すべての静的リソース（画像、音）をここに集めることで、コードやシーンファイルと混ざらず、整理しやすくなります。

### 2\. **機能による分離（垂直分割）**

  * **`scenes/ui` vs `scenes/windows`:**
	  * `ui`：メインメニューなど、画面全体を占める**排他的**なUI。
	  * `windows`：MDIウィンドウとして動的に生成され、**共存**する小さなUI。
  * **`scripts/core` vs `scripts/managers`:**
	  * `core`：`RootScene`や`Global`など、アプリケーションの実行ロジックに関わるもの。
	  * `managers`：`MissionManager`など、特定のデータや処理を管理するシングルトン。

### 3\. **非実行ファイルの隔離**

  * **`tests/` の独立:**
	  * テストコードは**実行コードではない**ため、トップレベルの専用フォルダに隔離することで、ビルド時に含める必要がないことが明確になります。
  * **`missions/` の独立:**
	  * ゲームコンテンツ（JSONデータ）は**スクリプトやシーンではない**ため、専用の`missions`フォルダに配置することで、`MissionManager`がデータをロードする場所が明確になります。
  * **`docs/` の独立:**
	  * `docs/`フォルダ内に、**リソース編集用の元ファイル**（PSD, AIなど）を`docs/source_files`として配置することで、プロジェクトファイルが肥大化するのを防ぎつつ、参照が必要なときにすぐに見つけられます。