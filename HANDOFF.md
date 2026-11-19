# RPG-survival-game：下一個 session 交接

更新：2026-11-20。開發目錄 `/Users/junming/Codex_ws/RPG_Game_Dev`；遠端私人 repository `michael1874888/RPG-survival-game`。v0.20 從 `fb44f07` 的 `main` 開發，整理於 `feature/nana-v0.20-r1`；接手前重新查 `git status --short --branch` 和遠端分支狀態。

**開發取捨（使用者確認）：**優先沿主線以小里程碑推進；不影響當前方向的問題先記錄，留待相關階段處理，避免發散。可能改變核心玩法、操作或構築方向，或阻礙下一里程碑的問題，先釐清。具體方向見 [開發路線](docs/design/development-roadmap.md)。

**最新工作（2026-11-20，v0.20 / D1 R1）：**玩家回報 v0.19 感受改善、想試新取得裝備，先要求完整設計、確認後實作，隨後明確說「好 開始實作」。目前已實作首章九戰、六成形、15 天賦、六件首章寶物、六路線事件、收藏／續玩／練習／結果及 Android 試玩包。[主設計](docs/design/nana-full-version-design-v1.md)、[內容表](docs/design/nana-full-version-content-v1.md)、[製作／試玩／發布門檻](docs/design/nana-full-version-release-plan-v1.md)、[v0.20 試玩說明](docs/development/nana-v0.20-practice.md)。R1 真人和手機驗收尚未完成，R2 完整首發內容與 R3 發布候選尚未完成。

**先前進度（2026-11-19，v0.19）：**回身鈴鐺已實作、匯出並推送至 `main`，提交 `fb44f07`。完成第三段取得並永久收藏，下局可選裝備，B2 提前追咬並鎖定成形路線；該版與 v0.20 的共通成長上限不同。已收到上述整體體感與首次試用動機回饋；設備、存檔細項與跨日重玩尚未提供。APK 與開發驗證見 [v0.19 試玩說明](docs/development/nana-v0.19-practice.md)。

**先前進度（2026-11-18，v0.18）：**依使用者確認實作 B 三級兩條分支。成長選 B3 時可選雙發蓄勢或回身追咬，後者在成功推開存活目標後標記 2 秒，下一爪命中追加傷害。v0.18 Android debug APK 已建置並驗簽。玩家覺得回身追咬打最後守關者較輕鬆，雙發蓄勢在一般戰況較輕鬆。願意試不同路線，玩完後再開一局的意願仍不強。完整自動測試 356 項及封裝後分支規則通過；自動對照都在守關失敗，非真人勝率。詳細見 [v0.18 試玩紀錄](docs/development/nana-v0.18-practice.md)。相關原始碼已隨 v0.19 整理推送。

