#  Analytics

Tweety uses Firebase Analytics with a custom event system that automatically enriches all events with generic device/app properties.

## Implementation

Events are defined as `Encodable` structs in `Analytics/Events/`, wrapped by the `AppEvent` enum for type-safe logging:

```swift
AnalyticsManager.log(.voiceSessionBegan(
    VoiceSessionBeganEvent(sessionLaunchTimeMs: 1250)
))
```

All events are automatically enriched with `GenericProperties` before being sent to Firebase.

### Generic Properties (Added to All Events)

These properties are automatically added to every event:

- `gitRevision`: Exact commit hash - enables perfect reproducibility for debugging
- `localizedName`: App name shown to users - tracks A/B testing or region-specific branding
- `debugBuild`: Filters out internal testing from production analytics - prevents skewed metrics
- `isSimulator`: Excludes simulator sessions - simulators don't reflect real device performance or behavior
- `physicalMemory`: RAM amount (bytes) - correlates memory crashes, optimizes cache sizes, sets background processing limits
- `physicalCores`: Core count - profiles performance on lower-end devices
- `screenSize`: Resolution (e.g., "390x844") - reveals layout bugs, optimizes for common sizes, validates tap target sizes
- `screenScale`: @2x/@3x - optimizes image asset delivery and bandwidth usage

### Properties Already Tracked by Firebase*

These are automatically collected by Firebase and do not need to be manually added:

- `bundleID`: Distinguishes production vs beta vs different app variants
- `version`: User-facing version (e.g., "1.2.0")
- `build`: Internal build number
- `deviceType`: iPhone/iPad/Mac/Watch/TV
- `deviceModel`: Specific model (e.g., "iPhone 15 Pro")
- `systemName`: iOS/macOS/etc.
- `systemVersion`: iOS version (e.g., "17.2")
- `country`: User's country
- `language`: Device language
- Firebase Installation ID (FID): Persistent anonymous identifier for tracking unique users
- Session tracking: Automatic session start/end events

*See "Automatically Logged User Attributes" below for full Firebase auto-tracking details

### Automatically Logged User Attributes (Google Analytics)

The following user dimensions are automatically collected by Google Analytics:

| User Dimension | Type | Platforms | Description |
|----------------|------|-----------|-------------|
| Age | Text | app, web | The age of the user by bracket: 18-24, 25-34, 35-44, 45-54, 55-64, and 65+ |
| App store | Text | app | The store from which the app was downloaded and installed |
| App version | Text | app | The versionName (Android) or the Bundle version (iOS) |
| Browser | Text | web | The browser from which user activity originated |
| City | Text | app, web | The city from which user activity originated |
| Continent | Text | app, web | The continent from which user activity originated |
| Country | Text | app, web | The country from which user activity originated |
| Device brand | Text | app, web | The brand name of the mobile device (such as Motorola, LG, or Samsung) |
| Device category | Text | app, web | The category of the mobile device (such as mobile or tablet) |
| Device model | Text | app | The mobile device model name (such as iPhone 5s or SM-J500M) |
| Gender | Text | app, web | The gender of the user (male or female) |
| Interests | Text | app, web | The interests of the user (such as Arts & Entertainment, Games, Sports) |
| Language | Text | app, web | The language setting of the device OS (such as en-us or pt-br) |
| New/Established | N/A | app | New: First opened the app within the last 7 days. Established: First opened the app more than 7 days ago |
| Operating system | Text | app, web | The operating system used by visitors to your website or mobile app |
| OS version | Text | app, web | The operating system version used by visitors to your website or mobile app (such as 9.3.2 or 5.1.1) |
| Platform | Text | app, web | The platform on which your website or mobile app ran (such as web, iOS, or Android) |
| Region | Text | app, web | The geographic region from which user activity originated |
| Subcontinent | Text | app, web | The subcontinent from which user activity originated |

### Events

All events are defined in `Analytics/Events/` and logged via `AppEvent` enum.

#### Login Events
- `login_screen_shown`: Login screen is displayed
- `login_button_pressed`: User taps "Login with X"

#### Voice Session Events
- `voice_assistant_screen_shown`: Voice assistant screen is displayed
- `voice_session_start_button_pressed`: User taps session start button
- `voice_session_began`: Session successfully connected (includes `session_launch_time_ms`)
- `voice_session_stop_button_pressed`: User taps stop button
- `voice_session_stopped_abruptly`: Session ended unexpectedly (includes `reason`)
- `session_rejected`: Session start rejected (includes `reason`: no subscription, no credits, etc.)
- `voice_model_event`: Voice model events (includes `event_type`, obscures sensitive data)
- `user_session_event`: User session events (includes `event_type`, obscures sensitive data)

#### Purchase Events
- `subscribe_btn_chat_error`: Subscribe button pressed from chat error
- `subscribe_succeeded_from_chat_error`: Subscription purchase succeeded from chat error (includes `product_id`, `price`, `currency`)
- `subscribe_failed_from_chat_error`: Subscription purchase failed from chat error (includes `product_id`, `error_reason`)
- `subscribe_btn_settings`: Subscribe button pressed from settings
- `subscribe_succeeded_from_settings`: Subscription purchase succeeded from settings (includes `product_id`, `price`, `currency`)
- `subscribe_failed_from_settings`: Subscription purchase failed from settings (includes `product_id`, `error_reason`)
- `credits_btn_chat_error`: Credits purchase button pressed from chat error
- `credits_success_chat_error`: Credits purchase succeeded from chat error (includes `product_id`, `price`, `currency`, `credits_amount`)
- `credits_failed_chat_error`: Credits purchase failed from chat error (includes `product_id`, `error_reason`)
- `credits_btn_settings`: Credits purchase button pressed from settings
- `credits_success_settings`: Credits purchase succeeded from settings (includes `product_id`, `price`, `currency`, `credits_amount`)
- `credits_failed_settings`: Credits purchase failed from settings (includes `product_id`, `error_reason`)

#### UI Events
- `batch_tweets_view_opened`: Batch tweets view opened full screen
- `tool_confirmation_button_pressed`: Confirm/Cancel button pressed (includes `action`, `tool_name`)
- `app_lifecycle_changed`: App lifecycle stage changed (includes `stage`)

