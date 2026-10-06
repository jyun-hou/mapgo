# iOS 裝置控制 adapter

目前以 Xcode 內建的 `xcrun devicectl list devices --json-output -` 列舉已配對的 iOS 裝置；模擬定位命令則透過 UI Test Runner 的 TCP IPC 接收，再由 `XCUIDevice.shared.location` 套用。

`devicectl` 掃描不到裝置或回傳錯誤時，UI 會顯示掃描失敗，不會以 fake 裝置冒充真實裝置。實體裝置需要配對、信任電腦與開啟 Developer Mode；Test Runner 仍需在裝置上持續執行。

接入前需要確認：

- 支援的 iOS 版本與裝置連線方式。
- 是否要求裝置開發者模式、受信任電腦或額外授權。
- 實際定位命令 API、取消行為與斷線事件來源。
- 實機驗收時的單點、路徑、暫停／恢復／停止與搖桿更新行為。
