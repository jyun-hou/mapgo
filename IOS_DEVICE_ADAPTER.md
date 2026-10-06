# iOS 裝置控制 adapter

目前專案已完成 `DeviceProvider` 與 `LocationController` ports，以及可驗證 UI／流程的 fake adapter。

真實 iOS 裝置列舉與模擬定位尚未接入，原因是 repository 尚未指定可用的 Apple 開發者工具、裝置通訊協定、iOS 版本與授權流程。`UnavailableIOSLocationController` 會以可理解的錯誤拒絕命令，避免將未完成的功能誤當成成功定位。

接入前需要確認：

- 支援的 iOS 版本與裝置連線方式。
- 是否要求裝置開發者模式、受信任電腦或額外授權。
- 實際定位命令 API、取消行為與斷線事件來源。
- 實機驗收時的單點、路徑、暫停／恢復／停止與搖桿更新行為。
