// Handler for tracking API usage and deducting credits

import { UsageData } from '../types';
import { calculateCost } from '../utils/pricing';
import { getRemainingCredits, updateCreditsSpent, logUsage } from '../utils/db';

interface Env {
	tweety_credits: D1Database;
}

export async function trackUsage(request: Request, env: Env): Promise<Response> {
	if (request.method !== 'POST') {
		return new Response('Method not allowed', { status: 405 });
	}

	try {
		const body = await request.json() as {
			userId: string;
			service: string;
			usage: UsageData;
		};

		const { userId, service, usage } = body;

		if (!userId || !service || !usage) {
			return new Response(
				JSON.stringify({ error: 'Missing required fields' }),
				{ status: 400, headers: { 'Content-Type': 'application/json' } }
			);
		}

		// Calculate cost
		const cost = calculateCost(service, usage);
		const amount = usage.minutes || usage.audioInputTokens || usage.postsRead || 0;

		// Execute as atomic batch transaction (row-level lock on this user_id)
		const results = await env.tweety_credits.batch([
			// 1. Update credits spent atomically
			env.tweety_credits.prepare(
				'UPDATE users SET credits_spent = credits_spent + ?, updated_at = unixepoch() WHERE user_id = ?'
			).bind(cost, userId),

			// 2. Log usage
			env.tweety_credits.prepare(
				'INSERT INTO usage_logs (user_id, service, amount, cost) VALUES (?, ?, ?, ?)'
			).bind(userId, service, amount, cost),

			// 3. Get updated credits spent
			env.tweety_credits.prepare(
				'SELECT credits_spent FROM users WHERE user_id = ?'
			).bind(userId),

			// 4. Get total credits purchased
			env.tweety_credits.prepare(
				'SELECT SUM(credits_amount) as total_credits FROM receipts WHERE user_id = ?'
			).bind(userId)
		]);

		// Extract results from batch with proper typing
		const spentResult = results[2].results[0] as { credits_spent: number } | undefined;
		const totalResult = results[3].results[0] as { total_credits: number | null } | undefined;

		const creditsSpent = spentResult?.credits_spent ?? 0;
		const totalCredits = totalResult?.total_credits ?? 0;
		const remaining = totalCredits - creditsSpent;

		return new Response(
			JSON.stringify({
				success: true,
				cost,
				spent: creditsSpent,
				total: totalCredits,
				remaining: remaining,
				exceeded: remaining < 0
			}),
			{ headers: { 'Content-Type': 'application/json' } }
		);

	} catch (error) {
		console.error('Track usage error:', error);
		return new Response(
			JSON.stringify({
				error: 'Failed to track usage',
				details: error instanceof Error ? error.message : String(error)
			}),
			{ status: 500, headers: { 'Content-Type': 'application/json' } }
		);
	}
}
