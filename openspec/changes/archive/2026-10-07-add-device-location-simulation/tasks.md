## 1. Project Setup and Platform Boundary

- [x] 1.1 建立 macOS SwiftUI App 的最小專案結構、建置設定與測試 target，確認最低 macOS 版本與 Swift concurrency 設定。
- [x] 1.2 建立 Presentation、Application、Domain、Ports、Adapters 的模組／目錄邊界，並加入 MapKit、CoreLocation 所需 framework 權限與使用說明。
- [x] 1.3 確認可支援的 iOS 版本、裝置列舉方式、開發者模式與模擬定位授權流程，將實際控制限制記錄在 iOS adapter 文件中。

## 2. Domain Models and Control State

- [x] 2.1 建立裝置摘要、裝置連線狀態、座標、LocationSnapshot、目標點與路徑模型，包含來源與最後成功更新時間。
- [x] 2.2 建立輸入錯誤、裝置不可用、授權、外部服務、命令傳送與取消等可呈現的錯誤模型。
- [x] 2.3 實作座標格式與緯度／經度範圍驗證，覆蓋有效、無效與邊界輸入測試。
- [x] 2.4 實作速度值驗證與 km/h 至 m/s 換算，固定第一版最大值為 60 km/h，覆蓋零值、負值、超限與小數測試。
- [x] 2.5 實作路徑採樣、依速度計算時間與位置插值的純 domain service，使用虛擬時間測試距離、速度與預估時間。
- [x] 2.6 實作搖桿方向／幅度轉換為相對座標位移的純 domain service，覆蓋中心、四方位、幅度上限與邊界座標測試。

## 3. Ports, Session, and Scheduling

- [x] 3.1 定義 DeviceProvider、LocationController、Geocoder、RoutePlanner 與時鐘／排程器 port，讓上層不依賴 Apple framework 或真實裝置 SDK。
- [x] 3.2 實作裝置 session 狀態機，涵蓋掃描、ready、路徑規劃、路徑執行、暫停、停止、手動控制、斷線與錯誤轉移。
- [x] 3.3 實作路徑控制 coordinator，提供開始、暫停、繼續、停止、取消與錯誤中止，並保證停止或斷線後不再送定位命令。
- [x] 3.4 實作搖桿控制 coordinator，將輸入合併為最新待送位置並以 1 Hz 排程；release、視窗失焦與斷線時取消排程。
- [x] 3.5 實作 route 與 joystick 的單一控制 owner，驗證兩者不可同時寫入同一目標裝置。
- [x] 3.6 建立 fake device、geocoder、route planner 與 location controller，供 UI preview、整合測試與錯誤情境使用。

## 4. Apple Map and Location Adapters

- [x] 4.1 建立 MapKit 地圖容器與可觀察地圖狀態，支援平移、縮放、目前位置、搜尋結果、單一目標點與路徑 overlay。
- [x] 4.2 以 `CLGeocoder` 建立地址搜尋 adapter，處理空輸入、無結果、網路／服務錯誤、取消與結果選擇後的地圖定位。
- [x] 4.3 以 `MKDirections` 建立路徑規劃 adapter，將結果轉換為 domain 路徑與距離／預估時間，並處理無法規劃與取消。
- [x] 4.4 建立 Apple adapter 的錯誤轉換與測試替身，確保 MapKit／CoreLocation 細節不外洩至 domain。

## 5. Device Selection and Location UI

- [x] 5.1 建立裝置掃描畫面，顯示掃描中、空清單、裝置名稱／平台／型號／狀態與重新掃描操作。
- [x] 5.2 建立目標裝置選擇與連線狀態區塊，停用未授權裝置的定位控制並提供可理解的恢復提示。
- [x] 5.3 建立地圖工具列，支援地址搜尋、座標輸入、輸入驗證、搜尋結果選擇與目標點取代。
- [x] 5.4 建立目前位置、目標點、路徑預覽、距離、預估時間與控制狀態的 UI 綁定。
- [x] 5.5 建立點到點速度輸入與開始／暫停／繼續／停止控制，顯示 60 km/h 上限及錯誤狀態。
- [x] 5.6 建立 1 Hz 搖桿 UI，處理拖曳、放開、失焦、不可用與路徑控制衝突提示。
- [x] 5.7 將所有 async 操作的 loading、取消、斷線、權限與錯誤狀態接到 UI，避免背景 task 在 view 消失後持續更新。

## 6. iOS Device Adapter

- [x] 6.1 依已確認的 Apple 開發者工具與授權流程實作 iOS 裝置列舉 adapter，回傳穩定識別碼與可控制狀態。
- [x] 6.2 實作 iOS 模擬定位命令 adapter，支援目前位置寫入、成功／失敗回報、取消與斷線事件。
- [x] 6.3 將 iOS adapter 接入 session 與控制 coordinator，驗證授權不足與裝置斷線時不會繼續送命令。
- [x] 6.4 在無真實裝置的環境以 fake adapter 完成端到端流程測試，並以實機驗證裝置掃描與單點／路徑／搖桿命令。

## 7. Verification and Release Readiness

- [x] 7.1 補齊 domain、session、路徑生命週期、搖桿節流與錯誤恢復的單元測試。
- [x] 7.2 補齊 SwiftUI 畫面在無裝置、無結果、無法規劃、斷線與控制衝突情境的 UI／整合測試。
- [x] 7.3 以 fake services 驗證 MapKit、`CLGeocoder`、`MKDirections` adapter 的取消、錯誤與狀態轉換。
- [x] 7.4 以實機完成 iOS 裝置選擇、固定點定位、60 km/h 上限、路徑暫停／恢復／停止與搖桿 1 Hz 更新驗收。
- [x] 7.5 檢查權限說明、API 使用限制、敏感資訊與 debug log，確認未將裝置控制命令或服務憑證寫入公開 log。

## 8. Follow-up Location and Mode UX

- [x] 8.1 啟動時透過 macOS `CLLocationManager` 取得使用者目前位置，處理授權與定位失敗提示，並將地圖初始視角移至使用者位置。
- [x] 8.2 新增點到點／搖桿 segmented mode 切換，切換時停止舊模式的背景控制 task。
- [x] 8.3 點到點模式支援獨立開始／結束地點；搖桿模式支援使用搜尋／座標目標或使用者目前位置作為起點。
- [x] 8.4 將未接入真實 iOS 控制協定的預設 controller 改為明確錯誤回報，避免 fake 成功造成手機位置未變但 UI 顯示成功。
