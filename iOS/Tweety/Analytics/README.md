#  Analytics

### Tracked
- `bundleID`: Distinguishes production vs beta vs different app variants
- `version`: User-facing version (e.g., "1.2.0") - correlates bugs to releases and tracks feature adoption
- `build`: Internal build number - identifies exact binary when multiple builds exist for same version
- `gitRevision`: Exact commit hash - enables perfect reproducibility for debugging
- `localizedName`: App name shown to users - tracks A/B testing or region-specific branding
- `sessionID`: Incremented launch counter - measures DAU/WAU, session frequency, crash rate per session, engagement trends
- `debugBuild`: Filters out internal testing from production analytics - prevents skewed metrics
- `isSimulator`: Excludes simulator sessions - simulators don't reflect real device performance or behavior
- `deviceID` (UUID): Persistent anonymous identifier - tracks unique users, links events across sessions, identifies retention patterns
- `deviceType`: iPhone/iPad/Mac/Watch/TV - segments by major UX differences and interaction patterns
- `deviceModel`: Specific model (e.g., "iPhone 15 Pro") - analyzes performance gaps, plans features requiring specific hardware, identifies memory constraints, informs
support decisions
- `systemName`: iOS/macOS/etc. - understands platform-specific issues for cross-platform apps
- `systemVersion`: iOS version (e.g., "17.2") - correlates OS-level bugs, determines API availability, tracks adoption for dropping old OS support
- `physicalMemory`: RAM amount (e.g., "4GB") - correlates memory crashes, optimizes cache sizes, sets background processing limits
- `cpuType`: ARM64/x86_64 - identifies architecture-specific bugs, especially for Mac Intel vs Apple Silicon
- `physicalCores`: 2-core vs 8-core - profiles performance on lower-end devices
- `country`: Identifies growing markets, optimizes server locations, determines payment support, ensures legal compliance
- `language`: Measures translation quality, identifies non-English user churn, prioritizes localization updates
- `screenSize`: Resolution (e.g., "390x844") - reveals layout bugs, optimizes for common sizes, validates tap target sizes
- `screenScale`: @2x/@3x - optimizes image asset delivery and bandwidth usage

### Events
Below are the events Tweety tracks and the information gathered:

- Login screen is shown
- `Login with X` button is pressed
- Voice Assistant screen is shown
- Voice session start button is pressed
- Session rejections (no subscription, no credits)
- "Subscribe" button pressed from chat view error
- "Subscribe" action from chat view error succeeds
- "Subscribe" presses from settings
- "Subscribe" action from settings succeeds
- "Tweety Credits purchase" presses from settings
- "Tweety Credits purchase" action from settings succeeds
- Voice session stop button is pressed
- Session stops abruptly (ran out of credits, disconnection, etc.)
- Batch of tweets view is opened full screen
- App moved to background / foreground / other lifecycle stage
- Voice model events (tool calls, audio chunks, etc.) while obscuring potentially sensitive information like audio content, tool call params, etc.
- User session events (input chunks sent, etc.) while obscuring potentially sensitive information like audio content, tool call params, etc.
- On-screen presses of Confirm / Cancel buttons in tool action confirmation preview.
- Session has officially began (fully connected to voice model and user can start speaking)
    - Session launch time in milliseconds
