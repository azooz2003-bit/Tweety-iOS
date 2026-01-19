import { DurableObject } from 'cloudflare:workers';
import { syncTransactions } from './handlers/syncTransactions';

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

export class UserTransactionSyncV2 extends DurableObject<Env> {
	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
	}

	async fetch(request: Request): Promise<Response> {
		return await syncTransactions(request, this.env);
	}
}
