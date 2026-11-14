# 手機 2D 生存動作原型：Godot 與 Unity 引擎選型

研究日期：2026-11-13（Asia/Taipei）。狀態：**研究建議，尚未由使用者確認引擎，也尚未安裝或完成任何平台建置。**

後續進度（同日）：使用者已授權採用 Godot 並安裝、開始實作。Godot 4.7.2 已安裝，Mac 原型已啟動；下文保留研究當時的盤點。最新結果見 [實作狀態](../development/prototype-v0.1-status.md)。

## 建議與適用範圍

**本案推論：優先評估 Godot 標準版搭配有型別註記的 GDScript，Unity + C# 保留為替代方案。** 目前範圍是單人離線、2D 俯視角、一隻刺蝟、一張小場地、約 3 分鐘；核心是手機橫向雙手操作、瞄準持續攻擊、清怪與升級構築。這些需求適合先用簡單場景和文字程式碼反覆驗證。可愛動物題材不構成引擎的技術門檻，美術風格仍可獨立決定。

這項建議依據下列已查閱的官方資料，並非已完成的比較實測。沒有證據可在此保證哪套引擎的 FPS、包體、開發速度或耗電一定較好。本次不指定「最新版」或固定 patch 版本：Godot 使用官方 `stable` 文件；Unity 功能比較使用明確的 Unity 6.0 文件分支及 Input System 1.11 文件，**它們是查證依據，不代表專案應安裝這個版本**。實際安裝前需重新查核受支援的正式版本及對應 SDK 要求。

## 可驗證事實與本案解讀

