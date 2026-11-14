# Solomon’s Boneyard 1.3.0（1049）：38 份技能資料目錄

本機證據檔案未納入 Git。本文的檔名與行號引用以 `/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/solomons-boneyard/1.3.0-1049/decoded-data/` 為原開發證據根目錄；repository 保留報告與雜湊清單，沒有將原作資料檔包入遊戲。

本目錄以本次 XAPK 解出的 `decoded-data` 為唯一遊戲資料來源，讀取日期 2026-11-12。解碼方法、原檔／衍生檔 hash 與證據限制見 [data-findings](solomons-boneyard-data-findings.md)。未執行遊戲或新增測試。

**閱讀界線：** id 是檔名；英文名稱來自 TITLE 欄位，中文為整理者釋意。功能分類完全由整理者依描述與依賴整理，不是已恢復的原作 type。`CAP/MAX` 只保留原始欄位，不解作自然升級／裝備上限。`REQ/XREQ` 原文完整保留；多條條件的 AND/OR、候選可見性及解鎖規則尚未驗證。索引 `_1` 等不先當成畫面等級，數值不附推測的 FPS、費率或機率。

數值欄位列出各 family 的首個非零索引項與末項（全零時首項），必要時保留額外基礎項；箭頭只表示列舉起迄，不是線性成長公式。來源欄的檔案連結指解碼檔，括號內皆為精確 1-based 行號。

## 完整目錄

