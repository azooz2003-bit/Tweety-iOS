// Handler for syncing batch of transactions from iOS

import { AppleTransaction } from '../types';
import { getCreditsForProduct } from '../utils/pricing';
import {
	getRemainingCredits,
	isTransactionProcessed,
	createUserIfNotExists,
	storeReceipt
} from '../utils/db';

interface Env {
	tweety_credits: D1Database;
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

		// Create user if doesn't exist
		await createUserIfNotExists(userId, env);

		// Process each transaction
		let newCreditsAdded = 0;
		let processedCount = 0;
		let skippedCount = 0;

		// Build batch of inserts for new transactions (single atomic operation per user)
		const insertStatements = [];

		for (const transaction of transactions) {
			// Check if already processed
			const alreadyProcessed = await isTransactionProcessed(
				transaction.transaction_id,
				env
			);

			if (alreadyProcessed) {
				skippedCount++;
				continue;
			}

			// Determine credits amount
			const isTrial = transaction.is_trial_period === 'true';
			const creditsAmount = getCreditsForProduct(transaction.product_id, isTrial);

			// Add to batch
			insertStatements.push(
				env.tweety_credits.prepare(
					`INSERT INTO receipts (
						user_id, transaction_id, original_transaction_id,
						product_id, credits_amount, purchase_date, is_trial_period
					) VALUES (?, ?, ?, ?, ?, ?, ?)`
				).bind(
					userId,
					transaction.transaction_id,
					transaction.original_transaction_id,
					transaction.product_id,
					creditsAmount,
					parseInt(transaction.purchase_date_ms),
					isTrial ? 1 : 0
				)
			);

			newCreditsAdded += creditsAmount;
			processedCount++;
		}

		// Execute all inserts atomically (if any new transactions)
		if (insertStatements.length > 0) {
			await env.tweety_credits.batch(insertStatements);
		}

		// Get updated balance
		const balance = await getRemainingCredits(userId, env);

		return new Response(
			JSON.stringify({
				success: true,
				userId,
				processedCount,
				skippedCount,
				newCreditsAdded,
				...balance
			}),
			{ headers: { 'Content-Type': 'application/json' } }
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
