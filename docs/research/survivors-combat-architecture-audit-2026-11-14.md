# Survivors 類戰鬥架構盤點：主攻、輔助、選敵與專精

查核日期：2026-11-14。研究範圍是奈奈 v0.9 的設計問題：是否能將「掃群」與「純單點較高輸出」視為兩個完整流派，再以相同怪潮要求兩者同樣可行。本文僅做官方資料研究，沒有安裝或實玩競品，也未修改奈奈程式。

## 結論

**官方案例支持「不同主攻有不同職責」，沒有支持「拿走清群能力，只補固定比例單體傷害，就會形成同樣完整且好玩的流派」。** Brotato 與 Vampire Survivors 明確以多武器組合構成當局能力；20 Minutes Till Dawn 即使保留主武器，也提供狀態、召喚與特殊能力；DRG:S 更直接記錄了選敵優先、方向主武器、輔助武器與地形的整體設計。

因此，較合理的比較單位是「整套能力能否處理整局必要挑戰」，再看不同主攻如何以不同效率、風險和操作完成任務。這是設計推論，並非競品已證明奈奈應採哪個數字或哪種分支。

## 證據範圍與來源

本輪先讀既有 [Brotato／20 Minutes 研究](mechanics-brotato-dawn-sources.md)、[Vampire Survivors／Survivor.io 研究](mechanics-vampire-survivorio-sources.md) 與 [專精案例研究](nana-specialization-research-2026-11-14.md)。以下只補足與本次重新盤點直接相關的戰鬥架構，不重列下載量或靜態資料。