| id／來源 | 顯示名稱 → 中文釋意 | 整理者分類 | CAP / MAX（行） | REQ / XREQ 原始條件（行） | 主要欄位與關鍵原始值（行） |
| --- | --- | --- | --- | --- | --- |
| acidcloud（本機證據：`acidcloud.txt:1`） | ACID RAIN → 酸雨 | 範圍主動技 | 5 (L7) / 10 (L8) | `REQ1=level:6` (L6) | `COST_1=70` (L10) → `COST_10=50` (L19); `DAMAGE_1=2` (L21) → `DAMAGE_10=20` (L30) |
| battlemage（本機證據：`battlemage.txt:1`） | BATTLE MAGE → 戰鬥法師 | 耗魔支援 | 6 (L6) / 11 (L7) | `REQ1=level:5` (L5) | `COST_1=15` (L9) → `COST_11=100` (L19) |
| callcomet（本機證據：`callcomet.txt:1`） | CALL COMET → 召喚彗星 | 範圍主動技 | 5 (L7) / 10 (L8) | `REQ1=level:6` (L6) | `COST_1=100` (L10) → `COST_10=190` (L19); `DAMAGE_1=50` (L21) → `DAMAGE_10=200` (L30) |
| chaining（本機證據：`chaining.txt:1`） | CHAINING → 連鎖 | 閃電分支 | 5 (L5) / 10 (L6) | `REQ1=lightning:1` (L7) | `MANACOST_1=.15` (L9) → `MANACOST_10=1.0` (L18); `QTY_1=1` (L20) → `QTY_10=15` (L29) |
| channelmana（本機證據：`channelmana.txt:1`） | CHANNEL MANA → 引導魔力 | 回魔支援 | 4 (L5) / 9 (L6) | 未列 | `REC_1=35` (L8) → `REC_9=320` (L16) |
| chillwind（本機證據：`chillwind.txt:1`） | CHILL WIND → 寒風 | 冰霜分支 | 5 (L5) / 10 (L6) | `REQ1=frostwail:1` (L7) | `PUSH_1=10` (L9) → `PUSH_10=100` (L18); `MANACOST_1=.1` (L20) → `MANACOST_10=.5` (L29) |
| coneofice（本機證據：`coneofice.txt:1`） | CONE OF ICE → 冰錐／擴展冰霜錐 | 冰霜分支 | 6 (L6) / 11 (L7) | `REQ1=frostwail:1` (L8) | `ANGLE_1=30` (L10) → `ANGLE_11=270` (L20); `MANACOST_1=.15` (L22) → `MANACOST_11=1.0` (L32) |
| creativity（本機證據：`creativity.txt:1`） | CREATIVITY → 創造力 | 升級選項支援 | 1 (L5) / 1 (L6) | `REQ1=level:5` (L4) | `XTRA1=CHOICES: +1` (L3) |
| embers（本機證據：`embers.txt:1`） | EMBERS → 餘燼 | 火球分支 | 5 (L6) / 10 (L7) | `REQ1=fireball:1` (L8); `REQ2=explode:1` (L9) | `DAMAGE1_1=2` (L11) → `DAMAGE1_10=15` (L20); `MANACOST_1=3` (L22) → `MANACOST_10=24` (L31); `FRAGMENTS_1=5` (L33) → `FRAGMENTS_10=15` (L42) |
| ethercharge（本機證據：`ethercharge.txt:1`） | ETHER CHARGE → 乙太充能 | 魔彈分支 | 5 (L10) / 8 (L11) | `REQ1=magicmissile:1` (L6); `REQ2=moremissiles:1` (L7); `REQ3=missilespeed:1` (L8); `REQ4=level:25` (L9) | `DAMAGE_1=10` (L13) → `DAMAGE_8=10` (L20); `CHARGES_1=1` (L22) → `CHARGES_8=8` (L29) |
| explode（本機證據：`explode.txt:1`） | EXPLODE → 爆炸 | 火球分支 | 6 (L5) / 11 (L6) | `REQ1=fireball:1` (L7) | `DAMAGE1_1=3` (L9) → `DAMAGE1_11=30` (L19); `MANACOST_1=5` (L21) → `MANACOST_12=60` (L32) |
| explosiveshield（本機證據：`explosiveshield.txt:1`） | EXPLOSIVE SHIELD → 爆裂護盾 | 護盾分支 | 4 (L7) / 8 (L8) | `REQ1=magicshield:1` (L6) | `COST_1=10` (L10) → `COST_8=51` (L17); `DAMAGE_1=5` (L19) → `DAMAGE_8=65` (L26) |
| fastercaster（本機證據：`fastercaster.txt:1`） | FASTER CASTER → 快速施法 | 攻擊節奏支援 | 4 (L5) / 9 (L6) | `REQ1=level:25` (L7) | `SPEED_1=10` (L9) → `SPEED_9=90` (L17) |
| fireball（本機證據：`fireball.txt:1`） | FIRE BALL → 火球 | 基礎攻擊候選 | 12 (L6) / 17 (L7) | 未列 | `MANACOST_0=12` (L8); `DAMAGE1_1=4` (L10) → `DAMAGE1_21=140` (L30); `MANAPLUS_2=5` (L33) → `MANAPLUS_21=42` (L52) |
| frostwail（本機證據：`frostwail.txt:1`） | FROST JET → 冰霜噴流 | 基礎攻擊候選 | 15 (L6) / 20 (L7) | 未列 | `MANACOST_0=.25` (L8) → `MANACOST_20=1.0` (L50); `DAMAGE1_0=1.25` (L9) → `DAMAGE1_20=25` (L29); `MANAPLUS_2=.1` (L32) → `MANAPLUS_19=.9` (L49) |
| harden（本機證據：`harden.txt:1`） | HARDEN → 硬化 | 冰霜分支 | 5 (L6) / 10 (L7) | `REQ1=frostwail:1` (L8); `REQ2=coneofice:1` (L9); `REQ3=chillwind:1` (L10); `REQ4=level:25` (L11) | `ARMOR_1=8` (L13) → `ARMOR_10=60` (L22); `ACAP_1=25` (L24) → `ACAP_10=300` (L33); `MANACOST_1=.1` (L35) → `MANACOST_10=1.0` (L44) |
| immolation（本機證據：`immolation.txt:1`） | IMMOLATION → 焚燒 | 火球分支 | 5 (L9) / 8 (L10) | `REQ1=fireball:1` (L5); `REQ2=explode:1` (L6); `REQ3=embers:1` (L7); `REQ4=level:25` (L8) | `DAMAGE_1=5` (L12) → `DAMAGE_8=20` (L19); `MANACOST_1=8` (L21) → `MANACOST_8=60` (L28) |
| lifeup（本機證據：`lifeup.txt:1`） | LIFE UP → 生命提升 | 容量支援 | 4 (L4) / 4 (L5) | 未列 | `LIFE_1=25` (L7) → `LIFE_4=100` (L10); `XLIFE_5=100` (L11) → `XLIFE_10=100` (L16) |
| lightning（本機證據：`lightning.txt:1`） | LIGHTNING → 閃電 | 基礎攻擊候選 | 15 (L5) / 20 (L6) | 未列 | `MANACOST_0=.25` (L7) → `MANACOST_25=1.5` (L59); `DAMAGE1_0=1` (L8) → `DAMAGE1_25=35` (L33); `MANAPLUS_2=.1` (L36) → `MANAPLUS_19=.9` (L53) |
| magiccircle（本機證據：`magiccircle.txt:1`） | MAGIC CIRCLE → 魔法陣 | 區域主動技 | 5 (L7) / 8 (L8) | `REQ1=level:3` (L6) | `COST_1=75` (L10) → `COST_8=110` (L17); `SIZE_1=1.5` (L19) → `SIZE_8=3.5` (L26) |
| magicmissile（本機證據：`magicmissile.txt:1`） | MAGIC MISSILE → 魔法飛彈 | 基礎攻擊候選 | 15 (L6) / 20 (L7) | 未列 | `MANACOST_0=6.5` (L8) → `MANACOST_25=62` (L81); `DAMAGE1_0=1` (L9) → `DAMAGE1_25=35` (L34); `DAMAGE2_0=1` (L35) → `DAMAGE2_20=40` (L55); `MANAPLUS_2=3` (L58) → `MANAPLUS_19=54` (L75) |
| magicshield（本機證據：`magicshield.txt:1`） | MAGIC SHIELD → 魔法護盾 | 防護主動技 | 4 (L7) / 9 (L8) | `REQ1=level:4` (L6) | `COST_1=80` (L10) → `COST_9=40` (L18); `ABSORB_1=25` (L20) → `ABSORB_9=450` (L28) |
| magictrap（本機證據：`magictrap.txt:1`） | MAGIC TRAP → 魔法陷阱 | 部署主動技 | 8 (L7) / 12 (L8) | `REQ1=level:6` (L6) | `COST_1=25` (L12) → `COST_12=75` (L23); `DAMAGE1_1=1` (L25) → `DAMAGE1_12=25` (L36); `DAMAGE2_1=5` (L38) → `DAMAGE2_12=60` (L49) |
| manaup（本機證據：`manaup.txt:1`） | MANA UP → 魔力提升 | 容量支援 | 4 (L4) / 4 (L5) | 未列 | `MANA_1=50` (L7) → `MANA_10=200` (L16) |
| meditation（本機證據：`meditation.txt:1`） | MEDITATION → 冥想 | 條件回魔支援 | 1 (L5) / 1 (L6) | `REQ1=level:8` (L4) | `XTRA1=RECOVER: 4X` (L3) |
| mentalfocus（本機證據：`mentalfocus.txt:1`） | MENTAL FOCUS → 精神專注 | 副技能恢復支援 | 1 (L12) / 1 (L13) | `REQ1=level:9` (L5); `XREQ1=teleport:1` (L6); `XREQ2=ringoffire:1` (L7); `XREQ3=acidcloud:1` (L8); `XREQ4=magicshield:1` (L9); `XREQ5=magiccircle:1` (L10); `XREQ6=flashfreeze:1` (L11) | `XTRA1=RECOVER: 2X` (L4) |
| missilespeed（本機證據：`missilespeed.txt:1`） | POTENT MISSILES → 強效飛彈 | 魔彈分支 | 5 (L7) / 10 (L8) | `REQ1=magicmissile:1` (L9) | `SPEED_1=10` (L11) → `SPEED_10=150` (L20); `MANACOST_1=1` (L22) → `MANACOST_10=10` (L31) |
| moremissiles（本機證據：`moremissiles.txt:1`） | MORE MISSILES → 更多飛彈 | 魔彈分支 | 7 (L6) / 12 (L7) | `REQ1=magicmissile:1` (L8) | `MANACOST_1=4` (L10) → `MANACOST_12=42` (L21); `QTY_0=1` (L22) → `QTY_12=14` (L34) |
| resist（本機證據：`resist.txt:1`） | RESIST POISON → 抗毒 | 防禦支援 | 3 (L6) / 9 (L7) | `REQ1=level:6` (L5) | `DAMAGE_1=10` (L9) → `DAMAGE_9=60` (L17) |
| ringoffire（本機證據：`ringoffire.txt:1`） | RING OF FIRE → 火焰環 | 近身範圍主動技 | 5 (L7) / 8 (L8) | `REQ1=level:3` (L6) | `COST_1=75` (L10) → `COST_8=110` (L17); `DAMAGE_1=5` (L19) → `DAMAGE_8=70` (L26) |
| ringofice（本機證據：`ringofice.txt:1`） | FLASH FREEZE → 急速冰凍 | 近身控制主動技 | 5 (L7) / 8 (L8) | `REQ1=level:3` (L6) | `COST_1=40` (L10) → `COST_8=100` (L17); `DAMAGE_1=10` (L19) → `DAMAGE_8=75` (L26) |
| rush（本機證據：`rush.txt:1`） | RUSH → 疾行 | 移動支援 | 3 (L4) / 8 (L5) | 未列 | `SPEED_1=10` (L7) → `SPEED_8=65` (L14) |
| siegemage（本機證據：`siegemage.txt:1`） | SIEGE MAGE → 攻城法師 | 傷害支援 | 4 (L5) / 9 (L6) | `REQ1=level:25` (L7) | `DAMAGE_1=25` (L9) → `DAMAGE_9=250` (L17) |
| storm（本機證據：`storm.txt:1`） | HURRICANE → 颶風 | 閃電分支 | 5 (L9) / 8 (L10) | `REQ1=lightning:1` (L5); `REQ2=chaining:1` (L6); `REQ3=stun:1` (L7); `REQ4=level:25` (L8) | `DAMAGE_1=10` (L12) → `DAMAGE_8=27` (L19); `MANACOST_1=.2` (L21) → `MANACOST_8=2.0` (L28) |
| stun（本機證據：`stun.txt:1`） | STUN → 暈眩 | 閃電分支 | 4 (L5) / 10 (L6) | `REQ1=lightning:1` (L7) | `STUNTIME_1=40` (L9) → `STUNTIME_10=100` (L18); `MANACOST_1=.1` (L20) → `MANACOST_10=.5` (L29) |
| telekinesis（本機證據：`telekinesis.txt:1`） | TELEKINESIS → 念力 | 拾取支援 | 1 (L5) / 1 (L6) | `REQ1=level:10` (L4) | `XTRA1=AREA: 4X` (L3) |
| teleport（本機證據：`teleport.txt:1`） | TELEPORT → 傳送 | 移動主動技 | 1 (L5) / 1 (L6) | `REQ1=level:3` (L4) | `COST_1=10` (L8) |
| turnundead（本機證據：`turnundead.txt:1`） | TURN UNDEAD → 驅散不死生物 | 控制主動技 | 5 (L8) / 8 (L9) | `REQ1=level:6` (L7) | `COST_1=40` (L11) → `COST_8=100` (L18); `WEAKEN_1=10` (L20) → `WEAKEN_8=60` (L27); `DAMAGE_1=8` (L29) → `DAMAGE_8=30` (L36) |

