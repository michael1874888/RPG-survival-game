# RPG-survival-game

可愛動物題材的手機生存動作遊戲開發專案，目前工作名稱為 **Bramble**。包含可玩的 Godot 原型、主題方向、討論決策與試玩回饋、競品研究和開發驗證紀錄。

暫用工作名稱；正式遊戲名稱尚未決定。Godot 4.7.2 標準版 + GDScript，目前提供 Mac 開發版本及已簽署的 Android ARM64 測試 APK，手機實機驗收待辦。

目前是 **v0.4 陣形比較 PoC**：刺蝟 A／B 構築可在「四面包圍／單向隊列」各玩 45 秒，能力固定、不升級，結算可只換構築或陣形。原本三分鐘生存與小熊仍可選。試玩重點見 [陣形比較](docs/design/formation-comparison-poc-v0.4.md)。

最新試玩結論：**保留散射＋反彈的清怪方向，穿透暫緩深化**。v0.4 比較內容仍保留作為實驗紀錄；目前沒有要求繼續重複測試這組對照。構築多樣性尚未驗證完成。

## 文件入口

| 想了解的內容 | 入口 |
| --- | --- |
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
| 暫停 | P／Esc，或右上按鈕 | 右上按鈕；切換背景時也會暫停 |
| 選強化 | 點選升級卡片 | 點選升級卡片 |
| 靜音切換 | M | 原型尚未提供觸控音量設定；可用裝置音量 |

原本生存為存活三分鐘成功，生命歸零失敗；擊敗敵人掉落「星種」，靠近拾取後升級、暫停三選一。45 秒短情境保留操作與受傷規則，但固定起始能力、不升級；出怪前有一秒橘圈預告。所有模式均可重新開始。刺蝟有散射、穿透與反彈；小熊有揮擊角度、距離與擊退；兩者共享傷害、攻擊頻率與移速強化。數值仍是測試起點，尚未驗證平衡或長期耐玩性。

## 已驗證與尚待驗證

- 已驗證：官方下載 SHA-512、安裝檔 SHA-256、macOS 程式簽章、引擎版本、專案匯入及 Mac 視窗實際啟動。
- 自動檢查：戰鬥規則 96 項、真實場景流程 36 項，共 132 項全數通過。包含觸控、攻擊／升級池、固定陣形、預告與暫停、45 秒結束、結算切換、成功、失敗與重玩。
- 自由遊玩與 A／B 的三分鐘流程，以及四個陣形／構築的 45 秒流程，均使用測試專用無敵輸入遍歷；遊戲本身沒有開啟無敵。這項結果不代表玩家能輕鬆通關或任一構築必定較強。
- Android 已完成：使用者明確同意 SDK 條款後，安裝 Command-line Tools、穩定版 platform-tools 與 Build Tools 36.1.0；已產出 35.6 MiB 的 ARM64 debug APK，獨立簽章、Manifest、ZIP 完整性與內容檢查通過。
- 使用者已提供 v0.4 的主觀試玩回饋；此次未列明設備／平台與量測結果。設備相容性、真實多點觸控、手機效能、耗電及發熱仍待系統化驗證；iOS 尚未建置。

執行檢查：

```sh
./scripts/test-game.sh
```

首次 Git 整理時另以全新檔案副本驗證匯入、132 項檢查與啟動入口，見 [Repository 驗證紀錄](docs/development/repository-verification-2026-11-14.txt)。

## 專案結構

- `game/scripts/run_model.gd`：戰鬥、成長、敵人、投射物與勝敗規則。
- `game/scripts/touch_controls.gd`：左右手獨立的觸控歸屬與方向。
- `game/scripts/main.gd`：輸入、畫面、介面與簡單程序音效。
- `game/tests/`：規則與場景流程檢查。
- `docs/design/`：已確認方向、原型規格與階段路線。
- `docs/research/`：先前遊戲研究及引擎選型。
- `tools/godot-install.json`：引擎來源、儲存位置與雜湊驗證收據。
- `tools/android-prerequisites.json`：Java 與匯出模板的來源、路徑及驗證收據。
- `tools/android-build.json`：最新 APK 絕對路徑、SHA-256、簽章與 Manifest 結果。
- `scripts/export-android.py`：重新核對 SSD、匯出並獨立驗證 APK。

數值集中在 `run_model.gd`，升級說明及上限在 `UPGRADE_DATA`。散射每級多兩根，最多兩級；每根傷害除以 `1 + 0.45 × 散射級數`。傷害加成每次為基礎的 20%；發射頻率每次增加基礎的 15%，發射間隔最低 0.065 秒；移速每次增加基礎的 10%，最高 490。穿透與反彈各最多三級，先穿透再反彈，同一發不重複命中同一敵人。

小熊專屬設定在 `BEAR_UPGRADE_DATA`；揮擊基礎傷害 30、距離 118、角度 120°、間隔 0.70 秒、擊退 75。它使用真實扇形碰撞，不發射尖刺。完整公式見角色對照文件。

刺蝟比較入口在 `RUN_MODES`：A 為散射 1、反彈 2、傷害 1；B 為穿透 2、攻速 1、傷害 1，各四次起始強化，不代表等強。原本生存仍自由三選一；短情境的時間與規則在 `SCENARIOS`，不進行升級。短情境固定位置、波次與怪物數值，走位仍會影響遭遇。自由遊玩不帶起始強化。

## 儲存與素材

原始碼、設定與小型報告保留在本專案。Godot 應用程式在內部磁碟；170,622,178 bytes 的下載 ZIP 保留於核准 SSD 的專案獨立目錄，完整位置與驗證資訊見安裝收據。這是新下載與新安裝，未移動既有應用狀態。

角色、場地、介面與音效均以程式生成，無需外部圖庫。內附 Noto Sans TC 字型，來源及 SIL Open Font License 1.1 見 `game/assets/fonts/SOURCE.md` 和 `OFL.txt`。本專案的正式授權尚未決定。

Android APK 與安裝方式見 [Android 測試版安裝](docs/development/android-install.md)。重新匯出可執行 `python3 scripts/export-android.py`；需要核准 SSD 掛載，使用本機內部的專案除錯 keystore，並更新 Godot 的 Java／SDK／除錯金鑰路徑。

下一個設計問題是找出用途與玩家行為確實不同的構築。持續區域與引怪走位是候選方向，尚未選定實作；完整主題／故事、UI／美術與震動依後續階段規劃。
