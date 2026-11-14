# REA 官方案例研究

查閱日期：2026-11-12。固定 REA repository checkpoint：[a01674377f1f2a0fed467035fddc25e90e74d75a](https://github.com/morluto/rea/tree/a01674377f1f2a0fed467035fddc25e90e74d75a)。

本報告閱讀官方案例頁、官方 evidence notes 及教學範例；未執行案例、啟動目標程式或下載遊戲、APK、原生分析引擎。下列成功數字是作者記錄，本次未重跑 REA、原遊戲、APK 或歷史編譯器；完整 raw Evidence、原始 binaries 及部分 harness/compiler 產品未公開，公開文件提供選取結果、hash 與來源。官方的 evidence notes 通常比展示頁更完整，會說明哪些結果由 REA 取得、哪些來自人工閱讀、另寫的 harness 或先前重建專案。[案例索引](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/public/showcase/index.html)

## 先看哪個案例

| 案例 | 要學的能力 | 證明的範圍 | RPG 開發關聯（推論） |
| --- | --- | --- | --- |
| Dino Lab | 讀取已載入 JS，抽出一條速度規則 | 原版受控 update 與重建加速曲線 | 最適合初學的移動／難度曲線練習 |
| DX-Ball | 用組語、呼叫端、常數補足反編譯缺口 | 單一函式的輸入輸出與完整編譯位元組 | 位置音效、傷害或移動公式 |
| TH04 | 還原 16 位元整數與 byte-angle 算式 | 彈幕 helper 所在程式區段的歷史編譯一致 | 環形技能、瞄準、取整及溢位規則 |
| Notion | 追蹤 Electron renderer → preload → IPC → main | 靜態橋接路徑及隔離模組探測 | 編輯器、工具程式與存檔匯出 |
| Aegis | 從 APK 找方法、追引用、重建演算法 | 隔離方法與公開測試向量 | 冷卻、時間分段等決定性邏輯的研究方法 |
| CTF | 字串 → 交叉引用 → 函式 → 資料 → 約束 | 找到一個原程式接受的解及拒絕對照 | 遊戲內謎題、規則與資料格式復原 |

## Dino Lab：第一個最適合動手的遊戲範例

**輸入與工具。** 官方以 wayou 的 Chromium 衍生 HTTP 小恐龍頁面作目標；REA 4.1.0 passive inspection 取回已載入 `index.js`。目標是 `https://wayou.github.io/t-rex-runner/`，不是 `chrome://dino/`。

**流程與輸出。** 從 settings 與 update branch 找到初速 6、每次 update 加 0.001、門檻 13。規則是先檢查 `speed < 13` 再加值；因此浮點數可略超門檻，而非強制 clamp。網站另寫 `dino-speed.js` 與可操作教學遊戲，每秒固定 60 simulation updates。

**證據與限制。** 作者使用另一個 Playwright controller 關閉原版障礙物與自動排程，再呼叫 `Runner.update()`：0／1,000／4,000／10,000 次更新的速度約 6／7／10／13.001。重建規則的 rounded 結果一致。REA 負責取資料，原版操控另有工具；跳躍、繪圖、碰撞與關卡間隔是新教學程式碼，並未聲稱恢復完整原遊戲。

**RPG 啟發（推論）。** 最適合第一個練習：只還原一條可量化的移動或難度曲線，保留閾值、浮點與 update 次數，再放進自己的極小遊戲觀察差別。

來源：[互動 Lab](https://rea.tools/examples/dino-lab/) · [證據與原版 source anchors](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/calculator-and-dino.md)

## Windows Calculator：先確認真正的計算位置

**輸入、流程與輸出。** 官方檢查 Windows Calculator 11.2508.4.0。`calc.exe` 只是以 `ms-calculator:` 啟動 App；百分比邏輯在 `CalcViewModel.dll`。分析員先協助挑選候選函式，REA 返回偽碼、指令、呼叫與引用，再用 Microsoft 公開 source 確認 operator 意義：乘／除時用 `current / 100`，其餘分支用 `current * (previous / 100)`。

**證據與限制。** DLL 指令有比較 operator、建立常數 100 及兩條算式路徑；公開 source 與標準模式測試提供 cross-check，但未執行 Microsoft 測試，也未完成 Windows GUI 輸入驗證。公開 source commit 不是已確認對應此安裝套件的 build commit。**RPG 啟發（推論）：** 安裝目錄的入口檔未必含目標邏輯；先定位實際 module，可避免分析錯層。

來源：[官方證據與 Microsoft 直接 source links](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/calculator-and-dino.md)

## DX-Ball：位置如何轉成聲音左右平衡

**輸入與工具。** 英文版 DX-Ball 1.07 的 Windows i386 `DXBALL.EXE`，158,208 bytes；作者使用 REA 4.1.0、Ghidra 12.1.4。焦點函式位於 `0x406400`，共 63 bytes。

**流程與輸出。** `analyze_function` 取得目標與磚塊碰撞呼叫端，從組語看出 stack 整數參數，再以 `read_bytes` 解讀兩個浮點常數與可變 scale。得到的核心關係是 `((x * 1.5625) - 500.0) * scale`，之後依原轉換常式轉成整數。呼叫端把磚塊座標換成橫向螢幕位置，支撐 `x` 的解釋。原反編譯偽碼漏掉輸入與 x87 算式；可讀 C 與命名由重建者補上。

**證據與限制。** 官方記錄 3,205 組原始 x86 差分案例，以及 VC4.0 編譯後完整 63 bytes 一致，包含已審核 relocation 與常數。這些驗證固定在重建 commit `a55dca27`；網站更新重用先前結果，未重跑編譯或執行驗證，亦未證明整款遊戲整合完成。

**RPG 啟發（推論）。** 先研究一個可界定的公式，追到實際呼叫端確認輸入意義，再把常數、取整和輸出列為獨立驗證點。位置音效或傷害計算很適合這種切入方式。

來源：[案例](https://rea.tools/showcase/dx-ball/) · [完整證據與原始專案連結](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/dx-ball-sound-pan.md)

## TH04：瞄準玩家的環形彈幕

**輸入與工具。** PC-98《東方幻想鄉》的 16-bit DOS MZ `MAIN.EXE`，156,258 bytes；REA 4.1.0 搭配 Ghidra 12.1.4，指定 real-mode 載入方式。遊戲重建 commit 為 `0d72e980`。

**流程與輸出。** `open_binary` → `inspect_native_load_image` 確認 header、module、load segment → `analyze_function` → `address_to_file_offset` 與 `read_bytes` 對照原始檔。還原環上角度 `(index * 256) / count`，加玩家相對發射點的方向與模板旋轉量，最後存成 byte。先乘後除、整數取整、256 回繞都會影響行為；角度約定為右 0、下 64、左 128、上 192。

**證據與限制。** 新 REA 查詢確認指令與原始 bytes。歷史重建專案另有兩次 Turbo C++ 4.0J/TASM/TLINK cold build，完整 2,139-byte 所屬區段、MAP contribution、relocation 一致；本次展示未重跑 compiler。REA 回報 helper 非連續 body，不能把 enclosing span 誤算完整函式。圖中的 16 發彈與瞄準方向是數學示意，不能推論所有難度都有相同數量。命名與來源邊界部分承接既有重建，並非 REA 自動從零恢復。

**RPG 啟發（推論）。** 最值得沿用的是環形技能的精確角度表示與取整順序；移植成浮點數後看起來相近，仍可能改變重播、碰撞或目標選擇。應先寫出行為契約再考慮現代引擎實作。

來源：[案例](https://rea.tools/showcase/th04/) · [完整證據與歷史編譯來源](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/th04-bullet-ring.md)

## Notion：從網頁 API 追到系統剪貼簿

**輸入與工具。** Notion Desktop 7.6.1 Windows `app.asar` 與另一份 2026-07-13 web-editor 快取。REA 4.1.0 的 `analyze_javascript_application` 靜態分析 tab preload，另搭配包裝碼閱讀與 Node/JSDOM 隔離探測。

**流程與輸出。** REA 定位 `__electronApi` 與動態 invoke wrapper；人工沿 API 物件讀出 `clipboard.write`、literal channel `notion:clipboard:write`，再追到 main receiver、sender check 與 Electron `clipboard.write(data)`。web-editor 另顯示以 HTML marker ID 連回私有 rich-block 資料的機制，並有 Markdown table 結構探測。

**證據與限制。** 一個 preload JS 成功解析，但 bridge members 與 channel 仍是 dynamic。feature graph 只有 partial coverage；以 channel 查詢沒有匹配，因此不能稱為工具自動配對完成的端到端 IPC 圖。desktop ASAR 與 web 快取是兩個不同 artifact，沒有同版本 live copy/paste session；JSDOM stub 結果也未證明 OS 剪貼簿完整還原。示範 JSON 與圖為簡化呈現。

**RPG 啟發（推論）。** 若開發 Electron 劇情或地圖編輯器，可研究操作如何跨 renderer 與原生能力，但需把靜態推導、stub 結果與實際使用者操作分開記錄。

來源：[案例](https://rea.tools/showcase/notion/) · [完整證據](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/notion-clipboard.md)

## Aegis：Android 驗證碼的計算鏈

**輸入與工具。** 官方 Aegis v3.4.3 APK，6,881,897 bytes，已依 release digest 核對；作者使用 REA 6.1.0 CLI、`jadx-headless-mcp` 0.7.1、OpenJDK 21。這次 CLI 的 provider 可用，當時已連線 MCP server 的 Android provider 不可用；展示頁以等價工具參數呈現成功的 CLI 查詢。

**流程與輸出。** 搜尋 `Totp`、檢視 class/method、追 static references，從 UI 呼叫找到時間 overload 與生成器：時間轉秒、除以 period 取整、counter 編成 8-byte big endian、HMAC、dynamic truncation、十進位取餘數與補零。預設為 30 秒、SHA1、6 位，不能推成所有帳號都使用該設定。混淆後的實際 helper 位在 `kotlin.ExceptionsKt`，直接猜原 source 名稱可能找不到。

**證據與限制。** 從反編譯結果取六個方法建立 JVM harness，再與獨立 Python 與 WebCrypto 比較 133 個輸入，包含 RFC 6238 向量、0–120 秒與前導零。沒有執行原 APK 或驗證 Android UI；反射、動態載入、vault、安全儲存與簽章也不在這個結論範圍。範例固定 key 是公開測試資料。

**RPG 啟發（推論）。** 可學習如何把時間邊界、輸出格式與混淆後引用關係抽成獨立規格；這種方法能用於冷卻或時段事件，但案例本身沒有研究遊戲機制。

來源：[案例](https://rea.tools/showcase/aegis/) · [完整證據、release 與 source anchors](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/aegis-login-code.md)

## DownUnderCTF：把檢查器變成方程式

**輸入與工具。** DownUnderCTF 2023 的 easy challenge「masked squares flag checker」，stripped Linux x86-64 ELF，15,248 bytes。REA 4.1.0、Ghidra 12.1.4，加另寫的 Python/Z3 solver。

**流程與輸出。** `search_strings` 找提示及成功失敗訊息，`xrefs` 與 `resolve_containing_procedure` 定位檢查函式，再分析兩個 helper、讀取 masks 與 targets。恢復 36 個輸入位置、26 個 mask；signed-byte run length 展開成選取區域，選中位置的字元碼相加等於目標，轉成約束求解。

**證據與限制。** 作者先分析 handout，再讀主辦 source/solution cross-check。原 checker 的 `capture_process_scenario` 接受候選 flag（`Correct!`、exit 0），拒絕改一字的對照（`Incorrect!`、exit 255）。solver 另加 `DUCTF{...}` 與字元集假設，第二組解搜尋逾時，故沒有證明解唯一。Z3 solver 與可讀 C 摘要是分析者撰寫，並非 REA 自動產出的完整解答。

**RPG 啟發（推論）。** 適合學習如何還原謎題、條件判定、未知編碼；同時保留一個通過與一個失敗的原程式對照，避免只驗證自己的模型。

來源：[案例](https://rea.tools/showcase/ctf/) · [完整證據與官方 challenge](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/ctf-masked-squares.md)

## 能親自練習的小範例

- **Notes Electron：** 六個來源檔，研究 Export 按鈕經 preload、IPC、main 到 CSV formatter。官方解析四個 JS，得到一個暴露 API、一個 literal IPC channel 與一組配對；完整按鈕到寫檔路徑仍含 source 閱讀推論。可從靜態分析學習，再單獨檢查 CSV 的引號跳脫。這是 source-owned fixture，未包成完整 Electron 安裝版。[來源目錄](https://github.com/morluto/rea/tree/a01674377f1f2a0fed467035fddc25e90e74d75a/website/public/examples/notes-electron)
- **Notes Web：** 瀏覽器載入本地頁，REA passive capture 觀察 `notes.json` 的 GET、200 與 body shape。按按鈕及確認 CSV 下載是另一個 Playwright controller 做的，REA 沒有按按鈕；CSV 內容建構另由 source 解釋。捕捉窗口開始前的請求不包含在觀察內。[來源目錄](https://github.com/morluto/rea/tree/a01674377f1f2a0fed467035fddc25e90e74d75a/website/public/examples/notes-web)
- **GitHub Actions：** 手動 `workflow_dispatch`，Node 24.22.1、REA 6.7.0，先產生簡單 JS fixture 再靜態分析，保存 JSON、stderr、原始 exit code，失敗也嘗試上傳報告。fixture 含一段若執行就 throw 的程式，強調此 workflow 分析檔案而非執行目標。不能把 workflow 複製到 repo 視為已驗證自己的遊戲打包產物。[workflow](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/examples/github-actions/rea-analysis.yml)

Notes 執行與來源身份的細節：[guide-examples evidence](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/guide-examples.md)。上述版本是各記錄的固定版本，並非本報告對目前安裝相容性的保證。

## 對本 workspace 的具體建議（推論）

若目標是研究既有遊戲的一項戰鬥或技能機制，建議先讀 DX-Ball，再讀 TH04：先界定輸入輸出、定位呼叫端和資料、對照原程式，最後才寫自己的版本。若目前只是熟悉 REA，建議第一個做 Dino Lab 的單一加速規則；之後選 Notes Electron 讀完整小型靜態範例，再用 CTF 練習從線索定位未知函式。

驗證需保留不同層次：原程式輸入輸出、重建函式結果、編譯 bytes，以及真正遊戲中的整合表現。任一層成功，不能自動代替其他層。

補充官方 Touhou 重建方法記錄：其建議次序為精確 baseline → 原平台可跑 → 語意重建且保留 byte 與行為兩條驗證 → 現代移植。文件也記錄 TH08 的 oracle 曾只檢查指令與引用位址，漏查該位址的常數內容，導致 128.0 誤成 0.0 仍過關；後來補上資料驗證。這裡依 REA 官方 evidence note 轉述，未獨立查閱其所列 issue/PR。歷史重建有多種專案工具與既有工作，不能全歸功於 REA；日曆跨度也不是工時或算力基準。[方法與引用紀錄](https://github.com/morluto/rea/blob/a01674377f1f2a0fed467035fddc25e90e74d75a/website/evidence/touhou-reconstruction-method.md)
