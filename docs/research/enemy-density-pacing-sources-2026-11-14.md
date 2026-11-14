# 敵群密度與壓力節奏：官方案例

研究日期：2026-11-14。範圍：官方商店說明、開發團隊公告、原作者技術簡報；未進行這些遊戲的執行期量測。這份文件只整理外部案例，奈奈目前出怪規則的診斷與修改提案另行處理。

## 證據摘要

| 案例 | 官方能確認的機制 | 未知、不能據此假定 |
|---|---|---|
| Brotato | 每波 20–90 秒；波間購物 | 每秒出怪量、場上上限、波內補怪演算法 |
| DRG: Survivor 1.0 | 護送任務以移動目標、停留風險維持壓力；快速擊殺關底精英有較好獎勵 | 停留如何換算敵量、傷害或生命；各關出怪表 |
| DRG: Survivor Endless | 前十關縮短、提高敵群密度、加快成長，第十一關起明顯提高挑戰 | 縮短多少秒、密度倍率、場上上限 |
| Left 4 Dead | 高低壓階段、威脅持續生成及減量、獨立 Boss 節點 | 可直接搬到手機近戰 survivors 的最佳時間與數量 |

## 1. Brotato：短戰鬥與波間整理

- 來源：[Brotato 官方 Steam 商店頁](https://store.steampowered.com/app/1942280/Brotato/)，開發／發行：Blobfish。
- 日期／版本／平台：頁面未標示文案更新日，2026-11-14 查閱；Steam 商店現行說明，無數字版號；列出 Windows、macOS、SteamOS/Linux。這不是手機版規格。
- **官方事實：**每波持續 20–90 秒，期間盡量擊殺；收集材料取得經驗，並於敵人波次之間購物。預設自動開火，可手動瞄準。[來源](https://store.steampowered.com/app/1942280/Brotato/)
- **設計推論：**「波次制」仍能採短而集中的戰鬥，將完整休息放在波間；波次制本身不代表戰鬥中應長時間空場。
- **限制：**商店文案未公布生成頻率、敵量、生成距離或波內是否依存活數補怪，不能把 20–90 秒當成出怪間隔。

## 2. Deep Rock Galactic: Survivor 1.0：用目標與獎勵製造持續壓力

- 來源：Funday Games 官方公告 [1.0 OUT NOW!](https://store.steampowered.com/news/app/2321470/view/534361794856091729)。
- 日期／版本／平台：2025-09-17；1.0；Steam PC 公告，未據此假定其他平台與版本數值相同。
- **官方事實：**Escort Duty 的鑽機需要補燃料，且玩家靠近才前進；等待越久，敵群難度越高。鑽機亦能當掩體並清除敵人。團隊明確區分這個護送玩法與以擊殺 Boss 為重點的構築。公告另說關底精英擊殺越快，寶箱獎勵越好，讓玩家權衡獎勵與繼續採集。[來源](https://store.steampowered.com/news/app/2321470/view/534361794856091729)
- **設計推論：**高單體火力需要有價值的強敵與明確時機；群體火力則能透過護送空間、清出通道產生價值。只比較普通小怪的總傷害容易看漏這些用途。
- **限制：**「敵群難度提高」沒有給出量化公式，不能自行解讀成線性增加出怪數。公告也不能證明特定持續補怪演算法。

## 3. Deep Rock Galactic: Survivor Endless：密度與成長速度一起調

- 來源：Funday Games 官方公告 [OUT NOW: HEAVY DUTY EXPANSION](https://store.steampowered.com/news/app/2321470/view/675119576448500282)。
- 日期／版本／平台：2026-04-30；Heavy Duty 上線同日的更新，Endless 為免費更新內容；Steam PC 公告，不推及主機或手機版。
- **官方事實：**Endless 前十個階段較短、敵人密度較高，角色也更快成長；模式是 Elimination 的變體，限制最多攜帶 15 個 artifacts；第十一階段起挑戰明顯提高。[來源](https://store.steampowered.com/news/app/2321470/view/675119576448500282)
- **設計推論：**增加密度應同步檢查經驗、升級與能力成形速度。若只加敵人，可能讓早期單體玩法先崩潰；若只加火力，也可能讓場面更容易被清空。
- **限制：**公告沒有密度倍率、每秒生成量、關卡縮時數字或存活上限；不能當作奈奈數值的直接標準。

## 4. Left 4 Dead：持續威脅與喘息採不同層次控制

- 來源：Michael Booth／Valve，[The AI Systems of Left 4 Dead 官方簡報](https://cdn.cloudflare.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)，重點為 PDF 第 68、78–82、92 頁（以閱讀器一頁起算）。
- 日期／版本／平台：2009 年 AIIDE 簡報；Left 4 Dead 當時設計，未標數字版號。為四人合作 FPS 生存恐怖遊戲，不能視為手機 survivors 同類配方。
- **官方事實：**Director 以玩家的戰鬥壓力估計調節威脅；經過累積、維持高峰、消退與喘息。高峰維持階段保留完整威脅 3–5 秒；喘息維持最低威脅 30–45 秒或到隊伍前進一定距離。既有敵人仍可攻擊，Boss 不受此節奏調節。簡報亦描述普通難度 Mob 以 90–180 秒隨機間隔產生；這不是所有敵人的共同出怪間隔。[來源](https://cdn.cloudflare.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)
- **設計推論：**分開管理日常敵群、突發事件與精英節點，能保留穩定接敵，同時讓高峰後有喘息；不要將每個小包清完後的等待都當成正式休息。
- **限制：**以上秒數只說明該歷史案例。不同鏡頭、跑速、攻擊與合作條件下，需要重新量測，不應直接移植。

## 取證方式與結論邊界

Steam 商店與 Valve PDF 可直接讀取。兩篇 DRG 公告的文章正文在一般網頁擷取中未完整呈現，已透過 Steam 官方 `ISteamNews/GetNewsForApp/v2/` 的 `steam_community_announcements` feed 讀到全文，並循其官方重新導向核對公告網址與時間；未使用 SteamDB 或玩家轉貼補足規則。可重現查詢：[Steam 官方新聞 API（appid 2321470）](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2321470&count=100&maxlength=0&format=json)。

這些案例支持將「基礎接敵密度、壓力高峰、喘息、事件／精英目標、角色成長」一起設計；**沒有證據能替奈奈決定固定每秒幾隻、上限幾隻，或證明單體攻速加多少就足夠平衡**。這些值必須由目前程式診斷、固定情境比較與真人試玩取得。
