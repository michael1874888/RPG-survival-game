# 奈奈夜巡 X1：調參指南

X1 的數值與內容全部放在 `game/data/x1/*.json`，程式只讀取，不寫死數字。大部分調整只要改 JSON，不必改程式。

## 改完之後怎麼看結果

1. **Mac 上即時試：**用 Godot 開啟專案執行（debug 建置），進入戰鬥後按 **F5**，會重新讀取所有 JSON 並重開目前這一場。
2. **跑規則測試：**`bash scripts/test-game.sh`。其中 `x1_data_tests` 會檢查所有 JSON 格式、ID、互相引用與卡片數量；改錯會直接報出是哪個檔案、哪個欄位。
3. **看節奏數字：**`/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/x1_autoplay_probe.gd -- seeds=3`。輸出每局的勝負、層數、等級、各類戰鬥時長、每場夜影次數與構築。自動玩家反應瞬間、不看選單，**只能看規則與節奏，不能代表真人難度或樂趣**。
4. **看畫面：**`/Applications/Godot.app/Contents/MacOS/Godot --path game --fixed-fps 60 --script res://tests/x1_visual.gd -- out=/某個資料夾` 會截下每個畫面；加 `--resolution 1600x720` 看 20:9。
5. **更新可讀內容表：**`python3 -B scripts/x1-content-table.py` 會依 JSON 重寫 [內容表](../design/nana-x1-content.md)。

## 常見調整對照

| 想調整的感覺 | 檔案 | 欄位 |
| --- | --- | --- |
| 撲擊次數、回復速度、距離、無敵時間 | `tuning.json` | `pounce.charges`、`pounce.recharge`、`pounce.distance`、`pounce.duration`、`pounce.after_invuln` |
| 撲擊路徑傷害、落地咬擊傷害與範圍 | `tuning.json` | `pounce.path_damage`、`pounce.bite_damage`、`pounce.bite_radius` |
| 咬中獵物返還撲擊與冷卻 | `tuning.json` | `pounce.prey_refund`、`pounce.prey_refund_icd` |
| 「拖曳多遠才算撲擊」 | `tuning.json` | `pounce.deadzone`（像素） |
| 爪擊速度、傷害、角度、自動索敵距離 | `tuning.json` | `claw.interval`、`claw.damage`、`claw.angle`、`claw.seek` |
| 夜影多久充滿 | `tuning.json` | `ult.gain`（每種擊殺給多少）、`ult.meter_max` |
| 夜影效果 | `tuning.json` | `ult.radius`、`ult.damage`、`ult.duration`、`ult.damage_mult`、`ult.recharge_mult` |
| 移動多少距離換一次撲擊 | `tuning.json` | `roam.step`；遊習性另在 `habits.json` 的 `roam_step_set` |
| 升級頻率 | `tuning.json` | `xp.thresholds`（每級所需經驗）、`xp.drop`（每種敵人掉多少） |
| 卡片格數、等級上限、刷新次數 | `tuning.json` | `build.slots`、`build.max_level`、`build.rerolls` |
| 習性偏向強度、普通／稀有出現比例 | `tuning.json` | `build.habit_bias`、`build.rarity_weight` |
| 命中停頓、震屏、震動、特效、音效、音樂 | `feel.json` | 見下方「手感與回饋」 |
| 同時最多幾個特殊攻擊 | `tuning.json` | `fairness.max_special_attacks` |
| 地圖層數、每層節點數、各節點機率 | `tuning.json` | `map.*` |
| 獵物巢／守關的獎勵 | `tuning.json` | `rewards.den`、`rewards.boss` |
| 一場戰鬥多長、怪有多密 | `spawns.json` | `hunt.fodder.rate`、`rate_step`、`max_rate`、`cap`、`hunt.targets.first/gap/count` |
| 疾追影偶何時加入、最多幾隻 | `spawns.json` | `hunt.hounds.from`、`every`、`max_alive` |
| 後面幾層的敵人變多硬 | `spawns.json` | `layer_hp_mult`、`layer_damage_mult`（索引 1–7 是地圖層） |
| 某種敵人的生命、速度、招式時間 | `enemies.json` | 該敵人的欄位（例：`E03.windup`、`EL01.hp`、`B02.seed_count`） |
| 區域難度、障礙位置、出現的敵人 | `regions.json` | `hp_mult`、`damage_mult`、`obstacles`、`specials`、`targets`、`elites`、`boss` |
| 卡片效果與數值 | `cards.json` | 每張卡的 `effects`；`desc` 是卡面文字，記得一起改 |
| 習性效果 | `habits.json` | `effects` |
| 寶物效果 | `items.json` | `effects` |
| 夜深各層規則 | `night_levels.json` | `levels[].mods` |
| 月光事件 | `events.json` | `options[].effects`、`requires` |
| 商店價格 | `shop.json` | `card_price`、`heal`、`reroll`、`remove`、`upgrade` |
| 解鎖條件 | `unlocks.json` | `counter` 與 `value`，或 `win` 的 `habit`／`region`／`night` |

