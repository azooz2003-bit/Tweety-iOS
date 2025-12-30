# GrokMode

X (Twitter) voice assistant app for iOS.

## Project Structure

- **`iOS/GrokMode/Audio/`** - Voice streaming, audio processing, XAI/OpenAI voice services
- **`iOS/GrokMode/X API/`** - X API client, tool definitions (`XTool.swift`), orchestrator, models
- **`iOS/GrokMode/UI/`** - SwiftUI views: voice assistant, conversation items, content blocks, settings
- **`iOS/GrokMode/UI/Voice Assistant/Models/`** - Conversation state, item types, tool call status
- **`Proxy/grokmode-proxy/`** - Cloudflare Worker for secure API key handling (xAI/OpenAI tokens, X OAuth2)
