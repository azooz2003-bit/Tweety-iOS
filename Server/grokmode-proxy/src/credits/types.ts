// Type definitions for credit tracking system

export interface AppleTransaction {
	app_account_token: string;  // UUID that acts as user_id
	transaction_id: string;
	original_transaction_id: string;
	product_id: string;
	purchase_date_ms: string;
	is_trial_period?: string;
}

export interface AppleReceipt {
	status: number;
	latest_receipt_info?: AppleTransaction[];
}

export interface CreditBalance {
	spent: number;
	total: number;
	remaining: number;
}

export interface UsageData {
	// Grok Voice
	minutes?: number;

	// OpenAI Realtime
	audioInputTokens?: number;
	audioOutputTokens?: number;
	textInputTokens?: number;
	textOutputTokens?: number;
	cachedTextInputTokens?: number;

	// X API
	postsRead?: number;
	usersRead?: number;
	dmEventsRead?: number;
	contentCreates?: number;
	dmInteractionCreates?: number;
	userInteractionCreates?: number;
}