## 四種基礎攻擊與升級分支

依顯示描述與其他技能的 REQ，最清楚的四個攻擊根節點是 **magicmissile（Magic Missile）、fireball（Fire Ball）、lightning（Lightning）、frostwail（Frost Jet）**。這是資料支持的分組，並非由 runtime 確認的四個原作 type enum。特別注意 `frostwail` 的顯示名是 **Frost Jet／冰霜噴流**。

下列 `→` 表示後者資料中列出前者作 REQ，**不表示我們已確定所有必要／充分解鎖條件**：

- 魔彈：`magicmissile → moremissiles`（moremissiles L8）、`magicmissile → missilespeed`（missilespeed L9）。`ethercharge` 同時列出 `magicmissile:1`、`moremissiles:1`、`missilespeed:1`、`level:25`（L6–9）。
- 火球：`fireball → explode`（explode L7）；`embers` 列 fireball 與 explode（L8–9）；`immolation` 再列 fireball、explode、embers、level:25（L5–8）。
- 閃電：`lightning → chaining / stun`（chaining L7、stun L7）；`storm` 顯示名為 Hurricane，列 lightning、chaining、stun、level:25（L5–8）。
- 冰霜：`frostwail → coneofice / chillwind`（coneofice L8、chillwind L7）；`harden` 列 frostwail、coneofice、chillwind、level:25（L8–11）。
- 護盾：`magicshield → explosiveshield`（explosiveshield L6）。它是另一個明確技能依賴，不應硬併成四元素分支之一。

