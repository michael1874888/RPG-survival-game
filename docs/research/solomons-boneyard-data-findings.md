# Solomon’s Boneyard 1.3.0（1049）：靜態資料表發現

本機證據檔案未納入 Git。本文的檔名與行號引用以 `/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/solomons-boneyard/1.3.0-1049/decoded-data/` 為原開發證據根目錄；repository 保留報告與雜湊清單，沒有將原作資料檔包入遊戲。

研究日期：2026-11-12。目標 package 為 `com.raptisoft.SB`；主代理直接讀 binary AndroidManifest 確認 version `1.3.0`、build `1049`、minSdk `31`、targetSdk `35`。本報告是對解出資料檔的唯讀分析與衍生解碼，未執行遊戲，並非 REA runtime Evidence。數值能證明資料表內寫了什麼，不能單獨證明引擎實際採用了哪些列、如何運算或使用什麼時間單位。

## 來源、解碼與可重現性

SSD 本次 artifact 根目錄：

`/Volumes/Samsung SSD 990 EVO Plus 1TB/AI-Data/Artifacts/codex/RPG_Game_Dev/solomons-boneyard/1.3.0-1049/`

- 原始解出檔：`extracted/assets/data/*.txt`，未修改。
- 衍生可讀檔：`decoded-data/*.txt`，40 份共 41,835 bytes。
- 每檔 source/derived SHA-256、candidate key、長度、行數：`decoded-data/manifest.json`（本機證據：`manifest.json`）。
- 重現工具：[`tools/research/decode_solomon_data.py`](../../tools/research/decode_solomon_data.py)，僅讀 input；要求新的 output 目錄，拒絕覆蓋。

`.txt` 副檔名不代表明文：原檔含大量控制字元。先以重複 XOR 的頻率／結構規律找出三個 key 候選，完整還原為 ASCII、CRLF 與一致欄位結構。三個 literal 也都存在 `libSB_ndk.so`：

| 範圍 | ASCII key | library file offset（十進位） |
| --- | --- | --- |
| 38 份技能資料 | `FORASUMMERSDAY` | 1192987 |
| `wave.txt` | `BEwareTheFisH` | 1222923 |
| `items.txt` | `F0rk1tA3ll` | 1207069 |

主代理以 Capstone 保存的 `native-static/native-static.json` 與 `selected-functions.asm` 提供下列靜態支持：

- **wave：** `Formations::Load`（VA `0x2337b4`）在 `0x233808/0x23380c` 將 `BEwareTheFisH` 放入 x1，`0x233814` 設 w2=0，`0x233818` 呼叫 `IOBuffer::Decrypt(char*,bool)`。
- **items：** `Stats::MakeNewStore`（VA `0x2da470`）在 `0x2da4c0/0x2da4c4` 載入 `F0rk1tA3ll`，`0x2da4d0` 呼叫同一 IOBuffer decoder。
- **兩份 buffer 的 transform：** `IOBuffer::Decrypt`（VA `0x3888ac`）的 `0x388904..0x388930` loop 是純重複 XOR，沒有相等 byte 跳過。工具對 wave/items 採此規則。
- **技能 transform：** `String::Decrypt(char*)`（VA `0x40c898`）才有「相等保留，否則 XOR」分支；`Stats::Init` 在 `0x2da040/0x2da044` 載入技能 key 並複製到 String/field。工具對技能資料採 String variant，但完整技能 loader 與資料消費者尚未追完，不能稱整條路徑已確認。

40 份資料的 ciphertext==keybyte 數皆為 0，因此兩種 transform 對這組輸入結果相同；修正逐類型規則後，decoded bytes/hash 不變，manifest 的 transform/authority 已更新。上述為靜態呼叫與指令證據，遊戲 runtime 仍未執行。


以下 `檔名:Lx` 一律指 **decoded-data 的 1-based 行號**，不是混淆原檔被文字工具誤切出的行號。

## 技能格式：顯示模板、限制／需求欄位、索引數值分離

技能檔大致由 `key=value` 組成。`TITLE*`、`DESC`、`XTRA*` 有顯示文案與 `[DAMAGE1]` 等 placeholder；`|` 出現在文案中，可能供換行使用，但顯示端尚未核對。其餘包含 `CAP`、`MAX`、`REQ*`、`XREQ*` 與 `DAMAGE1_數字` 等索引欄位。下表保留欄位原名；索引暫稱 index，尚不認定等於玩家看到的技能等級。

