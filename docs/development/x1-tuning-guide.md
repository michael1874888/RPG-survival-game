# 奈奈夜巡 X1：調參指南

X1 的數值與內容全部放在 `game/data/x1/*.json`，程式只讀取，不寫死數字。大部分調整只要改 JSON，不必改程式。

## 改完之後怎麼看結果

1. **Mac 上即時試：**用 Godot 開啟專案執行（debug 建置），進入戰鬥後按 **F5**，會重新讀取所有 JSON 並重開目前這一場。
2. **跑規則測試：**`bash scripts/test-game.sh`。其中 `x1_data_tests` 會檢查所有 JSON 格式、ID、互相引用與卡片數量；改錯會直接報出是哪個檔案、哪個欄位。
3. **看節奏數字：**`/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/x1_autoplay_probe.gd -- seeds=3`。輸出每局的勝負、層數、等級、各類戰鬥時長、每場夜影次數與構築。自動玩家反應瞬間、不看選單，**只能看規則與節奏，不能代表真人難度或樂趣**。
4. **看畫面：**`/Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/x1_visual.gd -- out=/某個資料夾` 會截下每個畫面。
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
| 命中停頓、震屏、震動強度 | `tuning.json` | `feel.*` |
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
