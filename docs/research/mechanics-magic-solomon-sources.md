# Magic Survival 與 Solomon’s Boneyard：魔法生存的機制比較與證據

研究日期：2026-11-13。版本範圍：Magic Survival Android 0.9941、Solomon’s Boneyard Android 1.3.0／build 1049。本筆記補強機制設計研究，不包含本專案的開發方向或原型規格。

**證據範圍：** 本次直接閱讀 Magic Survival 已提取的繁中與部分英文 CSV、開發者的 Google Play 說明，並承接 Solomon 已有的資料與選取指令研究。沒有安裝執行遊戲、沒有實玩錄影、沒有取得留存數據。下文「文字／資料」是封包內容；「設計解讀」是研究者推論，不等於已驗證程式運算或玩家感受。

## 1. 共同題材下，玩家負擔放在不同位置

Solomon 官方明確定位雙拇指生存射擊，包含選法師、面對不死敵群、升級選技能與跨局 perks；Magic Survival 官方主打單手操作、用魔法對抗四面敵人。因此兩款能支持的比較是「雙向即時控制」與「較少輸入的魔法生存」。Magic 的本次官方文字沒有完整指定所有攻擊的自動瞄準規則，不能只據單手操作就斷言每一法術都自動鎖敵。[Solomon 官方 Google Play](https://play.google.com/store/apps/details?id=com.raptisoft.SB&hl=en_US)、[Magic 官方 Google Play](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie&hl=en)

**設計解讀：** Solomon 把走位、瞄準、魔力收支放在同一個戰鬥過程；Magic 的資料則顯示，技能選擇、特性、組合與神器可以承接大量思考負擔。操作減少之後，深度仍可來自「投入哪些成長路線」及「不同法術覆蓋哪些空間」。這只說明可研究的決策結構，沒有證明某款更好玩。

## 2. Magic Survival：升級如何改變戰鬥行為

| 機制層 | 具體資料例子 | 設計解讀與界線 |
| --- | --- | --- |
| 基本法術 | Ability ID2 火焰球描述爆炸投射體；ID7 落雷描述對附近敵人劈雷；ID10 隕石描述隨機位置落下 | 投射方向、附近選敵、隨機覆蓋是不同的空間行為；不是單純三種特效。實際命中效率仍需觀察。 |
| 逐步投資 | Ability ID1 魔力彈列最大等級 7、特性欄位值 4／7，升級字串包含增加數量與傷害；ID2 火焰球列最大等級 7，字串包含數量、傷害與面積 | 同一法術存在連續投資與階段性變化。欄位值和字串存在不等於已確認每次升級的索引、顯示順序或最終加算。 |
| 特性分岔 | Ability ID417 閃電爆炸描述擴大落雷爆炸、改為隨機位置依序生成；ID444 流星雨描述隕石數量 ×3、生成間隔減少 30%，同時傷害／面積各減少 25% | 成長能在密度、覆蓋、威力間交換，而非一律增加全部能力。 |
| 組合變形 | MagicCom ID6 邪靈方程式將火焰球改為多方向同時發射、穿透 +2、數量 ×4、傷害 ×6.66，但冷卻 ×3.3 且大爆炸特性消失 | 有更大齊射與更長空窗的交換；數字不能直接相乘成最終 DPS，因發射次數、命中、疊加與傷害公式未知。英文同 ID 也確認 Big Bang 不再生效與冷卻增加。 |
| 屬性轉換 | MagicCom ID16 等離子光線文字稱光線固定 4 個、永久持續，大小／持續轉為傷害，冷卻從 4 秒降至 1 秒的區間影響光線數 | 屬性不必只服務原本用途，變形後可轉為其他收益；精確門檻、取整與超出區間行為尚未確認。 |
| 防禦轉攻擊 | MagicCom ID18 量子爆炸（英文 Photon Explosion）稱護盾不再充電而改爆炸，每個護盾影響傷害／大小，所有魔法面積增幅又影響傷害 | 構築可能犧牲原本保命功能換清怪能力；不能把它描述成無代價附送爆炸。 |

以上定位：來源 [Ability CSV][ma] 的 `ID` 與 `효과 설명줄01..06`、[MagicCom CSV][mc] 同欄位；ID6、18 另與 [英文 MagicCom][mce] 對讀。特性欄名 `특성A레벨` 等雖含「level」，組合表實際填 371、499 等 Ability ID，故本筆記把它當 **ID 交叉索引線索**，未宣稱已完整還原解鎖條件。

### 組合有投資階段，也有有限機會

Name CSV 的 `ID001=25`／`전투 인터페이스` 文字明示，符合條件的法術在等級 **25、50、75** 時取得魔法組合次數；ID27 指引玩家到上方按鈕查看組合。Ability ID168 權能領域又描述組合次數 +1、等級上限 +1。MagicCom ID28 創造之門描述組合次數 +2、等級上限 +5，並依啟動組合增加攻擊力。**這支持「組合次數本身是一種稀缺成長資源」的設計解讀**，但不證明所有模式基礎恆為三次，亦未驗證實際消耗、額外次數上限或是否退還。[Name CSV][mn] ID25／27；[Ability CSV][ma] ID168；[MagicCom CSV][mc] ID28。

MagicCom ID60 機械降神則描述「無法再進行魔法組合」，換取等級上限 +10，以及每取得主動魔法等級的全法術強化。**設計解讀：** 這是一種鎖住未來選擇換取另一條成長路徑的承諾；資料沒有告知它在何時出現、是否可撤銷，不能當成每局固定選項。[MagicCom CSV][mc] ID60。

### 協同不只是湊滿後額外加傷害

Synergy ID28「機器人」列 `ID_01..03=215/166/52`、`개수=3`，文字稱移除 215、166 的減益。Ability ID215 等離子體描述攻擊力增幅 40%／魔法體積減少 20%；ID166 改造人描述攻擊力 +50%／生命珠無法回血。ID27「宇宙恐怖」另列 `115/195/152`，文字稱移除死靈之書、深淵的減益；其中死靈之書文字限制當前體力不超過上限 50%，換攻擊力增幅。[Synergy CSV][ms] ID27／28；[Ability CSV][ma] ID115／166／195／215。

**設計解讀：** 在組合尚未形成時承受副作用，完成關聯後消除副作用，能讓「現在承擔風險，換未來構築」成為選擇；但當前僅有需求清單與效果文字，沒有確認三項必須全部持有的程式判斷、取得順序與每局可達性，也沒有證明所有被稱為減益的效果如何計算。

## 3. 選擇控制、學派與局外成長如何連起來

Magic 的選擇控制有明確代價例子：Class ID6 魔道學者文字稱每升一級，所有魔法傷害增幅 1%，但可選魔法數量 -1，且無法法力回收；Ability ID155 幾何學稱法力回收效果固定達 100%，可用次數卻少 1。Name 有法力回收次數用盡、重新投擲與更換選項等文字。**設計解讀：** 選項數、拒絕選項的補償與重擲機會可以各自具有價值，傷害提升可能以「降低未來應變彈性」付款。基礎選項數、回收比例與重擲取得方式仍未知。[Class CSV][ml] ID6；[Ability CSV][ma] ID155；[Name CSV][mn] ID8／25／26／29 的戰鬥資訊或介面欄。

| 進度層次 | 檔內證據 | 可支持的研究結論 |
| --- | --- | --- |
| 學派偏好 | Class ID1 魔法師有魔力彈起始等級、每五級的魔力彈增傷文字；另列冷卻、數量與「所有學派均有效」加成 | 專精法術、成長被動與跨學派收集收益有不同資料入口；各色文字何時生效尚未還原。 |
| 特殊學派規則 | Class ID8 大主教按啟用護盾數增幅攻擊，並特別寫即使護盾用於魔法組合也有效 | 同一能力可參與防禦、攻擊與組合；此例也提醒不能概括所有組合都必然失去所有原功能。 |
| 實驗體 | Class ID41..65 的 `유형=실험체` 與學派分開；例如 ID44 對應雷神之鎚與落雷全學派加成 | 實驗體選擇與學派是兩個資料維度，不應合併成一份角色數。未把名稱欄當作已驗證起始神器發放。 |
| 研究 | Name ID15／`일지` 明示用金幣購研究點強化屬性；ID16 明示寶石購學派並強化能力 | 具備局外資源用途與持續投資目標的文字證據。成本與獲取速度未驗證。 |
| 究極技目標 | Name ID20／`도감` 說符合實驗體與學派、達 100 級可把組合強化為究極技；MagicCom ID1 列風暴使者、條件值 4、描述落雷瞬間劈下 | 有比基本組合更後段的目標；未完整還原條件值映射，不能據此推測每局一定能到達。 |

來源：[Class CSV][ml]、[Name CSV][mn]、[MagicCom CSV][mc]，ID 如表。

**重玩解讀：** 學派偏向、實驗體、特性選擇、組合路線與神器副作用，提供多個重新規劃的理由；研究／學派購買又把單局以外的資源變成目標。然而「組合數多」「有永久成長」不等於已證明耐玩，亦可能形成記配方、先刷資源或強勢組合收斂的負擔；本研究沒有玩家留存、掉落分布與平均解鎖時間，無法判定實際發生程度。

## 4. Solomon：深度更明顯地接到施法與資源節奏

Solomon 的四種基礎攻擊資料分別是追蹤魔法飛彈、火球、連鎖方向的閃電、冰霜噴流。火球的 Explode → Embers → Immolation 依賴文字，把濺射、命中碎片、碎片再爆炸串起來；閃電的 Chaining／Stun → Hurricane 則把擴散和控場連在一起。資料中的 REQ 與 `level:25` 只證明條件記錄存在，未完整確認多條件 AND／OR。[技能目錄](solomons-boneyard-skill-catalog.md)、[資料發現](solomons-boneyard-data-findings.md)、[核心參考第 2 節](../design/solomons-boneyard-core-reference.md)

**設計解讀：** 玩家可先熟悉一種主攻擊，再透過後續技能改變覆蓋、命中延伸與安全距離。這是一條逐步累積的行為鏈；不能把更華麗的彈幕直接當成更高有效傷害。

魔力容量 Mana Up、回復 Channel Mana、減耗 Battle Mage、射速 Faster Caster 在資料中各自獨立。Meditation 文字要求站定以換回魔，而移速、傳送、護盾、周身凍結提供不同解圍方式。Creativity 文字增加升級選項，也讓投資從本次戰力延伸至未來選擇。[核心參考第 3–4 節](../design/solomons-boneyard-core-reference.md)、[第一輪指令分析](solomons-boneyard-intake.md)

**設計解讀：** 射速與追加命中追求更強輸出，回魔與減耗支持續戰，站定回復則與逃離包圍競爭安全空間。這比單純堆傷害有更多互相牽動的問題。實際耗魔是否隨彈數增加、各效果如何相乘，仍未完整確認，不能寫成原作已驗證公式。

Solomon 波次有 formation、敵人修飾、生成間隔、波間延遲、MAXENEMIES 與可分支 NEXT。戒指可含平加值、百分比與技能加值。**設計解讀：** 變化能同時從「敵人怎麼施壓」「法師怎麼成長」「裝備補強哪一環」形成；但 33 筆波次記錄不等於 33 關、166 戒指記錄不等於 166 個唯一可取得道具。波次時間單位、分支機率及掉落規則未還原。[資料發現](solomons-boneyard-data-findings.md)、[核心參考第 5–6 節](../design/solomons-boneyard-core-reference.md)

局外成長目前由官方確認 perks 與高分榜；Android build 的死亡保留、戒指保存、perks 完整規則尚未還原。也不能從存在 `WeldSkill` 名稱就補寫合法合成配方。[官方 Google Play](https://play.google.com/store/apps/details?id=com.raptisoft.SB&hl=en_US)、[核心參考的未知項目](../design/solomons-boneyard-core-reference.md)

## 5. 壓力、爽感與耐玩的證據強度

| 設計問題 | Magic Survival | Solomon’s Boneyard | 目前能下的結論 |
| --- | --- | --- | --- |
| 為何簡單仍有深度？ | 組合機會、特性路線、神器代價、選項控制 | 瞄準與走位、魔力收支、主攻擊與功能技能 | 兩者有不同決策位置；無法量化哪一款負擔更低。 |
| 爽感如何擴大？ | 齊射、長時存在、冷卻轉光線數等行為變形 | 火球碎片爆炸鏈、連鎖與控場 | 資料支持可見行為升級；何時開始爽、密度是否遮蔽危險仍需執行觀察。 |
| 壓力如何構成？ | UnitStat 分別配置生命、移速、抗性；官方 v0.993 說新增敵人並改分布 | 生成與波間延遲、formation、敵人修飾、分支 NEXT | 有多種施壓入口；尚缺隨時間的完整敵群曲線。 |
| 為何再開一局？ | 換學派／實驗體、追組合與究極技、研究與解鎖 | 換法師／技能／戒指、perks、挑戰高分 | 有重玩目標的結構證據，沒有證明玩家實際願意重玩的留存結果。 |

Magic 壓力來源：[UnitStat CSV][mu] 的生命／移速／抗性欄；[官方更新說明](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie&hl=en) v0.993。官方同時提到已學法術更常出現在選項中，這是「減少構築落空」的設計線索；實際概率和新舊版本差距未公開。以上官網概括與更新資訊總結不超過其本文可支持的範圍。

仍缺的關鍵證據是：固定起始配置的完整單局、首次升級與各組合完成時間、低傷害／高傷害期、不同構築的對敵差異、死亡原因與結算保留。現有分析能談「機制如何創造選擇」，尚不能宣稱精確平衡已還原、每條路線有效，或某套系統已被證明耐玩。

## 6. 可重現來源索引

Magic 的 CSV 均出自使用者提供 XAPK 中主 APK 的 `assets/bin/Data/data.unity3d`，提取器 UnityPy 1.25.0。`ID`／`ID001` 是資料內鍵，非畫面等級。不同表的 0／Name／空白／反引號列及未啟用內容不能算可玩規模。原物件 path ID 與檔案 SHA-256 見 [提取 manifest][mm]；原 XAPK 版本與 hash 見 [本機清單](competitive-apks-manifest.json)。

| 代號 | CSV | TextAsset path ID | 本筆記主要定位 |
| --- | --- | ---: | --- |
| MA | [tw_Dictionary_Ability.csv][ma] | 2846 | ID1／2／7／10／115／155／166／168／195／215／371／417／444 |
| MC | [tw_Dictionary_MagicCom.csv][mc] | 2839 | ID1／2／6／16／18／28／60 |
| MS | [tw_Dictionary_Synergy.csv][ms] | 2833 | ID27／28 |
| ML | [tw_Dictionary_Class.csv][ml] | 2835 | ID1／6／8／41..65 |
| MN | [tw_Dictionary_Name.csv][mn] | 2873 | ID001=15／16／20／25／27／29，須配合欄名 |
| MU | [Dictionary_UnitStat.csv][mu] | 2854 | 最大生命、移速、抗性與特殊能力欄 |

[ma]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/tw_Dictionary_Ability.csv>
[mc]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/tw_Dictionary_MagicCom.csv>
[mce]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/eng_Dictionary_MagicCom.csv>
[ms]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/tw_Dictionary_Synergy.csv>
[ml]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/tw_Dictionary_Class.csv>
[mn]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/tw_Dictionary_Name.csv>
[mu]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/Dictionary_UnitStat.csv>
[mm]: </Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/competitive-apks-20261113/packages/com.vkslrzm.Zombie/decoded-tables/manifest.json>