| 編號 | 原始發布者／平台 | 日期與版本界線 | 本輪來源 |
| --- | --- | --- | --- |
| S1 | Blobfish／Steam PC | 商品頁查核 2026-11-14；非手機版執行證據 | [Brotato 商品頁](https://store.steampowered.com/app/1942280/Brotato/) |
| S2 | poncle／Steam | 商品頁查核 2026-11-14；提示不保證所有特殊模式適用 | [Vampire Survivors 商品頁](https://store.steampowered.com/app/1794680/Vampire_Survivors/) |
| S3 | flanne／Steam PC | 商品頁查核 2026-11-14；不據此推定手機控制方式 | [20 Minutes Till Dawn 商品頁](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/) |
| S4 | Funday Games／Ghost Ship Publishing／Steam | 2024-01-26，發售前武器設計說明；不是現行完整平衡表 | [The Weapons of Deep Rock Galactic: Survivor](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)；[Steam 官方 API 全文](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2321470&count=100&maxlength=0&enddate=1706278015) |
| S5 | flanne／Steam PC | 2023-06-08，1.0 正式版當時規格 | [20 Minutes Till Dawn — 1.0 Released](https://steamcommunity.com/games/1966900/announcements/detail/3675547066618941165)；[Steam 官方 API 全文](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1966900&count=100&maxlength=0) |
| S6 | flanne／Steam PC | 2022-11-12，v0.8.5 歷史規格 | [Aero Magic and Dodge 官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6368680725428123732)；[Steam 官方 API 全文](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1966900&count=100&maxlength=0&enddate=1668300000) |
| S7 | flanne／Steam PC | 2024-10-28，封閉測試／公開測試預告；本文不視為已正式推出 | [Blessings & Curses 預告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212245217911959733)；[Steam 官方 API 全文](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1966900&count=100&maxlength=0) |
| S8 | Blobfish／Steam PC | 2026-05-12，All Pain No Gain 正式更新當時的調整 | [官方更新公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1832065502824117)；[Steam 官方 API 全文](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1942280&count=100&maxlength=0) |

部分 Steam Community 單篇網頁由網頁工具只取得圖片外殼；本輪以 Python 的標準 HTTP 讀取 Steam 官方 `ISteamNews/GetNewsForApp` JSON，依 app ID、`feedname=steam_community_announcements`、標題及發布時間核對全文。API 為滾動清單，未來重查若文章移出最近 100 則，需加入當時 `enddate`；不能把抽取外殼或滾出清單視為文章不存在。本文不引用非官方攻略作機制證據。

## 八項具體發現

### 1. 一把武器的弱點通常由整套構築承擔

**官方事實：** Brotato 商品頁同時描述最多六把武器、角色特性、物品與波間商店。Vampire Survivors 官方入門提示則建議先拿兩三把攻擊武器，逐把集中升級。這些說明都把玩家的戰鬥能力建立在多項攻擊工具上。[S1](https://store.steampowered.com/app/1942280/Brotato/)、[S2](https://store.steampowered.com/app/1794680/Vampire_Survivors/)

**對奈奈的推論：** 從競品找出「單點武器」不能證明「全套能力都只有單點」也能舒適打怪潮。奈奈的狩獵應盤點主攻、大絕、位移、控制與升級後的整體能力；掃群同樣要以整套評估。也不必為此直接增加六個裝備欄位，一個角色的爪、咬與大絕已可承擔不同職責。

**未知：** 本輪未驗證各遊戲所有單武器挑戰、角色例外或最高難度；不聲稱純單武器永遠不可行，也不聲稱混搭一定最佳。

### 2. 「打強敵較強」需要能把攻擊交給強敵

**官方事實：** DRG:S 的武器設計文章明說，M1000 自動選敵優先血量最高者；另一把 Zhukov 則朝四個方向開火。開發者把選敵方式視為會明顯改變玩法的設計問題。[S4](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)

**對奈奈的推論：** 狩獵若被定位成清除特殊敵人的路線，需要檢查玩家是否能可靠選到、接近並持續攻擊該目標。只提高攻速或傷害，若攻擊仍長期被最近的小怪吸走，優勢就不能穩定兌現。可行解法可能是明確的自動選敵規則、可讀的標記或站位引導，但不能直接宣告「最高血量優先」最適合奈奈。

**未知：** 沒有官方來源證明哪一種自動選敵演算法對我們的近戰、手機移動輸入最好；必須由奈奈實際場景判斷。

### 3. 攻擊幾何會被改造以適應怪潮，武器名稱不決定只能單點

**官方事實：** DRG:S 開發者說，Cryo Cannon 從原作的單束改成角色周圍的多束旋轉攻擊，目的是更適合此類型並支援站位玩法。20 Minutes 1.0 的 Salvo Knives 以移動追蹤敵人後對已追蹤目標投出一輪飛刀；Cyclone Sword 明確用旋轉攻擊切開大群敵人。[S4](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)、[S5](https://steamcommunity.com/games/1966900/announcements/detail/3675547066618941165)

**對奈奈的推論：** 抓、咬和狩獵身份不要求每一下永遠只接觸一隻敵人。「集中打主要獵物，擊殺後轉移」、「狹窄路徑突破」或「累積後爆發」都可能保留主題又解決持續堵塞。此處列的是待設計方向，未替奈奈決定招式。

### 4. 方向攻擊的操作代價，需要學習階段與後續配套

**官方事實：** Brotato 預設自動開火，提供手動瞄準選項；20 Minutes PC 頁則直接把方向瞄準與主動射擊列為玩法。DRG:S 武器文章記錄：把多數方向武器放在起始武器，讓玩家於威脅較低的初期熟悉，再組合相容武器；Subata 向身後射擊，配合 Driller 的挖掘行為。[S1](https://store.steampowered.com/app/1942280/Brotato/)、[S3](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/)、[S4](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)

**對奈奈的推論：** 兩路攻擊若要求不同的接近、面向與逃離行為，固定同一怪潮不等於給了同樣的操作負擔。必須先寫清「單手移動還能控制什麼」，並讓前段敵人教會它；否則所謂技巧型路線，可能只是目標控制不足。

### 5. 主武器不等於單一傷害通道，輔助工具本身是構築內容

**官方事實：** 20 Minutes PC 說明明列升級、召喚與特殊能力，並用點燃霰彈、閃電及穿刺魔法矛舉例；1.0 的 Watering Gun 由澆灌 Spore Flower 召喚物促成孢子砲擊。DRG:S 設計文章也包含防禦／攻擊 drone、turret 與 shock fence。[S3](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/)、[S5](https://steamcommunity.com/games/1966900/announcements/detail/3675547066618941165)、[S4](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)

**對奈奈的推論：** 不必讓每個專精每個動作都能掃群，但整套能力需要處理包圍與堵路。若大絕負責這個缺口，應檢查冷卻期間是否仍有可用對策，以及大絕是主動選時機的獎勵，還是固定被迫交出的通行費。

### 6. 專精可以是可選的重大變體，不必立刻擴成多層樹

**官方事實：** 20 Minutes 1.0 把武器變體安排在局內達到 20 級時，從三種選一種。2024 年 Blessings & Curses 預告另提出角色三選一專精，理由包括減少角色升級隨機順序造成的挫折、提高臨場適應；同一預告指出某些既有升級幾乎全構築過強，另一些不促成有趣構築。[S5](https://steamcommunity.com/games/1966900/announcements/detail/3675547066618941165)、[S7](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6212245217911959733)

**對奈奈的推論：** 專精應先產生能辨認的不同決策與戰鬥循環，再考慮後續子分支。增加樹深不能修復第一層的職責重疊、弱點無解或選擇時點錯誤。20 Minutes 的 20 級不是奈奈應照搬的門檻，必須按四分鐘流程安排。

**版本限制：** 2024 年預告明說當時仍在封閉測試、即將公開測試；本輪不把該整套方案寫成現行 Steam 或手機已實裝規格。

### 7. 生存收益、目標可見性與控制，也是攻擊平衡的一部分

**官方事實：** 20 Minutes v0.8.5 公告說，玩家被怪碰撞後反覆推來推去令人挫折，因此改成把敵人推開；也將子彈 bounce 改成朝最近敵人 ricochet，目的包含降低子彈遮擋角色。這是開發者對問題與改動目的的直接說明。[S6](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/6368680725428123732)

**對奈奈的推論：** 掃群若同時推開多隻怪，它得到的不只是更多總傷害，也得到可走空間、較少接觸傷害與更容易收經驗的機會。比較狩獵與掃群時只列 DPS，會漏掉這些收益；加大特效也不能取代目標、威脅與攻擊命中的可讀性。

### 8. 連射與強擊也會搭配穿透；競品持續調整，不能視為現成平衡證明

**官方事實：** Brotato 2026-05-12 正式更新同時調整 Minigun 的傷害、穿透傷害衰減與速度，並把 Wand 的穿透從 0 改為 1。這提供了具體例子：輸出頻率、單發強度與多目標傳遞可以一起調整，而不是固定把武器永久分成純單點／純範圍兩類。[S8](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1832065502824117)

**對奈奈的推論：** 快攻與重擊可以保留作為手感實驗，但不能只用紙面 DPS 相同推定整體價值相同。敵人血量門檻、過量傷害、出手空檔、鎖定是否轉移、一次擋住幾隻與可兌現的輸出時間，都會改變結果。

**限制：** 上述更新證明官方做了這些調整，不證明調整後所有武器已平衡，更不證明應把相同穿透或倍率搬到奈奈。

## 哪些假設應修正

| 簡化假設 | 官方證據能支持到哪裡 | 對本專案的盤點問題 |
| --- | --- | --- |
| 同類遊戲有單點武器，所以純單點完整流派自然可行 | 有不同主武器與選敵方式，但常置於多工具構築中 | 狩獵整套能力如何解決包圍、堵路與收經驗？ |
| 增加 50% 攻速足以補償範圍優勢 | 未找到這種通用比例；競品同步改幾何、穿透、選敵與輔助 | 能否實際清除指定強敵？換到的時間是否足以保命？ |
| 比較模式同密度，兩路就應同樣輕鬆 | 同場景有助找差異；沒有證據要求每種遭遇同效率 | 完整關卡有哪些必要能力？每路的強項是否真的被需要？ |
| 專精更多層就能增加深度 | 有重大變體與條件改造案例，未證明樹深本身帶來樂趣 | 第一層是否改變選敵、站位、出手或資源循環？ |
| 看起來更難操作就代表技巧與回報 | 官方會專門改造方向武器的學習階段與目標規則 | 額外操作是否可控、有回報，或只是攻擊交付不可靠？ |

## 仍需奈奈本身的證據

這些官方資料不能決定奈奈的最終平衡。完整盤點仍需查明：主攻如何選敵、咬擊與擊殺後如何轉移、每種敵人需要的爪擊次數、大絕能否跨越危險窗口、不同路線實際收取多少經驗，以及特殊敵人是否構成值得優先處理的真實威脅。

後續若做比較，至少區分「固定能力測試主攻差異」與「完整成長測試整套流派」；並記錄弱小怪群、混合特殊敵人、精英窗口與持續包圍。這是本輪設計推論與研究建議，不是已執行的遊戲測試，也不是把競品規則當作保證成功的道路。
