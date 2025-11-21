# Auto Bitrate Feature

## Overview

This PR implements an automatic bitrate adjustment feature that dynamically adapts video streaming bitrate based on real-time network conditions. Users can enable this feature via a checkbox in the settings UI.

## Key Features

- ✅ **Auto Bitrate Checkbox**: Simple toggle in settings to enable/disable automatic bitrate adjustment
- ✅ **Network Condition Monitoring**: Uses bandwidth tracking and connection status to assess network quality
- ✅ **Dynamic Adjustment**: Automatically reduces bitrate on poor connections and increases on good connections
- ✅ **Non-Disruptive**: Updates preferences for future sessions without interrupting current stream
- ✅ **UI Feedback**: Bitrate slider is disabled and label shows "(Auto)" when auto mode is enabled

## Design Documentation

📖 **For detailed architecture, flow diagrams, and implementation details, see the [Auto Bitrate Feature Design Document](docs/auto-bitrate-design.md)**

The design document includes:
- System architecture diagrams
- Mermaid flowcharts showing the adjustment logic
- State diagrams for feature lifecycle
- Sequence diagrams for component interactions
- Detailed explanation of network condition monitoring
- Bitrate adjustment strategies and constraints

## Changes Made

### UI Changes
- Added "Auto bitrate" checkbox in `SettingsView.qml`
- Disabled bitrate slider when auto mode is enabled
- Updated bitrate label to show "(Auto)" indicator
- Added tooltip explaining the feature

### Backend Changes
- Added `checkAndAdjustBitrate()` method in `Session` class
- Implemented QTimer-based periodic network condition checking
- Added bandwidth access methods to `FFmpegVideoDecoder`
- Integrated connection status monitoring for immediate adjustments
- Updated preferences when adjustments are made

### Files Modified
- `app/gui/SettingsView.qml` - UI components
- `app/streaming/session.h` - Session class interface
- `app/streaming/session.cpp` - Bitrate adjustment logic
- `app/streaming/video/ffmpeg.h` - Bandwidth access interface
- `app/streaming/video/ffmpeg.cpp` - Bandwidth access implementation

## How It Works

1. **User enables auto bitrate** via checkbox in settings
2. **When streaming starts**, a timer begins checking network conditions every 5 seconds
3. **Network conditions are assessed** using:
   - Average bandwidth from `BandwidthTracker`
   - Peak bandwidth measurements
   - Connection status from Limelight (`CONN_STATUS_POOR`/`CONN_STATUS_OKAY`)
4. **Bitrate is adjusted** based on conditions:
   - Poor connection: Reduce by 20% (minimum 500 kbps)
   - Good connection with headroom: Increase gradually (up to 10% at a time, capped at 80% of available bandwidth)
5. **Preferences are updated** for future sessions (current session continues with initial bitrate)

## Testing

- [x] UI toggle works correctly
- [x] Slider disabled when auto mode enabled
- [x] Bitrate label updates correctly
- [x] Timer starts/stops appropriately
- [x] Network condition monitoring functional
- [x] Bitrate adjustment logic tested
- [x] Preferences persist correctly

## Limitations

- Bitrate adjustments apply to future sessions only (current session continues with initial bitrate)
- This is intentional to avoid disrupting active streams
- The system learns and adapts across sessions

## Future Enhancements

See the design document for potential future improvements including in-session adjustment support if Limelight API allows it.
