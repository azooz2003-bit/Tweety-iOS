export interface Env {
    X_AI_API_KEY: string;
    APP_SECRET: string;
    X_OAUTH2_CLIENT_SECRET: string;
    X_OAUTH2_CLIENT_ID: string;
}

// Request body types
interface TokenExchangeRequest {
    code: string;
    redirect_uri: string;
    code_verifier: string;
}

interface TokenRefreshRequest {
    refresh_token: string;
}

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext):
Promise<Response> {
        const url = new URL(request.url);

        // Auth check
        const appSecret = request.headers.get('X-App-Secret');
        if (appSecret !== env.APP_SECRET) {
            return new Response('Unauthorized', { status: 401 });
        }

        // Get ephemeral token for Grok Voice API
        if (url.pathname === '/grok/v1/realtime/client_secrets') {
            const response = await
fetch('https://api.x.ai/v1/realtime/client_secrets', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${env.X_AI_API_KEY}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    expires_after: { seconds: 3600 }
                })
            });

            return new Response(response.body, {
                headers: { 'Content-Type': 'application/json' }
            });
        }

        // OAuth2: Exchange authorization code for access token
        if (url.pathname === '/x/oauth2/token') {
            try {
                const { code, redirect_uri, code_verifier } = await request.json() as TokenExchangeRequest;

                // Validate environment variables
                if (!env.X_OAUTH2_CLIENT_ID || !env.X_OAUTH2_CLIENT_SECRET) {
                    return new Response(JSON.stringify({
                        error: 'Server configuration error: OAuth credentials not set'
                    }), { status: 500, headers: { 'Content-Type': 'application/json' } });
                }

                const response = await fetch('https://api.twitter.com/2/oauth2/token', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'Authorization': `Basic ${btoa(`${env.X_OAUTH2_CLIENT_ID}:${env.X_OAUTH2_CLIENT_SECRET}`)}`
                    },
                    body: new URLSearchParams({
                        code,
                        grant_type: 'authorization_code',
                        redirect_uri,
                        code_verifier
                    })
                });

                const responseData = await response.text();

                // If X API returned an error, pass it through
                if (!response.ok) {
                    return new Response(responseData, {
                        status: response.status,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }

                return new Response(responseData, {
                    headers: { 'Content-Type': 'application/json' }
                });
            } catch (error) {
                return new Response(JSON.stringify({
                    error: 'Token exchange failed',
                    details: error instanceof Error ? error.message : String(error)
                }), { status: 500, headers: { 'Content-Type': 'application/json' } });
            }
        }

        // OAuth2: Refresh access token
        if (url.pathname === '/x/oauth2/refresh') {
            try {
                const { refresh_token } = await request.json() as TokenRefreshRequest;

                // Validate environment variables
                if (!env.X_OAUTH2_CLIENT_ID || !env.X_OAUTH2_CLIENT_SECRET) {
                    return new Response(JSON.stringify({
                        error: 'Server configuration error: OAuth credentials not set'
                    }), { status: 500, headers: { 'Content-Type': 'application/json' } });
                }

                const response = await fetch('https://api.twitter.com/2/oauth2/token', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'Authorization': `Basic ${btoa(`${env.X_OAUTH2_CLIENT_ID}:${env.X_OAUTH2_CLIENT_SECRET}`)}`
                    },
                    body: new URLSearchParams({
                        refresh_token,
                        grant_type: 'refresh_token'
                    })
                });

                const responseData = await response.text();

                // If X API returned an error, pass it through
                if (!response.ok) {
                    return new Response(responseData, {
                        status: response.status,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }

                return new Response(responseData, {
                    headers: { 'Content-Type': 'application/json' }
                });
            } catch (error) {
                return new Response(JSON.stringify({
                    error: 'Token refresh failed',
                    details: error instanceof Error ? error.message : String(error)
                }), { status: 500, headers: { 'Content-Type': 'application/json' } });
            }
        }


        return new Response('Not found', { status: 404 });
    }
};