**先前進度（2026-11-18，v0.17）：**v0.17 R1 已完成、整理並推送至 `main`；成長短局、受限選項、三級能力、守關支援及 Android APK 已交付，已收到[首輪回饋](docs/design/poc-feedback-and-followups.md#v017-成長與重玩回饋2026-11-18)：A／B 會改變打法，能力在守關有用，紅怪追擊壓力最明顯，中途較少想停，但持續重玩意願普通。[試玩說明](docs/development/nana-v0.17-practice.md)／[設計規格](docs/design/nana-growth-run-proposal-v0.17.md)。自動控制器無無敵的三次開局均在守關失敗，受保護版本能完成；不能由自動結果推論真人勝率或樂趣。

**v0.16 實玩：**使用者表示疾追者較有威脅性，需要走位和開大絕；其後補充上述整局回饋。未提供能力配置、終局結果；不推論平衡或完整核心循環驗收通過。暫停單獨追擊校準，轉向整局成長與回報的設計 review。[回饋紀錄](docs/design/poc-feedback-and-followups.md#v016-追擊試玩回饋2026-11-17)。

**最新 v0.15 實玩：**仍簡單、沒有追擊或腹背受敵的緊張感，敵人一兩下被清掉且未用大絕；未提供本次配置或終局結果。使用者同意處理接敵、威脅存活與包圍，已實作 v0.16；不能以腳本死亡替代真人判斷。見 [追加回饋及受控核對](docs/design/poc-feedback-and-followups.md#v015-追加回饋2026-11-16)。

**2026-11-16 最新回饋：**v0.14 使用 A、B 均打到最後一段，未確認是否完成；單調、沒有特別好玩的地方、機制不夠豐富、打怪輕鬆且未用大絕，缺乏重玩吸引力。挑戰、隨機及資源延續是使用者提出的原因候選，尚未證實。核心循環樂趣需優先檢視，具體改版尚未定案；不能以自動通關推定驗收通過。見 [回饋紀錄](docs/design/poc-feedback-and-followups.md#v014-完整短局回饋2026-11-16)。

使用者追加確認「操作順，但敵人太好處理，沒什麼需要判斷」，並指示開始 v0.15。已調整遭遇與決策提示；不是基礎攻擊已完整驗收。

**最新可玩版本為 v0.20.0 R1：首章完整循環已交付供試玩，尚未達首發／上架候選。** [v0.20 試玩說明](docs/development/nana-v0.20-practice.md)。`v1.0` 是三章及發布品質全部完成後的目標。

## 1. 接手後先做什麼

**目前優先入口：**先讀 [v0.20 試玩說明](docs/development/nana-v0.20-practice.md)、D1 三份文件及[最新回饋](docs/design/poc-feedback-and-followups.md)。使用者已授權開始實作；優先收集 R1 真正遊玩的手感、取捨及重玩感受。v0.19 規則以其歷史文件為準，不拿新版數值解讀舊 APK。

1. 試玩首局、自然決定是否換裝再出發；觀察戰鬥是否需要判斷、至少兩次升級取捨及取得裝備後的自主目標。
2. 核對手機安裝更新、雙手操作、切背景與存檔；本機 adb 沒有偵測到裝置。iOS 的早期檢查因只有 Command Line Tools、沒有可用 Xcode 而阻塞。
3. 固定控制器在三個起手各跑一次，戰鬥時間約 148–165 秒、瞬間瞄準且跳過獎勵，不代表真人；與 8–10 分鐘設計假設差距大，是要請玩家觀察的節奏風險。
4. 用 `git log -1` 和 `git status --short --branch` 確認目前提交與工作樹；APK 路徑與雜湊見 [建置收據](tools/android-build.json)。

**授權與範圍：**使用者已確認 D1 後說「好 開始實作」；本輪完成首章 R1 可玩包，不宣稱 R2／R3 或商店發布完成。依已確認計畫先實玩並修正 R1，再推進其餘首發工作。

## 2. 已確認的方向與合作方式

- 第一版聚焦一位角色：家中寵物黑貓「奈奈」。抓、咬是特色來源，也容許爪影等誇張延伸；保留其他角色擴充空間。
- 手機橫向雙手操作，左移動、右瞄準並持續攻擊；必須有可主動釋放、帶冷卻的大絕。
- 追求構築選擇、持續清怪與可感覺的成長。正式美術、故事、其他角色及周邊系統排在核心機制之後。
- 使用者負責 review、方向決策與實玩回饋；Codex 負責調查、完整提案、細節、實作和開發驗證。
- 已核准並實作 v0.10 構築實驗；固定兩條專精不是不可變動的產品承諾。現有模式的正式替代方案仍待試玩決定。

## 3. 最新試玩回饋與研究判斷

| 使用者回饋／問題 | 接手時如何理解 |
| --- | --- |
| 11/15 v0.12 三連戰：不想換能力、幾乎沒用大絕，B＋C 不直觀；B 方式可接受 | 已依討論調整 v0.13，使用者其後已試玩並提出 A／B 路線與厚血追兵的想法 |
| 11/15 v0.10 在 Android 手機「目前測試起來體感ok」 | 已有 v0.10 手機試玩的正向整體回饋；v0.11 的能力差異與效能仍待對照 |
| 11/15 追加：B 要走位、停手換爆發；A 遠距不明顯；不確定重擊會咬誰，也考慮自動選敵 | B 已有可描述的節奏差異；A 尚不能分清提示與收益問題。原文選敵段仍稱 A，先按共用重咬問題記錄，不推定為 C 回饋；後續已同意有限度選敵輔助，詳見回饋紀錄與 v0.11 說明 |
| 普通範圍／傷害升級也能改強，早期專精差異不明顯 | 專精應改變行為、節奏或選敵；不能只靠名稱與倍率 |
| 怪多時大範圍多點較爽，成長挑戰前版不夠密集 | v0.9 已增加分批生成；密度不是唯一壓力指標 |
| v0.9 成長模式後期還可以，同密度比較單點較吃力 | 保留正向後期回饋；仍需檢查前段、清路與單體收益，不能宣稱平衡已通過 |
| 能否借 Balatro，依每局隨機得到的機會選擇攻擊方式？ | 使用者提出新設計問題，並未指定必須沿用成長模式或固定專精 |

v0.9 回饋未提供比較的是狩獵原版、快攻或重擊，也未完整提供設備、升級選擇與擊殺／受傷量測；保留這些未知。

研究建議以可理解的隨機機會支援投入、保持彈性或付出代價轉向；能力圍繞命中、連擊、移動、重咬和擊殺形成組合。v0.20 R1 已加入受限候選與有限刷新，完整 24 天賦池仍待 R2；先依實玩確認成長與構築回報。

11/15 流程 review 曾將實驗順序細分：先驗證自由搭配的能力差異，再評估三連戰的段間選擇，之後研究受限隨機與整局節奏。三連戰已在 v0.12 作為固定選擇試驗交付；v0.17 已把小範圍受限選擇接入短局，完整隨機構築仍待後續試玩決策。

這仍是推薦，沒有已定案的牌池、卡片名稱、機率、經濟或技能樹。第一次實驗宜共用目前角色與敵人；比較隨機／可規劃選擇時，兩邊使用同樣能力和遭遇，避免把新增招式的效果誤當隨機性的效果。

## 4. 已實作範圍

- v0.20／D1 R1：首章九戰、三核心六成形、15 天賦、六寶物、六事件、兩精英與一守關者、輔助、定向尋寶、練習、存檔與續玩；入口 [r1_main.gd](game/scripts/r1_main.gd)、[r1_expedition.gd](game/scripts/r1_expedition.gd)。首章沿用同一基本開闊場地，EV03 守關招式以文字預覽，並非完整首發的多張場地與動畫示範。

- v0.17：四段短局接回經驗拾取、受限選項與三級核心，守關者血量觸發支援；[試玩說明](docs/development/nana-v0.17-practice.md)。

- v0.16：加入疾追者，保留普通追兵，在四段從不同方向排入；B 和大絕能推開疾追者。[規則和驗證](docs/development/nana-v0.16-practice.md)。

- v0.15：調整四段敵人排程、提早精英登場、加入收招空檔提示；[規則和驗證](docs/development/nana-v0.15-practice.md)。

- v0.14：四段森林短局、三次段間選擇、厚血追兵、現有精英終戰與整局結算；[規則和驗證](docs/development/nana-v0.14-practice.md)。

- v0.13：E1／E2／E3 壓力排程；C 永久獵痕、B＋C 蓄勢命中獵痕後為下一次重咬蓄滿；三連戰每段後發展／加裝，兩格已滿也可替換。A Lv.2 前後爪影，B Lv.2 推開非獵痕目標，C Lv.2 兌現波及附近敵人；詳細邊界與代價見試玩說明。大絕規則及段間回血 25 保留。

- v0.12：固定三段與已知下一段威脅；段間回復 25、能力新增／替換、生命／大絕／保留能力進度跨段延續。死亡／逾時結束本輪，重試從第一段開始；每段紀錄共用 series_id，終段含全程摘要。

- v0.11：重咬預覽顯示已鎖定目標，加入有限特殊敵人偏好與選敵穩定；A 改為 340 × 90 長條、維持 8 傷害並加強特效；E3 精英生命調為 320。單 B 在固定控制器的 E3 失敗；使用者其後表示符合預期，完整平衡及效能紀錄仍未取得。

- v0.10：新增三種可選能力及三種固定事件實驗情境、重咬預計目標、行為事件紀錄與結果重試；基礎／單能力／兩兩組合均可選，最多裝兩個。E1／E2 已根據受控探針調整節奏；Android 首輪整體手感獲正向回饋，能力間的行為差異仍待比較。

- 奈奈：移動中扇形爪擊，命中蓄三格後追加重咬；大絕夜影解放為啟動衝擊、短暫保護與六秒增距／增傷，冷卻 40 秒。
- 敵人：追逐、衝撞、投擲、守衛與雙段攻擊精英；有預警、收招、特殊威脅並發限制。
- 成長挑戰：四分鐘，拾經驗升級；Lv.4 起固定提供掃群／狩獵選擇。時間到仍需精英已擊敗才成功。精英從 150 秒開始排入。
- 新怪潮：普通怪分批生成、短暫減量、安全取消後重試並重新完整預警；45 容量包含在場、預警與重試。經驗同步調整。
- 怪潮／狩獵比較：固定能力、生存 90 秒；原密度／新怪潮，掃群／狩獵原版／快攻／重擊。狩獵爪擊分別為 14/0.42 秒、14/0.28 秒、21/0.42 秒；成長採快攻。
- 主畫面已移除舊角色及成長、專精、怪潮比較等入口與專用 UI；相關底層規則仍供歷史探針使用，原 v0.9 版本可由 Git 歷史取得。

首章已有九戰與守關者、有限隨機構築；設計目標局長及更多章節、敵人與其他首發內容仍待驗證或實作。

## 5. 接手時要留意的設計與規格落差

1. 狩獵把原本的多目標爪擊改為單點，同時失去部分清群與多目標擊退收益；共享大絕不一定足以支付冷卻期間的清路需求。
2. 90 秒怪潮比較測不到 150 秒精英；守衛到 80 秒才加入隨機候選。它不足以單獨驗證整局取捨。
3. 同種子不代表完全同遭遇；走位、安全取消、擊殺與容量會改變生成及亂數消耗。原密度與新版還有特殊敵人排程差異。
4. 狩獵依瞄準中心線選敵，同角度再取近者；標記沒有持續鎖定功能。對強敵的紙面收益需要能可靠交付到該目標。
5. 快攻傷害在取得兩次強健後跨過普通追逐者的一擊門檻，可能解釋成長後期改善，尚未確認使用者那局選擇。
6. 草案提出精英登場暫停普通守衛補充；現行怪潮排程並未據精英在場排除 guard。後續設計時應明確決定處理。
7. 隨機性需要基本可用的戰鬥與可組合規則；只把專精變成隨機掉落可能增加等待。以有利、普通、不合拍的候選序列檢查，並保留玩家拒絕與轉向的選擇。

## 6. 程式與研究入口

| 工作內容 | 檔案 |
| --- | --- |
| v0.20 首章入口、遠征、成長與收藏 | [r1_main.gd](game/scripts/r1_main.gd)、[r1_expedition.gd](game/scripts/r1_expedition.gd)、[r1_growth.gd](game/scripts/r1_growth.gd)、[r1_profile.gd](game/scripts/r1_profile.gd) |
| v0.20 波次、敵人與戰鬥 | [r1_waves.gd](game/scripts/r1_waves.gd)、[r1_encounters.gd](game/scripts/r1_encounters.gd)、[r1_combat.gd](game/scripts/r1_combat.gd) |
| 角色攻擊、連段、重咬、大絕 | [nana_combat.gd](game/scripts/nana_combat.gd) |
| 敵人 AI、固定情境、新舊怪潮 | [nana_encounters.gd](game/scripts/nana_encounters.gd) |
| 構築實驗固定事件、取樣與紀錄 | [nana_experiment.gd](game/scripts/nana_experiment.gd) |
| 場次、升級池、經驗、勝敗、亂數 | [run_model.gd](game/scripts/run_model.gd) |
| 輸入、選單、HUD、構築實驗入口 | [main.gd](game/scripts/main.gd) |
| 扇形／長條與圓碰撞 | [combat_geometry.gd](game/scripts/combat_geometry.gd) |
| 規則與實際場景流程 | [run_tests.gd](game/tests/run_tests.gd)、[scene_flow.gd](game/tests/scene_flow.gd) |
| Balatro 作者與官方原文 | [來源研究](docs/research/balatro-randomness-primary-sources-2026-11-14.md) |
| 同類遊戲主攻、輔助與選敵 | [戰鬥架構研究](docs/research/survivors-combat-architecture-audit-2026-11-14.md) |
| 壓力與專精的先前官方案例 | [節奏](docs/research/enemy-density-pacing-sources-2026-11-14.md)、[分層改造](docs/research/nana-specialization-research-2026-11-14.md) |

歷史完整草案見 [戰鬥設計 v1.1](docs/design/nana-combat-design-v1.md)，後續研究與現行程式優先於其中尚未同步的提案數字／進度。美術研究 [game-visual-toolchain](docs/research/game-visual-toolchain-2026-11-14.md) 一併保存，待核心完成後再啟用。

## 7. 執行與驗證

Godot 4.7.2 標準版、GDScript；同一台 Mac 執行 `./Play.command`，或以 Godot 開啟 `game/project.godot`。引擎預設 `/Applications/Godot.app/Contents/MacOS/Godot`；不同環境用 `BRAMBLE_GODOT_BIN` 指定。詳見 [開發環境](docs/development/getting-started.md)。

```sh
bash scripts/test-game.sh
python3 -B scripts/verify-packaged-nana.py
```

v0.20 完整測試包含舊版 377 項回歸、R1 九節點受控流程、80 組各十次成長選擇、成形／事件／存檔以及場景流程；最新精確數量見 [v0.20 試玩說明](docs/development/nana-v0.20-practice.md)。測試專用無敵和自動輸入不在正式遊戲中，也不代表樂趣、真人勝率或手機效能已驗證。

設計盤點另有 [受控靶群探針](scripts/research/probe-nana-design-audit.gd)：固定靶、完美瞄準、無敵人反擊；只能說明當時攻擊規則的差異。其他 `scripts/research/probe-*` 有歷史版本界線，先讀註解再解讀輸出。

## 8. APK、儲存與版本管理

最新 Android 建置為 v0.20.0／versionCode 20、ARM64 debug；獨立簽章、Manifest、啟動畫面打包、封裝後 R1 規則與存檔均已驗證。保留 v0.19 相同 package 與簽章；手機實際更新與舊資料遷移尚未實機驗證。v0.19 APK 保留於同目錄。

APK 仍在本機核准 SSD，並未隨 Git push；確切位置、大小與 SHA-256 以 [tools/android-build.json](tools/android-build.json) 為準，安裝方式見 [Android 安裝說明](docs/development/android-install.md)。SDK、競品原始包、擷取大量資料與私鑰亦不在 Git。

本 Mac 的大量資料目的地透過 `/Users/junming/AI-Setup/storage/storagectl.py path artifacts --project codex/RPG_Game_Dev` 驗證；大型下載、歷史備份等寫入前讀 `/Users/junming/AI/workspace/STORAGE-POLICY.md`。原始碼與小報告留內部磁碟，簽署金鑰保留本機，依 [repository 收錄規則](docs/development/repository-layout.md) 管理。

`skills-lock.json` 保存使用者加入的三個 skill 來源；`.agents/` 安裝本身被忽略。新環境未必具備相同 skills 或 Mac／SSD 工具；先確認可用環境，不把歷史絕對路徑當作雲端附件。

Git HTTPS CLI 在本次交接環境沒有登入；已連接的 GitHub 工具可存取此私人 repository。推送採 GitHub Git data API 的 tree／commit／非強制 ref 更新，並核對本地與遠端提交；沒有改寫遠端既有歷史或擴大可見性。後續使用 Git CLI 前需確認該 session 自己的驗證方式。

## 9. 新 session 可直接使用的起始訊息

> 請先讀 HANDOFF.md、docs/development/nana-v0.20-practice.md 與 D1 三份設計文件。使用者已確認開始實作；v0.20 是 R1 首章循環試玩版，先依手機實玩回饋修正節奏、構築及重玩動機，之後按既定計畫完成 R2 首發內容與 R3 發布候選。不要把受控探針當玩家體感或商店驗收。
