import { AppleTransaction } from '../types';

/**
 * Get user ID from appAccountToken
 * All transactions from the same user have the same appAccountToken
 */
export function getUserIdFromTransactions(transactions: AppleTransaction[]): string {
	if (!transactions || transactions.length === 0) {
		throw new Error('No transactions provided');
	}

	const firstTransaction = transactions[0];

	return firstTransaction.app_account_token || '';
}
