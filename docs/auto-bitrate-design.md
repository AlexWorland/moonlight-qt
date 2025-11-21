# Auto Bitrate Feature Design Document

## Overview

The Auto Bitrate feature automatically adjusts video streaming bitrate based on real-time network conditions during an active streaming session. This ensures optimal streaming quality by dynamically adapting to available bandwidth and connection quality.

**Key Point**: The feature does **not** grow bitrate unbounded. It respects multiple caps including measured bandwidth (with safety margin), default bitrate for the resolution/FPS setting, and hard limits (150 Mbps default, 500 Mbps if unlocked). See [Maximum Bitrate Limits](#maximum-bitrate-limits) for details.

## Goals

- **Adaptive Quality**: Automatically adjust bitrate to match network conditions
- **User-Friendly**: Simple checkbox toggle in settings UI
- **Non-Disruptive**: Updates preferences for future sessions without interrupting current stream
- **Intelligent**: Uses multiple signals (bandwidth tracking, connection status) for decision-making

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  SettingsView.qml                                    │  │
│  │  - Auto Bitrate Checkbox                             │  │
│  │  - Bitrate Slider (disabled when auto enabled)      │  │
│  │  - Bitrate Display Label                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Preferences
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              StreamingPreferences                          │
│  - autoAdjustBitrate: bool                                 │
│  - bitrateKbps: int                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Used by
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Session Class                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  - QTimer* m_BitrateAdjustTimer                      │  │
│  │  - int m_LastConnectionStatus                        │  │
│  │  - int m_LastAdjustedBitrate                         │  │
│  │  - checkAndAdjustBitrate()                           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Monitors
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Network Condition Sources                      │
│  ┌──────────────────────┐  ┌──────────────────────────┐  │
│  │ BandwidthTracker     │  │ Connection Status         │  │
│  │ - GetAverageMbps()   │  │ - CONN_STATUS_POOR        │  │
│  │ - GetPeakMbps()       │  │ - CONN_STATUS_OKAY        │  │
│  └──────────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## System Flow

### High-Level Flow Diagram

```mermaid
graph TD
    A[User Enables Auto Bitrate] --> B[Session Starts]
    B --> C[Connection Established]
    C --> D[Start Bitrate Adjustment Timer]
    D --> E{Timer Fires Every 5s}
    E --> F[Check Network Conditions]
    F --> G{Connection Status?}
    G -->|POOR| H[Reduce Bitrate by 20%]
    G -->|OKAY| I{Bandwidth Available?}
    I -->|Yes, >120% current| J[Increase Bitrate Gradually]
    I -->|No| K[Keep Current Bitrate]
    H --> L[Update Preferences]
    J --> L
    K --> E
    L --> M[Log Adjustment]
    M --> E
    N[Connection Terminated] --> O[Stop Timer]
```

### Detailed Bitrate Adjustment Flow

```mermaid
flowchart TD
    Start([checkAndAdjustBitrate Called]) --> Check1{Auto Bitrate Enabled?}
    Check1 -->|No| Stop1[Stop Timer & Return]
    Check1 -->|Yes| Check2{Video Decoder Available?}
    Check2 -->|No| Stop1
    Check2 -->|Yes| GetBW[Get Bandwidth Metrics]
    GetBW --> GetAvg[Get Average Bandwidth Mbps]
    GetBW --> GetPeak[Get Peak Bandwidth Mbps]
    GetAvg --> CheckStatus{Connection Status}
    GetPeak --> CheckStatus
    
    CheckStatus -->|CONN_STATUS_POOR| PoorLogic[Calculate Reduction]
    PoorLogic --> Reduce[Reduce by 20%<br/>Min: 500 kbps]
    Reduce --> CheckChange{Change Significant?}
    
    CheckStatus -->|CONN_STATUS_OKAY| GoodLogic{Bandwidth > 120%<br/>Current Bitrate?}
    GoodLogic -->|Yes| IncreaseLogic[Calculate Increase]
    IncreaseLogic --> CapCheck[Cap at 80% bandwidth<br/>or Default Bitrate]
    CapCheck --> Increase[Increase by 10%<br/>Max: Calculated Cap]
    Increase --> CheckChange
    GoodLogic -->|No| CheckChange
    
    CheckChange -->|Yes, >=5% or 1000kbps| UpdatePref[Update Preferences]
    CheckChange -->|No| Return[Return]
    UpdatePref --> Log[Log Adjustment]
    Log --> Return
    Stop1 --> End([End])
    Return --> End
```

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Disabled: User Disables
    
    Disabled --> Enabled: User Checks Box
    Enabled --> Monitoring: Connection Started
    
    Monitoring --> Checking: Timer Fires (5s)
    Checking --> Adjusting: Conditions Changed
    Checking --> Monitoring: No Change Needed
    
    Adjusting --> Updating: Calculate New Bitrate
    Updating --> Monitoring: Preferences Updated
    
    Monitoring --> Stopped: Connection Terminated
    Stopped --> [*]
    
    Enabled --> Disabled: User Unchecks Box
    Disabled --> [*]
    
    note right of Monitoring
        Continuously monitors:
        - Bandwidth (avg/peak)
        - Connection status
        - Current bitrate
    end note
    
    note right of Adjusting
        Adjustments:
        - Poor: -20%
        - Good: +10% (capped)
    end note
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant UI as SettingsView
    participant Prefs as StreamingPreferences
    participant Session
    participant Timer as QTimer
    participant Decoder as FFmpegVideoDecoder
    participant BW as BandwidthTracker
    participant Limelight as Connection Status

    User->>UI: Enable Auto Bitrate Checkbox
    UI->>Prefs: Set autoAdjustBitrate = true
    
    User->>Session: Start Stream
    Session->>Session: Initialize Connection
    Session->>Limelight: LiStartConnection()
    Limelight-->>Session: connectionStarted()
    Session->>Timer: Start (5s interval)
    
    loop Every 5 seconds
        Timer->>Session: timeout()
        Session->>Session: checkAndAdjustBitrate()
        Session->>Decoder: Get Bandwidth Info
        Decoder->>BW: GetAverageMbps()
        BW-->>Decoder: avgBandwidth
        Decoder->>BW: GetPeakMbps()
        BW-->>Decoder: peakBandwidth
        Decoder-->>Session: Bandwidth Metrics
        
        Session->>Session: Check Connection Status
        Session->>Session: Evaluate Conditions
        
        alt Poor Connection
            Session->>Session: Calculate Reduction (20%)
            Session->>Prefs: Update bitrateKbps
            Session->>Session: Log Adjustment
        else Good Connection & High Bandwidth
            Session->>Session: Calculate Increase (10%)
            Session->>Session: Apply Caps
            Session->>Prefs: Update bitrateKbps
            Session->>Session: Log Adjustment
        end
    end
    
    Limelight->>Session: Connection Terminated
    Session->>Timer: Stop()
    Session->>Session: Cleanup
```

## Network Condition Monitoring

### Bandwidth Tracking

The `BandwidthTracker` class maintains a sliding window of network throughput:

- **Window Size**: 10 seconds
- **Bucket Interval**: 250ms
- **Average Calculation**: Uses most recent 25% of buckets (2.5 seconds)
- **Peak Calculation**: Highest throughput in any single bucket

### Bandwidth Detection Logic

The system determines "available bandwidth" by measuring actual network throughput:

1. **Measurement**: `BandwidthTracker` tracks bytes received from the video stream over time
2. **Average Bandwidth**: Calculated from the most recent 2.5 seconds of data (25% of 10-second window)
3. **Available Bandwidth Check**: System considers bandwidth "available" if:
   - `averageBandwidthMbps > currentBitrateMbps × 1.2` (at least 20% headroom)

### Maximum Bitrate Limits

The auto bitrate feature does **not** grow unbounded. It respects two caps:

1. **80% of Measured Bandwidth**: Uses only 80% of measured average bandwidth as a safety margin
   - Formula: `bandwidthMax = avgBandwidthMbps × 1000 × 0.8`
   - Prevents saturating the connection by leaving 20% headroom

2. **Slider Maximum**: Uses the bitrate slider's maximum value as the absolute cap
   - **150 Mbps** (150,000 kbps) if `unlockBitrate` is disabled (default)
   - **500 Mbps** (500,000 kbps) if `unlockBitrate` is enabled (experimental)
   - This is the same maximum value shown in the UI slider

3. **Final Maximum**: The system uses the **minimum** of these two caps:
   ```
   maxBitrate = min(
       80% of measured bandwidth,
       slider maximum (150 Mbps or 500 Mbps)
   )
   ```

**Example**: If measured bandwidth is 200 Mbps, the system calculates 160 Mbps (80% of 200 Mbps). If the slider max is 150 Mbps, the system caps at 150 Mbps. If unlockBitrate is enabled (500 Mbps max), it would cap at 160 Mbps (the bandwidth limit).

### Connection Status

The Limelight library provides connection status updates:

- `CONN_STATUS_POOR`: Network conditions are degraded
- `CONN_STATUS_OKAY`: Network conditions are acceptable

These status updates trigger immediate bitrate adjustment checks.

## Bitrate Adjustment Logic

### Reduction Strategy (Poor Connection)

When `CONN_STATUS_POOR` is detected:

1. **Calculation**: `newBitrate = currentBitrate × 0.8`
2. **Minimum**: Never go below 500 kbps
3. **Threshold**: Only adjust if change ≥ 5% or ≥ 1000 kbps
4. **Action**: Update `StreamingPreferences.bitrateKbps`

### Increase Strategy (Good Connection)

When `CONN_STATUS_OKAY` and bandwidth headroom exists:

1. **Condition**: `avgBandwidth > currentBitrate × 1.2` (at least 20% headroom detected)
2. **Calculation**: `newBitrate = min(currentBitrate × 1.1, maxBitrate)`
   - Increases gradually by 10% per adjustment
   - Never exceeds the calculated maximum (see Maximum Bitrate Limits above)
3. **Caps Applied**:
   - **80% of measured bandwidth**: Safety margin to avoid saturating the connection
   - **Slider maximum**: 150 Mbps (or 500 Mbps if unlockBitrate enabled)
   - System uses the **minimum** of these two caps
4. **Threshold**: Only adjust if `newBitrate > currentBitrate + 1000 kbps`
5. **Action**: Update `StreamingPreferences.bitrateKbps`

**Important**: The system uses the bitrate slider's maximum value as the single source of truth for the absolute maximum bitrate. This ensures consistency between manual and automatic bitrate settings.

### Adjustment Constraints

- **Minimum Change**: 5% of current bitrate OR 1000 kbps (whichever is larger)
- **Update Frequency**: Checked every 5 seconds
- **Immediate Triggers**: Connection status changes
- **Persistence**: Updates preferences for future sessions

## User Interface

### Settings View Components

1. **Auto Bitrate Checkbox**
   - Location: Below bitrate slider in Basic Settings
   - Tooltip: Explains automatic adjustment behavior
   - Binding: `StreamingPreferences.autoAdjustBitrate`

2. **Bitrate Slider**
   - State: Disabled when auto bitrate is enabled
   - Behavior: Manually moving slider disables auto bitrate
   - Visual: Shows current bitrate value

3. **Bitrate Display Label**
   - Format: `"Video bitrate: X.X Mbps"` or `"Video bitrate: X.X Mbps (Auto)"`
   - Updates: Reacts to both bitrate and auto mode changes

### Debug Stats Overlay

The performance overlay (enabled via "Show performance stats while streaming" checkbox) displays bandwidth information:

- **Bandwidth Display**: Shows average and peak bandwidth measurements
- **Format**: `"Bandwidth: X.X Mbps avg, X.X Mbps peak (10s window)"`
- **Location**: Appears in the debug stats overlay alongside other performance metrics
- **Purpose**: Helps users monitor network conditions and understand auto bitrate adjustments
- **Update Frequency**: Updated approximately every second along with other stats

### UI State Diagram

```mermaid
stateDiagram-v2
    [*] --> ManualMode: Initial State
    
    ManualMode --> AutoMode: Check Auto Bitrate
    AutoMode --> ManualMode: Uncheck Auto Bitrate
    
    ManualMode --> SliderEnabled: Slider Active
    AutoMode --> SliderDisabled: Slider Disabled
    
    SliderEnabled --> ManualMode: User Moves Slider
    SliderDisabled --> AutoMode: Auto Adjusting
    
    note right of AutoMode
        Label shows "(Auto)"
        Slider disabled
        Preferences update automatically
    end note
    
    note right of ManualMode
        Label shows bitrate only
        Slider enabled
        User controls bitrate
    end note
```

## Implementation Details

### Timer Management

- **Creation**: Timer created in `Session` constructor
- **Start**: Timer starts when connection is established and auto bitrate is enabled
- **Stop**: Timer stops when:
  - Connection terminates
  - Auto bitrate is disabled
  - Session ends
- **Interval**: 5 seconds between checks

### Bandwidth Access

The `FFmpegVideoDecoder` exposes bandwidth metrics:

```cpp
double getAverageBandwidthMbps();
double getPeakBandwidthMbps();
```

These methods provide access to the internal `BandwidthTracker` for network condition assessment.

**Bandwidth Display**: These metrics are also displayed in the debug stats overlay (performance overlay) to help users monitor network conditions in real-time.

### Preference Updates

Bitrate adjustments update `StreamingPreferences.bitrateKbps`:

- **Immediate**: Preference value updated in memory
- **Persistence**: Saved on next `StreamingPreferences.save()` call
- **Future Sessions**: New bitrate used for subsequent streams
- **Current Session**: Continues with initial bitrate (no interruption)

## Limitations and Future Improvements

### Current Limitations

1. **No In-Session Adjustment**: Bitrate changes apply to future sessions only
   - Reason: Limelight doesn't support dynamic bitrate changes mid-stream
   - Impact: Users must restart stream to see adjusted bitrate

2. **Preference-Based**: Adjustments update preferences, not active stream
   - Reason: Avoid disrupting active session
   - Impact: Learning happens across sessions

### Potential Future Enhancements

1. **In-Session Adjustment**: If Limelight API supports it, adjust bitrate during active stream
2. **More Granular Control**: Separate thresholds for increase/decrease
3. **User Overrides**: Allow temporary manual override without disabling auto mode
4. **Statistics Display**: Show adjustment history in performance overlay
5. **Adaptive Timing**: Adjust check interval based on connection stability

## Testing Considerations

### Test Scenarios

1. **Enable/Disable Toggle**: Verify UI state changes correctly
2. **Poor Connection**: Verify bitrate reduction logic
3. **Good Connection**: Verify bitrate increase logic
4. **Boundary Conditions**: Test minimum/maximum bitrate caps
5. **Timer Lifecycle**: Verify timer starts/stops correctly
6. **Preference Persistence**: Verify adjustments persist across sessions

### Metrics to Monitor

- Bitrate adjustment frequency
- Average adjustment magnitude
- Connection quality correlation
- User satisfaction with quality

## Conclusion

The Auto Bitrate feature provides an intelligent, user-friendly way to maintain optimal streaming quality by automatically adapting to network conditions. While current limitations prevent in-session adjustments, the system learns and adapts across sessions to provide the best possible experience.
