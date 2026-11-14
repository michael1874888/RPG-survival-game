# RPG-survival-game：下一個 session 交接

更新：2026-11-14。開發目錄 `/Users/junming/Codex_ws/RPG_Game_Dev`；遠端私人 repository `michael1874888/RPG-survival-game`，分支 `main`。

**可玩版本為 v0.9.0。最新進度是完成設計盤點與 Balatro 式隨機構築研究；新模式及專精重整尚未開始實作。** 本文件隨最新程式、研究與分析一同提交；接手時以 `git log -1 --oneline` 確認所在提交。

## 1. 接手後先做什麼

1. 先讀 [隨機構築可行性分析](docs/research/random-driven-combat-mode-feasibility-2026-11-14.md)，了解使用者最新問題、模式選擇及推薦理由。
2. 再讀 [v0.9 設計重新盤點](docs/design/nana-v0.9-design-audit-2026-11-14.md)，了解清路、選敵、強敵收益與比較模式的問題。
3. 對照 [v0.9 試玩說明](docs/development/nana-v0.9-practice.md) 與現行程式，分清楚已實作和研究提案。
4. 下一個有用產出是供使用者 review 的小型實驗規格：提出如何讓隨機機會塑造奈奈的攻擊打法，包含基本能力、少量可組合規則、選擇／轉向成本及驗證方式。先討論方向，使用者確認具體範圍後再實作。

**授權界線：**使用者這輪要求先把研究、分析及最新版本 push，並交接新 session；沒有因這次 push 而批准製作隨機構築模式。前一輪訊息是「調查研究一下，我也不確定是否合適，研究完再跟我說分析結果，也有可能不是目前的成長模式，是另外一種新的模式」。

## 2. 已確認的方向與合作方式

- 第一版聚焦一位角色：家中寵物黑貓「奈奈」。抓、咬是特色來源，也容許爪影等誇張延伸；保留其他角色擴充空間。
- 手機橫向雙手操作，左移動、右瞄準並持續攻擊；必須有可主動釋放、帶冷卻的大絕。
- 追求構築選擇、持續清怪與可感覺的成長。正式美術、故事、其他角色及周邊系統排在核心機制之後。
- 使用者負責 review、方向決策與實玩回饋；Codex 負責調查、完整提案、細節、實作和開發驗證。
- 已核准的原型做到 v0.9；固定兩條專精不是不可變動的產品承諾。最新研究允許重新評估它們，尚未選定替代方案。

## 3. 最新試玩回饋與研究判斷

| 使用者回饋／問題 | 接手時如何理解 |
| --- | --- |
| 普通範圍／傷害升級也能改強，早期專精差異不明顯 | 專精應改變行為、節奏或選敵；不能只靠名稱與倍率 |
| 怪多時大範圍多點較爽，成長挑戰前版不夠密集 | v0.9 已增加分批生成；密度不是唯一壓力指標 |
| v0.9 成長模式後期還可以，同密度比較單點較吃力 | 保留正向後期回饋；仍需檢查前段、清路與單體收益，不能宣稱平衡已通過 |
| 能否借 Balatro，依每局隨機得到的機會選擇攻擊方式？ | 使用者提出新設計問題，並未指定必須沿用成長模式或固定專精 |

未提供這次比較的是狩獵原版、快攻或重擊，也未完整提供設備、升級選擇與擊殺／受傷量測；保留這些未知。

最新研究推薦：隨機提供可理解的機會，玩家選擇投入、保持彈性或付出代價轉向；能力圍繞共用的命中、連擊、移動、重咬、擊殺等機制形成組合。先評估「分段戰鬥、段間構築」的獨立實驗規則，觀察是否真的產生不同打法，再決定整合成長模式、保留新模式或放棄。

這仍是推薦，沒有已定案的牌池、卡片名稱、機率、經濟或技能樹。第一次實驗宜共用目前角色與敵人；比較隨機／可規劃選擇時，兩邊使用同樣能力和遭遇，避免把新增招式的效果誤當隨機性的效果。

## 4. v0.9 已實作範圍

