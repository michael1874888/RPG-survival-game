# 五款遊戲 XAPK：REA 第一輪靜態分析

**後續更新：** 已安裝專案專用分析工具並取得更多遊戲資料，請以 [後續遊戲資料分析](competitive-apk-game-data-analysis.md) 的最新進度為準。

日期：2026-11-13。範圍：使用者自 APKPure 下載的五個 XAPK；本輪未安裝或執行遊戲。目標是確認檔案、程式與資源所在位置，為後續研究戰鬥、成長與耐玩機制建立可追溯的基礎。這是第一輪封裝分析，**不是完整玩法逆向報告**。

## 檔案與保全

五份檔案已從 Chrome 原下載位置 `/tmp/openclaw/downloads` 搬到已透過 storagectl 驗證 UUID 的 SSD 目錄：

`/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/`

複製後逐檔比對大小與 SHA-256，全部相符才移除原檔。完整路徑、大小、hash 與原路徑見 [檔案清單](competitive-apks-manifest.json)。來源是使用者下載的第三方套件；雜湊證明搬移前後相同，**不證明與開發商原始發行檔相同**。拆分後 APK、資源清單與 REA Evidence JSON 也保存在同一 SSD 目錄。

## 套件比較

下表版本、Android SDK 數字及 split 組成來自 XAPK 附帶的 `manifest.json` 與 ZIP 清單，屬於封裝聲明，並非 APK 簽章的開發者身分驗證。版本只代表這次取得的檔案。

| 遊戲 | 版本 / build | 最低 / 目標 Android API | 原始 XAPK 大小 | 拆分與初步定位 |
| --- | --- | --- | ---: | --- |
| 20 Minutes Till Dawn | 8.7 / 1109 | 24 / 36 | 129,093,242 bytes | 主 APK + ARM64 拆分 |
| Brotato | 1.3.932 / 1030932 | 24 / 36 | 219,847,360 bytes | 主 APK + armeabi-v7a 拆分 |
| Magic Survival | 0.9941 / 612 | 24 / 36 | 202,766,661 bytes | 主 APK + armeabi-v7a 拆分 |
| Survivor.io | 5.4.0 / 1666 | 26 / 36 | 1,947,517,103 bytes | 主 APK + ARM64 拆分 + 兩個 Unity 資源包 |
| Vampire Survivors | 1.16.111 / 64959276 | 24 / 35 | 1,244,723,096 bytes | 主 APK + ARM64 拆分 + Unity 資源包 |

這些 XAPK 中的架構只代表這次下載的變體；不能推論官方只有這些 CPU 版本。各主 APK 都包含 `assets/bin/Data/Managed/Metadata/global-metadata.dat`；各 CPU 拆分都包含 `libunity.so` 與 `libil2cpp.so`。這是 Unity／IL2CPP 封裝的直接線索：分析時必須將配套資源與 native 函式庫納入，而不能只讀主 APK 的 Android 層。名稱和封裝結構本身不能證明遊戲內某項行為。

Survivor.io 和 Vampire Survivors 的資源分別另放在大型 asset pack；前者另有 `UnityStreamingAssetsPack.apk`，其中可見 `assets/aa/catalog.json`。目前只確認檔案存在，未完成資源內容解碼或機制還原。

## 已完成的 REA 工作與證據

使用本機既有 REA CLI 6.7.0 的 `inspect-artifact`，對五個 XAPK 與各自的主 APK 共進行 10 次封裝檢查；完整 JSON 隨檔案保存在 SSD。以下 Evidence ID 對應 XAPK／主 APK，並非已完成遊戲機制追蹤：

| 遊戲 | XAPK Evidence ID | 主 APK Evidence ID |
| --- | --- | --- |
| 20 Minutes Till Dawn | `ev_6f3127ce14d7326ba613e9bd6772ae1d2c51a7e04c15a7f2681808472cd70143` | `ev_10fe654cf0194b0cbb3d10500c7cd3001b2b877550b08d61950ee5c5fbc477ae` |
| Brotato | `ev_de1e736b03294482d5544d80e64d20c406f8b1b0c455f256b661003dfbcd7a8f` | `ev_9e001a4fbb340d881ab43fb3a9101db4cbb234f17c204397d27364af0726e888` |
| Magic Survival | `ev_5e4f71da4e032d65605bb912a79aa957834eeb3eed28e01d9ac19eb97fc82d06` | `ev_d2221df14b7e8ca824805fcd8b4cd36f72e5e20810f3fbf28ea6a67c9754010c` |
| Survivor.io | `ev_ac2f94e2fbfa7961671b1f5c07428571b0e79d599f63b69dbd9fef82e2729adb` | `ev_0fae4f4d195f55d0601ccbd280728b7a0367f9e9bc10638468c169d548ee8e0e` |
| Vampire Survivors | `ev_870ea53ccf4adfd061e54eb2726a8c714d3bd360f11d937c4ae554b2eb56d651` | `ev_35fd9671cec0e3e3b03b2a3e40f32f72a79b6f89bf4cfd93e66eebc04caf5d76` |

## 初步線索：不能當成機制結論

以一般 Python ZIP 檢視及原始字串掃描（不是 REA 的方法反編譯）可在部分 metadata 中找到與法術升級、武器、傷害、波次相關的文字。它們只能幫助定位後續研究候選，不可單憑名字認定實際功能、觸發條件、數值、是否使用或完成度。Survivor.io 的 metadata 開頭不符合另外四個檔案可見的標準 metadata 標頭，因此不能假定同一種解析法適用；是否加密或混淆尚未確認。

## 尚未回答的問題與阻礙

- 目前沒有確認各遊戲實際的攻擊公式、升級候選規則、技能組合條件、敵人生成曲線、掉落率或局外成長公式；不能以封裝清單代替這些答案。
- `inspect-android-package` 實際嘗試回傳 `capability_unavailable`：本機缺少 REA 指定的 `jadx-headless-mcp 0.7.1`；`java -version` 顯示目前找不到 Java runtime。REA 6.7.0 的封裝檢查不需要它，因此上述 10 筆檢查已完成，但 Android 類別與方法分析未完成。
- 這些 Unity/IL2CPP 遊戲的主要邏輯可能位於 native 程式與資源中；即使補上 JADX，也不能保證能還原主要玩法。還需要對應的 IL2CPP metadata／native 分析能力，並依實際結果決定後續檢查範圍。
- 未在 Android 裝置或模擬器上執行，沒有實際操作、錄影、執行時資料或留存測量。