這四個高階分支分別呈現「額外最大生命削減描述／餘燼再爆炸／施放閃電時生成風暴／施放冰霜時累積護甲」的不同設計方向，不能僅憑資料認定為 Weld 或合成系統。

## 副技能恢復與回魔必須分開

**Mental Focus 恢復的是 secondary skills，而非 mana。** `mentalfocus` L3–4 的顯示描述明確指向副技能恢復，並顯示 2X；它沒有一組回魔 REC 數值表。`channelmana` L3–4 才是回魔速度增加；`meditation` L2–3 則是靜止時回魔與 4X 顯示模板。這三者應在核心規格裡分成「副技能恢復」、「一般魔力回復」、「條件魔力回復」，且倍率仍待 code／runtime 對照。

Mental Focus 的 XREQ 列 `teleport`、`ringoffire`、`acidcloud`、`magicshield`、`magiccircle`、`flashfreeze`（mentalfocus L6–11）。這是具體副技能候選線索，不等於完整副技能清單：例如 callcomet、magictrap、turnundead 雖有主動效果描述，並未出現在此 XREQ 清單。

另有名稱映射風險：檔案 `ringofice` 顯示 **Flash Freeze**（L1–2），但 Mental Focus 用 `flashfreeze:1` 作條件；檔案 `acidcloud` 顯示 **Acid Rain**。只從檔名建立 id map 可能漏掉 alias，需追原作 parser。`chaining` 與 `moremissiles` 還使用小寫 `title1/title2`；不可未確認 parser 就一律改寫原始欄位。

