# Tweety Server

Backend for the Tweety iOS app. Handles API authentication and user credit tracking.

## What it does

Proxies xAI and OpenAI voice APIs with server-side API key management. Generates ephemeral tokens for the client and tracks credit usage per user. Also handles X OAuth.

## Setup

```bash
npm install

# Configure secrets
npx wrangler secret put X_AI_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put X_OAUTH2_CLIENT_ID
npx wrangler secret put X_OAUTH2_CLIENT_SECRET

# Dev
npx wrangler dev

# Deploy
npx wrangler deploy
```

## Security

Requests are validated using App Attest. API keys stay on the server.
