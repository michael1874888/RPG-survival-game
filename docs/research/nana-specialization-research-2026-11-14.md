# 奈奈專精規劃研究：官方案例

研究日期：2026-11-14。這份文件是研究與設計輸入，**尚未因此修改遊戲**。以下記錄兩款遊戲、三種可比較的設計做法；來源限官方公告與開發者網站。公告證明當時的規則或計畫，不代表已實機驗證，也不證明玩家樂趣、留存或平衡效果。

## 1. Deep Rock Galactic: Survivor：數值、觸發規則與代價並存

**版本與來源：** 2024-05-13，Early Access Update 02「Hoxxes Fights Back」。[官方公告](https://steamcommunity.com/games/2321470/announcements/detail/4170973472362104918)；[可讀的官方公告歷史頁](https://store.steampowered.com/news/posts/?enddate=1715601956&feed=steam_community_announcements)。後者可讀取全文，單篇頁本次擷取僅回傳外殼。

官方列出的 overclock 同時包含不同類型：Omni Barrel 改為八方向射擊；Storm E-Mag 讓彈匣最後一發向全方向發射；Potent Juice 以直接傷害換取狀態累積；Impact Punch 則作反向交換。它們涵蓋攻擊幾何、特定時點觸發及強弱交換，沒有把每個 overclock 都限定成同一種數值增幅。該版也加入武器檢視頁，讓玩家查看傷害計算與 overclock 效果。[來源](https://store.steampowered.com/news/posts/?enddate=1715601956&feed=steam_community_announcements)

**奈奈設計推論：** 一般升級可以繼續提供傷害、射程；專精則應明確負責目標規則、攻擊形狀、出手機會或資源循環。名稱不同不是充分條件，必須可描述「玩家因此如何站位／選目標／抓時機」。額外傷害也需要提示，才能辨認規則已發生。

**限制：** 未實測以上選項的強度、出現機率與組合相容性，不引用該公告推斷目前全武器資料。

## 2. Hades：武器形態與當局改招可分層

**版本與來源：** 官方頁標題為「The Superstar Update Patch Notes」，頁首日期為 2019-08-13，但正文整合 2019-10-08 至 10-17 的多次 Early Access patch；本段以各 patch 標示日期為準。[Supergiant 官方更新記錄](https://www.supergiantgames.com/blog/hades-superstar-update-patch-notes/)

2019-10-08 的 Patch 028 加入可永久升級的 Weapon Aspects。同次更新的 Hammer 包含：每次斬擊發出遠距波、Bull Rush 改為射出投射物，以及轟炸改成火箭。10-15 與 10-17 的修訂又讓特定劍／弓 Hammer 可以按住攻擊連續出手。這些例子直接改變攻擊交付方式與操作節奏。官方也記錄了部分舊 Hammer 概念移到 Aspects，及兩者互動的修正。[來源](https://www.supergiantgames.com/blog/hades-superstar-update-patch-notes/)

**奈奈設計推論：** 可以把第一層專精定為整局的核心攻擊規則，再讓第二層選擇改寫其中一個可辨認的動作。這不是要求同時建立永久養成；借鏡的是不同層級有不同責任。若新增子分支，需列出互斥與相容條件，避免效果疊加後失去原本動作的意義。

**限制：** 這是歷史 Early Access 的機制案例，並非現行 Hades 或 Hades II 的完整規則表；未據此宣稱所有 Aspects 都改招，或所有 Hammer 都超越數值升級。

## 3. Deep Rock Galactic: Survivor：分階段改造與有條件的後續選項

**來源 A：** 2024-01-26「The Weapons of Deep Rock Galactic: Survivor」。當時介紹武器在等級 6、12、18 的 overclock 節點，18 級 unstable 可有強烈增幅、代價或功能改變。文內原有「首次先升到 12 才解鎖」門檻。[官方公告](https://steamcommunity.com/games/2321470/announcements/detail/3971679674351840364)；[官方全文歷史頁](https://store.steampowered.com/news/posts/?enddate=1706278015&feed=steam_community_announcements)

**版本修正：** 2024-06-25 Update 03 明確移除上述 overclock 初次解鎖門檻，因此不可把一月介紹中的這項門檻當作現行設計。[官方 Update 03](https://steamcommunity.com/games/2321470/announcements/detail/4182236270515682743)；[官方全文歷史頁](https://store.steampowered.com/news/posts/?enddate=1719315098&feed=steam_community_announcements)

**來源 B：** 2026-04-24「Coming Soon: Endless Mode」預告：選 Sidearm overclock 後，可取得 Ultimate Sidearm Unbalance overclock；多把武器採用 Sidearm 後，可開始出現相關協同升級卡。[官方預告](https://steamcommunity.com/games/2321470/announcements/detail/506233956051452740)；[官方全文歷史頁](https://store.steampowered.com/news/posts/?enddate=1777025727&feed=steam_community_announcements)。此處僅確認預告的依賴關係，未以執行中的版本核實後續實裝結果。

**奈奈設計推論：** 後續層級可以透過「已選核心專精」或「已建立某種攻擊機制」來開放，讓強化沿既有打法發展。多個節點不等於完整的樹狀分支；應分清楚連續升級、互斥分叉與條件協同。四分鐘流程是否容得下兩次以上重大分叉，仍需以實際升級時間及使用次數決定。

## 開發順序的補充證據

2024-04-12 的 DRG:S roadmap 更新曾把 Bosco 2.0 延後，優先做敵人與 overclock，官方說明當時想先增加橫向變化，再加額外層次。這是該團隊當時的選擇，並非所有遊戲都適用的定律。[官方公告](https://steamcommunity.com/games/2321470/announcements/detail/7499131229792113483)；[官方全文歷史頁](https://store.steampowered.com/news/posts/?enddate=1712912750&feed=steam_community_announcements)

**對奈奈的推論：** 先讓兩個核心專精在同一場景可辨認，再逐層增加子分支，比同時擴充很多層更容易判斷差異來源。是否採用、節點時間與分支數量，仍屬本專案的待驗證設計。
