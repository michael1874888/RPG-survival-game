# 俯視角 2D 生存動作遊戲：美術、介面、動畫與特效工具選型

研究日期：2026-11-14（Asia/Taipei）。範圍：為本專案選擇可落地的視覺製作工具，並比較目前採用的 Godot 與 Unity 對 2D 視覺工作的支援。這是工具與流程研究，不代表已選定最終畫風、購買軟體或匯入素材。

## 專案現況與選型邊界

本專案現有方向是手機優先、2D 俯視角；角色美術傾向可愛動物，戰鬥可以誇張但非血腥。目前主角是黑貓奈奈，正式美術風格仍未決定。[遊戲方向草案](../design/game-direction.md) 專案已使用 Godot 4.7，渲染設定為 GL Compatibility。[project.godot](../../game/project.godot) 因此本報告把 Solomon’s Boneyard 與 Survivor.io 當作成熟度參考，沒有假設本案應照搬它們的造型或製作工具。

## 建議摘要

以「盡量免費、Codex 能用程式和命令列完成大部分工作、少依賴人工編輯器操作」作為優先條件，**目前建議保留 Godot，而非現在轉 Unity**。原因是專案已在 Godot 4.7，Godot 場景 `.tscn` 是可讀文字格式，且官方支援 headless 匯入、執行、檢查和匯出；Codex 可直接改場景、Theme、shader 和腳本，再透過 CLI 建置。Unity 同樣可批次執行與命令列建置，並有文字場景格式及 UXML/USS 文字 UI，因此不是不能自動化；但本案轉換會增加遷移成本，目前沒有足以抵銷它的需求證據。[Godot TSCN 格式](https://docs.godotengine.org/en/4.7/engine_details/file_formats/tscn.html)、[Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)、[Unity CLI 建置](https://docs.unity3d.com/ja/current/Manual/build-command-line.html)、[Unity 文字場景](https://docs.unity3d.com/ru/current/Manual/TextSceneFormat.html)、[Unity UI Toolkit](https://docs.unity3d.com/2023.2/Documentation/Manual/UIElements.html)

**建議採用的免費優先工作流：** Godot（遊戲、UI、shader、粒子、動畫及自動建置）+ Codex 維護文字格式場景與程式化視覺 + Krita（需要手繪時才使用）。不把 Figma 設為必要依賴；它適合人手視覺規劃，但不符合「盡量由 Codex 自動產出」的首要目標。Unity Personal 目前仍可免費使用，但有最近 12 個月 USD 200,000 財務門檻；轉換建議留待出現 Unity 專屬功能、既有團隊資產／技能、或明確的平台／外掛需求時重新評估。[Unity Personal 條件](https://unity.com/products/unity-personal%20)、[Unity Editor Terms](https://unity.com/legal/editor-terms-of-service/software)

**自動化的品質界線：** Codex 可自動產生或修改 UI 排版、向量圖形、粒子與 shader、素材清單、建置及可重複的尺寸／透明度／匯入檢查；但「風格是否統一、角色是否討喜、手機縮小後是否易讀、特效是否遮擋戰鬥」屬主觀視覺品質，仍需人看實際遊戲畫面並做最後接受。免費軟體不代表素材生成服務免費；本報告不假設任何 AI 圖像生成服務可免費無限制使用。若 Unity 後續納入考慮，應一併閱讀其現行條款對 AI agent 互動 Unity 產品／服務的限制，並確認預定的自動化入口符合條款。[Unity Terms of Service（AI 及自動化條款）](https://unity.com/legal/terms-of-service)

**精簡且適合目前專案的工具組合：**

| 工作 | 建議工具 | 適用理由與界線 |
| --- | --- | --- |
| 角色、敵人、場景繪製與手繪特效紋理 | **Krita** | 免費開源的數位繪圖軟體，支援繪畫、圖層，也包含逐格 raster 動畫時間軸與 onion skin。適合手繪／柔和上色素材及技能貼圖；動畫可簡單預覽，但正式遊戲動畫仍匯出影格並在 Godot 管理。[Krita 下載與授權](https://krita.org/en/download/)、[Krita 動畫手冊](https://docs.krita.org/en/user_manual/animation.html) |
| 如果最後決定像素美術 | **Aseprite** | 專門處理 pixel art 和逐格 sprite 動畫：時間軸可編輯影格、圖層、cel，支援動畫標籤和 onion skin。官網標示 1.x 版本建議價格最低 USD 19.99；授權可在商業遊戲中使用創作內容，不能再散布編輯器本體。[動畫功能](https://www.aseprite.org/docs/animation)、[價格與商業使用 FAQ](https://www.aseprite.org/faq/) |
| 介面流程、HUD、升級卡與選單原型（可選） | **Figma Starter，非必要依賴** | 適合需要人手畫螢幕版面和互動原型時使用。Starter 免費但功能受限；若需要團隊 libraries、較完整原型和 Dev Mode，Professional Full seat 官網目前列 USD 16/月。若目標是 Codex 盡可能自動完成，直接在 Godot 以文字場景、Control/Theme 建 UI，可略過 Figma；無論採哪種方式，正式介面仍須看實際遊戲畫面驗收。[方案與功能](https://www.figma.com/pricing/)、[Godot GUI Theme](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html) |
| HUD、升級卡、主選單實際介面 | **Godot Control、Theme、StyleBox** | 不需另買 UI runtime。Godot 的 Control Theme 可集中統一控制項樣式、顏色與字型；搭配 theme variations 和自訂 StyleBox 可建立共用按鈕、生命條、卡片、面板樣式。Figma 先做規格與試排，Godot 完成縮放、文字與觸控驗收。[GUI skinning](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html)、[Theme type variations](https://docs.godotengine.org/en/stable/tutorials/ui/gui_theme_type_variations.html) |
| 受擊、揮擊、爆炸、技能光效 | **Godot GPUParticles2D／CPUParticles2D、CanvasItem shader、AnimationPlayer** | 即時粒子和 shader 應在遊戲引擎內調整，以便綁定命中時機、角色位置、遊戲速度與畫面效果。Godot 有 2D 粒子與自訂 shader，AnimationPlayer 可以動畫化節點、UI、粒子與材質屬性。Krita 可額外提供 hand-painted 閃光／煙塵貼圖或 flipbook。大量敵人時需在目標手機量效能，功能存在不等於效能已驗證。[Godot 2D 功能](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)、[動畫功能](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html) |
| 角色逐格動畫匯入遊戲 | **Godot AnimatedSprite2D / AnimationPlayer** | Godot 能直接以圖檔序列或 spritesheet 建立 SpriteFrames 並播放；AnimationPlayer 則可同步改位置、縮放、材質或 UI 狀態。適合少量主角／敵人的走路、攻擊、受擊、死亡與勝敗動作。[2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) |
| 大量骨架動畫（條件式採用） | **Spine Professional** | 只有在角色／敵人很多、需要骨架重用、換裝或連續可調姿勢時才值得增加付費與匯入流程。Spine 官網標示 Essential USD 69、Professional USD 379（目前頁面促銷價，原價分別 USD 99/449）；每位使用者都需要自己的授權，符合特定融資／收入門檻的企業需 Enterprise。Spine 有 Godot runtime，但應在採購前核對 Godot 版本及目標平台相容性。[Spine 價格與授權門檻](https://esotericsoftware.com/spine-purchase)、[官方 Godot runtime](https://us.esotericsoftware.com/spine-godot) |

## 引擎比較與本案決策

| 項目 | Godot | Unity | 對目前專案的解讀 |
| --- | --- | --- | --- |
| 2D 視覺製作 | 官方文件涵蓋專用 2D rendering、TileMap、2D lighting、sprite/cutout animation、particles、shader。[來源](https://docs.godotengine.org/en/stable/tutorials/2d/introduction_to_2d.html) | Unity 6.6 文件列出 sprites、Tilemaps、2D physics；文件導覽也含 animation、lighting、materials/shaders、visual effects。[來源](https://docs.unity.com/en-us/engine/6000.6/manual/unity2d) | 兩者均有能力，不需僅為了美術品質轉換。熟悉和已在用的工具鏈會影響產出速度，但這是本案推論，不是引擎 benchmark。 |
| 美術與遊戲 UI 分工 | 可在 Godot 內建立 Control、Theme 和樣式資源；素材工具只負責圖像／字型資產。[GUI Theme](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html) | Unity 也有自己的 UI、sprite、動畫與 VFX 工作流。 | UI mockup 工具不取代引擎內的真實螢幕尺寸、字型、本地化及觸控測試。 |
| 引擎費用與授權 | Godot 為 MIT，允許商業用途；發行遊戲時要提供 MIT license/copyright notice。[授權說明](https://godotengine.org/license/) | Unity Personal 在總財務不超過最近 12 個月 USD 200,000 時符合個人版門檻；條款門檻高於該數字需使用對應付費方案。Unity 官方說明已取消 Runtime Fee，不能沿用過期的按安裝收費傳聞作為當前比較。[Editor Terms](https://unity.com/legal/editor-terms-of-service/software)、[Pricing updates](https://unity.com/products/pricing-updates) | 本案已使用 Godot；授權成本沒有觸發改引擎的理由。若未來團隊財務／支援需求改變，再即時核對 Unity 條款。 |
| 圖像資產授權 | Godot 引擎 MIT 不會把遊戲素材改成 MIT；素材、字型、外掛仍需各自記錄授權。[Godot license compliance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) | 商用引擎授權與遊戲素材版權是分開項目。 | 對自製與 AI 生成素材保留來源、授權、修改和交付紀錄；引擎免權利金不代表第三方素材免查授權。 |

## Codex 自動化友善度與引擎選擇

| 工作流程面向 | Godot | Unity | 本案判斷 |
| --- | --- | --- | --- |
| Headless / CLI | 官方 CLI 可 headless 執行專案、匯入資源、執行腳本及依匯出 preset 建置；官方明確提到 CI 匯出用途。[CLI 文件](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | 可用 `-batchmode`、`-executeMethod`、`-buildTarget`、`-projectPath` 在命令列執行自訂建置腳本；官方列為 CI 與建置管線用途。[CLI 建置](https://docs.unity3d.com/ja/current/Manual/build-command-line.html) | 兩者都有足以讓 Codex 寫腳本、呼叫 CLI、讀建置結果的自動化入口。 |
| 場景與 UI 的文字表示 | `.tscn` 場景和 `.tres` 資源可從檔案系統編輯；官方稱 TSCN 大致可讀且適合版本控制。[TSCN](https://docs.godotengine.org/en/4.7/engine_details/file_formats/tscn.html) UI 可用 Control 節點與 Theme 資源。 | 可選文字序列化的 scene；UI Toolkit 可用 UXML 定義結構、USS 設定樣式，也可以 C# 建 UI。[Text scenes](https://docs.unity3d.com/ru/current/Manual/TextSceneFormat.html)、[UI Toolkit](https://docs.unity3d.com/2023.2/Documentation/Manual/UIElements.html) | 兩者均可由 Codex 直接產生和修改；Godot 在本案不需先遷移既有節點樹、資源和遊戲程式。Unity 亦可以高度程式化，不應說它必須依賴人工拖拉。 |
| 免費條件 | MIT 授權、無引擎權利金；仍須遵守授權聲明要求。[Godot 授權](https://godotengine.org/license/) | Unity Personal 免費但受 USD 200,000 / 12 個月財務門檻和適用條款限制。[Unity Personal](https://unity.com/products/unity-personal%20) | 兩者對符合條件的小型開發者都可零引擎費用；Godot 的授權條件較簡單。 |
| 轉換代價與收益 | 專案已是 Godot 4.7 / GL Compatibility；現有場景、素材匯入、程式和手機設定能繼續沿用。 | 需重建／移植場景、資源匯入設定、UI、渲染和遊戲程式；雖可自動化 Unity 端建置，但建置自動化本身不等同於值得搬引擎。 | 暫不遷移。僅在需求清楚需要 Unity 生態中特定套件、平台整合、人才或工作流，且其收益經小型垂直切片證實後考慮。 |

補充：Unity 2026 年 6 月更新的服務條款提到，AI agents、LLMs、MCP clients/servers 與 Unity 平台互動須透過 Unity 營運或指定的 framework，並限制自動化 scraper/bot。這段條文涉及的是 Unity 產品／服務互動；它不抹去官方文件所支持的本機 Editor batch mode，但在承諾「Codex 全自動」前，必須核對具體執行路徑與條款，不應只憑有 CLI 就假定所有 agent 操作皆可用。[Unity Terms of Service](https://unity.com/legal/terms-of-service)

## 對標作品與「品質」判斷

Solomon’s Boneyard、Survivor.io 在此只作為使用者提出的**大方向品質參考**。本次沒有第一手製作人訪談或官方技術文件可證明它們使用了哪套美術軟體、引擎特效管線、委外流程或人力配置，因此不把上述推薦說成對標作品的內部製程。

工具能提供的是產出能力。要讓俯視角場面接近成熟產品的視覺完成度，仍需要建立一致的畫面規格：角色和敵人輪廓在手機縮小後可辨、主角／敵人／攻擊／掉落物／HUD 有清楚層級、命中與技能有明確起止節奏、粒子不遮住主要目標、字級與安全區適配不同螢幕。這些是依本遊戲類型提出的設計檢查項，不是競品品質的測量結果。

## 實作順序建議

1. 先以一張角色、普通敵人、地面、攻擊效果、升級卡的同屏情境確認畫風方向；畫風未定前，不要同時採購像素與骨架工具。
2. 若選手繪彩色風格，用 Krita 建立原始角色與特效紋理；若選像素風，改用 Aseprite。統一畫布尺寸、描邊／明暗規則、色票、透明邊界和匯出尺寸。
3. 在 Figma 畫手機 HUD、升級選擇、暫停和結算四個核心狀態，先檢查小螢幕辨讀與可點區域；再在 Godot 用 Control 和 Theme 做真實 UI。
4. 在 Godot 先完成三個效果：受擊回饋、一次普通攻擊、一次大招；以粒子/shader 為動態部分，必要時加手繪影格，測試畫面可讀性與實機負載。
5. 角色數量及動畫重用需求明確後，再評估 Spine；否則先用 spritesheet / AnimatedSprite2D，避免目前增加授權與匯入複雜度。

## 官方來源清單

- Godot 2D、動畫與 UI： [2D overview](https://docs.godotengine.org/en/stable/tutorials/2d/introduction_to_2d.html)、[2D topics](https://docs.godotengine.org/en/stable/tutorials/2d/index.html)、[2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)、[AnimationPlayer introduction](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html)、[GUI skinning](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html)、[license](https://godotengine.org/license/)
- Unity： [Unity 6.6 2D manual](https://docs.unity.com/en-us/engine/6000.6/manual/unity2d)、[Editor Software Terms](https://unity.com/legal/editor-terms-of-service/software)、[pricing updates](https://unity.com/products/pricing-updates)
- 素材與設計工具： [Krita download/license](https://krita.org/en/download/)、[Krita animation manual](https://docs.krita.org/en/user_manual/animation.html)、[Aseprite animation](https://www.aseprite.org/docs/animation)、[Aseprite FAQ](https://www.aseprite.org/faq/)、[Figma pricing/features](https://www.figma.com/pricing/)、[Spine purchase/license](https://esotericsoftware.com/spine-purchase)、[Spine Godot runtime](https://us.esotericsoftware.com/spine-godot)