- 奈奈：移動中扇形爪擊，命中蓄三格後追加重咬；大絕夜影解放為啟動衝擊、短暫保護與六秒增距／增傷，冷卻 40 秒。
- 敵人：追逐、衝撞、投擲、守衛與雙段攻擊精英；有預警、收招、特殊威脅並發限制。
- 成長挑戰：四分鐘，拾經驗升級；Lv.4 起固定提供掃群／狩獵選擇。時間到仍需精英已擊敗才成功。精英從 150 秒開始排入。
- 新怪潮：普通怪分批生成、短暫減量、安全取消後重試並重新完整預警；45 容量包含在場、預警與重試。經驗同步調整。
- 怪潮／狩獵比較：固定能力、生存 90 秒；原密度／新怪潮，掃群／狩獵原版／快攻／重擊。狩獵爪擊分別為 14/0.42 秒、14/0.28 秒、21/0.42 秒；成長採快攻。
- 舊的固定敵群專精比較、自由練習、刺蝟和小熊原型保留。

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
| 場次、升級池、經驗、勝敗、亂數 | [run_model.gd](game/scripts/run_model.gd) |
| 輸入、選單、HUD、比較入口 | [main.gd](game/scripts/main.gd) |
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

v0.9 有 176 項規則與 51 項場景檢查通過，共 227 項；交接前重新檢查的輸出保存在 [交接驗證紀錄](docs/development/test-results-v0.9-handoff-2026-11-14.txt)。測試專用無敵和自動輸入不在正式遊戲中，也不代表樂趣、真人勝率或手機效能已驗證。

設計盤點另有 [受控靶群探針](scripts/research/probe-nana-design-audit.gd)：固定靶、完美瞄準、無敵人反擊；只能說明當時攻擊規則的差異。其他 `scripts/research/probe-*` 有歷史版本界線，先讀註解再解讀輸出。

## 8. APK、儲存與版本管理

最新 Android 建置為 v0.9.0／versionCode 9、ARM64 debug；獨立簽章、Manifest 與封裝規則已有檢查，開發端尚未在 Android 手機安裝／試玩。本次交接僅對齊版本標示並重新匯出，沒有調整戰鬥規則。

APK 仍在本機核准 SSD，並未隨 Git push；確切位置、大小與 SHA-256 以 [tools/android-build.json](tools/android-build.json) 為準，安裝方式見 [Android 安裝說明](docs/development/android-install.md)。SDK、競品原始包、擷取大量資料與私鑰亦不在 Git。

本 Mac 的大量資料目的地透過 `/Users/junming/AI-Setup/storage/storagectl.py path artifacts --project codex/RPG_Game_Dev` 驗證；大型下載、歷史備份等寫入前讀 `/Users/junming/AI/workspace/STORAGE-POLICY.md`。原始碼與小報告留內部磁碟，簽署金鑰保留本機，依 [repository 收錄規則](docs/development/repository-layout.md) 管理。

`skills-lock.json` 保存使用者加入的三個 skill 來源；`.agents/` 安裝本身被忽略。新環境未必具備相同 skills 或 Mac／SSD 工具；先確認可用環境，不把歷史絕對路徑當作雲端附件。

Git HTTPS CLI 在本次交接環境沒有登入；已連接的 GitHub 工具可存取此私人 repository。推送採 GitHub Git data API 的 tree／commit／非強制 ref 更新，並核對本地與遠端提交；沒有改寫遠端既有歷史或擴大可見性。後續使用 Git CLI 前需確認該 session 自己的驗證方式。

## 9. 新 session 可直接使用的起始訊息

> 請先讀 RPG-survival-game 根目錄的 HANDOFF.md，再讀 Balatro 式隨機構築可行性與 v0.9 設計盤點。我們目前最新可玩版是 v0.9；隨機構築尚未實作。先整理一份最小實驗規格，讓每局隨機機會影響奈奈的攻擊打法，說明選擇與轉向、基本生存能力及驗證方式。我負責 review 與方向決策，確認範圍後再開始製作。
