# Solomon’s Boneyard：以 REA 案例建立開發參考的研究計畫

研究日期：2026-11-12。這次僅閱讀官方遊戲頁、商店、版本紀錄及 REA 文件。未下載遊戲、購買商品、安裝分析工具、啟動 REA 或實際觀察遊戲執行。REA 文件固定 checkpoint：[a01674377f1f2a0fed467035fddc25e90e74d75a](https://github.com/morluto/rea/tree/a01674377f1f2a0fed467035fddc25e90e74d75a)。本報告的流程與研究題是建議，尚未產生 Solomon 遊戲本體的反向工程證據。


更新：使用者已提供 APKPure XAPK；已確認 Android 1.3.0 / build 1049、解出資料並完成第一輪靜態閱讀。當前結果與工具狀態請見 [XAPK 第一輪分析](solomons-boneyard-intake.md)。下列平台比較保留為取得檔案前的研究背景。

## 費用限制與更新路線

使用者指定不付費：後續不新增遊戲購買、工具授權、訂閱或按量計費服務。優先研究官方免費手機版，採用免費開源分析工具；Steam 版僅在已有可用授權及本體時列入候選，不為本研究購買。免費手機版含廣告及選購內購，本研究不購買去廣告、金幣或其他項目。

台灣 App Store 目前標示「免費 · App內購買」；Google Play 提供安裝並標示廣告與內購。REA 的 MIT 授權不收軟體授權費。這些資訊不保證特定裝置相容、可取得可讀 APK/IPA，或能完整還原所有付費／未解鎖內容；實際取得與分析能力仍待確認。

來源：[台灣 App Store](https://apps.apple.com/tw/app/solomons-boneyard/id387497198)、[Google Play](https://play.google.com/store/apps/details?id=com.raptisoft.SB)、[REA MIT License](https://github.com/morluto/rea/blob/main/LICENSE)。

## 官方目前能確認的內容

Raptisoft 的 [Solomon’s Boneyard 官網](https://www.solomonsboneyard.com/) 直接提供 Android 與 iOS 連結，分別轉向 [Google Play `com.raptisoft.SB`](https://play.google.com/store/apps/details?id=com.raptisoft.SB&hl=en_US) 與 [Apple `id387497198`](https://apps.apple.com/us/app/solomons-boneyard/id387497198)。這建立產品身份；官網本身文字很少，不能當作完整機制規格。

手機商店由 Raptisoft 發布的描述確認：選擇法師、以雙拇指操作進行生存射擊，面對一波波不死敵人，藉升級選擇新技能；另有高分榜與持續遊玩逐漸成長的 perks 系統。手機文案標示七位年輕法師、三十多種技能。這能支持「操作、生存、局內成長、局外成長」的設計研究方向，但不提供移速、傷害、冷卻、掉落率、波次計時或技能候選權重。[Google Play 官方說明](https://play.google.com/store/apps/details?id=com.raptisoft.SB&hl=en_US)

官方 PC 產品為 [Steam《Solomon’s Boneyard: Hideous Retro Edition》](https://store.steampowered.com/app/3362180/Solomons_Boneyard_Hideous_Retro_Edition/)，開發／發行皆為 Raptisoft，頁面發售日為 2025-10-31。它同樣定位為 twin-stick survival shooter，描述選擇法師、擊敗敵群獲得經驗、角色升級，以及部分物品可跨局保留；文案標示六十多種技能／法術與數百種增強屬性的物品。商店列 Windows、SteamOS/Linux，未列 macOS。本次未確認這台 Mac 是否可實際執行該版本。

## 版本差異要如何解讀

| 議題 | 手機版本官方記錄 | PC Hideous Retro Edition 官方記錄 | 研究上的界線 |
| --- | --- | --- | --- |
| 產品身份 | Android package 與 iOS app ID 如上 | Steam app 3362180 | 三個平台各自固定版本／build |
| 宣傳規模 | 7 位法師、30+ 技能 | 60+ 技能／法術、數百道具 | 統計口徑及文案年代可能不同，不能直接相減成新增清單 |
| 成長 | 升級選技能、perks 成長 | 升級、技能、部分物品跨局延續 | 是否使用相同數值與保存規則未知 |
| 操作平台 | iPhone/iPad 與 Android | Windows、Linux | 觸控與電腦控制的手感不可直接互推 |

來源：[手機官方商店](https://play.google.com/store/apps/details?id=com.raptisoft.SB&hl=en_US)、[PC 官方商店](https://store.steampowered.com/app/3362180/Solomons_Boneyard_Hideous_Retro_Edition/)。上述是可觀察的產品描述差別，不代表已驗證完整重製內容。

「手機原版」自身也有演變。Apple 的開發者版本紀錄顯示：3.75 曾重做 perks 與物品系統，3.80 又把 perks 回復為買一次的制度；3.0 曾新增法師、技能及調整平衡；最新列出的 3.92 含存檔修正。因而不能把不同年份的攻略或影片視為同一套規則。這裡採用開發者 changelog，不把商店使用者評論當作機制證據。[Apple 官方 Version History](https://apps.apple.com/us/app/solomons-boneyard/id387497198)

目前未知：實際引擎、語言、程式架構、遊戲核心所在 module、是否混合 managed/native、固定或變動 timestep，以及各平台／年代的數值一致性。本次沒有 artifact 可供確認；商店的 OpenGL/SDL 系統需求也不能推出特定引擎或語言。

## 將 REA 例子轉成適合這款遊戲的流程

| REA 案例 | 值得搬用的方法 | 套用到 Solomon 的研究提案 | 不可推出的結論 |
| --- | --- | --- | --- |
| Dino | 只挑一條規則，取得原始實作，再用受控更新次數對照 | 固定角色、固定狀態，研究移動或單一施法的時間序列 | Solomon 也有 Dino 的加速度、60 Hz 或先判斷後加邏輯 |
| DX-Ball | 用呼叫端確認參數意義，以原始 bytes 解讀常數，補偽碼缺口 | 若取得本體，定位單一攻擊或資源公式，對照其輸入與常數 | 偽碼中的型別、函式名與數值一定正確 |
| TH04 | 保留角度表示、乘除順序、取整與回繞，再對照原程式 | 若觀察到多方向／瞄準技能，選一種研究角度與發射順序 | Solomon 使用 TH04 的 byte-angle、環形公式或碰撞規則 |
| Aegis | 先辨識 package 與方法引用，抽出小段邏輯做隔離比較 | 若 Android 目標邏輯在 DEX，可追到單一技能或時間計算 | 所有 APK 的遊戲核心都能由 JADX 讀到 |

各案例輸入、驗證範圍及限制見 [REA examples 研究](rea-examples.md)。直接證據：[Dino](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/calculator-and-dino.md)、[DX-Ball](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/dx-ball-sound-pan.md)、[TH04](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/th04-bullet-ring.md)、[Aegis](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/aegis-login-code.md)。

這些流程的共同產物應是「帶來源的機制規格」：輸入狀態、輸出、邊界條件、證據位置與尚未確定的部分。原創遊戲實作可以依這份規格改設計；原作素材、角色名稱與畫面並不是驗證機制所必需。

## 建議第一題：固定條件下，一個基本攻擊的施放節奏

這是建議研究題，並非對原作內部的既知結論。先在選定版本確認可重複操作的角色、初始攻擊、HUD 和資源顯示；如果無法控制條件，就縮回只量測可見的發射時點，不假設存在固定耗魔或冷卻公式。

**要回答的問題：** 在同一角色、同一初始等級、同一套裝備／perks／技能設定下，持續按住攻擊會於哪些時間點發射？若畫面可確認魔力顯示，記錄開始攻擊、持續攻擊、放開後三段的資源變化。先分清「畫面上看到一次發射」與「內部處理一次傷害／扣資源」，兩者不能互相代替。

**第一階段輸入。** 固定平台、版本／build、畫面設定與起始條件；記下角色及技能的遊戲內原名。未取得可執行本體時，只從使用者選定版本的實際操作錄影建立觀察表。官方宣傳片可作找題目線索，但有剪輯、角色配置與版本未知時不適合推精確數值。

**最小觀察情境。** 同一場景記錄短按、持續按住、放開、再次按住四段；避開升級、拾取道具與受傷等狀態改變，另記一次無攻擊的時間基線。若畫面或狀態受干擾，該區間標為不可用。這是之後經授權執行的觀察方案，本次沒有操作遊戲。

**對照方法。** 建立事件表：影片 timestamp／frame、可見發射、攻擊輸入狀態、可見資源、狀態變化及不確定性。影片幀率不等於模擬 update 頻率；錄影不能單獨證明精確的 timestep。若有可分析本體，再追候選更新函式、時間常數、資源條件與呼叫端，確認是固定間隔、依 elapsed time 或其他規則。

**第一題完成的標準。** 至少能用一個明確、可重播的輸入序列描述觀察結果，並讓候選規則預測另一段未用來猜公式的序列。若本體分析可行，補對應 module hash、函式／資料位置、原始常數與 REA Evidence ID。只靠錄影時，產物須標為外部行為近似與量測誤差；不能宣稱已恢復原程式。未知就保留，不先湊一條看似合理的公式。

**提供開發的最小交付。** 一頁機制規格、一份事件表、一個與美術無關的小型攻擊節奏模擬器，以及「哪些數字來自原版、哪些是我們另設」清單。後續再依相同方法擴充移動、技能選擇、波次與局外成長，避免第一題就包含整套遊戲。

## 取得哪種本體，決定 REA 路線

下面是條件式方案；不表示已確認 Solomon 使用其中任何架構，也不表示本機已安裝相關 provider。

- **Android：** 先固定來源與 APK／split APK 集合，記錄版本、ABI、hash 與 package 身份，檢查 archive inventory。若邏輯在 DEX，走 `inspect_android_package`、class/method inspection 與 references；JADX 路線需完整 JDK 及對應 headless provider。若 DEX 只是入口、核心在 bundled ELF `.so`，需辨識實際 native library，再走支援該架構的 native provider。當 server 宣告提供時可用 `inspect_android_jni_bindings` 協助找 native 宣告與候選 binding；靜態候選不等於已觀察到 runtime 呼叫。[REA Android guide](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/docs/guides/android/android-analysis.md)
- **iOS：** IPA／Apple bundle inventory 與 resources 可先提供 package 結構；真正 executable 的取得、可讀性、加密狀態及 provider 支援須另確認。能解讀 bundle metadata 不等於能反編譯遊戲核心，更不代表此 Mac 能執行該 iOS 版本。[REA Apple guide](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/docs/guides/apple/apple-application-analysis.md)
- **Steam PC：** 若可取得合法可讀安裝目錄，且工具宣告提供，先以 `inspect_desktop_application` 的 summary 分析；保留完整 Evidence，再透過 `inspect_analysis_view` 的 desktop-application view 看 files、candidates、components、next_probes。component marker 只能提供線索，不能證明 runtime。接著辨識入口檔與依賴，避免 Calculator 案例那種只分析 launcher 的情況。依檔案事實決定 native、managed 或其他路線；不同平台的本體需各自記錄身份。Windows／Linux 商店支援不保證 macOS runtime 驗證可行；若本機只能靜態分析，實際遊戲觀察須在支援主機上完成。[REA 桌面安裝目錄分析](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/docs/desktop-applications.md)

取得 XAPK 前，本回合沒有 REA MCP tools，workspace skill 僅提供指引。取得檔案後已安裝並實際使用 REA CLI 6.7.0 做封裝與 Android inventory projection；JADX / Ghidra 尚未安裝。現有靜態 ARM64 閱讀使用 Capstone，與 REA Evidence 分開記錄。詳細進度見第一輪分析報告。

## 進入執行前尚缺的資料

使用者已表示版本不限，並追加不付費限制。優先勘查可合法取得的官方免費 Android 版本，或使用既有 iPhone/iPad 上的免費 iOS 版觀察行為；依實際檔案可讀性與免費 provider 可用性選擇。若 APK 核心在 DEX，可走 Android 方法分析；若核心在 native `.so`，仍需 native 路線。Steam 版只有在已持有授權及可用本體時才列入候選。目前未見任何本體，無法先斷言哪個版本最容易。選擇時同時考慮能否在支援裝置執行原遊戲做對照，不新增購買裝置或付費執行環境。

目前已有使用者提供的 XAPK、可用 REA CLI 與選取 native 指令／資料表的靜態結果；錄影或實際遊玩對照尚未建立。後續深度反編譯仍需對應 provider。大型資料依 STORAGE-POLICY 放在已驗證 SSD，workspace 保留小型報告、清單與重現腳本。
