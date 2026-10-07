## Purpose

提供以地圖為中心的定位操作介面，讓使用者透過地址或座標快速定位目標區域，並設定可供模擬定位使用的目標點。

## ADDED Requirements

### Requirement: Display and navigate the map

系統 SHALL 顯示可平移、縮放的地圖，並在地圖上標示目前模擬位置、搜尋結果與選定目標點（若存在）。

#### Scenario: Map is opened

- **WHEN** 使用者已選擇可控制裝置並開啟定位控制
- **THEN** 系統顯示地圖與目前模擬位置；若沒有位置則顯示尚未設定位置的狀態

### Requirement: Search an address

系統 SHALL 接受地址文字搜尋，並顯示可供使用者選擇的地理編碼結果；選擇結果後，地圖 SHALL 移動至該位置並標示目標點。

#### Scenario: Address search succeeds

- **WHEN** 使用者輸入有效地址並選擇搜尋結果
- **THEN** 系統將地圖中心移至結果座標、顯示目標標記，並保留地址與座標資訊

#### Scenario: Address search has no result

- **WHEN** 地址服務找不到符合的結果
- **THEN** 系統顯示無結果訊息，不改變目前地圖中心與既有目標點

### Requirement: Accept coordinates

系統 SHALL 接受有效的緯度與經度輸入，並拒絕超出地理範圍或格式不正確的座標。

#### Scenario: Coordinate input is valid

- **WHEN** 使用者輸入有效緯度與經度
- **THEN** 系統移動地圖至該座標並設定為目標點

#### Scenario: Coordinate input is invalid

- **WHEN** 使用者輸入無法解析或超出範圍的座標
- **THEN** 系統顯示欄位錯誤，不發送定位命令且不覆蓋既有目標點

### Requirement: Set a single target point

系統 SHALL 讓使用者以地圖點選或搜尋結果設定單一目標點，並在下一次設定時取代前一個目標點。

#### Scenario: Target point is replaced

- **WHEN** 使用者在已有目標點時設定另一個目標點
- **THEN** 系統只保留新的目標點，並更新可用的定位操作

### Requirement: Initialize from the user's location

系統 SHALL 在啟動後要求 macOS 位置權限，並在取得使用者目前位置後將地圖初始視角移至該座標；若無法取得位置，系統 SHALL 保留地圖功能並顯示可理解的錯誤。

#### Scenario: User location is available

- **WHEN** 使用者允許位置權限且系統收到目前位置
- **THEN** 系統將地圖中心移至使用者位置，並可將該位置設定為模擬起點

#### Scenario: User location is unavailable

- **WHEN** 使用者拒絕權限或位置服務回報失敗
- **THEN** 系統顯示錯誤提示，不阻止使用者以地址或座標設定地點
