# 簡單爽快動作 RPG／生存遊戲：熱門競品調查

**機制設計研究：** 完整的跨遊戲比較與具體取捨案例，請見 [簡單、爽快、耐玩的機制設計比較](popular-survival-rpg-mechanics-design-report.md)。

調查日期：2026-11-13。用途：調查與 Solomon’s Boneyard 類似的熱門遊戲，整理其玩法機制、公開規格與人氣資料。

## 判準與限制

- 「熱門」先統一採 **Google Play 單一 Android 商品頁顯示的累計下載級距**，此次納入至少 500 萬次的候選，另列付費版對照。數字來自當日查閱的頁面，會變動；不同地區頁面可能顯示不同資訊。
- 這是方便交叉比較的下限，不是精確下載數、玩家數、近期活躍、收入、留存、品質或目前排行榜；同級距不能互相排名。Android 也不代表 iOS、PC、主機全部表現；不同 App 版本不可直接合併或推測不重複玩家。
- 篩選依俯視角戰鬥、少操作、敵群、隨機成長等與目標相符程度；屬目的性樣本，非完整市場排行榜。受限於公開材料，本次未安裝實玩，也沒有存檔／留存數據。資料為發行商提供之商店敘述，可能有宣傳性；可玩性、耐玩性與相似度是設計判斷而非量測結果。
- 比較基準見專案既有 [Solomon’s Boneyard 核心規格](../design/solomons-boneyard-core-reference.md)：雙搖桿、魔法攻擊、升級與局外成長；部分原作規則仍待 runtime 驗證。

## 候選比較

操作簡單與相似度是依公開敘述的初步估計，**不是實玩評分**。營運模式為商店標示，並不表示廣告是否強制、是否公平或無課進度如何。

