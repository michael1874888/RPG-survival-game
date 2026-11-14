# 五款熱門遊戲：Android 套件中的遊戲資料研究

**機制設計研究：** 完整的跨遊戲比較與具體取捨案例，請見 [簡單、爽快、耐玩的機制設計比較](popular-survival-rpg-mechanics-design-report.md)。

研究日期：2026-11-13。範圍為使用者下載的 Android XAPK，版本、大小、來源及 SHA-256 見 [檔案清單](competitive-apks-manifest.json)，第一輪封裝見 [封裝分析](competitive-apk-first-pass.md)。本報告研究遊戲機制與規格，不包含新遊戲的第一版設計提案。

**閱讀界線：**「資料」指封包內檔案或文字實際存在；「解讀」是對資料結構的推論。未執行遊戲，沒有確認實際載入路徑、所有解鎖條件、倍率公式、各模式差異或線上更新。遊戲內文字也可能有占位符或與實際運算不一致。這是分範圍的靜態研究，不能當成所有遊戲的完整規則或留存調查。

## 整體結果

| 遊戲及版本 | 本次進度 | 與研究目的相關的發現 |
| --- | --- | --- |
| Magic Survival 0.9941 | Unity 資源可讀；REA metadata 可讀 | 找到繁中魔法、融合、協同、職業及敵人資料，能觀察組合與成長的資料形狀。 |
| Brotato 手機免費版 1.3.932 | 主 APK 的部分 Unity 資源可讀；REA metadata 可讀 | 找到武器、角色、升級、技能與波次表，顯示角色配置、數值與波次拆成不同資料。 |
| Vampire Survivors 1.16.111 | REA metadata 可讀；部分 Unity 資源包可讀 | 掃描取得部分擴充內容資料，可觀察武器、角色、敵人、地圖與突破資料之間的 ID 關係。 |
| 20 Minutes Till Dawn 8.7 | REA metadata 與局部在地化資源可讀 | 找到和冰凍、燃燒、子彈傷害相關的類別／欄位名稱，以及兩份在地化表；公式尚未讀取。 |
| Survivor.io 5.4.0 | 資源包局部可讀；REA metadata 解析失敗 | 取得大量 TextAsset 清單，找到名為波次、技能與武器的項目，但檢視的內容不是可直接閱讀的文字表；具體規則未還原。 |

本次處理的遊戲都是手機下載版本，Brotato、20 Minutes 等與其他平台／付費版本可能有差異。包內存在擴充內容資料不代表帳號已購買、內容可解鎖，或一般玩家一定能玩到。

## Magic Survival：技能、魔法組合與協同

**資料來源與規模。** 從主 APK 的 `assets/bin/Data/data.unity3d` 以 UnityPy 1.25.0 讀出 59 個 TextAsset；其中包含 `tw_Dictionary_Ability`、`tw_Dictionary_MagicCom`、`tw_Dictionary_Synergy`、`tw_Dictionary_Class`、`Dictionary_UnitStat`。繁中及英文表與來源物件 ID、SHA-256 保存在 SSD `packages/com.vkslrzm.Zombie/decoded-tables/manifest.json`。各表中的韓文字段名稱是來源檔案的欄位名。

- 能力表共 620 筆資料列；依「數字 ID 大於 0、名稱非空或占位符」的簡單篩選，有 347 筆具名稱的記錄。這些記錄混合魔法、特性、神器、研究等，不是 347 種可同時選擇的技能。
- 魔法組合表共 999 筆資料列，依相同篩選有 63 筆具名稱記錄；協同表同樣有 63 筆具名稱記錄。其餘可能是空白或保留列；數量不能視為實際已開放內容。
- 組合表記錄名稱、類型、三個特性欄位與效果描述。例如「蒼穹之怒」的資料列描述落雷的範圍、傷害和數量變化，並填有特性欄位 `417 / 444 / 0`。能力表的同 ID 記錄分別命名為「閃電爆炸」和「流星雨」。**這是 ID 對應線索**；是否為完整合成前置條件、如何判定尚待讀取消費程式。
- 「以氣馭劍」的文字描述中，精靈的表現會受冷卻時間影響；這是將一項屬性與多項表現連結的資料例子，並未驗證計算順序或上下限。
- 職業表描述角色／學派與特定魔法、升級或加成的連結；例如「魔法師」欄位有魔力彈等級、冷卻、數量與傷害相關文字。不同顏色與欄位可能對應不同用途，尚未確認何時生效。
- 敵人資料表含攻擊、最大生命、移動速度、抗性和特殊能力等欄位，尚未確認單位、倍率或難度修正。

