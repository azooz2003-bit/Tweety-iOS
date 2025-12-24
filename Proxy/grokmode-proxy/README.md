# GrokMode Proxy Server

Cloudflare Workers proxy for securely handling API keys and authentication for the GrokMode iOS app.

## Features

- **xAI Voice API**: Proxy for ephemeral token generation
- **OpenAI Realtime API**: Proxy for ephemeral token generation with WebRTC
- **X OAuth2**: Token exchange and refresh endpoints

## Endpoints

### 1. xAI Voice - Ephemeral Token
**Path**: `/grok/v1/realtime/client_secrets`
**Method**: POST
**Auth**: App Attest (X-Apple-Attest-Key-Id and X-Apple-Attest-Assertion headers)

Generates an ephemeral token for connecting to xAI's Realtime Voice API.

**Request Body**: None (automatically adds expires_after)

**Response**:
```json
{
  "value": "eph_abc123...",
  "expires_at": 1234567890
}
```

---

### 2. OpenAI Realtime - Ephemeral Token
**Path**: `/openai/v1/realtime/client_secrets`
**Method**: POST
**Auth**: App Attest (X-Apple-Attest-Key-Id and X-Apple-Attest-Assertion headers)

Generates an ephemeral token for connecting to OpenAI's Realtime API via WebSocket.

**Request Body**:
```json
{
  "session": {
    "type": "realtime",
    "model": "gpt-realtime",
    "audio": {
      "output": {
        "voice": "alloy"
      }
    }
  }
}
```

**Response**:
```json
{
  "value": "eph_xyz789...",
  "expires_at": 1234567890
}
```

---

### 3. X OAuth2 - Token Exchange
**Path**: `/x/oauth2/token`
**Method**: POST
**Auth**: App Attest (X-Apple-Attest-Key-Id and X-Apple-Attest-Assertion headers)

Exchanges an authorization code for access and refresh tokens.

**Request Body**:
```json
{
  "code": "authorization_code",
  "redirect_uri": "grokmode://oauth/callback",
  "code_verifier": "verifier_string"
}
```

---

### 4. X OAuth2 - Token Refresh
**Path**: `/x/oauth2/refresh`
**Method**: POST
**Auth**: App Attest (X-Apple-Attest-Key-Id and X-Apple-Attest-Assertion headers)

Refreshes an expired access token.

**Request Body**:
```json
{
  "refresh_token": "refresh_token_string"
}
```

## Environment Variables

Configure these secrets in Cloudflare Workers:

```bash
# xAI API Key
wrangler secret put X_AI_API_KEY

# OpenAI API Key
wrangler secret put OPENAI_API_KEY

# X OAuth2 Credentials
wrangler secret put X_OAUTH2_CLIENT_ID
wrangler secret put X_OAUTH2_CLIENT_SECRET
```

### Getting API Keys

1. **xAI API Key**: Get from [x.ai/api](https://x.ai/api)
2. **OpenAI API Key**: Get from [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
3. **X OAuth2**: Register your app at [developer.twitter.com](https://developer.twitter.com/en/portal/dashboard)

## Deployment

### Development
```bash
npm install
npx wrangler dev
```

### Production
```bash
npx wrangler deploy
```

### Set Secrets
```bash
# Set all required secrets
npx wrangler secret put X_AI_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put X_OAUTH2_CLIENT_ID
npx wrangler secret put X_OAUTH2_CLIENT_SECRET
```

## Security

- All protected endpoints require App Attest verification (iOS-only, hardware-backed device attestation)
- Attestation data stored in Cloudflare KV with 90-day expiration
- Each request requires a cryptographic assertion proving it comes from an attested app instance
- API keys are stored as Cloudflare Workers secrets and never exposed to clients
- Ephemeral tokens have short expiration times (5-60 minutes)
- OAuth tokens are only used for X API authentication

## iOS Integration

The iOS app is configured to use this proxy via `Config.swift`:

```swift
static let baseXAIProxyURL = URL(string: "https://your-worker.workers.dev/grok")!
static let baseOpenAIProxyURL = URL(string: "https://your-worker.workers.dev")!
```

Update these URLs to point to your deployed worker.

## API Flow

### xAI Voice (WebSocket)
1. iOS app requests ephemeral token from `/grok/v1/realtime/client_secrets`
2. Proxy forwards to xAI with API key
3. iOS app uses token to connect to xAI WebSocket
4. Audio streams via WebSocket with manual chunking

### OpenAI Voice (WebSocket)
1. iOS app requests ephemeral token from `/openai/v1/realtime/client_secrets`
2. Proxy forwards session config to OpenAI with API key
3. iOS app uses token to connect to WebSocket at `wss://api.openai.com/v1/realtime`
4. Audio streams as base64 chunks via WebSocket messages
5. All events sent via WebSocket

## Error Handling

All endpoints return proper HTTP status codes:
- `200 OK`: Success
- `401 Unauthorized`: Missing App Attest headers
- `403 Forbidden`: Invalid App Attest assertion
- `404 Not Found`: Unknown endpoint
- `500 Internal Server Error`: API errors (details in response body)

Error responses include details:
```json
{
  "error": "Description of error",
  "details": "Additional error information"
}
```
