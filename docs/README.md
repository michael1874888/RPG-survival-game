# 專案文件索引

這個 repository 收錄遊戲原型與專案整理後的設計／研究紀錄。遊戲正式名稱、完整故事與美術方向尚未定案；Bramble、森林場景及目前介面文案是原型表現。

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

原型已通過 132 項規則與場景檢查；這與玩家爽感、平衡、設備相容性及完整階段驗收是不同層面的證據。使用者已提供的主觀回饋保留在各輪紀錄，不推論尚未提供的設備、場次或量測結果。

## 其他入口

- [名詞表](../GLOSSARY.md)
- [Android 安裝與試玩](development/android-install.md)
- [手機測試清單](development/mobile-test-checklist.md)
- [Repository 整理說明](development/repository-layout.md)

文件中的原開發 Mac／SSD 絕對路徑是歷史證據位置；不表示這些檔案已跟著 clone 下載。原始競品安裝包、工具鏈與 APK 產物不放入 Git。
