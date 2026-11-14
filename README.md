# RPG-survival-game

可愛動物題材的手機生存動作遊戲開發專案，目前工作名稱為 **Bramble**。包含可玩的 Godot 原型、主題方向、討論決策與試玩回饋、競品研究和開發驗證紀錄。

暫用工作名稱；正式遊戲名稱尚未決定。Godot 4.7.2 標準版 + GDScript，目前提供 Mac 開發版本及已簽署的 Android ARM64 測試 APK，手機實機驗收待辦。

目前是 **v0.9 奈奈怪潮與狩獵比較**：包含四分鐘成長挑戰、分批怪潮、環掃與狩獵快攻／重擊對照；試玩說明見 [奈奈 v0.9](docs/development/nana-v0.9-practice.md)。刺蝟、小熊與既有固定情境保留為歷史原型。

**新 session 請先讀 [HANDOFF.md](HANDOFF.md)。** 最新工作為 [v0.9 設計盤點](docs/design/nana-v0.9-design-audit-2026-11-14.md) 與 [Balatro 式隨機構築可行性](docs/research/random-driven-combat-mode-feasibility-2026-11-14.md)。隨機構築及分段模式仍是待 review 提案，尚未實作；使用者先決定方向，接著才製作。

最新試玩回饋：成長模式後期尚可，同密度比較中單點較吃力。當前優先檢查整套能力的清路、選敵與強敵收益，以及隨機機會能否促成不同打法。歷史刺蝟「保留散射＋反彈、穿透暫緩」紀錄仍保留。

## 文件入口

| 想了解的內容 | 入口 |
| --- | --- |
| 下一個 session 的起點、決策與待辦 | [交接文件](HANDOFF.md) |
| 全部文件與閱讀順序 | [文件索引](docs/README.md) |
| 主題、動物角色與故事的已定／待定範圍 | [主題與角色方向](docs/design/theme-and-characters.md) |
| 已確認的玩法與五輪討論 | [遊戲方向與決策紀錄](docs/design/game-direction.md) |
| 各階段目標與目前進度 | [開發路線](docs/design/development-roadmap.md) |
| 每輪試玩回饋、取捨與寵物候選 | [PoC 回饋與後續事項](docs/design/poc-feedback-and-followups.md) |
| 同業研究與證據範圍 | [競品研究索引](docs/research/README.md) |
| 新環境啟動、測試與 Android 匯出 | [開發環境說明](docs/development/getting-started.md) |
| 版本管理的收錄／排除範圍 | [Repository 整理說明](docs/development/repository-layout.md) |

## 開始遊玩

在 Finder 雙擊根目錄的 **Play.command**。若要修改場景，雙擊 **Edit.command**，或以 Godot 開啟 `game/project.godot`。

新環境先安裝 **Godot 4.7.2 標準版**，並用編輯器匯入 `game/project.godot`；不需要 .NET。原開發 Mac 的引擎位置為 `/Applications/Godot.app`。這兩個入口預設使用該位置，也可用 `BRAMBLE_GODOT_BIN` 指定其他執行檔。命令列也可執行：

```sh
./Play.command
```

其他平台可直接用 Godot 開啟專案，或執行 `godot --path game`。中文字型與授權已附在原始碼中，首次匯入產生的 `.godot/` 快取不納入版本管理。

| 操作 | Mac | 手機輸入設計（待實機驗收） |
| --- | --- | --- |
| 移動 | WASD／方向鍵 | 畫面左半部按住並拖曳 |
| 瞄準與攻擊 | 滑鼠瞄準、按住左鍵攻擊，放開停止 | 畫面右半部按住並拖曳；超出小死區後連續攻擊 |
| 奈奈大絕 | 空白鍵或「夜影解放」按鈕 | 點「夜影解放」，右側重新拖曳後繼續攻擊 |
| 暫停 | P／Esc，或右上按鈕 | 右上按鈕；切換背景時也會暫停 |
| 選強化 | 點選升級卡片 | 點選升級卡片 |
| 靜音切換 | M | 原型尚未提供觸控音量設定；可用裝置音量 |

奈奈成長挑戰為四分鐘，須存活且已擊敗精英；可拾經驗升級。怪潮／狩獵比較固定能力並生存 90 秒；自由練習存活三分鐘，固定敵人短情境須在三分鐘內清除。生命歸零失敗。歷史刺蝟與小熊的生存模式可拾經驗升級；45 秒陣形短情境固定能力。所有模式均可重新開始。數值仍是測試起點，尚未驗證平衡或長期耐玩性。

## 已驗證與尚待驗證

