# Brotato 與 20 Minutes Till Dawn：機制設計研究與來源

查核日期：2026-11-13。目的是研究「低操作負擔、清怪爽感、構築深度與重玩動機」，不包含新遊戲原型或第一版方向。本輪未安裝或實際遊玩；以下分別標示官方事實、包內資料與設計推論。下載級距是 Android 商店累計下限，不是活躍玩家或留存率。

## 版本邊界

| 研究對象 | 本機分析包／官方產品 | 可套用範圍 |
| --- | --- | --- |
| Brotato 手機免費版 | `com.brotato.shooting.survivors.action.roguelike`，本機 1.3.932 | 先前 APK 靜態分析、免費版 Google Play 說明。官方頁標示含廣告與內購、1,000 萬以上下載。 |
| Brotato: Premium 手機版 | `com.brotato.shooting.survivors.games.paid.android` | 另一個付費產品；官方頁標示 100 萬以上下載，本機未分析其套件。不能以免費版下載量稱作 Premium 下載量。 |
| Brotato PC | Steam app 1942280 | PC 商店與 PC 官方更新；與手機的同步情況未驗證。 |
| 20 Minutes Till Dawn 手機免費版 | `com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp`，本機 8.7 | 先前靜態分析與該免費版商店；官方頁標示含廣告與內購、500 萬以上下載。 |
| 20 Minutes Till Dawn 手機付費版／PC | Android `.gp` 與 Steam app 1966900 | 與手機免費版分開。開發者置頂文明確列出不同 package；2022 年對付費版「無廣告、無內購」的說明屬當時資訊，不推定為 2026 年全版本商業規則。 |

