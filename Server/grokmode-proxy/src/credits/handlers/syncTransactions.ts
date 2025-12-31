import { AppleTransaction } from '../types';
import { classifyTransaction } from '../utils/transactionClassifier';
import {
	getRemainingCredits,
	isTransactionProcessed,
	createUserIfNotExists
} from '../utils/db';

interface Env {
	tweety_credits: D1Database;
	BUNDLE_ID: string;
}

export async function syncTransactions(request: Request, env: Env): Promise<Response> {
	if (request.method !== 'POST') {
		return new Response('Method not allowed', { status: 405 });
	}

	try {
		const body = await request.json() as {
			transactions: AppleTransaction[];
		};

		const { transactions } = body;

		if (!transactions || transactions.length === 0) {
			return new Response(
				JSON.stringify({ error: 'No transactions provided' }),
				{ status: 400, headers: { 'Content-Type': 'application/json' } }
			);
		}

		// Get user_id from appAccountToken (same for all transactions)
		const userId = transactions[0].app_account_token;

		if (!userId) {
			return new Response(
				JSON.stringify({ error: 'Missing appAccountToken' }),
				{ status: 400, headers: { 'Content-Type': 'application/json' } }
			);
		}

		await createUserIfNotExists(userId, env);

		// Rate limiting: Prevent abuse by limiting transaction syncs per hour
		// This is a high limit - normal usage is ~1-5 syncs per hour
		const oneHourAgo = Date.now() - (60 * 60 * 1000);
		const recentSyncs = await env.tweety_credits.prepare(
			'SELECT COUNT(*) as count FROM receipts WHERE user_id = ? AND validated_at >= ?'
		).bind(userId, Math.floor(oneHourAgo / 1000)).first<{ count: number }>();

		if (recentSyncs && recentSyncs.count > 1000) {
			return new Response(
				JSON.stringify({ error: 'Rate limit exceeded - too many transaction syncs in the past hour' }),
				{ status: 429, headers: { 'Content-Type': 'application/json' } }
			);
		}

		let newCreditsAdded = 0;
		let processedCount = 0;
		let skippedCount = 0;
		const errors: string[] = [];

		// Sort transactions by purchase date to process in chronological order
		const sortedTransactions = transactions.sort((a, b) =>
		parseInt(a.purchase_date_ms) - parseInt(b.purchase_date_ms)
		);

		// Process transactions sequentially to ensure each sees correct history
		for (const transaction of sortedTransactions) {
			const alreadyProcessed = await isTransactionProcessed(
				transaction.transaction_id,
				env
			);

			if (alreadyProcessed) {
				skippedCount++;
				continue;
			}

			// Classify transaction and calculate credits
			const classification = await classifyTransaction(transaction, env);
			const creditsAmount = classification.creditsToGrant;

			const isTrial = transaction.is_trial_period === 'true';
			const revocationDate = transaction.revocation_date_ms
				? parseInt(transaction.revocation_date_ms)
				: null;

			// Handle refunds differently - update existing transactions
			if (classification.type === 'REFUND') {
				try {
					const result = await env.tweety_credits.prepare(
						`UPDATE receipts
						 SET revocation_date = ?,
						     revocation_reason = ?,
						     credits_amount = credits_amount + ?,
						     transaction_type = 'REFUND',
						     notes = ?,
						     validated_at = ?
						 WHERE transaction_id = ?`
					).bind(
						revocationDate,
						transaction.revocation_reason || null,
						creditsAmount, // Already negative from handleRefund
						classification.notes,
						Math.floor(Date.now() / 1000),
						transaction.transaction_id
					).run();

					if (result.meta.changes > 0) {
						newCreditsAdded += creditsAmount;
						processedCount++;
					} else {
						console.warn(`Refund transaction ${transaction.transaction_id} not found in database - may need to insert as new refund record`);
						skippedCount++;
					}
				} catch (error) {
					const errorMsg = `Transaction ${transaction.transaction_id}: ${error instanceof Error ? error.message : String(error)}`;
					console.error(`Failed to update refund:`, errorMsg);
					errors.push(errorMsg);
				}
			} else {
				// Regular transactions - use INSERT OR IGNORE to handle race conditions
				// If another request inserts same transaction_id, this will silently skip
				try {
					await env.tweety_credits.prepare(
						`INSERT OR IGNORE INTO receipts (
							user_id, transaction_id, original_transaction_id,
							product_id, credits_amount, purchase_date, is_trial_period,
							transaction_type, previous_product_id, revocation_date,
							revocation_reason, expiration_date, notes
						) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
					).bind(
						userId,
						transaction.transaction_id,
						transaction.original_transaction_id,
						transaction.product_id,
						creditsAmount,
						parseInt(transaction.purchase_date_ms),
						isTrial ? 1 : 0,
						classification.type,
						classification.previousProductId,
						revocationDate,
						transaction.revocation_reason || null,
						transaction.expiration_date_ms ? parseInt(transaction.expiration_date_ms) : null,
						classification.notes
					).run();

					const inserted = await isTransactionProcessed(transaction.transaction_id, env);
					if (inserted) {
						newCreditsAdded += creditsAmount;
						processedCount++;
					} else {
						skippedCount++;
					}
				} catch (error) {
					const errorMsg = `Transaction ${transaction.transaction_id}: ${error instanceof Error ? error.message : String(error)}`;
					console.error(`Failed to insert transaction:`, errorMsg);
					errors.push(errorMsg);
				}
			}
		}

		const balance = await getRemainingCredits(userId, env);

		return new Response(
			JSON.stringify({
				success: errors.length === 0,
				userId,
				processedCount,
				skippedCount,
				newCreditsAdded,
				errors: errors.length > 0 ? errors : undefined,
				...balance
			}),
			{
				status: errors.length > 0 ? 207 : 200,  // 207 Multi-Status for partial success
				headers: { 'Content-Type': 'application/json' }
			}
		);

	} catch (error) {
		console.error('Transaction sync error:', error);
		return new Response(
			JSON.stringify({
				error: 'Transaction sync failed',
				details: error instanceof Error ? error.message : String(error)
			}),
			{ status: 500, headers: { 'Content-Type': 'application/json' } }
		);
	}
}
