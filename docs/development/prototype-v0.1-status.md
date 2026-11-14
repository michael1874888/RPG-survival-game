# 原型 v0.1：實作與驗證狀態

日期：2026-11-13。使用者已授權安裝並開始。工作名稱 Bramble，正式遊戲名稱尚未決定。

目前開發版本已前進至 [v0.4 陣形比較 PoC](../design/formation-comparison-poc-v0.4.md)，保留既有角色與生存模式，新增四面包圍／單向隊列的 45 秒固定構築比較；新增檢查後共 132 項通過。下列 60 項數字保留 v0.1 的歷史驗證結果，最新 APK 見建置收據。

## 後續使用者回饋

2026-11-14：使用者表示目前測試起來 OK，認可現階段採簡單快速的 PoC。已記錄後續 UI／美術與主題故事、震動回饋，以及不同動物攻擊特色三項方向，見 [回饋與後續事項](../design/poc-feedback-and-followups.md)。

本次未附測試平台、設備或逐項結果；以下安裝與自動檢查保留開發端原始紀錄，逐項實機驗收欄位仍待具體紀錄補足。

## 安裝結果

- Godot 4.7.2.stable.official.ed1daf0bf 標準版，應用程式位於 `/Applications/Godot.app`。
- 官方 macOS Universal ZIP：170,622,178 bytes，新增下載保留在核准 SSD `Artifacts/codex/RPG_Game_Dev/tool-downloads/4.7.2-stable/`。實際絕對位置與來源見 [安裝收據](../../tools/godot-install.json)。
- ZIP 與官方 SHA-512 清單吻合；SHA-256 為 `c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e`，亦與官方資產 digest 一致。
- `/usr/bin/codesign --verify --deep --strict /Applications/Godot.app` exit 0；引擎 `--version` 成功。
- 應用程式裝在內部磁碟，原始碼、字型及小型紀錄保留專案；未搬移既有應用狀態。
- 使用者後續表示 iPhone 與 Android 都有，授權選較容易開始的路徑；已先選 Android。
- Temurin OpenJDK 17.0.21+9 及 Godot 4.7.2 Android 匯出模板已放核准 SSD，官方雜湊核對通過，Java 已實際執行。收據見 [Android 前置工具](../../tools/android-prerequisites.json)。
- 使用者已明確同意 SDK 條款，Android SDK 已安裝且工具版本已核對；[安裝計畫與結果](android-setup-plan.md) 已更新。
- Android ARM64 debug APK 已產出，簽章、Manifest 及內容檢查通過；[建置收據](../../tools/android-build.json) 記錄來源產物、大小、SHA-256 及檢查結果。尚未在手機安裝或執行。

## 可玩內容

已實作：2D 刺蝟、相機與場地邊界、移動與手動瞄準、持續發射尖刺、追逐敵人、預警衝刺敵人、命中與非血腥退場、經驗拾取、暫停三選一、六種升級、生命與短暫無敵、三分鐘成功、失敗結算、重新開始、失焦暫停，以及簡單程序音效。

角色、場景與特效使用程式繪製。中文字型使用隨專案附帶的 Noto Sans TC，已附來源及 OFL；不依賴 Mac 私有字型路徑。

## 驗證結果

執行根目錄 `scripts/test-game.sh`，三個 Godot 程序均 exit 0，最後一次結果：

```text
INTEGRATION: kills=118 upgrades=5 max_enemies=110 (test-only invulnerability)
RESULT: 49 checks, 0 failures
SCENE RESULT: 11 checks, 0 failures
```

- 規則檢查：左右雙指獨立、跨區不換手、取消釋放、暫停、受傷無敵、勝敗、重設、升級溢出經驗、合法選項、上限退出、穿透先於反彈、碰撞沿行進順序、同發不重複命中、出生距離與衝刺預警。
- 真實場景檢查：主選單、開始、左手不誤射、過濾觸控模擬滑鼠、失焦清除輸入、暫停凍結、升級卡片、成功／失敗介面與重新開始。
- 三分鐘整合模擬以固定 seed 901，使用測試專用自動移動、瞄準與無敵，遍歷生成、碰撞、拾取、升級及終點。實際遊戲預設無無敵或自動瞄準；此檢查不證明難度合理或玩家能通關。
- Mac GUI 已實際啟動，透過原生視窗操作開始、移動、瞄準攻擊、P 暫停、失敗結算。介面可讀且無程序錯誤輸出；主觀清怪爽感尚待使用者測試。

## 里程碑邊界

| 里程碑 | 目前結果 | 尚未完成 |
| --- | --- | --- |
| P0 | 引擎與 Android SDK 安裝、版本／雜湊／簽章核對、Mac 啟動、Android APK 匯出與獨立驗證 | 連接實際手機並確認安裝成功 |
| P1 | 操作、尖刺、追逐、受傷、重玩及桌面 UI 已實作／檢查 | 真實手機雙指、遮擋與手感驗收 |
| P2 | 拾取、三選一、升級組合與場景轉換已實作／檢查 | 手機可讀性、不同升級的實際體感及數值調整 |
| P3 | 三分鐘規則、兩種敵人、成功／失敗與重玩已檢查 | 手機上完整一局、幀時間、發熱與觸控穩定性 |

下一步：依 [Android 安裝步驟](android-install.md) 在手機安裝並試玩。沒有 Android 裝置連接到 Mac，實機驗收仍待辦；本輪只建立本機專案除錯 keystore，未建立正式發布金鑰或安排商店發布。
