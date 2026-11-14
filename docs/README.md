# 專案文件索引

這個 repository 收錄遊戲原型與專案整理後的設計／研究紀錄。遊戲正式名稱、完整故事與美術方向尚未定案；Bramble、森林場景及目前介面文案是原型表現。

目前優先工作：[第一版單一角色與敵人戰鬥設計](design/first-version-combat-plan.md)。主角已選定為寵物黑貓「奈奈」，先完成牠的攻擊與機制，再完成敵人設計，之後接續其他部分；保留其他角色的擴充空間。

[奈奈與第一版敵人戰鬥設計草案 v1.1](design/nana-combat-design-v1.md) 含角色與敵人機制、成長、節奏與分段交付計畫；[奈奈 v0.9 怪潮與狩獵比較](development/nana-v0.9-practice.md) 說明目前已交付範圍。最新方向盤點見 [v0.9 設計 review](design/nana-v0.9-design-audit-2026-11-14.md)。

新 session 先讀根目錄 [交接文件](../HANDOFF.md)。最新討論是 [Balatro 式隨機構築的可行性與模式選擇](research/random-driven-combat-mode-feasibility-2026-11-14.md)，目前為待 review 研究，尚未實作。

## 建議閱讀順序

1. [主題與角色方向](design/theme-and-characters.md)：可愛動物題材、特色與故事的邊界。
2. [遊戲方向與決策紀錄](design/game-direction.md)：五輪已確認共識，以及後續討論進度。
3. [分階段開發路線](design/development-roadmap.md)：每階段問題、產出與完成條件。
4. [PoC 回饋與後續事項](design/poc-feedback-and-followups.md)：試玩結果與近期取捨。
5. [競品研究索引](research/README.md)：同業調查、靜態分析及證據限制。
6. [開發環境說明](development/getting-started.md)：啟動原型與執行驗證。

## 原型演進

| 版本 | 驗證問題與紀錄 |
| --- | --- |
| v0.1 | [原型規格](design/prototype-v0.1-spec.md)、[歷史實作與驗證](development/prototype-v0.1-status.md)：手機雙手操作、三分鐘生存、升級與重玩 |
| v0.2 | [角色對照](design/animal-attacks-poc-v0.2.md)：刺蝟遠距尖刺與小熊近距揮擊 |
| v0.3 | [構築比較](design/build-comparison-poc-v0.3.md)：散射＋反彈與穿透＋攻速；含固定靶群分析 |
| v0.4 | [陣形比較及收斂](design/formation-comparison-poc-v0.4.md)：包圍／隊列各 45 秒；近期保留反彈，穿透暫緩深化 |
| v0.9 | [奈奈怪潮與狩獵比較](development/nana-v0.9-practice.md)：分批怪潮、快攻／重擊對照；[設計重新盤點](design/nana-v0.9-design-audit-2026-11-14.md) |
| v0.8 | [奈奈專精比較](development/nana-v0.8-practice.md)：環掃與點殺改招、四個固定比較情境 |
| v0.7 | [奈奈成長挑戰](development/nana-v0.7-practice.md)：升級、專精、精英及動態出怪 |
| v0.6 | [奈奈戰鬥練習](development/nana-v0.6-practice.md)：追加重咬與四種普通敵人短情境 |
| v0.5 | [奈奈手感試玩](development/nana-v0.5-practice.md)：連抓、重咬、主動大絕與追逐敵人 |

v0.9 已有 227 項規則與場景檢查通過；這與玩家爽感、平衡、設備相容性及完整階段驗收是不同層面的證據。使用者已提供的主觀回饋保留在各輪紀錄，不推論尚未提供的設備、場次或量測結果。

## 其他入口

- [名詞表](../GLOSSARY.md)
- [Android 安裝與試玩](development/android-install.md)
- [手機測試清單](development/mobile-test-checklist.md)
- [Repository 整理說明](development/repository-layout.md)

文件中的原開發 Mac／SSD 絕對路徑是歷史證據位置；不表示這些檔案已跟著 clone 下載。原始競品安裝包、工具鏈與 APK 產物不放入 Git。
