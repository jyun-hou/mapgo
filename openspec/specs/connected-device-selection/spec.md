## Purpose

讓使用者能辨識電腦目前可控制的手機與平板，選定單一目標裝置，並在控制前清楚知道連線與可用狀態。此能力也負責處理裝置授權、連線變化與目標裝置中斷。

## Requirements

### Requirement: Discover connected devices

系統 SHALL 在進入裝置選擇流程時掃描電腦可辨識的手機與平板，並為每個結果提供穩定識別碼、裝置名稱、平台、型號（若可取得）與連線狀態。

#### Scenario: Devices are discovered

- **WHEN** 使用者開啟裝置選擇畫面或要求重新掃描
- **THEN** 系統顯示掃描中的狀態，完成後列出目前可辨識的手機與平板

#### Scenario: No device is available

- **WHEN** 掃描完成但沒有可控制裝置
- **THEN** 系統顯示沒有裝置的說明、可能的連線或授權檢查方向，並提供重新掃描操作

### Requirement: Select a target device

系統 SHALL 讓使用者選擇一個已連線且可控制的裝置作為模擬定位目標，並在選擇後持續顯示目標裝置摘要與連線狀態。

#### Scenario: A device is selected

- **WHEN** 使用者選擇清單中的可控制裝置
- **THEN** 系統將該裝置設為目標，並啟用地圖與定位控制功能

#### Scenario: Device is not ready

- **WHEN** 使用者選擇的裝置需要授權、開發者模式或其他前置條件
- **THEN** 系統標示不可控制原因，且不得開始模擬定位

### Requirement: Handle target disconnection

系統 SHALL 在目標裝置斷線或失去控制權限時停止對該裝置發送新的定位命令，保留目前 UI 狀態並通知使用者。

#### Scenario: Target disconnects during simulation

- **WHEN** 路徑移動或搖桿控制進行中失去目標裝置連線
- **THEN** 系統將控制狀態標示為中斷、停止後續命令，並提供重新連線或重新選擇裝置的操作
