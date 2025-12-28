// Apple transaction utilities

import { AppleTransaction } from '../types';

/**
 * Get user ID from appAccountToken
 * All transactions from the same user have the same appAccountToken
 */
export function getUserIdFromTransactions(transactions: AppleTransaction[]): string {
	if (!transactions || transactions.length === 0) {
		throw new Error('No transactions provided');
	}

	// All transactions should have the same appAccountToken
	// Just get it from the first one
	const firstTransaction = transactions[0];

	// In our simplified approach, we'll receive appAccountToken directly
	// from iOS in the transaction data
	return firstTransaction.app_account_token || '';
}
