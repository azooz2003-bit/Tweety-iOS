# Tweety

X (Twitter) voice assistant app for iOS with real-time voice chat.

## Project Structure

- **`iOS/Tweety/Audio/`** - Voice streaming, audio processing, Grok/OpenAI voice services, VAD
- **`iOS/Tweety/X API/`** - X API client, tool definitions and orchestration
- **`iOS/Tweety/UI/`** - SwiftUI views: voice assistant, authentication, settings, conversation history
- **`iOS/Tweety/Authentication/`** - X OAuth2, App Attest, keychain
- **`iOS/Tweety/Store/`** - In-app purchases, StoreKit, credits management
- **`iOS/Tweety/Usage/`** - Usage tracking and cost analytics
- **`Server/grokmode-proxy/`** - Cloudflare Worker for API key handling and OAuth2