| 遊戲與商店 | Android 下載級距 | 本次看到的玩法規格 | 初步適合度／差異 | 收費標示 |
| --- | ---: | --- | --- | --- |
| [Survivor.io](https://play.google.com/store/apps/details?id=com.dxx.firenow&hl=en) | 5,000 萬+ | 單手操作；官方稱同時對抗 1,000+ 敵人；隨機技能組合、不同難度關卡 | **首選**：低操作、高怪量與技能成長；需實測具體局長、攻擊方式和廣告流程 | 廣告、應用程式內購買 |
| [Brotato 免費版](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.action.roguelike&hl=en) | 1,000 萬+ | 俯視競技場、預設自動射擊、至多 6 武器、蒐集材料、角色特性與大量道具 | **首選**：將操作簡化，把選擇深度放在構築；商店與波次之間節奏值得研究 | 廣告、應用程式內購買，含隨機商品 |
| [Vampire Survivors](https://play.google.com/store/apps/details?id=com.poncle.vampiresurvivors&hl=en) | 500 萬+ | 極簡操作、存活與清群、局內選擇造成戰力成長；帶金幣進局外升級；行動版支援橫向本地 1–4 人合作 | **首選**：研究從弱到強的清怪回饋、局內與局外循環；具體升級數量和節奏需實測 | 廣告、應用程式內購買 |
| [Magic Survival](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie&hl=en) | 500 萬+ | 單手操控、用多種魔法消滅四面來敵；更新文字提及魔法、神器與協同效果 | **首選**：魔法題材與原作最接近；實際組合、升級與局長待確認 | 廣告、應用程式內購買，含隨機商品 |
| [20 Minutes Till Dawn](https://play.google.com/store/apps/details?id=com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp&hl=en) | 500 萬+ | 官方稱每局 10–20 分鐘、80+ 升級、角色／武器／符文／地圖；以升級建立不同流派 | **高**：偏射擊操作與技能組合；手動瞄準和移動端的預設方式需實測 | 廣告、應用程式內購買 |
| [Zombie Waves](https://play.google.com/store/apps/details?id=com.ddup.zombiewaves.zw&hl=en) | 1,000 萬+ | 官方列出單手、自動瞄準、每局 6–12 分鐘、100+ 技能、角色與裝備、離線獎勵 | **高**：短局、清群與成長系統值得比較；實際節奏和營運體驗需實玩 | 廣告、應用程式內購買，含隨機商品 |
| [Archero](https://play.google.com/store/apps/details?id=com.habby.archero&hl=en) | 5,000 萬+ | 單人闖關、隨機技能、死亡重來、角色升級及裝備 | **延伸參考**：研究關卡和裝備循環；非以開放場地長時間清群為主要比較重點 | 廣告、應用程式內購買，含隨機商品 |
| [Soul Knight](https://play.google.com/store/apps/details?id=com.ChillyRoom.DungeonShooter&hl=en) | 1 億+ | Roguelike 射擊、生存與地牢動作 RPG，支援 2–4 人多人模式 | **延伸參考**：研究地牢、武器與合作；機制規模較大，整體系統規模較大 | 廣告、應用程式內購買，含隨機商品 |

[Brotato: Premium](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.games.paid.android&hl=en) 是另一個獨立商品頁：**100 萬+**、標示買斷及應用程式內購買，與免費版不合併計數。它的商店明確描述：單局 20–30 分鐘、每波 20–90 秒、波次間以材料在商店購裝，預設自動射擊或手動瞄準。以上為 **Premium 版**商店規格，不能未經驗證套用到免費版、其他平台或全部模式；價格因地區及時間而異。

## 哪些機制值得拆解

以下「觀察」是各商品頁可支持的範圍；「設計解讀」與「疑問」是下一輪研究的假設，不是留存或成功原因的實證。

### 1. 怪群壓力與爽感：Survivor.io、Vampire Survivors

- **觀察**：Survivor.io 強調單手操作和大量同屏怪；Vampire Survivors 強調用局內選擇讓戰力快速成長，以及帶回金幣做下一局升級。來源：[Survivor.io](https://play.google.com/store/apps/details?id=com.dxx.firenow&hl=en)、[Vampire Survivors](https://play.google.com/store/apps/details?id=com.poncle.vampiresurvivors&hl=en)。
- **設計解讀**：玩家只負責有限操作時，敵群仍可形成「被包圍 → 撐過去 → 清出空間」的節奏；升級造成的畫面變化可能是比單純增加數字更直接的回饋。
- **待量測**：出生到第一個升級、第一次大規模清怪所需時間；每分鐘遇敵數、敵人同屏上限、幀率、傷害數字／聲音／畫面震動設定；失敗後保留哪些資產。

### 2. 局內構築：Brotato、20 Minutes Till Dawn

- **觀察**：Brotato 的六武器與角色特性可產生不同裝備配置；Premium 商店具體列出短波次、波間購物及手動／自動瞄準。20 Minutes Till Dawn 官方列出 80+ 升級，以及角色、武器和符文。來源：[Brotato 免費版](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.action.roguelike&hl=en)、[Premium](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.games.paid.android&hl=en)、[20 Minutes Till Dawn](https://play.google.com/store/apps/details?id=com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp&hl=en)。
- **設計解讀**：較少按鍵並不妨礙深度：可以把決策放在「取得什麼、放棄什麼、何時投資」。波間決策有助於把戰鬥壓力與思考時間分開，但會打斷連續爽感，取捨需測試。
- **待量測**：每次選項數／可重抽次數、升級與武器如何相互作用、每局決策次數、玩家是否看得懂效果；免費和付費版的差異。

### 3. 法術風格及操作選擇：Magic Survival、Solomon’s Boneyard

- **觀察**：Magic Survival 官方描述單手與多種魔法；商店更新提及神器、魔法及協同。既有原作研究指出 Solomon’s Boneyard 使用雙搖桿，並有不同法術與魔力維度，但部分數值和效果仍未驗證。來源：[Magic Survival](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie&hl=en)、[原作研究](../design/solomons-boneyard-core-reference.md)。
- **設計解讀**：可以保留法術之間「追蹤、爆炸、連鎖、冰凍」等可辨識差異，實驗用自動攻擊降低負擔；雙搖桿手動瞄準則保留施法技巧與緊張感。
- **待量測**：Magic Survival 精確升級與合成條件、操作實際負荷，及自動射擊是否削弱原作喜歡的瞄準樂趣。

### 4. 長期目標：Archero 與 Soul Knight

- **觀察**：Archero 列出隨機技能、地圖與裝備；Soul Knight 提到地牢與多人合作。來源：[Archero](https://play.google.com/store/apps/details?id=com.habby.archero&hl=en)、[Soul Knight](https://play.google.com/store/apps/details?id=com.ChillyRoom.DungeonShooter&hl=en)。
- **設計解讀**：新角色、地圖、裝備、挑戰或合作都可能提供重玩目標，但也增加內容、平衡、介面與測試成本；高下載無法證明其中任何單一功能帶來留存。

## 建議下一輪實玩研究

優先順序為 **Survivor.io → Vampire Survivors → Brotato 免費版與 Premium → Magic Survival → 20 Minutes Till Dawn**。先各玩新帳號至少 3 局，記錄實際版本、裝置與模式；測量局長、操作、攻擊、升級頻率、候選規則、失敗結算與首次付費／廣告介面，並保留螢幕錄影與時間戳。若要比較耐玩性，需更長期試玩與多位玩家的追蹤資料；商店級距無法代替這項證據。錄製大型媒體前，依本機儲存政策處理。