| 資料檔 | 原始欄位與值（選取） | 行號 | 尚不能確認 |
| --- | --- | --- | --- |
| magicmissile | `CAP=15`, `MAX=20`, `MANACOST_0=6.5` | 6–8 | CAP/MAX 的使用分支；MANACOST 是每發、每更新或其他基準 |
| magicmissile | `DAMAGE1_1=1`, `DAMAGE2_1=2`; index 19=`19,35`; index 20=`30,40` | 10,36,28–29,54–55 | 兩欄是否傷害上下界、何時抽樣、是否受抗性／裝備修正 |
| fireball | `CAP=12`, `MAX=17`, `MANACOST_0=12` | 6–8 | 上限與索引規則、資源計算方式 |
| fireball | `DAMAGE1_1=4`, `_12=50`, `_13=60`, `_17=100`, `_21=140` | 10,21–22,26,30 | 超過 MAX 的資料是否可達或僅為預留 |
| fireball | `MANAPLUS_1=0`, `_2=5`, `_3=5`, `_12=16`, `_17=34` | 32–34,43,48 | 是否直接加到基礎 MANACOST，是否有外部倍率 |
| lightning | `CAP=15`, `MAX=20`, `MANACOST_0=.25` | 5–7 | 不可把 .25 解作每秒、每幀或每 tick |
| lightning | `DAMAGE1_1=1.25`, `_15=17.5`, `_19=25.5`, `_20=30.5`, `_25=35` | 9,23,27–28,33 | 傷害頻率及是否屬持續傷害，尚未從 runtime 證實 |
| fastercaster | `CAP=4`, `MAX=9`, `REQ1=level:25`, `SPEED_1=10` 至 `_9=90` | 5–17 | `SPEED` 如何進入攻擊間隔／頻率公式，不能直接宣稱 10% 減冷卻 |
| mentalfocus | `REQ1=level:9`, `XREQ1=teleport:1` 至 `XREQ6=flashfreeze:1`, `CAP=1`, `MAX=1` | 5–13 | XREQ 是 OR、AND 或其他篩選；候選可見性和生效條件 |
| meditation | `REQ1=level:8`, `CAP=1`, `MAX=1` | 4–6 | 靜止判定、回魔分支、疊加順序 |

直接檔案：magicmissile（本機證據：`magicmissile.txt`）、fireball（本機證據：`fireball.txt`）、lightning（本機證據：`lightning.txt`）。

**值得優先追的兩個邊界。** magicmissile 在 `MANAPLUS_19=54` 後接 `MANACOST_20=57`，lightning 同樣在 index 20 從 MANAPLUS 換成 MANACOST（各自 L75–81、L53–59）。這可能是特意設計、舊資料或錯字；本次保留原樣，不能自動更名或拼成一條總耗魔公式。magicmissile 的 DAMAGE1 有 index 25，DAMAGE2 只到 20，也顯示「取最高索引就是實際上限」並不可靠。

Mental Focus 的 `XTRA1` 表示恢復速度 2X；Meditation 的描述表示靜止時回魔，`XTRA1` 表示 4X。這兩者是**顯示模板所宣稱的效果**，不是本次對倍率實作的驗證。下一步需追 `MentalFocus`／`Meditation` 的消費者，而非直接把 2 或 4 寫入我們的模擬器。mentalfocus L3–13（本機證據：`mentalfocus.txt:3`）、meditation L2–6（本機證據：`meditation.txt:2`）、fastercaster L4–17（本機證據：`fastercaster.txt:4`）。

## wave：帶下一狀態清單與 formation 的文字資料

`wave.txt` 有 33 個 `WAVE:` record，ID 包含 0–30，其中 2 與 4 各出現兩次。不可在解析時直接用單一 ID 覆寫前一筆。第一層是 `WAVE:id`，下一層含 `NEXT`、`SPAWN`、`SPAWNDELAY`、`WAVEDELAY`、`MAXENEMIES`，再以 `FORMATION` 或 `FORMATION:` 分群，下一層是敵人名稱及 `|` 分隔的 flags。有的敵人行沒有冒號，或冒號後沒有 flag，解析時需容許這些原始形式。

| record 與來源 | NEXT | SPAWN | SPAWNDELAY | WAVEDELAY | MAXENEMIES |
| --- | --- | --- | --- | --- | --- |
| WAVE 0，L1–6 | `1` | `14` | `50-300` | `100-300` | `40` |
| WAVE 1，L18–23 | `1,2` | `14` | `50-150` | `100-200` | `45` |
| WAVE 4 第一筆，L105–110 | `5` | `18` | `50-150` | `50-150` | `50` |
| WAVE 4 第二筆，L124–129 | `5` | `12` | `50-150` | `20-30` | `80` |
| WAVE 24，L649–654 | `25,25,25,23` | `20` | `5-10` | `100-300` | `80` |
| WAVE 30，L770–775 | `25,24,26` | `20` | `5-10` | `100-300` | `80` |

直接來源：`wave.txt`。

