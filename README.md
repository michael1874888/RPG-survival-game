# RPG-survival-game

可愛動物題材的手機生存動作遊戲開發專案，目前工作名稱為 **Bramble**。包含可玩的 Godot 原型、主題方向、討論決策與試玩回饋、競品研究和開發驗證紀錄。

暫用工作名稱；正式遊戲名稱尚未決定。Godot 4.7.2 標準版 + GDScript，目前提供 Mac 開發版本及已簽署的 Android ARM64 測試 APK，使用者已在 Android 手機試玩並回饋體感 OK。

目前是 **v0.16 奈奈森林短局**：加入疾追者，試驗追擊與多方向壓力。[v0.16 試玩說明](docs/development/nana-v0.16-practice.md)。

**新 session 請先讀 [HANDOFF.md](HANDOFF.md)。** 依 v0.15 回饋已製作 v0.16 試驗；隨機構築尚未實作。

最新回饋是 v0.16 的疾追者較有威脅性，需要走位及使用大絕；但整局仍缺少重玩目標、成就感與回饋感。[v0.17 局內成長與構築回報提案](docs/design/nana-growth-run-proposal-v0.17.md) 僅供 review，待確認後才實作。

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
| 靜音切換 | M | 原型尚未提供觸控音量設定；可用裝置音量 |

森林短局與三連戰均由一個開局能力出發，段間可發展或加裝，兩格已滿後可發展或替換；短局四段、三連戰三段全部清除才完成。單場實驗可任選 0–2 個 Lv.1 能力，單場實驗每段最多 60 秒；短局各段上限見試玩說明。數值仍是試玩起點。

## 已驗證與尚待驗證

- 已驗證：官方下載 SHA-512、安裝檔 SHA-256、macOS 程式簽章、引擎版本、專案匯入及 Mac 視窗實際啟動。
- v0.16：既有規則 176 項、構築實驗 55 項、跨段規則 44 項、場景流程 35 項，共 310 項通過。
- 使用者已提供 v0.16 實玩回饋；本次設備、安裝方式及效能量測未提供。APK 資訊見建置收據。

執行檢查：

```sh
./scripts/test-game.sh
```

首次 Git 整理時另以全新檔案副本驗證匯入、132 項檢查與啟動入口，見 [Repository 驗證紀錄](docs/development/repository-verification-2026-11-14.txt)。

## 專案結構

- `game/scripts/run_model.gd`：戰鬥、成長、敵人、投射物與勝敗規則。
- `game/scripts/nana_combat.gd`：奈奈的連抓、重咬、影化與大絕冷卻。
- `game/scripts/nana_encounters.gd`：敵人行為、固定情境與怪潮排程。
- `game/scripts/nana_experiment.gd`：構築實驗事件表、觀察紀錄與命中停頓。
- `game/scripts/nana_series.gd`：固定三連戰、跨段狀態、合法選擇與整輪摘要。
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

奈奈攻擊數值位於 `nana_combat.gd`，敵人與排程位於 `nana_encounters.gd`，場次規則位於 `run_model.gd`。歷史原型和研究請由文件索引與 Git 歷史查閱。

## 儲存與素材

原始碼、設定與小型報告保留在本專案。Godot 應用程式在內部磁碟；170,622,178 bytes 的下載 ZIP 保留於核准 SSD 的專案獨立目錄，完整位置與驗證資訊見安裝收據。這是新下載與新安裝，未移動既有應用狀態。

角色、場地、介面與音效均以程式生成，無需外部圖庫。內附 Noto Sans TC 字型，來源及 SIL Open Font License 1.1 見 `game/assets/fonts/SOURCE.md` 和 `OFL.txt`。本專案的正式授權尚未決定。

Android APK 與安裝方式見 [Android 測試版安裝](docs/development/android-install.md)。重新匯出可執行 `python3 scripts/export-android.py`；需要核准 SSD 掛載，使用本機內部的專案除錯 keystore，並更新 Godot 的 Java／SDK／除錯金鑰路徑。

目前開發順序已收斂為 [第一版單一角色與敵人戰鬥設計](docs/design/first-version-combat-plan.md)：第一版主角已選定為寵物黑貓「奈奈」，先完成牠的攻擊模式與機制，再完成敵人種類、特色、攻擊及機制，之後接續其他部分；保留其他角色的擴充空間。

完整設計及後續敵人規劃見 [奈奈與第一版敵人戰鬥設計草案 v1.1](docs/design/nana-combat-design-v1.md)。目前實作範圍見 [v0.10 試玩說明](docs/development/nana-v0.10-practice.md)；研究後的下一步見 [交接文件](HANDOFF.md)。
