# Tweety

X (Twitter) voice assistant app for iOS with real-time voice chat.

## Project Structure

- **`iOS/Tweety/Audio/`** - Audio streaming and voice activity detection (VAD)
- **`iOS/Tweety/Voice Service/`** - Grok and OpenAI voice service integration
- **`iOS/Tweety/X/`** - X API client, tool definitions and orchestration
- **`iOS/Tweety/UI/`** - SwiftUI views: voice assistant, authentication, settings, conversation history
- **`iOS/Tweety/Authentication/`** - X OAuth2, App Attest, keychain
- **`iOS/Tweety/Store/`** - In-app purchases, StoreKit, credits management
- **`iOS/Tweety/Usage/`** - Usage tracking and cost analytics
- **`Server/tweety-server/`** - Cloudflare Worker for API key handling, OAuth2, and credit tracking