## 手感與回饋

v0.31 起，戰鬥的「感覺」全部放在 `game/data/x1/feel.json`，和玩法數值分開，同樣可以按 F5 熱重載，`x1_data_tests` 會檢查引用。設計原則與重量階梯見 [手感設計](../design/x1-feel-design.md)。

### 一個事件會發生什麼

戰鬥事件（命中、擊殺、咬擊、受傷……）由 `scripts/x1/present/feedback_director.gd` 對應到 `cues` 裡同名的「提示」，一個提示可以同時指定：

| 欄位 | 作用 | 例 |
| --- | --- | --- |
| `hitstop` | 命中停頓秒數（全部加總後上限 `limits.hitstop_cap`） | `bite`: 0.045 |
| `slowmo` | 慢動作 `{scale, time}` | `kill_elite`: 0.35 倍、0.25 秒 |
| `shake`、`directional` | 震屏強度 0–1；`directional` 會往攻擊來的反方向震 | `hurt`: 0.45 |
| `kick`、`zoom` | 鏡頭頓一下（像素）、推近比例 | `land`: 5；`ult`: 0.12 |
| `flash`、`flash_strength` | 全畫面閃光顏色與強度（低閃光設定再乘 0.35） | `hurt`: 紅色、0.3 |
| `particles`、`ring`、`pillar`、`puff`、`fx` | 粒子預設與數量、擴散圈、光柱、影煙、特殊圖形（`teeth` 咬合、`mark`、`refund`、`land`） | `kill_prey`: 金色 26 顆＋光柱 |
| `text`、`text_color`、`text_size` | 浮動字。重疊時會自動往上（或靠近畫面頂端時往下）錯開 | `level_up`: 「升級！」 |
| `sound`、`pitch`、`pitch_var`、`ladder` | 音效、音高、隨機幅度；`ladder` 讓連續擊殺沿五聲音階爬 | `kill_fodder` |
| `haptic` | 觸覺圖案名稱（`haptics.patterns`） | `bite`: medium |
| `music` | 短音樂（`stingers`） | `net` |
| `fish_fly` | 小魚乾飛向左上計數 | `kill_prey` |

### 常見調整

| 想調整的感覺 | `feel.json` 欄位 |
| --- | --- |
| 某個時刻太輕或太重 | `cues.<名稱>` 的 `hitstop`、`shake`、`haptic`、`particles.count` |
| 停頓或慢動作整體上限 | `limits.hitstop_cap`、`limits.slowmo_min_scale` |
| 震屏最大位移、回復速度、鏡頭超前 | `camera.max_shake`、`camera.trauma_decay`、`camera.lookahead` |
| 震動太多或太弱 | `limits.haptic_gap`（兩次震動最短間隔）、`haptics.strength`、`haptics.patterns`（每段 `[毫秒, 強度]`，強度 0 是停頓）、`haptics.priority` |
| 粒子數量上限（依特效設定） | `limits.particles.high/medium/low`、`limits.particle_scale` |
| 粒子外觀 | `particles.<預設>`：速度、壽命、大小、阻力、形狀（`streak`、`shard`、`star`、`puff`、`line`、`slash`、`plus`、`dot`）、顏色、是否加色發光 |
| 連獵門檻與稱號 | `combo.tiers`、`combo.window`（幾秒內沒擊殺就歸零）、`combo.break_on_hurt` |
| 哪些命中顯示傷害數字（「重擊」模式） | `damage_numbers.heavy_sources`、`heavy_roles`、`heavy_prey` |
| 低血量心跳 | `low_hp.ratio`、`low_hp.beat` |
| 音效音量與同時上限 | `sounds.<名稱>.volume`（dB）、`max`、`bus` |
| 音樂層何時加入 | `music.layers`（強度門檻）、`music.intensity`（附近敵數、連獵、夜影、守關各佔多少） |
| 自動降特效的門檻 | `performance.frame_budget_ms`、`performance.window`（只在手機的正式建置生效） |
| 顏色語言 | `colors`（紅橘危險、金色獵物、青色影子攻擊、紫色夜影） |

### 音效與音樂

音效和音樂都是 `scripts/x1-make-audio.py` 用 Python 標準函式庫、固定種子產生的 WAV，重新產生結果相同：

```sh
python3 -B scripts/x1-make-audio.py
```

它會覆寫 `game/assets/audio/x1/sfx/` 與 `music/`，並印出每個檔案的峰值與 RMS。改了聲音的做法要改這支腳本；只想調大小聲就改 `feel.json` 的 `volume`。新增聲音時，在腳本加產生函式、在 `feel.json` 的 `sounds` 登記變體數，`x1_audio_tests` 會檢查檔案都存在、能載入、音樂循環長度一致。音樂循環檔的 `.import` 要保留 `edit/loop_mode=2`。

