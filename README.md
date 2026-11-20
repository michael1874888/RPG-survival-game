# RPG-survival-game

可愛動物題材的手機生存動作遊戲開發專案，目前工作名稱為 **Bramble**。包含可玩的 Godot 原型、主題方向、討論決策與試玩回饋、競品研究和開發驗證紀錄。

暫用工作名稱；正式遊戲名稱尚未決定。Godot 4.7.2 標準版 + GDScript，目前提供 Mac 開發版本及已簽署的 Android ARM64 測試 APK，使用者已在 Android 手機試玩並回饋體感 OK。

目前是 **v0.30.0 奈奈夜巡（X1 撲擊狩獵）**：爪擊自動、右手拖曳放開撲擊、擊殺充能的夜影解放；三個區域的夜巡地圖、48 張本能卡與 8 組進化、夜深 1–8、30 個解鎖目標與 12 件寶物。[v0.30 試玩說明](docs/development/nana-v0.30-practice.md)。

**新 session 請先讀 [HANDOFF.md](HANDOFF.md)。** v0.30 依使用者核准的 [X1 重設計提案](docs/design/nana-pounce-redesign-proposal-x1.md) 實作於分支 `feature/nana-x1-pounce-hunt`；手機實玩、效能與樂趣尚待驗收。

v0.20 的分析判斷底層 30 秒戰鬥缺判斷與爽感（尚無 v0.20 真人回饋，屬推論），因此改為大量雜兵＋撲擊判斷＋目標獵物的戰鬥。v0.20 的程式與測試保留，debug 建置首頁可開啟對照。

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

| 操作 | Mac | 手機（待實機驗收） |
| --- | --- | --- |
| 移動 | WASD／方向鍵 | 畫面左半部按住並拖曳 |
| 爪擊 | 自動攻擊身邊的敵人 | 自動攻擊身邊的敵人 |
| 撲擊 | 滑鼠左鍵朝游標撲出；J／K／Shift 朝移動方向撲出 | 畫面右半部拖曳顯示撲擊線，放開撲出；在 24 px 內放開取消 |
| 夜影解放 | 空白鍵或「夜影解放」按鈕（能量充滿時） | 點「夜影解放」按鈕 |
| 暫停 | P／Esc，或右上按鈕 | 右上按鈕；切換背景時也會暫停並保存 |
| 音量 | M 切換靜音；設定頁可調音量 | 設定頁 |
| 重新讀取資料檔 | F5（僅 debug 建置） | — |

一局：選區域、習性與寶物 → 走 7 層夜巡地圖（狩獵、獵物巢、貓窩、主人房間、月光）→ 打倒守關。數值都在 `game/data/x1/*.json`，調整方法見 [調參指南](docs/development/x1-tuning-guide.md)。

## 已驗證與尚待驗證

- 已驗證：官方下載 SHA-512、安裝檔 SHA-256、macOS 程式簽章、引擎版本、專案匯入及 Mac 視窗實際啟動。
- v0.30：既有回歸 4,563 項與 X1 新增 524 項（資料、戰鬥、敵人、卡片、局與存檔、實際場景流程）全部通過；Android 包另跑封裝後的規則檢查。數字細節與證據界線見 [v0.30 試玩說明](docs/development/nana-v0.30-practice.md)。
- 尚未驗證：手機安裝更新、觸控手感、效能與樂趣；自動玩家的結果不代表真人難度。

執行檢查：

```sh
./scripts/test-game.sh
```

首次 Git 整理時另以全新檔案副本驗證匯入、132 項檢查與啟動入口，見 [Repository 驗證紀錄](docs/development/repository-verification-2026-11-14.txt)。

## 專案結構

- `game/x1_main.tscn`、`game/scripts/x1_main.gd`：X1 主場景與畫面流程（目前的主場景）。
- `game/scripts/x1/core/`：X1 規則（戰鬥、撲擊、敵人湧出、卡片效果、構築、地圖、一局流程、存檔、解鎖），不含畫面。
- `game/scripts/x1/ai/`：每種敵人的行為。
- `game/scripts/x1/render/`、`game/scripts/x1/ui/`：戰鬥繪製、合成音效、地圖、觸控輸入與介面樣式。
- `game/data/x1/*.json`：所有 X1 數值與內容；[內容表](docs/design/nana-x1-content.md) 由 `scripts/x1-content-table.py` 產生。
- `game/scripts/combat_geometry.gd`：扇形、長條與圓形碰撞幾何（X1 與舊版共用）。
- `game/scripts/r1_*.gd`、`main.gd`、`run_model.gd`、`nana_*.gd`：v0.20 以前的版本，保留給回歸測試與對照。
- `game/tests/`：規則與場景流程檢查；`x1_autoplay_probe.gd` 與 `x1_visual.gd` 是開發用探針與截圖工具。
- `tools/android-build.json`：最新 APK 絕對路徑、SHA-256、簽章與 Manifest 結果。
- `scripts/export-android.py`、`scripts/verify-packaged-nana.py`：匯出並獨立驗證 APK，及封裝後的規則檢查。

## 儲存與素材

原始碼、設定與小型報告保留在本專案。Godot 應用程式在內部磁碟；170,622,178 bytes 的下載 ZIP 保留於核准 SSD 的專案獨立目錄，完整位置與驗證資訊見安裝收據。這是新下載與新安裝，未移動既有應用狀態。

角色、場地、介面與音效均以程式生成，無需外部圖庫。內附 Noto Sans TC 字型，來源及 SIL Open Font License 1.1 見 `game/assets/fonts/SOURCE.md` 和 `OFL.txt`。本專案的正式授權尚未決定。

Android APK 與安裝方式見 [Android 測試版安裝](docs/development/android-install.md)。重新匯出可執行 `python3 scripts/export-android.py`；需要核准 SSD 掛載，使用本機內部的專案除錯 keystore，並更新 Godot 的 Java／SDK／除錯金鑰路徑。

目前開發順序已收斂為 [第一版單一角色與敵人戰鬥設計](docs/design/first-version-combat-plan.md)：第一版主角已選定為寵物黑貓「奈奈」，先完成牠的攻擊模式與機制，再完成敵人種類、特色、攻擊及機制，之後接續其他部分；保留其他角色的擴充空間。

目前的設計見 [X1 重設計提案](docs/design/nana-pounce-redesign-proposal-x1.md)與[內容表](docs/design/nana-x1-content.md)；實作範圍見 [v0.30 試玩說明](docs/development/nana-v0.30-practice.md)；下一步見 [交接文件](HANDOFF.md)。