**分析意義。** 此版本的資料顯示出多層成長結構：基礎魔法、特性、組合、協同與職業分別有資料入口；多個系統以 ID 或文字互相指涉。它們如何影響實際重玩與留存，不能單憑表格下結論。

REA 對 metadata 的 Evidence：`ev_e9e55ce0fea2b91a0305edd36ba4226e4b858e4a00487308c08526b9cb34fb7e`；其中 `V_MagicComShow` 和 `C_Battle_EnemyUnit` 等類別及方法名稱可作追蹤入口，但名稱不是函式實作。

## Brotato：波次、武器與局內升級

在主 APK 的 `assets/bin/Data/` 中，限定掃描直接子檔、排除 `.resource`、大小 32 bytes 至 2 MiB，共檢查 3,885 個檔案並找到 812 個 TextAsset；這是掃描範圍內的物件數，不代表遊戲內容總量。其中名稱以 `skill_` 開頭者 395 筆，`Waves_` 46 筆。技能項目混合玩家、敵人與其他用途，不能直接算成 395 個可選技能。

- `Weapon` 表包含 `cd`、`damage`、`accuracy`、`critChance`、`critDamage`、`minRange/maxRange`、`piercing`、`bounce` 等欄位，並有近戰、遠程、元素、工程等比例欄位。表格可支持「武器配置分別記錄這些參數」，但目前不能從欄位名推算實際公式、時間單位與疊加順序。
- `Hero` 表包含武器清單、推薦武器／屬性、物品限制與禁用項目等欄位，提供角色如何限制或偏向不同構築的研究入口；實際生效條件未驗證。
- `Upgrade` 表中的攻速升級記錄 `tier=1, value=5` 與 `tier=2, value=10`，名稱鍵對應攻速。資料未證實 value 的最終顯示單位或加算方式。
- `Waves_2` 這份表的四個資料列依序記錄 `Time/MaxNum` 為 `15/20`、`30/60`、`40/150`、`50/250`，各列另有不同 `Groups` ID。表名與欄位支持它是波次相關配置；不能未經程式對照就把 Time 斷言為秒、MaxNum 斷言為同屏上限，或把此表套用全部模式。
- `skill_2008` 是一份結構化技能資料，帶有 ID、目標、事件清單及 `cd` 等欄位，內部標籤提及手槍；是否為特定武器在所有情境的真正冷卻仍需驗證。

REA metadata Evidence `ev_d60699bf5ec1316f01fe9ae90ffcf89bd817c1f7d1d0e017dd0df88b189563a8` 中，`WeaponData` 的欄位名與武器表有多處對應；`WavesData` 也有 `Time`、`MaxNum`、`Groups` 等欄位與存取方法。這提供表格可能被讀取的結構線索，尚不是完整讀取／運算路徑。

提取的代表檔、原 APK entry、TextAsset path ID 及 hash 見 SSD `packages/com.brotato.shooting.survivors.action.roguelike/decoded-selected/manifest.json`；完整掃描清單見同目錄 `unitypy-scan.json`。

## Vampire Survivors：擴充內容中的武器與關卡資料

對 `UnityDataAssetPack.apk` 的 `assets/aa/Android/` 下 32 bytes 至 2 MiB 的 bundle 做局部掃描：1,729 個 bundle 中找到 45 個 TextAsset。大於 2 MiB 的 bundle 與其他位置未涵蓋，因此不能用 45 推算遊戲完整資料量。可讀資料包含標記為 Foscari、Emeralds 等內容群組的角色、武器、敵人、地圖和其他表。

以 **Foscari 內容群組**為例，解碼後記錄保存在 SSD `packages/com.poncle.vampiresurvivors/decoded-selected/`：

