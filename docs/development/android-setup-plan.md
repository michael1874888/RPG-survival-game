# Android 第一輪實機工具準備

2026-11-13。使用者兩種手機都有，授權選較容易開始的路徑；先走 Android 原生 debug APK，iOS 仍保留。

## 已完成與可獨立進行

- Mac 原型已實作，Godot 4.7.2 已安裝並啟動。
- Godot 4.7.2 官方匯出模板與 Eclipse Temurin OpenJDK 17.0.21+9 已下載、核對官方雜湊並解壓；大型下載、模板及 JDK 工具鏈均在核准 SSD 的專案目錄。Java 已實際執行成功，具體路徑與來源見 [前置工具收據](../../tools/android-prerequisites.json)。
- 活躍原始碼與設定保留內部磁碟。除錯 keystore 若建立，也會留在內部，不放 SSD。

## 授權與安裝結果

Google 的 [SDK 下載頁與條款](https://developer.android.com/studio#terms) 明寫下載前須同意 Android SDK License Agreement。使用者已明確回覆「同意 SDK 條款並繼續安裝」，本輪只在安裝程式顯示 `android-sdk-license` 時接受該授權。

已安裝 ARM Mac Command-line Tools 22.0、穩定版 platform-tools 37.0.1、Build Tools 36.1.0。adb 與 apksigner 均已實際執行，未接受預覽版授權。

安裝位置由 storagectl 核對，位於核准 SSD `Artifacts/codex/RPG_Game_Dev/android-tools/sdk`。SDK、Java、模板及 APK 留在 SSD；原始碼、匯出設定及小型收據留在專案；專案除錯私鑰位於內部磁碟，未搬到 SSD。

## 精確版本的依據

Godot 通用 stable 文件列 SDK 35；但 [4.7.2 的 config.gradle](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle) 指定 Java 17、Build Tools 36.1.0、target SDK 36、最低 SDK 24。優先遵循實際採用版本。

本輪使用 [官方 legacy APK exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp)，關閉 Gradle，指定現成 android_debug.apk，無需從原始碼編譯引擎。因此先準備 adb 與 apksigner 所需套件；Android Studio、模擬器、NDK、CMake 不列入本輪安裝。

## 驗證結果

1. Java、adb 及 apksigner 已執行；官方 Command-line Tools SHA-256 核對通過。
2. Godot 已匯出 ARM64 debug APK；另跑 apksigner verify，v2／v3 簽章驗證通過。
3. APK ZIP 完整性、架構、字型授權及測試程式排除檢查通過；Manifest 為 org.bramble.prototype、最低 SDK 24、target SDK 36，沒有要求任何權限。
4. `adb devices -l` 無連接裝置，所以尚無實機安裝或手機效能結論。

匯出腳本使用官方 apkanalyzer 的 Java 入口檢查 Manifest，避開廠商 shell launcher 對含空格 SDK 路徑的分割問題，沒有修改 SDK 廠商檔案。sdkmanager 提示已棄用但本輪安裝成功；後續重新匯出不需再次使用該安裝命令。

具體 APK 位置、大小與雜湊見 [建置收據](../../tools/android-build.json)，手機安裝方式見 [安裝步驟](android-install.md)。
