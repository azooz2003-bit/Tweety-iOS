import { CreditBalance } from '../types';

interface Env {
	tweety_credits: D1Database;
}

export async function getRemainingCredits(userId: string, env: Env): Promise<CreditBalance> {
	const userResult = await env.tweety_credits.prepare(
		'SELECT credits_spent FROM users WHERE user_id = ?'
	).bind(userId).first<{ credits_spent: number }>();

	const creditsSpent = userResult?.credits_spent || 0;

	const receiptsResult = await env.tweety_credits.prepare(
		'SELECT SUM(credits_amount) as total_credits FROM receipts WHERE user_id = ?'
	).bind(userId).first<{ total_credits: number }>();

	const totalCredits = receiptsResult?.total_credits || 0;

	return {
		spent: creditsSpent,
		total: totalCredits,
		remaining: totalCredits - creditsSpent
	};
}

export async function isTransactionProcessed(transactionId: string, userId: string, env: Env): Promise<boolean> {
	const result = await env.tweety_credits.prepare(
		'SELECT id FROM receipts WHERE transaction_id = ? AND user_id = ?'
	).bind(transactionId, userId).first();

	return result !== null;
}

export async function createUserIfNotExists(userId: string, env: Env): Promise<void> {
	await env.tweety_credits.prepare(
		'INSERT INTO users (user_id, credits_spent) VALUES (?, 0) ON CONFLICT (user_id) DO NOTHING'
	).bind(userId).run();
}

/**
 * Store a receipt and add credits
 */
export async function storeReceipt(
	userId: string,
	transactionId: string,
	originalTransactionId: string,
	productId: string,
	creditsAmount: number,
	purchaseDate: number,
	isTrial: boolean,
	env: Env
): Promise<void> {
	await env.tweety_credits.prepare(
		`INSERT INTO receipts (
			user_id, transaction_id, original_transaction_id,
			product_id, credits_amount, purchase_date, is_trial_period
		) VALUES (?, ?, ?, ?, ?, ?, ?)`
	).bind(
		userId,
		transactionId,
		originalTransactionId,
		productId,
		creditsAmount,
		purchaseDate,
		isTrial ? 1 : 0
	).run();
}

export async function updateCreditsSpent(
	userId: string,
	additionalCost: number,
	env: Env
): Promise<void> {
	await env.tweety_credits.prepare(
		'UPDATE users SET credits_spent = credits_spent + ?, updated_at = unixepoch() WHERE user_id = ?'
	).bind(additionalCost, userId).run();
}

export async function logUsage(
	userId: string,
	service: string,
	amount: number,
	cost: number,
	env: Env
): Promise<void> {
	await env.tweety_credits.prepare(
		'INSERT INTO usage_logs (user_id, service, amount, cost) VALUES (?, ?, ?, ?)'
	).bind(userId, service, amount, cost).run();
}