可讀到的結構特徵是：NEXT 有多候選、自指與回到較小 ID；候選值也會重複。**待驗證假設：** 若載入器把這些數字當等機率陣列，重複值會形成權重；但也可能有去重或其他挑選邏輯，所以不能把 `25,25,25,23` 直接宣稱為 75%／25%。重複 WAVE ID 的選擇規則也未知。

早期 formation 以 `SKELETON` 加 `FLAG_WEAK`／`FLAG_HPDOWN`／`FLAG_SLOW` 為主（L8–17）；後段有裝備、HPUP、FAST 等組合（例如 L655–660），末筆則有 `IMP:FLAG_SPLIT`（L777）。名稱可以作敵人修飾系統的線索，但每個 flag 的實際倍率仍需 code 消費者。`SPAWN` 也不能單憑名稱確定是敵人數、群組數或抽選次數；所有 DELAY 單位未知，沒有換算為秒或推測 FPS。

## items：166 個戒指 record，效果與技能可並存

`items.txt` 有 166 個頂層 `RING` record；每筆以縮排行列出 effect、技能加值、`Rare`／`Epic` 標記與 `$數字`。原表保留重複 record、欄位大小寫與百分比。依文字統計有 27 個 `Rare`、37 個 `Epic` 標記；不是本次測出的掉落品質比率。

| 選取欄位與原始值 | 來源行號 | 可支持與尚未知 |
| --- | --- | --- |
| `Effect_RecoverMana:+5%`, `$100`，接著完全相同一筆 | 1–6 | 重複定義存在；不能推成掉落權重 |
| `Effect_UpDamage:+1`, `$300` | 59–61 | 有平加值表達；如何套到傷害未知 |
| `Effect_Updamage:+2`, `$1000` | 74–76 | 大小寫與前者不同，解析器是否忽略大小寫未知 |
| `Effect_FastCast:+10%`, `$200` | 84–86 | 施法相關 effect 與技能 SPEED 並存，疊加公式未知 |
| `Effect_UpDamage:+1`, `Effect_FastCast:+20%`, `Rare`, `$1500` | 324–328 | 一個 record 可同時含多種效果 |
| `LifeUp:+1`, `Effect_RecoverLife:+100%`, `Rare`, `$2000` | 336–340 | 技能等級型欄位與百分比 effect 可同筆出現 |
| `Effect_Updamage:+5`, `BattleMage:+1`, `Epic`, `$3000` | 471–475 | 同時有技能與一般效果，仍需實際分派器驗證 |
| `MentalFocus:+1`, `Effect_UpDamage:+3`, `Epic`, `$4000` | 601–605 | MentalFocus 可能由道具加值觸及；實際可達性未知 |
| `Effect_UpAllSkills:+2`, `Epic`, `$5000` | 632–635 | 跨技能增益欄位存在；CAP/MAX 與其互動待查 |

直接來源：`items.txt`。

`$` 值可能用在價格或估值，但單靠資料不能指定為購買價、販售價或掉落權重。檔內也沒有唯一 item ID 欄位；研究輸出應用「record 順序＋起始行號」定位，避免用效果文字去重後破壞原始池。

## 可直接帶入我們開發討論的五件事

1. **將平衡值與執行邏輯分開。** 現有檔案顯示顯示模板、索引數值、前置需求分層的可行形式。我們可以採原創 schema，明確區分基礎值、每級增量、顯示格式與實際公式，並保留來源索引。
2. **升級曲線不必單純線性。** Fireball 的選取 DAMAGE1 值及 Magic Missile 的 index 20 跳升，都能作曲線研究題。開發參考應採「設計拐點」的思想；原作哪些級數可達、是否真用此曲線仍待驗證。
3. **施法速度／資源／回復要各別驗證。** FasterCaster、戒指 FastCast、MentalFocus、Meditation 是不同資料入口；下一步優先追它們如何進同一角色狀態，避免將所有百分比當成同一乘數。
4. **波次可先建成圖與模板池。** NEXT、formation、敵人 flags 的結構可作資料編輯器設計靈感。實作前保留重複 ID／候選，不把索引直接當線性第幾波，不把 interval raw 值當秒。
5. **道具建模需支援混合效果並保留原始字面值。** 同筆可有技能＋一般效果、平加值＋百分比；讀取時記錄大小寫與重複定義，直到原作 parser 已確認後才考慮正規化。

下一個最小 code 研究題：確認技能表載入器如何處理 `CAP/MAX` 與 `MANAPLUS/MANACOST`，再定位 FasterCaster 與 FastCast 的消費端。第一個 runtime 研究題仍可維持固定角色／裝備的基本施放節奏；這份靜態表已提供值得比較的條件，但尚未給出經驗證的節奏或耗魔公式。