- 已驗證：官方下載 SHA-512、安裝檔 SHA-256、macOS 程式簽章、引擎版本、專案匯入及 Mac 視窗實際啟動。
- v0.9 自動檢查：戰鬥規則 176 項、真實場景流程 51 項，共 227 項通過。包含奈奈連段、大絕、觸控、暫停與重玩，以及既有角色與陣形流程。
- 自由遊玩與 A／B 的三分鐘流程，以及四個陣形／構築的 45 秒流程，均使用測試專用無敵輸入遍歷；遊戲本身沒有開啟無敵。這項結果不代表玩家能輕鬆通關或任一構築必定較強。
- Android 已完成：使用者明確同意 SDK 條款後，安裝 Command-line Tools、穩定版 platform-tools 與 Build Tools 36.1.0；已產出 v0.9 ARM64 debug APK，獨立簽章、Manifest、ZIP 與封裝規則檢查通過。最新檔案資訊見建置收據。
- 使用者已提供截至 v0.9 的主觀試玩回饋；未完整列明設備／平台與量測結果。設備相容性、真實多點觸控、手機效能、耗電及發熱仍待系統化驗證；iOS 尚未建置。

執行檢查：

```sh
./scripts/test-game.sh
```

首次 Git 整理時另以全新檔案副本驗證匯入、132 項檢查與啟動入口，見 [Repository 驗證紀錄](docs/development/repository-verification-2026-11-14.txt)。

## 專案結構

- `game/scripts/run_model.gd`：戰鬥、成長、敵人、投射物與勝敗規則。
- `game/scripts/nana_combat.gd`：奈奈的連抓、重咬、影化與大絕冷卻。
- `game/scripts/nana_encounters.gd`：敵人行為、固定情境與怪潮排程。
- `game/scripts/combat_geometry.gd`：扇形與圓形碰撞幾何。
- `game/scripts/touch_controls.gd`：左右手獨立的觸控歸屬與方向。
- `game/scripts/main.gd`：輸入、畫面、介面與簡單程序音效。
- `game/tests/`：規則與場景流程檢查。
- `docs/design/`：已確認方向、原型規格與階段路線。
- `docs/research/`：先前遊戲研究及引擎選型。
- `tools/godot-install.json`：引擎來源、儲存位置與雜湊驗證收據。
- `tools/android-prerequisites.json`：Java 與匯出模板的來源、路徑及驗證收據。
- `tools/android-build.json`：最新 APK 絕對路徑、SHA-256、簽章與 Manifest 結果。
- `scripts/export-android.py`：重新核對 SSD、匯出並獨立驗證 APK。

奈奈攻擊數值位於 `nana_combat.gd`，敵人與排程位於 `nana_encounters.gd`，升級與場次規則位於 `run_model.gd`。以下為保留的刺蝟／小熊歷史原型數值，非奈奈設定：散射每級多兩根，最多兩級；每根傷害除以 `1 + 0.45 × 散射級數`。傷害加成每次為基礎的 20%；發射頻率每次增加基礎的 15%，發射間隔最低 0.065 秒；移速每次增加基礎的 10%，最高 490。穿透與反彈各最多三級，先穿透再反彈，同一發不重複命中同一敵人。

小熊專屬設定在 `BEAR_UPGRADE_DATA`；揮擊基礎傷害 30、距離 118、角度 120°、間隔 0.70 秒、擊退 75。它使用真實扇形碰撞，不發射尖刺。完整公式見角色對照文件。

刺蝟比較入口在 `RUN_MODES`：A 為散射 1、反彈 2、傷害 1；B 為穿透 2、攻速 1、傷害 1，各四次起始強化，不代表等強。原本生存仍自由三選一；短情境的時間與規則在 `SCENARIOS`，不進行升級。短情境固定位置、波次與怪物數值，走位仍會影響遭遇。自由遊玩不帶起始強化。

## 儲存與素材

原始碼、設定與小型報告保留在本專案。Godot 應用程式在內部磁碟；170,622,178 bytes 的下載 ZIP 保留於核准 SSD 的專案獨立目錄，完整位置與驗證資訊見安裝收據。這是新下載與新安裝，未移動既有應用狀態。

角色、場地、介面與音效均以程式生成，無需外部圖庫。內附 Noto Sans TC 字型，來源及 SIL Open Font License 1.1 見 `game/assets/fonts/SOURCE.md` 和 `OFL.txt`。本專案的正式授權尚未決定。

Android APK 與安裝方式見 [Android 測試版安裝](docs/development/android-install.md)。重新匯出可執行 `python3 scripts/export-android.py`；需要核准 SSD 掛載，使用本機內部的專案除錯 keystore，並更新 Godot 的 Java／SDK／除錯金鑰路徑。

目前開發順序已收斂為 [第一版單一角色與敵人戰鬥設計](docs/design/first-version-combat-plan.md)：第一版主角已選定為寵物黑貓「奈奈」，先完成牠的攻擊模式與機制，再完成敵人種類、特色、攻擊及機制，之後接續其他部分；保留其他角色的擴充空間。

完整設計及後續敵人規劃見 [奈奈與第一版敵人戰鬥設計草案 v1.1](docs/design/nana-combat-design-v1.md)。目前實作範圍見 [v0.9 試玩說明](docs/development/nana-v0.9-practice.md)；研究後的下一步見 [交接文件](HANDOFF.md)。
