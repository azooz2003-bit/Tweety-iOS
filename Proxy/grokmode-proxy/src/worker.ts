import { verifyAttestation, verifyAssertion, generateChallenge } from './appAttest';

export interface Env {
    X_AI_API_KEY: string;
    OPENAI_API_KEY: string;
    X_OAUTH2_CLIENT_SECRET: string;
    X_OAUTH2_CLIENT_ID: string;
    ATTEST_STORE: KVNamespace;
    TEAM_ID: string;
    BUNDLE_ID: string;
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

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext):
Promise<Response> {
        const url = new URL(request.url);

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
            '/x/oauth2/refresh'
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
                // Parse the request body from iOS client
                const requestBody = await request.json();

                // Forward to OpenAI with the API key
                const response = await fetch('https://api.openai.com/v1/realtime/client_secrets', {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(requestBody)
                });

                const responseData = await response.text();

                // If OpenAI returned an error, pass it through
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
