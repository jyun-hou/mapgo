## Purpose

讓使用者將選定裝置從目前位置沿地圖可行路徑移動至目標位置，並以可預期的速度與生命週期控制模擬過程，同時能掌握規劃、執行與錯誤處理狀態。

## Requirements

### Requirement: Plan a route

系統 SHALL 在已選擇目標裝置、目前位置與目標點後，產生包含起點、終點與連續座標的可執行路徑，並在地圖上預覽該路徑。

#### Scenario: Route planning succeeds

- **WHEN** 使用者要求從目前位置前往有效目標點
- **THEN** 系統顯示路徑預覽、距離與預估時間，並允許開始模擬

#### Scenario: Route planning fails

- **WHEN** 路徑服務無法產生可行路徑或服務不可用
- **THEN** 系統顯示失敗原因，不開始移動且保留目前位置與目標點

### Requirement: Configure route endpoints

系統 SHALL 讓使用者分別設定點到點模式的開始地點與結束地點；開始地點可使用使用者目前位置，結束地點可使用搜尋或座標輸入結果。

#### Scenario: User selects separate endpoints

- **WHEN** 使用者設定開始地點與結束地點
- **THEN** 系統在地圖上分別標示兩點，並以該兩點規劃路徑

### Requirement: Configure movement speed

系統 SHALL 讓使用者以公尺／秒設定點到點移動速度，並拒絕非正數、無法解析或超出產品允許範圍的值；第一版上限 SHALL 為 60 km/h（約 16.67 m/s）。

#### Scenario: Speed is configured

- **WHEN** 使用者輸入允許範圍內的速度
- **THEN** 系統將該速度套用於下一次或尚未開始的路徑模擬，並更新預估時間

#### Scenario: Speed exceeds the maximum

- **WHEN** 使用者輸入高於 60 km/h 的速度
- **THEN** 系統顯示超過上限的錯誤且不得以該值開始模擬

#### Scenario: Speed is invalid while editing

- **WHEN** 使用者輸入無效速度
- **THEN** 系統顯示錯誤且不得以該值開始模擬

### Requirement: Execute route movement

系統 SHALL 依照路徑順序，以設定速度產生定位更新並送至目標裝置；移動狀態 SHALL 可被觀察。

#### Scenario: Route movement completes

- **WHEN** 路徑上的定位更新成功送達終點
- **THEN** 系統將狀態標示為完成、更新目前位置為終點，並停止後續更新

#### Scenario: Location update fails

- **WHEN** 任一定位更新被目標裝置拒絕或傳送失敗
- **THEN** 系統暫停移動、顯示錯誤與失敗位置，且不得默默跳到終點

### Requirement: Control route lifecycle

系統 SHALL 提供開始、暫停、繼續與停止操作；停止後不得繼續發送路徑更新，重新開始時 SHALL 明確要求使用者確認起點與路徑狀態。

#### Scenario: Movement is paused and resumed

- **WHEN** 使用者在移動中暫停後選擇繼續
- **THEN** 系統從暫停時的位置繼續沿剩餘路徑移動

#### Scenario: Movement is stopped

- **WHEN** 使用者停止路徑模擬
- **THEN** 系統停止更新並將控制狀態標示為已停止，保留最後成功的位置