版本及下載來源：[Brotato 免費版](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.action.roguelike)、[Brotato Premium](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.games.paid.android)、[20 Minutes 手機免費版](https://play.google.com/store/apps/details?id=com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp)、[開發者：20 Minutes 手機版本辨識](https://steamcommunity.com/app/1966900/discussions/0/3433453222979994542/)。本機版本及取證界線見 [Android 資料研究](competitive-apk-game-data-analysis.md)。

## Brotato：戰鬥操作簡化，決策集中在波次之間

### 操作、局內循環與節奏

**官方事實。** PC 與兩款手機商店都描述預設自動開火，可切換手動瞄準，同時持有最多六把武器。PC 說明的波次長度為 20–90 秒，波次之間以材料取得商店物品；單局標示少於 30 分鐘。Premium 手機頁另寫單局約 20–30 分鐘，這是整局宣稱，不能與單波秒數混為一談。[PC 商店](https://store.steampowered.com/app/1942280/Brotato/)、[Premium 手機商店](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.games.paid.android)

**設計推論。** 這個結構形成「移動與生存 → 收集材料 → 離開即時壓力作選擇 → 用下一波驗證構築」的循環。戰鬥時不必為每把武器分配按鍵，降低輸入複雜度；商店階段仍可能有較高閱讀與計算負擔。因此它符合「操作簡單」，不等於全程不需思考。波次把壓力切成短段，也讓每次補強有很近的驗證點。此處是對上述規則的設計解讀，未測量玩家實際心流或決策時間。

### 構築的深度：六把武器不是六次重複輸入

**官方事實與包內證據。** 官方將角色特性、物品與武器組合列為核心內容。本機免費版 `Hero` 表有可用武器、推薦屬性、`wantedTags`、`banned_items`、`banned_item_groups`；武器表包含不同傷害比例、射程、暴擊、穿透、彈跳等欄位。這支持角色、武器與道具並非彼此獨立的外觀選項，但尚未驗證推薦標籤是否直接影響商店抽選。包內 ID 10001 的 `banned_item_groups` 填有 `ranged_damage`，可作具體追查入口；不把它直接解讀成所有版本某角色的完整禁用規則。[Brotato 免費版官方玩法](https://play.google.com/store/apps/details?id=com.brotato.shooting.survivors.action.roguelike)、[本機資料與提取範圍](competitive-apk-game-data-analysis.md)

**設計推論。** 角色限制會改變物品的相對價值：一項對泛用角色有價值的屬性，對特定路線可能沒有幫助；同一把武器若依不同屬性成長，也會引導不同採購方向。深度來自「這次條件下什麼有用」，不只來自物品數量。六個武器位置還構成容量限制，令擴展攻擊組合與強化既有組合具有機會成本。確切合併、轉售、商店鎖定與刷新成本，本輪未由手機免費版執行證據確認，不列數值公式。

**官方事實，僅限 PC：重抽有價格，鎖定讓玩家保留目標。** PC 1.1.7.1 調整重抽價格；0.6.1.6 修正「回收武器後材料足夠，重抽按鈕仍顯示紅色」的問題；New Dawn 更新明列商店鎖定、封鎖與重抽快捷鍵。這些正式公告可交叉確認 PC 的重抽、材料與回收操作有資源關聯，不需只憑玩家攻略推定。[1.1.7.1 官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1783872411982114)、[0.6.1.6 官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/4980448574116090798)、[New Dawn 官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1814309641572669)

**設計推論。** 付費重抽讓「把現在可用的物品買下」與「花資源找更合適的物品」直接競爭。它給玩家修正隨機結果的能力，代價是少買一次即時戰力；鎖定則允許延後購買，減少看到好物卻付不起的純挫折。這些控制讓商店既是隨機輸入，又包含主動篩選。結果可能是成功湊齊路線的爽感，也可能是反覆刷新仍未出現的挫折，不能把重抽機制本身當成已證明好玩的原因。

**官方事實與設計推論，僅限 PC。** 1.1.4.0 明列不適用當前角色的物品不再出現，例如 Golem 的治療物品；公告稱全局移除 141 個不合用的物品選項。這顯示設計者也在維護「選項有意義」而非只維護數量。相同更新讓重抽更便宜，兩者合起來降低「沒有決定可做，只能接受廢選項」的機率；這是機制上的預期作用，未測得實際留存差異。[PC 1.1.4.0 官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212245217911987747)

### 爽感來源與壓力安排

**設計推論。** 多武器同時輸出讓攻擊規模的增加容易被看見；穿透、彈跳、範圍等行為差異，理論上能改變清怪覆蓋，而不只是單體數字變大。材料又把清怪結果帶回下一次購物，因此短時間戰鬥表現會影響後續成長機會。這個循環可能產生滾雪球，也可能在輸出不足時惡化；本輪沒有數據可證明它的強度或各波的精確難度曲線。依據為前述官方循環與免費版武器表，並非實玩觀察。

**官方更新的具體例子，僅限 PC。** 2026 年《Primal Dread》引入 Evolution：Mecha 路線強化武器，但會面對具新攻擊的機械敵人；Mutation 可隨機複製物品效果，同時改變敵人與場地危險。這是把玩家獎勵與敵方風險綁在同一選擇上的實例。不能假設本機手機免費版 1.3.932 也有相同內容。[PC 官方 Primal Dread 更新](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847920302249177)

### 局外目標與耐玩性

**官方事實，僅限 PC。** 2026 年的 All Pain No Gain 更新加入 Nightmare：官方正式版公告要求在 Danger 5 以不同角色或地圖取得 10 次勝利；通關 Nightmare 解鎖 Wounded，再用 Wounded 通關可解鎖 Rail Gun。這提供「掌握多種角色 → 更高挑戰 → 新角色 → 新武器」的具體重玩鏈，而不必把重玩等同於反覆提高永久攻擊力。[PC 官方公告，Steam 官方新聞入口](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1832065502824117)

**設計推論與未知。** 上述 PC 鏈以不同限制和難度構成精熟目標；角色、武器、地圖形成可重新組合的內容。免費手機版的廣告、內購、復活及角色強化則必須獨立研究：包內 `revive_buffs`、`vip_revive_buffs`、`buffGroups` 只是存在證據，尚未確認現行介面、取得成本與適用模式。因此本報告不聲稱免費手機版與 PC 的局外成長相同，也不把「無永久數值成長」寫成所有 Brotato 版本的共同規則。[本機 Hero／Item 資料界線](competitive-apk-game-data-analysis.md)

## 20 Minutes Till Dawn：以射擊行為和狀態連動形成構築

### 操作與局內循環

**官方事實。** PC 商店強調方向瞄準與主動射擊、局內升級、Boss 掉落 Tomes，以及約 10–20 分鐘的局長；局外以 Souls 強化 Runes 並解鎖角色與武器。手機免費版同樣宣傳 10–20 分鐘、符文與不同角色武器，但未在頁面確定所有操作選項，因此不把 PC 的輸入方案直接寫成手機版控制規格。[PC 商店](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/)、[手機免費版商店](https://play.google.com/store/apps/details?id=com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp)

**設計推論。** 相較於 Brotato 波次與商店的切換，此作的成長重心較接近「持續射擊與走位 → 選擇升級 → 射擊行為產生連動 → 面對 Boss／較高壓力」。主動瞄準使玩家能把輸出集中在特定方向，但也提高注意力要求。不能只因它屬割草類就評為最低操作負擔；需要在指定手機版本確認是否有自動瞄準、如何切換及換彈控制。

### 不只是傷害加成：升級可以改變觸發事件

**官方版本實例，PC 1.0 公告。** 玩家在一局達到 20 級時，該武器可選三種變體之一；Watering Gun 以澆灌召喚物使其發射孢子，Salvo Knives 以移動標記敵人再發射飛刀。公告同時列出冰凍、擊殺、彈藥返還、Soul Heart 數量與子彈傷害的聯動，以及 Mini Clip 的彈匣減少／換彈速度增加取捨。這些是 2023 年公告時的規則例子，不充當本機手機 8.7 的公式。[開發者 1.0 正式公告](https://steamcommunity.com/games/1966900/announcements/detail/3675547066618941165)、[同公告的 Steam 官方 API](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1966900&count=100&maxlength=0)

**包內證據，手機免費版 8.7。** 已提取在地化有換彈與燃燒文字；metadata 有 `DamageBoostAgainstFrozen`、`DamageOnFreeze`、`ApplyBurnEqualToBulletDamageAction` 等類別。它們與官方描述的狀態構築方向一致，但不能據此認定 PC 1.0 的數值在手機 8.7 全部成立。[本機靜態取證與限制](competitive-apk-game-data-analysis.md)

**設計推論。** 這種設計讓攻速、彈匣、換彈、狀態與召喚物的價值互相依賴：提高某個事件的發生次數，可能同時提高附帶效果。減少彈匣若能換得更頻繁的換彈收益，也可能成為主動追求的代價。因此構築不是永遠把每項能力都往最大堆疊，而是改變「什麼事件越頻繁越好」。這是對公開例子與程式結構的機制解讀；沒有計算已驗證的最優流派。

### 隨機性何時變成阻力：開發者對設計問題的直接解釋

**開發者事實，2023 年設計討論。** Flanne 指出新增升級會稀釋升級池、令抽選變得更不可靠；同時認為遊戲仍需要一定程度的差異。這證明「內容越多」與「想要的構築能否成形」存在開發者已辨識的張力；不是玩家評論就足以證實所有人討厭隨機。[Flanne：About the Future of 20 Minutes Till Dawn](https://steamcommunity.com/app/1966900/discussions/0/3958161899230616271/)

**開發者事實，2024-10-28 測試預告，非已確認正式版。** Blessings 讓早期升級從三項祝福擇一，引導當局調整構築；Runes 重做的理由是舊系統過早決定路線，難以臨場適應。角色專精計畫讓玩家自行選三路之一，取代隨機順序的角色升級，以降低挫折。公告當時說的是封閉測試及即將公開測試，本輪未找到足以證明這整套規則已套用本機手機 8.7 的來源。[官方 Blessings & Curses 測試預告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212245217911959733)

**設計推論。** 兩份官方說明一起揭露一個具體問題：局外選擇太固定，局內會變成等指定零件；局內抽選太分散，則可能沒有足夠時間完成組合。祝福／專精的設計意圖，是保留每局不同，又增加玩家能順應當局條件的決定權。這是設計意圖與推論，並非改版後留存改善的實證。

### 爽感、失敗代價與再開一局

**官方事實與推論。** 官方手機示例把霰彈槍與點燃、飛刀與穿透結合，顯示主武器可成為不同表現的載體；PC Souls／Runes 明確提供跨局強化。由此可推論，當局能看到攻擊行為改變，死亡後又仍有可購買的跨局目標，可能同時支撐短期回饋與下一局動機。不過本輪未確認手機 8.7 Souls 的實際結算、失敗時保留比例、角色取得與付費差異，也未測得幾分鐘形成爽感。[手機官方構築示例](https://play.google.com/store/apps/details?id=com.Flanne.MinutesTillDawn.roguelike.shooting.fr.gp)、[PC 官方跨局成長](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/)

## 兩款的設計差異與研究結論

下表是根據以上證據所作的設計歸納，不是實玩評分，也不代表各平台全部版本一致。

| 面向 | Brotato | 20 Minutes Till Dawn |
| --- | --- | --- |
| 操作簡化位置 | 自動開火，主要注意移動；可選手動瞄準 | PC 保留主動瞄準／射擊，手機操作選項待確認 |
| 思考重心 | 角色限制、武器位置、商店購買與屬性投資 | 射擊事件、狀態效果、升級組合與角色武器互動 |
| 成長回饋節點 | 每次波次後可購物，再進下一波驗證 | 局內升級與 Boss 掉落；PC 1.0 在玩家局內達 20 級時提供武器變體 |
| 典型機會成本 | 有限武器容量與有限材料，角色改變屬性價值 | 升級機會有限，彈匣／換彈等能力可能互相取捨 |
| 重玩來源 | 角色規則、配置、難度與挑戰解鎖；免費手機成長另查 | 角色×武器×升級組合，加上 PC 已確認的符文成長 |
| 主要潛在疲勞 | 採購計算重複、單一路線過強、戰鬥輸入變化有限 | 等待關鍵升級、升級池稀釋、預選符文鎖住構築 |

「爽感」可由多武器或連鎖效果解釋，「耐玩」可由角色限制、構築差異與挑戰目標解釋；這兩者都是合理的機制假說。下載量只能說明觸及規模，不能證明哪些機制導致高下載或高留存。本輪仍缺指定手機版本的實際流程錄影、每分鐘成長／敵群壓力量測、失敗與解鎖畫面，以及留存數據。

## 可追溯資料

- 先前包內取證：[competitive-apk-game-data-analysis.md](competitive-apk-game-data-analysis.md)，原檔 hash 見 [manifest](competitive-apks-manifest.json)。
- Brotato 手機免費版提取路徑：SSD `competitive-apks-20261113/packages/com.brotato.shooting.survivors.action.roguelike/decoded-selected/`，本輪直接讀取 `Hero-5420b463.txt`、`Weapon-478dd32b.txt`、`Item_0-ed2c03f8.txt` 核對欄位，未新增大量資源輸出。
- 20 Minutes 的 1.0 公告已用 Steam 官方 `ISteamNews/GetNewsForApp` API 交叉核對全文；Steam Community 網頁文字抽取只有圖片時，不能把抽取失敗視為公告不存在。
- 網頁查核日與本機 APK 版本日不等同；商店上的現行宣稱不保證反映 APKPure 所下載的每一項行為。
