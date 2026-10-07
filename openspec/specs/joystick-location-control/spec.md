## Purpose

提供低延遲且可理解的手動定位控制，讓使用者透過搖桿方向與幅度微調選定裝置的模擬位置，並在不同控制模式間維持清楚且不衝突的操作狀態。

## Requirements

### Requirement: Display a joystick control

系統 SHALL 在目標裝置已就緒且目前位置已知時提供搖桿控制，並清楚顯示搖桿中心、目前方向與輸入幅度。

#### Scenario: Joystick is available

- **WHEN** 使用者選擇可控制裝置且已有有效模擬位置
- **THEN** 系統顯示可操作搖桿與手動控制狀態

#### Scenario: Joystick is unavailable

- **WHEN** 沒有目標裝置、位置未知或路徑模擬正在獨占控制
- **THEN** 系統停用搖桿並顯示不可用原因

### Requirement: Configure joystick start location

系統 SHALL 讓使用者以地址／座標選擇搖桿起始位置，或直接使用 macOS 使用者目前位置作為起點。

#### Scenario: User starts from current location

- **WHEN** 使用者選擇「使用目前位置」
- **THEN** 系統將目前使用者座標設為搖桿起點與模擬初始位置

#### Scenario: User selects another location

- **WHEN** 使用者以地址／座標設定搖桿起始位置
- **THEN** 系統將該座標設為搖桿起點並更新地圖標記

### Requirement: Move location manually

系統 SHALL 將搖桿方向與幅度轉換為相對位移，並以預設每秒 1 次（1 Hz）的控制更新頻率更新目標裝置位置；放開搖桿後 SHALL 停止位移。

#### Scenario: User drags the joystick

- **WHEN** 使用者將搖桿由中心拖向某方向
- **THEN** 系統依方向與幅度產生相對位移，更新地圖上的目前位置並傳送定位更新

#### Scenario: User releases the joystick

- **WHEN** 使用者放開搖桿或將其返回中心
- **THEN** 系統停止產生新的手動位移，並將搖桿回到中心狀態

#### Scenario: Joystick updates are rate limited

- **WHEN** 使用者在一秒內持續拖曳搖桿
- **THEN** 系統最多產生一次對目標裝置的定位更新，並保留該秒結束時的最新位移

### Requirement: Prevent conflicting controls

系統 SHALL 防止搖桿控制與點到點路徑模擬同時寫入目標裝置的位置。

#### Scenario: Route movement is active

- **WHEN** 路徑模擬正在移動且使用者嘗試操作搖桿
- **THEN** 系統不接受搖桿定位更新，並提示先暫停或停止路徑模擬
