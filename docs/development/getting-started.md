# 開發環境與啟動

## 執行遊戲

1. 取得本 repository，安裝 Godot **4.7.2 標準版**。專案使用 GDScript，不需要 .NET。
2. 用 Godot 匯入並開啟 `game/project.godot`，等待資產匯入後執行主場景。字型與 OFL 授權已附在 `game/assets/fonts/`。
3. Mac 可雙擊 `Play.command` 或 `Edit.command`；預設引擎位置為 `/Applications/Godot.app/Contents/MacOS/Godot`。其他位置可設定 `BRAMBLE_GODOT_BIN`。

命令列範例，在 repository 根目錄執行：

```sh
godot --editor --path game
godot --path game
```

測試使用原開發版本 4.7.2；其他版本尚未驗證。首次匯入產生的 `game/.godot/` 不需要提交。原開發 Mac 的工具安裝收據位於 `tools/`，不是 clone 後自動安裝的依賴。

## 規則與場景檢查

```sh
BRAMBLE_GODOT_BIN=/path/to/godot ./scripts/test-game.sh
```

Mac 若使用預設安裝路徑，可直接執行 `./scripts/test-game.sh`。腳本依序做專案匯入、舊版回歸（4,563 項）與 X1 規則、存檔及實際場景流程檢查（522 項）；整合流程的自動輸入與無敵僅存在於測試程式，不能用來判定人類勝率或平衡。

單獨跑一個測試套件（例如 X1 戰鬥）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/x1_combat_tests.gd
```

X1 的數值調整、自動玩家探針、截圖工具與內容表產生方式見 [X1 調參指南](x1-tuning-guide.md)。

## Android 匯出

APK 不放入 Git。可將 `game/export_presets.cfg.example` 複製為 `game/export_presets.cfg`，再用 Godot 的 Android 匯出介面設定本機 JDK、Android SDK、官方匯出模板與自己的 debug keystore。實際 preset 與金鑰檔均被 `.gitignore` 排除。

原開發環境使用 JDK 17、Android Build Tools 36.1.0、ARM64、minSdk 24／targetSdk 36；詳細既有驗證見 [Android 安裝紀錄](android-install.md)。SDK 條款與工具安裝需由各環境自行完成，不因 repo 內的歷史授權紀錄而視為新使用者已同意。

`scripts/export-android.py` 是原開發 Mac 的專用可重現匯出工具，會呼叫該 Mac 的 SSD UUID 控制器、讀取本機工具位置並更新本機 Godot 匯出路徑；不是跨機器的一鍵安裝程式。其他環境使用範例 preset 與 Godot 匯出介面，不需要建立原開發 Mac 的絕對路徑。

若要以既有套件 ID 更新已安裝的原型，需要相同簽署身分。新環境的不同 debug key 不應宣稱可直接覆蓋原 APK；既有私鑰不存於 Git。
