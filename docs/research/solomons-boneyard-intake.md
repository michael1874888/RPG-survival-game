# Solomon’s Boneyard：XAPK 第一輪分析

日期：2026-11-12。已完成封裝勘查、資料解碼與選取 ARM64 函式的靜態閱讀。沒有安裝或執行遊戲，沒有原版 runtime 對照，沒有恢復完整原始碼。

## 結果

這份 XAPK 可供後續開發研究：它含 38 份技能資料、波次與物品資料，原生程式庫保留大量可讀 C++ 名稱，能把資料載入、技能值、耗魔與回復列為可追查的範圍。第一批資料發現見 [技能、波次與道具報告](solomons-boneyard-data-findings.md)。

| 項目 | 本次讀到的結果 | 來源與限制 |
| --- | --- | --- |
| 桌面輸入 | `Solomon's+Boneyard_1.3.0_APKPure.xapk`，35,092,085 bytes | 使用者提供；檔名標示 APKPure，不冒稱直接來自 Google Play |
| package | `com.raptisoft.SB` | 直接解析主 APK binary AndroidManifest，與 XAPK manifest 相符 |
| 版本 | `1.3.0` / versionCode `1049` | 主 APK binary manifest；其餘四個 split 同 package / versionCode |
| Android 要求 | minSdk `31`，targetSdk `35` | binary manifest；裝置實際相容性未測 |
| 組成 | base、ARM64、英文、法文、mdpi，共 5 APK | XAPK 成員與各 split manifest；不是單一可隨意省略 split 的 APK |
| Java 層 | base 有 `classes.dex` | 未反編譯 DEX；不判定 Java 層僅負責哪些功能 |
| 原生庫 | ARM64 `libSB_ndk.so`、`libbass.so` | 實際 ELF machine 183；前者含遊戲類別名稱與相關指令 |
| 遊戲符號 | `libSB_ndk.so` 有 9,865 個具名動態符號 | 包含匯入、資料、RTTI、別名及函式，不等於 9,865 個遊戲函式 |
| 資料 | 40 份，共 41,835 bytes 解碼文字 | 38 技能 + wave + items；40 份每檔長度與 hash 已記錄 |
| 憑證 | 五個 APK 的 v2/v3 區塊都攜帶同一 certificate SHA-256 | 僅解析憑證身份；未完整驗證 APK 簽章與內容 digest，未建立官方發布者對照 |

XAPK SHA-256：`c768af470d58676fb39484353b2e33570210867820effbb37c8ca7cd56fb86c3`。

主 APK SHA-256：`0b6bc1769f818025b37011f0a564cc883da6307addcccf71c88c731221f61db0`。

遊戲 native library SHA-256：`19bfbbe105c01018941d97b92b08615a72841151d50ca6f19bd12fcb83388d01`。

共同 certificate SHA-256：`868473e1a4de9d1d3d723b0170b70d69f99029291c6beb4467c46a6fa3da92cf`。

機器可讀記錄：[封裝與檔案清單](solomons-boneyard-artifact-inventory.json)、[binary manifest 與 certificate 身份](solomons-boneyard-apk-metadata.json)。

## 實際 REA 結果與輔助分析

已將免費 REA CLI **6.7.0** 安裝至 `/Users/junming/.local/share/rea-cli/6.7.0`。選此版本是因它接受現有 Node `24.21.0`；查到的 6.8.0 要求較新的 Node patch。未升級既有 Node、修改 MCP 註冊、安裝付費引擎或重啟服務。安裝省略 optional dependencies 並停用 npm install scripts。

下列是真正執行 REA CLI 產生的 Evidence：

| 操作／目標 | Evidence ID | 支持範圍 |
| --- | --- | --- |
| `inspect-artifact` base | `ev_ab0ad4717128737ea4d30e3b0024c3f127025d16690305dd4f7a45351d57cdb9` | 封裝檢查；內含 inventory Evidence |
| base `inventory_artifact` | `ev_1e0924889d64d571c7889cbdb04c630ad963453082733af5911c0bc008268422` | ZIP/APK 成員、內容身份、coverage |
| ARM64 split `inventory_artifact` | `ev_8ddabe693d7b3c759d67aef037bd70c29d39586cf5d8653c1750b78a70c01142` | 兩個 native libraries 所在的封裝 |
| `project-android-application-graph` base | `ev_2c06be58d5883b7b17c300536d7eb179fb579a4890cbcd99e11a9b260ee453c7` | 一份 DEX、資源、manifest；路徑分類而非執行結果 |
| 同操作 ARM64 split | `ev_91dd3962386d3a1f0609426f99e25746e37363fdb54d842fa886ad3171ad6073` | native 路徑分類；不是 JNI runtime 呼叫證據 |

兩份 Android graph 均回報 `complete-within-inventory`、`inventory_complete: true`。此完整性只涵蓋各自輸入的 ZIP inventory；不能推成全遊戲語意完整。base graph 沒列 signing entry，也不能推成 unsigned：APK Signing Block 位於一般 ZIP 成員清單之外。

