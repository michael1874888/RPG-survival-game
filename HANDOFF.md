# RPG-survival-game：下一個 session 交接

更新：2026-11-15。開發目錄 `/Users/junming/Codex_ws/RPG_Game_Dev`；遠端私人 repository `michael1874888/RPG-survival-game`，分支 `main`。

**可玩版本為 v0.10.0，奈奈構築實驗已實作；使用者已在 Android 手機試玩，回饋整體體感 OK。** 入口與對照方式見 [v0.10 試玩說明](docs/development/nana-v0.10-practice.md)。接手時以 `git log -1 --oneline` 和 `git status --short` 區分已提交基線與本輪文件變更。

## 1. 接手後先做什麼

1. 先讀 [v0.10 試玩說明](docs/development/nana-v0.10-practice.md) 與 [構築實驗規格](docs/design/nana-build-experiment-plan.md)：A 窄長爪影、B 命中才消耗、C 扇形內黏著與第二咬兌現；三連戰後移。
2. 再讀 [隨機構築可行性分析](docs/research/random-driven-combat-mode-feasibility-2026-11-14.md) 與 [v0.9 設計重新盤點](docs/design/nana-v0.9-design-audit-2026-11-14.md)，了解研究依據與已知問題。
3. 對照現行程式與 [自動探針輸出](docs/development/build-experiment-probe-v0.10.txt)，分清楚已實作、開發端量測與玩家體感。
4. 使用者可先依試玩說明比較基礎、A／B、基礎與 C；已收到 Android 手機整體體感 OK 的回饋；接下來整理各能力是否改變打法，裝置資訊與效能紀錄待補。

**授權界線：**使用者 review 修訂後於 11/15 指示「好 開始做吧」，已授權製作本版實驗場與 Android 測試 APK。三連戰、隨機構築與完整一局仍是後續候選；本輪沒有提交或推送。

## 2. 已確認的方向與合作方式

- 第一版聚焦一位角色：家中寵物黑貓「奈奈」。抓、咬是特色來源，也容許爪影等誇張延伸；保留其他角色擴充空間。
- 手機橫向雙手操作，左移動、右瞄準並持續攻擊；必須有可主動釋放、帶冷卻的大絕。
- 追求構築選擇、持續清怪與可感覺的成長。正式美術、故事、其他角色及周邊系統排在核心機制之後。
- 使用者負責 review、方向決策與實玩回饋；Codex 負責調查、完整提案、細節、實作和開發驗證。
- 已核准並實作 v0.10 構築實驗；固定兩條專精不是不可變動的產品承諾。現有模式的正式替代方案仍待試玩決定。

## 3. 最新試玩回饋與研究判斷

| 使用者回饋／問題 | 接手時如何理解 |
| --- | --- |
| 11/15 v0.10 在 Android 手機「目前測試起來體感ok」 | 已有實際手機試玩的正向整體回饋；先保留能力與數值，各能力行為差異與效能仍待對照 |
| 普通範圍／傷害升級也能改強，早期專精差異不明顯 | 專精應改變行為、節奏或選敵；不能只靠名稱與倍率 |
| 怪多時大範圍多點較爽，成長挑戰前版不夠密集 | v0.9 已增加分批生成；密度不是唯一壓力指標 |
| v0.9 成長模式後期還可以，同密度比較單點較吃力 | 保留正向後期回饋；仍需檢查前段、清路與單體收益，不能宣稱平衡已通過 |
| 能否借 Balatro，依每局隨機得到的機會選擇攻擊方式？ | 使用者提出新設計問題，並未指定必須沿用成長模式或固定專精 |

v0.9 回饋未提供比較的是狩獵原版、快攻或重擊，也未完整提供設備、升級選擇與擊殺／受傷量測；保留這些未知。

最新研究推薦：隨機提供可理解的機會，玩家選擇投入、保持彈性或付出代價轉向；能力圍繞共用的命中、連擊、移動、重咬、擊殺等機制形成組合。先評估「分段戰鬥、段間構築」的獨立實驗規則，觀察是否真的產生不同打法，再決定整合成長模式、保留新模式或放棄。

11/15 流程 review 已將實驗順序細分：先驗證自由搭配的能力差異，再評估三連戰的段間選擇，之後才研究受限隨機與整局節奏。具體規則以 v2 修訂稿為準；上述段間構築是研究推薦，不是本版新增交付。

這仍是推薦，沒有已定案的牌池、卡片名稱、機率、經濟或技能樹。第一次實驗宜共用目前角色與敵人；比較隨機／可規劃選擇時，兩邊使用同樣能力和遭遇，避免把新增招式的效果誤當隨機性的效果。

## 4. v0.10 與 v0.9 已實作範圍

- v0.10：新增三種可選能力及三種固定事件實驗情境、重咬預計目標、行為事件紀錄與結果重試；基礎／單能力／兩兩組合均可選，最多裝兩個。E1／E2 已根據受控探針調整節奏；Android 首輪整體手感獲正向回饋，能力間的行為差異仍待比較。