### 看手感的工具

- **F3**（電腦鍵盤）：在戰鬥左下角顯示每幀毫秒、fps、繪製毫秒、敵數、粒子數與特效等級；設定頁的「顯示每幀時間」也能打開（手機上用這個）。
- **逐格錄影：**`Godot --path game --fixed-fps 60 --script res://tests/x1_record.gd -- out=/某資料夾`，把撲擊咬擊、擊敗獵物、夜影、受傷、連獵、升級、預警、守關登場／轉階段／擊破錄成九張聯絡表。**一定要加 `--fixed-fps 60`**，否則在 120 Hz 螢幕上特效會看起來長一倍。
- **效能壓力：**`Godot --path game --script res://tests/x1_perf.gd -- seconds=10 effects=high`，畫面上維持 120 隻敵人、持續擊殺與夜影，輸出模擬、繪製清單、渲染 CPU 與實際每幀時間。數字只代表這台 Mac。

### 畫圖的效能規則

Compatibility 渲染器裡，`draw_colored_polygon`、`draw_circle`、`draw_arc`、`draw_polyline` 和有抗鋸齒的 `draw_line` 每次呼叫都會建立一個頂點緩衝（實測每次約 4 微秒）；`draw_rect`、`draw_texture_rect`、`draw_primitive`（3–4 點）則便宜而且會合批。所以每幀會畫很多次的東西（敵人身體、眼睛、粒子、寶石、草叢）用 `Looks.ellipse`／`Looks.disc`（著色的圓形貼圖）和 `Looks.poly`（三角形與四邊形）。改成這樣後，120 隻敵人加滿粒子時每幀從 22.6 毫秒降到 8.4 毫秒。少量的東西（預警、圈、HUD）照常用一般畫法即可。

## 卡片效果怎麼寫

每張卡、習性和寶物的 `effects` 都是同一種格式：

- **數值：**`{"type": "stat", "stat": "claw_damage_pct", "value": [20, 40, 60]}`。陣列依等級取值；可用的數值名稱列在 `scripts/x1/core/data.gd` 的 `STATS`。
- **觸發：**`{"type": "trigger", "hook": "kill", "sources": ["claw"], "chance": [0.25, 0.35, 0.45], "action": "bounce_ball", "params": {...}}`
  - `hook` 是時機：`claw_swing`、`claw_hit`、`hit`、`pounce_start`、`pounce_hit`、`pounce_land`、`bite_hit`、`kill`、`prey_kill`、`hurt`、`ult_start`、`roam_charge`、`tick`（搭配 `interval`）、`move`（搭配 `every_distance`）。
  - 可選條件：`sources`（傷害來源）、`target`（`{"marked": true}` 或 `{"prey": true}`）、`chance`、`every`（每第幾次）、`icd`（內部冷卻秒數）、`max_per_battle`。
  - `action` 是動作：`bounce_ball`、`shadow_line`、`shockwave`、`claw_burst`、`extra_claw`、`heal`、`refund_pounce`、`meter`、`bleed`、`slow`、`buff`、`mark`、`execute`。實作都在 `scripts/x1/core/effect_actions.gd`。

新增一張卡通常只要在 `cards.json` 加一筆，並在 `unlocks.json` 加它的解鎖條件（非起始卡）。`x1_build_tests` 會自動為每張卡跑一場受控戰鬥，確認它的每個觸發都真的發生過。

需要新的「動作」或「時機」才要改程式：動作加在 `effect_actions.gd`，時機在 `battle.gd` 呼叫 `effects.fire(...)`，再把名稱加進 `data.gd` 的 `ACTIONS` 或 `HOOKS`。

## 新增敵人

1. 在 `enemies.json` 加一筆，`ai` 選現有行為（`chaser`、`charger`、`thrower`、`guard`、`trapper`、`caller`、`lantern`、`warden`、`stalker`）就能直接使用。
2. 需要新行為時，在 `scripts/x1/ai/` 加一個檔案（參考 `guard.gd`），並在 `battle.gd` 的 `AI` 表登記。預警請用 `common.gd` 的 `start()`，畫面會自動畫出 `tele` 形狀。
3. 把敵人 ID 加進某區域的 `specials`／`targets`。

## 不能用調參改掉的公平規則

這些在程式裡固定，避免調數值時意外變成「看不到就被打」：

- 特殊攻擊必須先出現在畫面上至少 `fairness.visible_before_attack` 秒才會起手。
- 夜深不會縮短任何預警時間（`x1_enemy_tests` 會在夜深 8 檢查）。
- 警告出生的敵人離奈奈至少 `world.spawn_safe_distance`；出生時太近會換位置並重新完整預警。
- 同一模擬步多次受傷只算最大的一次；受傷後有保護時間。