- `weaponData_Foscari` 有 16 個頂層鍵；`SPELL_STRING` 有多筆等級資料，初始記錄包含 `power`、`interval`、`amount`、`critChance` 和 `evoSynergy` 等欄位。此項的 `evoSynergy` 指向兩個其他武器 ID，`evoInto` 指向另一 ID，顯示資料中有進化關聯；精確達成條件與數值疊加仍待驗證。
- 同一筆武器文字描述指出其傷害與速度有關；這是**顯示描述**，不能單憑此寫出倍率公式。
- `characterData_Foscari` 有 9 個頂層鍵；其中一個角色資料包含初始武器、不同等級獲得裝備的文字描述，以及不同造型可能對應的初始武器 ID。需要實測確認選擇、解鎖和模式限制。
- `stageData_Foscari` 的一筆關卡記錄帶有時間限制、敵人速度、金幣與經驗倍率等 `mods`；`enemyData_Foscari` 帶有生命、速度、攻擊和經驗等欄位。欄位單位及基礎值／模式修正的運算方式尚未確認。

REA metadata Evidence `ev_2d3aac7234475a775c04cd197e35ce5ad151bbfc898680a5ab81d58175bdc66f`；所見內容群組屬特定版本封裝，不能直接當成基本版所有內容。

## 20 Minutes Till Dawn：狀態效果與局內升級線索

在主 APK 的 Unity 小型資料檔局部掃描中檢查 1,815 個條目，找到 5 個 TextAsset，其中兩份名為 `localization`，分別有 1,114 與 847 個 CSV 列（含表頭）。兩份不是自動去重後的唯一技能清單，也未證實遊戲會在何種模式載入哪份。

繁體中文文字包含自動換彈、換彈速度，以及一個描述燃燒傷害增加 35% 的升級。這只能證明這些文字存在，不能推定它們在當前模式的解鎖與實際運算。

REA metadata Evidence `ev_982bc94109a4eb84aa7ee83eeaebdf72e59c04f535eaf3bce6c0c1f9e255ef6b` 中，找到 `DamageBoostAgainstFrozen`、`DamageOnFreeze`、`ApplyBurnEqualToBulletDamageAction` 等類別及其部分欄位。這些是「冰凍／燃燒可能參與傷害構築」的具體程式結構線索，但方法內容、觸發順序、數值和實際效果未被反編譯。

試圖以同一 XAPK 內 ARM64 `libil2cpp.so` 將方法連結到 native 位址，REA 因 module 配對存在歧義而拒絕（`code-gen-modules-not-found`，部分觀察 `ev_03650e87bc4ee4aef9652a2568645faaffee7a0be0a2bb32a1a5d9e3afad37f8`）。因此目前沒有已驗證的方法位址或公式。

## Survivor.io：資源可定位，核心內容仍未解讀

掃描 `UnityDataAssetPack.apk` 中指定範圍的 15,455 個小型資料檔，找到 3,018 個 TextAsset；名稱前綴包括 `Wave`、`Boss` 與 `Role`，並有名稱為 `Skill`、`Weapon` 和 `MonsterPressure` 的項目。

這些名稱表示有值得進一步檢查的資源；檢視過的 `Skill`、`Weapon`、`Wave_1` 內容呈現長串可列印字元，尚未辨識其編碼或格式，**不能斷定是加密，也不能讀出技能或波次內容**。同版本 `global-metadata.dat` 的標頭不被 REA 辨識，解析器回報 `unrecognized-magic`；原因未知。以上限制不表示無法分析，而是目前的工具與步驟尚未解析。

## 工具、驗證與可重現性

- 原有 REA 6.7.0 的封裝 Evidence 保留；本次為 IL2CPP 分析使用 REA 6.9.0，執行套件與可攜式 Node 24.22.1 保存在 SSD `analysis-tools/`，不覆蓋原系統 Node。Node 下載檔與 Node 官方 SHA-256 清單核對一致：`89c682593d76cd44233fa53b1563264e7de9cbb189cad169135c5b4fadfbc0a7`。
- UnityPy 1.25.0 與其依賴以專案專用路徑安裝於 SSD；Unity TextAsset 結果來自 UnityPy，不是 REA Evidence。掃描腳本：[scan_unity_textassets.py](../../scripts/research/scan_unity_textassets.py)。
- 四份可解析的 IL2CPP metadata 完整 REA Evidence 位於各 `packages/<package>/il2cpp-evidence.json`；原生二進位位址未確認。Magic Survival 的 Unity 資料表與 Brotato／Vampire／20 Minutes 代表資料檔另有 manifest 和 SHA-256。
- 掃描範圍刻意有限；檔案名稱、資料欄位與展示文字可以形成研究假設，實際遊戲機制需要對照讀取與運算程式，必要時再做合法取得的遊戲版本之執行觀察。