- 奈奈：移動中扇形爪擊，命中蓄三格後追加重咬；大絕夜影解放為啟動衝擊、短暫保護與六秒增距／增傷，冷卻 40 秒。
- 敵人：追逐、衝撞、投擲、守衛與雙段攻擊精英；有預警、收招、特殊威脅並發限制。
- 成長挑戰：四分鐘，拾經驗升級；Lv.4 起固定提供掃群／狩獵選擇。時間到仍需精英已擊敗才成功。精英從 150 秒開始排入。
- 新怪潮：普通怪分批生成、短暫減量、安全取消後重試並重新完整預警；45 容量包含在場、預警與重試。經驗同步調整。
- 怪潮／狩獵比較：固定能力、生存 90 秒；原密度／新怪潮，掃群／狩獵原版／快攻／重擊。狩獵爪擊分別為 14/0.42 秒、14/0.28 秒、21/0.42 秒；成長採快攻。
- 主畫面已移除舊角色及成長、專精、怪潮比較等入口與專用 UI；相關底層規則仍供歷史探針使用，原 v0.9 版本可由 Git 歷史取得。

完整十分鐘、結尾 Boss、後續子分支與隨機構築模式仍未完成；草案中的這些內容不可視為目前遊戲規則。

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
| 角色攻擊、連段、重咬、大絕 | [nana_combat.gd](game/scripts/nana_combat.gd) |
| 敵人 AI、固定情境、新舊怪潮 | [nana_encounters.gd](game/scripts/nana_encounters.gd) |
| 構築實驗固定事件、取樣與紀錄 | [nana_experiment.gd](game/scripts/nana_experiment.gd) |
| 場次、升級池、經驗、勝敗、亂數 | [run_model.gd](game/scripts/run_model.gd) |
| 輸入、選單、HUD、構築實驗入口 | [main.gd](game/scripts/main.gd) |
| 扇形／圓碰撞 | [combat_geometry.gd](game/scripts/combat_geometry.gd) |
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

主畫面整理後既有規則 176 項、新實驗規則 33 項及現行場景流程 16 項，共 225 項通過；[先前 v0.10 驗證紀錄](docs/development/test-results-v0.10.txt)記錄的是整理前版本。測試專用無敵和自動輸入不在正式遊戲中，也不代表樂趣、真人勝率或手機效能已驗證。

設計盤點另有 [受控靶群探針](scripts/research/probe-nana-design-audit.gd)：固定靶、完美瞄準、無敵人反擊；只能說明當時攻擊規則的差異。其他 `scripts/research/probe-*` 有歷史版本界線，先讀註解再解讀輸出。

## 8. APK、儲存與版本管理

最新 Android 建置為 v0.10.0／versionCode 10、ARM64 debug；獨立簽章、Manifest 與封裝規則已有檢查，開發端未偵測到連線裝置；使用者已自行在 Android 手機試玩並回饋體感 OK，機型與 Android 版本未提供。原 v0.9 APK 已保留；目前 v0.10 APK 亦是主畫面整理前的建置，尚未重匯出。

APK 仍在本機核准 SSD，並未隨 Git push；確切位置、大小與 SHA-256 以 [tools/android-build.json](tools/android-build.json) 為準，安裝方式見 [Android 安裝說明](docs/development/android-install.md)。SDK、競品原始包、擷取大量資料與私鑰亦不在 Git。

本 Mac 的大量資料目的地透過 `/Users/junming/AI-Setup/storage/storagectl.py path artifacts --project codex/RPG_Game_Dev` 驗證；大型下載、歷史備份等寫入前讀 `/Users/junming/AI/workspace/STORAGE-POLICY.md`。原始碼與小報告留內部磁碟，簽署金鑰保留本機，依 [repository 收錄規則](docs/development/repository-layout.md) 管理。

`skills-lock.json` 保存使用者加入的三個 skill 來源；`.agents/` 安裝本身被忽略。新環境未必具備相同 skills 或 Mac／SSD 工具；先確認可用環境，不把歷史絕對路徑當作雲端附件。

Git HTTPS CLI 在本次交接環境沒有登入；已連接的 GitHub 工具可存取此私人 repository。推送採 GitHub Git data API 的 tree／commit／非強制 ref 更新，並核對本地與遠端提交；沒有改寫遠端既有歷史或擴大可見性。後續使用 Git CLI 前需確認該 session 自己的驗證方式。

## 9. 新 session 可直接使用的起始訊息

> 請先讀 RPG-survival-game 根目錄的 HANDOFF.md、docs/development/nana-v0.10-practice.md 與構築實驗規格。目前 v0.10 實驗場及 APK 已完成開發驗證，使用者已在 Android 手機試玩並回饋整體體感 OK。先按同情境基準與能力順序比較，整理可觀察差異及問題；三連戰與隨機構築是後續候選。
