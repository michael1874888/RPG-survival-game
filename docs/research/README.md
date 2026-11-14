# 競品與技術研究索引

這裡保留先前的調查報告、來源筆記、版本與檔案雜湊清單。研究結果與原創遊戲的設計決策分開記錄；下載級距、靜態名稱或資產數量不能直接證明留存、平衡或實際操作規則。

| 主題 | 文件 |
| --- | --- |
| 生存動作 RPG 的構築、操作與壓力比較 | [跨作品機制設計報告](popular-survival-rpg-mechanics-design-report.md) |
| 競品選擇與 Google Play 資料 | [Action roguelite 調查](popular-action-roguelite-competitive-research.md) |
| 多款 APK／XAPK 的靜態資料觀察 | [遊戲資料分析](competitive-apk-game-data-analysis.md)、[第一輪封裝觀察](competitive-apk-first-pass.md) |
| Solomon’s Boneyard 封裝、資料與技能 | [研究入口](solomons-boneyard-intake.md)、[資料發現](solomons-boneyard-data-findings.md)、[技能目錄](solomons-boneyard-skill-catalog.md) |
| Solomon’s Boneyard 作為設計參考 | [設計側核心參考](../design/solomons-boneyard-core-reference.md) |
| Vampire Survivors／Survivor.io 來源 | [來源筆記](mechanics-vampire-survivorio-sources.md) |
| Brotato／20 Minutes Till Dawn 來源 | [來源筆記](mechanics-brotato-dawn-sources.md) |
| Magic Survival／Solomon 來源 | [來源筆記](mechanics-magic-solomon-sources.md) |
| 手機 2D 引擎選型 | [Godot 等引擎比較](mobile-2d-engine-selection.md) |
| REA 的分析計畫與使用案例 | [計畫](solomons-boneyard-rea-plan.md)、[案例與範圍](rea-examples.md) |

## 證據檔與重現範圍

- [競品套件清單](competitive-apks-manifest.json) 保留來源檔名、大小與 SHA-256。
- [Solomon 套件與成員清單](solomons-boneyard-artifact-inventory.json)、[Manifest 與憑證 metadata](solomons-boneyard-apk-metadata.json) 保留特定版本的封裝觀察。
- 分析腳本位於根目錄 `scripts/inspect_sb_*.py`、`scripts/research/` 與 `tools/research/`，不是遊戲執行依賴。額外 Python 模組依各腳本 import 準備，分析輸入需自行提供。
- 原始 APK／XAPK、擷取的遊戲檔案、原生程式庫與完整分析產物留在原開發 SSD，沒有放入 Git；清單中的絕對路徑僅是歷史位置。
- REA 工具與本機 skill 安裝不隨本 repository 發布。報告已標示哪些結論來自 REA、哪些來自輔助腳本，以及未完成的 runtime／反編譯範圍。