以下則來自 Python、Capstone 5.0.6 與 pyelftools 0.32，不是 REA Evidence：binary manifest / signing certificate 解析、ELF symbols、ARM64 指令與資料解碼。輔助 Python packages 位於 `/Users/junming/.local/share/rea-cli/python`。本輪沒有 Java / Ghidra / JADX，也沒有假稱產生高階反編譯偽碼。

## 解碼器與資料載入的靜態錨點

地址一律是此 ELF 的靜態 virtual address，不能與檔案 offset 混用。完整選取指令位於 SSD `native-static/selected-functions.asm`，結構化記錄為 `native-static/native-static.json`。

| 函式 | VA / 大小 | 觀察 |
| --- | --- | --- |
| `String::Decrypt(char*)` | `0x40c898` / 244 bytes | 重複 key；key 遇 NUL 回起點；cipher byte 等於 key byte 時保留，否則 XOR |
| `IOBuffer::Decrypt(char*, bool)` | `0x3888ac` / 152 bytes | loop `0x388904..0x388930` 逐 byte 做純重複 XOR；兩個資料載入 caller 的 bool 都是 false |
| `Formations::Load()` | `0x2337b4` / 4,272 bytes | `0x233808/0x23380c` 把 `BEwareTheFisH` 放到 key 參數，`0x233818` 呼叫 IOBuffer 解碼 |
| `Stats::MakeNewStore()` | `0x2da470` / 1,748 bytes | `0x2da4c0/0x2da4c4` 載入 `F0rk1tA3ll`，`0x2da4d0` 呼叫 IOBuffer 解碼 |
| `Stats::Init()` | `0x2d92ec` / 4,484 bytes | `0x2da040/0x2da044` 引用 `FORASUMMERSDAY`，複製進 String／初始化狀態；完整技能表消費鏈仍待追查 |

三個 key 都能解出相應資料且 literal 存在 binary。這 40 份檔案沒有 cipher byte 等於對應 key byte 的位置，因此兩種 XOR 分支在這批輸入上產生相同 decoded bytes。這是靜態交叉支持；未實際執行原載入器。

## 第一個可繼續驗證的機制：魔力回復

以下使用 raw 結構偏移保留證據界線；「魔力」是依 `HurtMana`、`Meditate` 命名及共同讀寫欄位建立的語意推論，尚未對照 HUD 或保存格式。

- `Stats::HurtMana(float)`（VA `0x2de7dc`，92 bytes）從物件 `+0x14`、`+0x1c` 兩個 float 各扣輸入，再把負值限制到 0。
- `Stats::Update()`（VA `0x2db4f4`，456 bytes）在 `0x2db538..0x2db570` 對 `+0x14` 加 `+0x18 * float32(0.2)`，以 `+0x10` 作上界。此函式後段還處理 `+0x1c` 等欄位，不能只摘第一條加法當作全部狀態更新。
- `Stats::Meditate()`（VA `0x2ee1a0`，48 bytes）在 `+0xb4` 的整數非零時，對 `+0x14` 加 `+0x18 * float32(0.6)`，同樣限制到 `+0x10`。

若這兩次回復在一個相同週期各執行一次，基礎的 0.2 加額外 0.6 會形成 4 倍；這與 Meditation 顯示模板的 4X 相符。**但呼叫時機、靜止條件與每秒頻率未確認，不能現在宣稱已測出「每秒四倍回魔」。** 下一步應追 `Stats::Meditate()` 的 caller 與遊戲更新排程，再用同版本遊玩畫面核對。

## 儲存、重現與下一步

SSD 目的地由 `storagectl.py path artifacts --project codex/RPG_Game_Dev/solomons-boneyard --mkdir` 解析並驗證，資料根目錄：

`/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/solomons-boneyard/1.3.0-1049/`

內容：`input/` 原 XAPK 複本、`packages/` 五個 APK、`extracted/` 原始資料與兩個 `.so`、`decoded-data/` 衍生文字與 hash manifest、`native-static/` 選取指令，以及 `rea-*.json` 完整 REA 結果。桌面原檔保留；XAPK 複本 SHA-256 相符；五個 APK 與解碼前後資料的 hashes 可由記錄追溯。

重現腳本：[XAPK/ELF 勘查](../../scripts/inspect_sb_xapk.py)、[APK metadata](../../scripts/inspect_sb_apk_metadata.py)、[ARM64 靜態閱讀](../../scripts/inspect_sb_native.py)、[資料解碼](../../tools/research/decode_solomon_data.py)。

建議接續兩題：先確認 `CAP/MAX`、`MANAPLUS/MANACOST` 的讀取分支與等級索引，再確認 FasterCaster、戒指 FastCast 及回魔效果如何組合。這批可讀資料與具名 native 函式已足以開展上述靜態研究；精確手感、每秒頻率及實際可達等級仍需原遊戲行為證據。