## 對開發規格有用的五組取捨與協同

以下是依資料／顯示描述提出的設計解讀，尚非實際強弱或最優 build 結論。

1. **覆蓋面與資源負擔。** More Missiles 的 QTY_1=2、QTY_12=14，MANACOST_1=4、_12=42（L10、21、23、34）；Chaining 的 QTY_1=1、_10=15，MANACOST_1=.15、_10=1.0（L9、18、20、29）。兩者都把「更多命中目標／發射物」與資源欄位連結，但不同基礎攻擊不可直接用表值比較耗魔效率。
2. **攻擊延伸與連鎖升級。** Fireball → Explode → Embers → Immolation 的描述分別延伸到濺射、撞擊碎片、碎片也爆炸。Embers FRAGMENTS_1=5、_10=15、MANACOST_1=3、_10=24（L22、31、33、42）；可以啟發逐步增加互動層次的技能樹，實際碎片數、疊加方式仍待驗證。
3. **範圍控制與持續防護。** Cone of Ice、Chill Wind 的描述延伸冰霜寬度／長度與擊退；Harden 又要求兩者並在射擊時增加護甲。其 ARMOR_1=8、ACAP_1=25、MANACOST_1=.1（harden L13、24、35）提供三個分開的平衡軸；即使顯示模板含 `/SEC`，本報告也未把底層 update 換算成秒。
4. **輸出速度與資源經濟。** Faster Caster 顯示攻速、Battle Mage 顯示進攻法術耗魔降低、Channel Mana 顯示回魔增加。Battle Mage COST_1=15 到 _11=100（L9–19）、Channel Mana REC_1=35 到 _9=320（L8–16），但不能推出100等於免費或多個加成可線性相加。Meditation 增添「停下來」這個位置風險條件；Rush／Teleport 則偏向移動與避險。
5. **技能品質、選項與生存。** Creativity 顯示升級多一個選項（L2–3），Telekinesis 顯示更大拾取區域（L2–3），Life Up／Mana Up 改變容量。這些可分成「決策選擇、取得資源、承受風險」三種不同成長方向，不必把所有升級都設成傷害百分比；原作的選項抽選機率與實際拾取範圍仍未知。

## 尚不能升格成核心執行規格的內容

- CAP/MAX 與裝備、自然升級、特殊技能的互動未確認；有的數值索引超過 CAP/MAX，不能截斷後宣稱有效範圍。
- Magic Missile／Lightning／Frost Jet 在高索引區從 `MANAPLUS` 換為 `MANACOST`；Life Up 出現 `XLIFE` 而 Mana Up 仍沿用 MANA（詳各檔與 data-findings）。不可直接正規化成同一條耗魔／容量公式。
- Lightning／Frost Jet 的顯示模板用 `[LIGHTNING]`，數值表用 DAMAGE1；placeholder 可能還經過顯示換算。Stun 的 STUNTIME 顯示 `%`，Flash Freeze 的 DAMAGE 顯示 `SEC`，同名／近名欄位不代表相同單位。
- `magictrap` 還含 `mCapLevel=8;`、`mMaxLevel=12;`（L9–10）；是原始檔字面值，是否被 parser 忽略、使用或另解尚未知。
- 這38份表沒有足以重建 Weld／法術融合配方與公式的完整證據；不能把 prerequisite 串列、四條高階分支或相似命名當作合成規格。