| 面向 | Godot：官方可驗證事實 | Unity：官方可驗證事實 | 本案推論 |
| --- | --- | --- | --- |
| 2D | 具有專用 2D 渲染、物理、精靈動畫與粒子工具。[Godot 2D](https://docs.godotengine.org/en/stable/tutorials/2d/introduction_to_2d.html) | 支援 Sprite、Tilemap 與 2D Physics，也提供 URP 的 2D 功能。[Unity 2D](https://docs.unity.com/en-us/engine/6000.0/manual/unity2d) | 兩者都能承載本案玩法；第一版用占位素材即可測試，不需先定正式畫風。 |
| 語言 | 同時提供 GDScript 與 C#；C# 需要 .NET 版編輯器。官方目前仍將 C# 的 Android、iOS 支援列為 experimental。[Godot C#](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html) | 遊戲及自訂元件可用 C# 撰寫。[Unity scripting](https://docs.unity.com/en-us/engine/6000.0/manual/scripting/get-started/creating-scripts) | Godot 原型先用 GDScript，可避開本案不需要的 .NET 手機出口變數。若已有必用 C# 程式庫或團隊 C# 經驗，再提高 Unity 的權重。 |
| 文字原始碼 | TSCN 是可讀的場景文字格式，官方明確指出便於版本管理。[TSCN](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html) | 資產序列化有 Force Text 選項，也是該文件分支的預設；場景可存為文字以利合併。[Unity Editor settings](https://docs.unity.com/en-us/engine/6000.0/manual/unity-editor/editor-settings-reference/comp-manager-group/class-editor-manager) | 兩者都能做 AI 協作與差異審查。Godot 的簡單場景搭配腳本符合這次小型原型；仍應由引擎匯入與執行驗證產物，文字可讀不等於內容正確。 |
| CLI 與自動化 | 支援從命令列執行專案、單一場景，以及 `--headless` 匯出；匯出仍需 editor binary、export templates 與 preset。[Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | 支援 `-batchmode`、`-executeMethod` 執行自訂靜態方法以做建置或測試；同一專案不能同時被 GUI editor 與 batchmode 開啟。[Unity CLI](https://docs.unity.com/en-us/engine/6000.0/manual/unity-editor/command-line-arguments/editor) | 兩者都能建立可重現檢查。CLI 通過只能證明其檢查範圍；畫面、手機雙指與手感要另外驗證。 |
| 觸控 | `InputEventScreenTouch` 提供多點觸控按下、放開、取消與手指 index。[Godot touch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html) | Input System 有 `OnScreenStick`，也有追蹤手指和 touch 的 EnhancedTouch API。[On-screen controls](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/OnScreen.html)、[Touch](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/Touch.html) | 兩者可實作左移動、右瞄準。需明確處理雙指歸屬、離開控制區、取消事件與暫停後釋放；不能用桌面滑鼠替代完整手機驗收。 |
| Android 匯出 | 需設定 Java SDK、Android SDK，官方 stable 文件目前建議 OpenJDK 17，並列出所需 SDK 元件。[Godot Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | 需 Android Build Support、SDK、NDK、JDK，依所選 Editor 使用受支援版本。[Unity Android setup](https://docs.unity.com/en-us/engine/6000.0/manual/platform-specific/android/getting-started/sdksetup) | Android Studio 並非「遊戲邏輯開發一定要開著」的工具；SDK 工具鏈仍要完整。先選版本，再依該版本文件準備依賴。 |
| iOS 匯出 | 本機出口需要 macOS、Xcode、Godot export templates；先輸出 Xcode 專案，再由 Xcode 建置。[Godot iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) | 先產生 Xcode 專案，再由 Xcode 建置；本機建置需要 macOS。[Unity iOS](https://docs.unity.com/en-us/engine/6000.0/manual/platform-specific/iphone/ios-building-and-delivering/build-process) | 此 Mac 符合主機平台方向，但有 Mac 不代表已具備 iOS SDK、簽署與實機測試能力。 |

GDScript 的型別註記可以讓部分錯誤在執行前被偵測，也有助補全及程式理解；不是完整邏輯正確性的保證。[Godot static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) **本案推論：**玩家狀態、投射物參數、升級資料等應使用清楚型別，將數值與選項資料集中，降低每次調參需要修改戰鬥程式的範圍。

## 手機測試、簽署與授權邊界

- **Android 事實：**裝置安裝的 APK 都需要數位簽署；開發測試與正式發布的金鑰流程不同，Play 上傳也有對應簽署要求。[Android app signing](https://developer.android.com/studio/publish/app-signing) **本案推論：**第一個手機里程碑以可安裝的 debug build 實玩為目標，正式商店發布另列里程碑，避免把「匯出成功」當作「已能上架」。
- **iOS 事實：**Apple Account 可在 Xcode 以 Personal Team 做個人裝置測試，但有裝置、App ID 與 provisioning 的限制，需要週期性重新佈署；一般 App Store Connect 的 beta 測試與散布則涉及 Developer Program。[Apple developer account](https://developer.apple.com/help/account/basics/about-your-developer-account) **本案推論：**早期個人實機測試可以先評估 Personal Team；需先確認實際裝置及帳號情況，不能預設已有付費會員，也不能保證免費路徑符合後續所有測試需要。本次未登入或查閱任何帳號、憑證。
- **Godot 授權事實：**引擎採 MIT，允許商業用途，遊戲內容可自行授權；散布引擎時需保留授權與著作權聲明，第三方元件亦有各自聲明。[Godot license](https://godotengine.org/license/) **本案推論：**適合先採免費工具路徑，發布時仍需整理引擎及素材授權。
- **Unity 授權事實：**Editor 層級使用資格依適用的財務及組織條件決定，不能僅憑「小遊戲」判定合資格；官方已取消先前的 Runtime Fee 政策。[目前 Editor Software Terms](https://unity.com/legal/editor-terms-of-service/software)、[官方取消公告](https://unity.com/blog/terms-update-runtime-fee-cancellation) **本案推論：**本報告不推定使用者的 Personal 資格，也不以舊 Runtime Fee 作為排除 Unity 的理由；實際採用前確認當下條款及適用方案。

## 本機唯讀盤點

以下是本輪 shell 觀察，僅查標準路徑與目前 PATH，**不是全磁碟安裝調查**：

| 檢查 | 實際結果 | 可下的結論 |
| --- | --- | --- |
| `/Applications/Godot.app`、`Godot_mono.app` | 路徑不存在 | 未在這兩個標準名稱找到 Godot；其他目錄或改名版本未查。 |
| `/Applications/Unity Hub.app`、`Unity` | 路徑不存在 | 未在這兩個標準位置找到 Unity Hub 或 Editor 安裝目錄。 |
| `/Applications/Xcode.app`、`Android Studio.app` | 路徑不存在 | 未在這兩個標準名稱找到完整 IDE。 |
| `command -v` 等價 PATH 查詢：`godot`、`unity`、`adb` | 均無結果 | 目前 shell 不能直接透過這些名稱執行它們。 |
| PATH：`xcodebuild`、`java` | `/usr/bin/xcodebuild`、`/usr/bin/java` | 只證明命令入口存在；沒有執行版本或建置檢查，不能據此認定完整 Xcode 或 JDK 可用。 |
| `xcode-select -p` | `/Library/Developer/CommandLineTools`，exit 0 | active developer directory 目前指向 Command Line Tools。尚未證明完整 iOS build toolchain。 |
| 工作目錄 `git status --short` | exit 128，`not a git repository` | 此目錄目前無可用 Git 狀態；本次沒有初始化版本庫。 |

尚未驗證：Editor/模板版本、macOS 與 SDK 相容性、Android SDK/JDK 是否另有安裝、手機型號及連接、USB debugging／Developer Mode、Apple Team 與簽署資格、任何實機建置與效能。以上結果不表示工具永遠不可用；安裝或路徑變更後必須重做驗證。

本輪主代理已讀本機 `STORAGE-POLICY.md`，以 `python3 -B /Users/junming/AI-Setup/storage/storagectl.py path artifacts --project codex/RPG_Game_Dev` 唯讀核對核准 SSD，解析至 `/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev`；未建立目錄、寫入或下載。依該政策規畫：應用程式本體在內部磁碟，大型下載、模板或 SDK 應先評估核准外部儲存目的地及工具支援的路徑設定；現有 application-managed state 不自行搬移。SDK 能否使用外部路徑及其影響，仍須按所選工具的 supported setting 驗證，不能視為可無代價搬移。

## 建議的選型驗收順序

以下為下一階段提案，並非本輪已執行項目：

1. 確認使用者手邊可測的 iPhone 或 Android，選擇第一條實機驗證路徑；iOS／Android 的長期優先順序仍可保持開放。
2. 以 Godot + GDScript 為候選，先查核所選正式版本與 export templates，整理安裝位置及 SDK 需求。任何引擎、SDK、模板等大檔下載前先依專案收到的本機儲存政策處理；本報告不自行安排下載或內部磁碟替代。
3. 做極小的「角色移動 + 左右雙指 + 尖刺」測試，先跑桌面，再及早取得第一個真手機可安裝版本；先排除出口與操作問題，再擴展完整 3 分鐘循環。
4. 保存引擎版本、CLI 指令、錯誤輸出與手機測試紀錄；驗證多指、失焦、升級暫停後輸入恢復及重新開始。
5. 累加敵人與投射物後，用目標手機觀察幀時間、發熱與觸控穩定性。沒有實測瓶頸前，不預先引入複雜最佳化；若必要套件、團隊技能或持續出口障礙使 Unity 更合適，再重做決策。

本輪產出只有此研究文件；沒有下載引擎或 SDK、接受條款、建立憑證、變更系統設定或執行遊戲。
