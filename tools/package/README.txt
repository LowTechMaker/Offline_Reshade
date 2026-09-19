Offline ReShade — 試用版
========================

把整個資料夾解壓到任何位置，執行 OfflineReShadeWinUI.exe 即可。
不需要安裝 .NET、Visual C++ 或 Windows App SDK，執行階段都已包含在內。

需求
----
  * Windows 10 1809 (17763) 以上，64 位元
  * 支援 Direct3D 11 的顯示卡

放 shader
---------
把 .fx 檔放進本資料夾底下的 Effects\，例如：

    Effects\SomeShader.fx
    Effects\Textures\      ← shader 用到的貼圖
    Effects\Addons\        ← ReShade add-on（選用，沒有就留空）

也可以在 Settings 裡把 Effect Dir 指到你現有的 reshade-shaders 資料夾，
不一定要搬進來。

怎麼用
------
  1. 按 Settings，設定：
       Color PNG    ← 來源圖（遊戲匯出的彩色圖）
       Depth        ← 對應的深度圖（.rfloat 或 .png）
       Effect Dir   ← shader 資料夾
       Output PNG   ← 輸出路徑
  2. 按 Start Preview，等 effect 編譯完成。
  3. 左側面板可勾選 technique、調整參數，右側即時預覽。
  4. 按 Save PNG 或 ReShade Shot 輸出結果。

Preset
------
工具列第二排是 preset 控制：

    Preset: <檔名>   [Load...] [Save] [Save As...]   [ ] Auto Save

  * Load... 可在預覽執行中直接切換 preset，不必重開。
  * 你選的 preset 檔只會被「讀取」。即時調參數只寫進內部的工作副本，
    原始檔案在你按下 Save 之前完全不會被動到。
  * 檔名後面出現 * 代表有未存檔的修改。
  * Auto Save 開啟時，每次調整都會直接寫回原始檔案。

兩個效能開關
------------
  Performance Mode
      把參數編譯成常數並提高最佳化等級，畫面輸出不變但跑得更快。
      代價是開啟期間所有參數都不能調整（面板會灰掉），也不能存 preset。
      切換會觸發全部 effect 重新編譯，需要數秒。

  Only Load Active Effects
      只編譯 preset 裡有啟用的 effect。shader 資料夾很大時，載入會快非常多。
      需要臨時載入全部時，按旁邊的 Load All Effects。

疑難排解
--------
  * 如果 effect 編譯失敗，展開左側面板最下方的 Log 查看原因。
  * 程式若異常結束，同資料夾會產生 OfflineReShadeWinUI.crash.log。
  * 設定會存在同資料夾的 OfflineReShadeWinUI.settings.json，
    刪掉它就會回到預設值。

備註
----
本版本基於 ReShade 6.8.0（非官方組建）。
未內含任何 shader，請自備。
