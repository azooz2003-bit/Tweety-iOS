import { verifyAttestation, verifyAssertion, generateChallenge } from './appAttest';
import { syncTransactions } from './credits/handlers/syncTransactions';
import { trackUsage } from './credits/handlers/trackUsage';
import { getBalance } from './credits/handlers/getBalance';
import { checkFreeAccess } from './credits/handlers/hasFreeAccess';

export interface Env {
    X_AI_API_KEY: string;
    OPENAI_API_KEY: string;
    X_OAUTH2_CLIENT_SECRET: string;
    X_OAUTH2_CLIENT_ID: string;
    ATTEST_STORE: KVNamespace;
    TEAM_ID: string;
    BUNDLE_ID: string;
    PRE_LOGIN_RATE_LIMIT: any;
    POST_LOGIN_RATE_LIMIT: any;
    USER_TRANSACTION_SYNC_V2: DurableObjectNamespace;
    tweety_credits: D1Database;
}

export { UserTransactionSyncV2 } from './credits/UserTransactionSync';

interface TokenExchangeRequest {
    code: string;
    redirect_uri: string;
    code_verifier: string;
}

interface TokenRefreshRequest {
    refresh_token: string;
}

async function createClientDataHash(request: Request): Promise<string> {
    const url = new URL(request.url);
    const encoder = new TextEncoder();
    let data = new Uint8Array();

    const pathData = encoder.encode(url.pathname);
    data = new Uint8Array([...data, ...pathData]);

    if (url.search) {
        const query = url.search.substring(1);
        const queryData = encoder.encode(query);
        data = new Uint8Array([...data, ...queryData]);
    }

    const methodData = encoder.encode(request.method);
    data = new Uint8Array([...data, ...methodData]);

    if (request.body && request.method !== 'GET') {
        const bodyData = new Uint8Array(await request.clone().arrayBuffer());
        data = new Uint8Array([...data, ...bodyData]);
    }

    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashBase64 = btoa(String.fromCharCode(...hashArray));
    return hashBase64;
}

function makeLimiterKey(pathname: string, sourceId: string): string {
    return sourceId.concat(".").concat(pathname)
}

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext):
Promise<Response> {
        const url = new URL(request.url);

        const ipRateLimitedPaths = ['/attest/challenge', '/attest/verify', '/x/oauth2/token']

        if (ipRateLimitedPaths.includes(url.pathname)) {
            const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
            if (ip === "unknown") {
                return new Response(`429 Failure – could not check rate limit`, { status: 429 })
            }
            const { success } = await env.PRE_LOGIN_RATE_LIMIT.limit({ key: makeLimiterKey(url.pathname, ip) })
            if (!success) {
                return new Response(`429 Failure – rate limit exceeded for ${url.pathname}`, { status: 429 })
            }
        } else {
            const userId = request.headers.get('X-User-Id');
            if (!userId) {
                return new Response('Missing X-User-Id header', { status: 401 })
            }
            const { success } = await env.POST_LOGIN_RATE_LIMIT.limit({ key: makeLimiterKey(url.pathname, userId) })
            if (!success) {
                return new Response(`429 Failure – rate limit exceeded for ${url.pathname}`, { status: 429 })
            }
        }

        if (url.pathname === '/attest/challenge') {
            const challenge = generateChallenge();
            return new Response(challenge, {
                headers: { 'Content-Type': 'application/octet-stream' }
            });
        }

        if (url.pathname === '/attest/verify') {
            try {
                const { keyId, attestation, challenge } = await request.json() as any;
                const isValid = await verifyAttestation(keyId, attestation, challenge, env);

                if (isValid) {
                    return new Response('OK', { status: 200 });
                } else {
                    return new Response('Invalid attestation', { status: 403 });
                }
            } catch (error) {
                console.error('Attestation verification error:', error);
                const errorMessage = error instanceof Error ? error.message : 'Unknown error';
                return new Response(JSON.stringify({
                    error: 'Attestation verification failed',
                    details: errorMessage
                }), {
                    status: 500,
                    headers: { 'Content-Type': 'application/json' }
                });
            }
        }

        const protectedPaths = [
            '/grok/v1/realtime/client_secrets',
            '/openai/v1/realtime/client_secrets',
            '/x/oauth2/token',
            '/x/oauth2/refresh',
            '/credits/transactions/sync',
            '/credits/usage/track',
            '/credits/balance',
            '/credits/has-free-access'
        ];

        if (protectedPaths.some(path => url.pathname === path)) {
            const keyId = request.headers.get('X-Apple-Attest-Key-Id');
            const assertion = request.headers.get('X-Apple-Attest-Assertion');

            if (!keyId || !assertion) {
                return new Response('Missing App Attest headers', { status: 401 });
            }

            const clientDataHash = await createClientDataHash(request);
            const isValid = await verifyAssertion(keyId, assertion, clientDataHash, env);

            if (!isValid) {
                return new Response('Invalid App Attest assertion', { status: 403 });
            }
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

        // Get ephemeral token for OpenAI Realtime API
        if (url.pathname === '/openai/v1/realtime/client_secrets') {
            try {
                const requestBody = await request.json();

                const response = await fetch('https://api.openai.com/v1/realtime/client_secrets', {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(requestBody)
                });

                const responseData = await response.text();

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
                    error: 'OpenAI token request failed',
                    details: error instanceof Error ? error.message : String(error)
                }), { status: 500, headers: { 'Content-Type': 'application/json' } });
            }
        }

        // OAuth2: Exchange authorization code for access token
        if (url.pathname === '/x/oauth2/token') {
            try {
                const { code, redirect_uri, code_verifier } = await request.json() as TokenExchangeRequest;

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

        // Credits: Sync transactions (batch)
        if (url.pathname === '/credits/transactions/sync') {
            const userId = request.headers.get('X-User-Id');
            if (!userId) {
                return new Response(
                    JSON.stringify({ error: 'Missing X-User-Id header' }),
                    { status: 400, headers: { 'Content-Type': 'application/json' } }
                );
            }

            const stub = env.USER_TRANSACTION_SYNC_V2.getByName(userId);
            return await stub.fetch(request);
        }

        // Credits: Track usage
        if (url.pathname === '/credits/usage/track') {
            return await trackUsage(request, env);
        }

        // Credits: Get balance
        if (url.pathname === '/credits/balance') {
            return await getBalance(request, env);
        }

        // Credits: Check free access
        if (url.pathname === '/credits/has-free-access') {
            return await checkFreeAccess(request, env);
        }

        return new Response('Not found', { status: 404 });
    }
};
