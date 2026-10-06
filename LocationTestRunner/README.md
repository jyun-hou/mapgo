# LocationTestRunner

這個專案提供第一階段的實體 iPhone 固定座標驗證。

## 使用方式

1. 用 Xcode 開啟 `LocationTestRunner.xcodeproj`。
2. 分別選取 `LocationTestHost` 與 `LocationTestHostUITests` target，打開 Signing & Capabilities，勾選 Automatically manage signing，並在 Team 選擇同一個 Apple Account Team；同時確認兩個 Bundle Identifier 唯一。
3. 使用 Xcode Device Hub 配對並選擇實體 iPhone。
4. 執行 `LocationTestHostUITests` 中的 `testSetFixedLocationOnDevice`。
5. 測試會設定 `25.0330, 121.5654`，啟動 Host App，並等待 Host App 的 Core Location 顯示 `Location: 25.033000, 121.565400`。

## macOS IPC 控制

1. 確認 Mac 與 iPhone 在同一個區域網路，取得 iPhone 的區域網路 IP。
2. 執行 `LocationTestHostUITests` 中的 `testRunLocationIPC`；這個測試會保持執行 30 分鐘並監聽 TCP port `58432`。
3. 在 Map Go 左側的 `Test Runner IPC` 輸入 iPhone IP，Port 使用 `58432`，按「套用連線設定」。
4. 選擇可控制裝置後，點到點與搖桿送出的座標會透過 IPC 傳給 Test Runner，再由 `XCUIDevice.shared.location` 更新裝置模擬位置。

這個通道只在 UI Test 執行期間有效。停止測試後，模擬定位與 IPC listener 都會停止，手機會恢復真實定位。

若最後 assertion 失敗，代表 XCTest 成功啟動 App 但裝置沒有把固定座標回傳給 Core Location；這時請先確認使用的是實體 iPhone、裝置已在 Xcode Device Hub 配對、Developer Mode 已開啟，並重新允許測試 App 使用位置。

這是 XCTest 的測試情境，不是一般 App 可直接使用的定位 API；下一階段才會加入 macOS 控制器與 Test Runner 之間的 IPC。
