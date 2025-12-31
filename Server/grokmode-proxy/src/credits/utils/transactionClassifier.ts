import { AppleTransaction } from '../types';
import { getCreditsForProduct, getPriceForProduct } from './pricing';

export type TransactionType =
	| 'NEW_SUBSCRIPTION'
	| 'RENEWAL'
	| 'RESUBSCRIPTION'
	| 'REFUND'
	| 'ONE_TIME_PURCHASE'
	| 'FAMILY_SHARED';

interface TransactionHistory {
	product_id: string;
	purchase_date: number;
	credits_amount: number;
	transaction_id: string;
	expiration_date?: number;
}

interface ClassificationResult {
	type: TransactionType;
	creditsToGrant: number;
	previousProductId: string | null;
	notes: string;
}

/**
 * Classify transaction type and calculate credits
 * Simplified for single-tier subscription model (Tweety Plus only)
 */
export async function classifyTransaction(
	transaction: AppleTransaction,
	env: { tweety_credits: D1Database }
): Promise<ClassificationResult> {

	// Check for family sharing FIRST - only the purchaser should get credits
	// Family members who access the subscription via Family Sharing get PURCHASED as ownership_type
	// on first-time setup, but get FAMILY_SHARED on subsequent transactions
	if (transaction.ownership_type === 'FAMILY_SHARED') {
		return {
			type: 'FAMILY_SHARED',
			creditsToGrant: 0,
			previousProductId: null,
			notes: 'Family shared subscription - credits only granted to original purchaser'
		};
	}

	// Check if it's a refund
	if (transaction.revocation_date_ms) {
		return await handleRefund(transaction, env);
	}

	// Check if one-time purchase (no expiration date means not a subscription)
	if (!transaction.expiration_date_ms) {
		return handleOneTimePurchase(transaction);
	}

	const history = await getTransactionHistory(
		transaction.original_transaction_id,
		env
	);

	// NEW SUBSCRIPTION - no history
	if (history.length === 0) {
		const credits = getCreditsForProduct(
			transaction.product_id,
			transaction.is_trial_period === 'true'
		);
		return {
			type: 'NEW_SUBSCRIPTION',
			creditsToGrant: credits,
			previousProductId: null,
			notes: 'First transaction in subscription chain'
		};
	}

	// Sort by purchase date to find most recent previous transaction
	history.sort((a, b) => a.purchase_date - b.purchase_date);
	const previousTransaction = history[history.length - 1];
	const currentPurchaseDate = parseInt(transaction.purchase_date_ms);

	// Check for resubscription (gap in service)
	if (previousTransaction.expiration_date) {
		const previousExpirationDate = previousTransaction.expiration_date;
		const gapInDays = (currentPurchaseDate - previousExpirationDate) / (1000 * 60 * 60 * 24);

		// Any positive gap means no active subscription = resubscription
		if (gapInDays > 0) {
			const credits = getCreditsForProduct(
				transaction.product_id,
				transaction.is_trial_period === 'true'
			);
			const gapDescription = gapInDays >= 1
				? `${Math.round(gapInDays)} day${Math.round(gapInDays) !== 1 ? 's' : ''}`
				: `${Math.round(gapInDays * 24 * 60)} minutes`;
			return {
				type: 'RESUBSCRIPTION',
				creditsToGrant: credits,
				previousProductId: previousTransaction.product_id,
				notes: `Resubscribed after ${gapDescription} gap (no active subscription)`
			};
		}
	}

	// RENEWAL - with single tier, all continuing subscriptions are renewals
	const credits = getCreditsForProduct(
		transaction.product_id,
		transaction.is_trial_period === 'true'
	);
	return {
		type: 'RENEWAL',
		creditsToGrant: credits,
		previousProductId: previousTransaction.product_id,
		notes: 'Subscription renewal'
	};
}

/**
 * Get transaction history for a subscription chain
 * Ordered by purchase_date to ensure chronological processing
 */
async function getTransactionHistory(
	originalTransactionId: string,
	env: { tweety_credits: D1Database }
): Promise<TransactionHistory[]> {
	try {
		const result = await env.tweety_credits.prepare(
			`SELECT product_id, purchase_date, credits_amount, transaction_id, expiration_date
			 FROM receipts
			 WHERE original_transaction_id = ?
			 ORDER BY purchase_date ASC`
		).bind(originalTransactionId).all<TransactionHistory>();

		return result.results || [];
	} catch (error) {
		console.error(`Failed to get transaction history for ${originalTransactionId}:`, error);
		return [];
	}
}

/**
 * Handle refund transactions
 * Note: Refunds are for actual customer refunds, NOT for upgrades (which are handled by proration)
 *
 * When Apple issues a refund, they send the same transaction with revocation_date_ms set.
 * We need to find the original purchase (without revocation_date) to know how much to deduct.
 */
async function handleRefund(
	transaction: AppleTransaction,
	env: { tweety_credits: D1Database }
): Promise<ClassificationResult> {
	try {
		// Find the ORIGINAL purchase transaction (before refund) in the subscription chain
		// The original transaction has the same original_transaction_id but NO revocation_date
		const original = await env.tweety_credits.prepare(
			`SELECT credits_amount
			 FROM receipts
			 WHERE original_transaction_id = ?
			 AND revocation_date IS NULL
			 AND credits_amount > 0
			 ORDER BY purchase_date DESC
			 LIMIT 1`
		).bind(transaction.original_transaction_id).first<{ credits_amount: number }>();

		const creditsToDeduct = original?.credits_amount || 0;

		if (creditsToDeduct === 0) {
			console.warn(`Refund received for transaction ${transaction.transaction_id}, but no original purchase found in chain ${transaction.original_transaction_id}`);
		}

		return {
			type: 'REFUND',
			creditsToGrant: -1 * creditsToDeduct,
			previousProductId: transaction.product_id,
			notes: `Refund (${transaction.revocation_reason || 'unknown reason'}): deducting $${creditsToDeduct.toFixed(2)}`
		};
	} catch (error) {
		console.error(`Failed to process refund for ${transaction.transaction_id}:`, error);
		// On error, don't grant or deduct credits
		return {
			type: 'REFUND',
			creditsToGrant: 0,
			previousProductId: transaction.product_id,
			notes: `Refund processing error: ${error}`
		};
	}
}

/**
 * Handle one-time credit purchases
 */
function handleOneTimePurchase(
	transaction: AppleTransaction
): ClassificationResult {
	const credits = getCreditsForProduct(transaction.product_id, false);
	return {
		type: 'ONE_TIME_PURCHASE',
		creditsToGrant: credits,
		previousProductId: null,
		notes: 'One-time credit purchase'
	};
}
