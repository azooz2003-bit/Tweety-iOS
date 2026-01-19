export interface AppleTransaction {
	transaction_id: string;
	original_transaction_id: string;
	product_id: string;
	purchase_date_ms: string;
	is_trial_period?: string;
	expiration_date_ms?: string;      // When subscription expires
	revocation_date_ms?: string;      // When refund occurred (if applicable)
	revocation_reason?: string;       // Why refund happened
	ownership_type?: string;          // Purchase type (e.g., PURCHASED, FAMILY_SHARED)
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
