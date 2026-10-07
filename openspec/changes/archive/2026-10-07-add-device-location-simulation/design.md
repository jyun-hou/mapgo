## Context

本專案目前沒有可沿用的產品程式碼、裝置控制層或既有地圖能力，因此本 change 需要建立最小的分層骨架。第一版固定為 macOS 原生 SwiftUI + Swift，僅支援 iOS 裝置；地圖、地理編碼與路徑分別使用 MapKit、`CLGeocoder` 與 `MKDirections`。實際 iOS 模擬定位控制協定仍透過 adapter 隔離。

## Goals / Non-Goals

**Goals:**

- 建立可替換的裝置控制、地理編碼、路徑規劃與地圖呈現邊界。
- 讓 UI 只依賴可觀察的裝置與定位狀態，不直接處理平台命令或計時細節。
- 將點到點與搖桿視為互斥的定位控制 session，避免兩個來源同時寫入位置。
- 以可測試的純邏輯處理座標驗證、速度換算、路徑採樣與搖桿位移。
- 對裝置斷線、權限不足、外部服務失敗與定位命令失敗提供可恢復狀態。

**Non-Goals:**

- 本 change 不實作真實手機／平板平台的底層控制協定，需在平台與授權條件確認後接入 adapter。
- 不包含正式帳號、雲端同步、歷史路徑儲存或多人協作。
- 不提供背景常駐控制、跨電腦遠端控制或未經授權的裝置操作。
- 不在第一版承諾高精度導航級定位、Android 裝置或第三方地圖服務。

## Decisions

### 1. 採用 ports-and-adapters 邊界

將系統分為：Presentation（裝置選擇、地圖、路徑、搖桿）、Application（裝置 session 與控制狀態機）、Domain（座標、路徑、速度與位移計算）、Ports（DeviceProvider、LocationController、Geocoder、RoutePlanner、MapRenderer），再由平台 adapter 實作 ports。

這可讓地圖 SDK、地址服務與 iOS／Android 控制方式替換，而不牽動移動狀態機。替代方案是讓 UI 直接呼叫 SDK，初期較快但會把平台差異與計時副作用散落在畫面層，後續測試及換服務成本較高。

### 2. 以明確 session 狀態機管理控制生命週期

裝置 session 至少區分 `noDevice`、`scanning`、`ready`、`routePlanning`、`routeRunning`、`routePaused`、`manualControl`、`disconnected` 與 `error`；所有命令先經由 session 驗證目前狀態，再交給定位控制 port。路徑控制與搖桿控制共用單一 owner，狀態機拒絕衝突操作。

替代方案是由每個畫面自行保存布林旗標，雖然程式碼少，但容易出現停止後仍送命令、斷線後背景計時器繼續執行等生命週期錯誤。

### 3. 將定位更新排程與路徑幾何分離

路徑規劃結果只描述有序座標與距離；Domain 層依速度計算每次更新的時間與插值位置，Application 層負責取消、暫停、恢復、背壓與將更新送至裝置。所有更新必須可取消，且在裝置回報失敗時停止後續更新。

這比直接依賴路徑服務回傳的時間或在 UI timer 中移動 marker 更可靠，也便於以虛擬時鐘測試速度與暫停行為。

### 4. 使用統一的 LocationSnapshot 與錯誤模型

目前位置、目標位置、來源（初始／路徑／搖桿）、時間戳與裝置回報狀態使用單一 domain model 傳遞。錯誤需分類為輸入錯誤、裝置不可用、授權錯誤、外部服務錯誤、命令傳送錯誤與取消，UI 才能提供對應的恢復操作。

### 5. 使用 Apple 原生地理服務

第一版使用 MapKit 顯示地圖與地圖互動，使用 `CLGeocoder` 處理地址搜尋，使用 `MKDirections` 產生路徑。這些 Apple framework 只在 adapter／presentation 邊界出現，domain 只接收標準化座標、路徑與錯誤。相較第三方服務，原生方案可減少 API key 與額外依賴；代價是需要遵守 Apple 服務限制，且未來若要跨平台仍需替換 adapter。

### 6. 固定第一版控制參數

點到點模擬速度的產品上限固定為 60 km/h（輸入與 domain 內部統一換算為 m/s）；搖桿定位更新頻率預設為 1 Hz。搖桿拖曳期間只保留最新待送位置，避免 UI 事件頻率直接造成裝置命令洪水；release、視窗失焦與斷線時立即停止排程。

## Risks / Trade-offs

- [平台控制協定未知] → 先完成 port、fake adapter 與 UI 狀態機；在正式 adapter 前確認 iOS／Android 版本、開發者模式、授權與可否寫入模擬位置。
- [Apple 地圖／路徑服務有網路限制或資料偏差] → 將 framework 呼叫隔離、集中處理 timeout／取消與錯誤，並以清楚錯誤狀態避免把失敗誤當成成功定位。
- [高頻搖桿更新造成裝置或連線負載] → 設定固定更新頻率、合併尚未送出的最新位置，並在 release／失焦／斷線時立即取消更新。
- [路徑更新與實際裝置回報不同步] → 以最後成功送達的位置作為目前位置，不因本地預估直接跳到終點；顯示傳送中與失敗狀態。
- [iOS 模擬定位控制協定未知] → 先完成 iOS 裝置 adapter port、fake adapter 與 UI 狀態機；接入真實控制前確認開發者模式、授權與可否寫入模擬位置。

## Migration Plan

這是新功能，沒有既有資料或行為需要遷移。實作時先以 fake adapters 驗證 domain 與 UI，再接入 MapKit、`CLGeocoder`、`MKDirections` 與實際 iOS 裝置 adapter；若實際 adapter 尚未可用，功能旗標應保持關閉，避免 UI 讓使用者以為已能控制真實裝置。回滾時移除功能旗標與新 adapter，不需資料庫回復。

## Open Questions

- 實際 iOS 裝置列舉與模擬定位控制所需的開發者工具、授權流程與支援的 iOS 版本，需在 adapter 實作前確認；此項不改變上層分層與規格。
