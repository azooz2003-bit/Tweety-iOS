// Pricing configuration and cost calculation

import { UsageData } from '../types';

// Pricing constants (matches iOS PricingConfig.swift)
const PRICING = {
	grokVoice: {
		perMinute: 0.05
	},
	openAIRealtime: {
		audioInputPer1M: 32.00,
		audioOutputPer1M: 64.00,
		textInputPer1M: 4.00,
		textOutputPer1M: 16.00,
		cachedTextInputPer1M: 0.40
	},
	xAPI: {
		postRead: 0.005,
		userRead: 0.01,
		dmEventRead: 0.01,
		contentCreate: 0.01,
		dmInteractionCreate: 0.01,
		userInteractionCreate: 0.015
	}
};

/**
 * Calculate cost for API usage
 * @param service - Service name: 'grok_voice', 'openai_realtime', 'x_api'
 * @param usage - Usage data with service-specific fields
 * @returns Cost in USD
 */
export function calculateCost(service: string, usage: UsageData): number {
	let cost = 0;

	switch (service) {
		case 'grok_voice':
			cost = (usage.minutes || 0) * PRICING.grokVoice.perMinute;
			break;

		case 'openai_realtime':
			cost = ((usage.audioInputTokens || 0) / 1_000_000) * PRICING.openAIRealtime.audioInputPer1M +
				((usage.audioOutputTokens || 0) / 1_000_000) * PRICING.openAIRealtime.audioOutputPer1M +
				((usage.textInputTokens || 0) / 1_000_000) * PRICING.openAIRealtime.textInputPer1M +
				((usage.textOutputTokens || 0) / 1_000_000) * PRICING.openAIRealtime.textOutputPer1M +
				((usage.cachedTextInputTokens || 0) / 1_000_000) * PRICING.openAIRealtime.cachedTextInputPer1M;
			break;

		case 'x_api':
			cost = ((usage.postsRead || 0) * PRICING.xAPI.postRead) +
				((usage.usersRead || 0) * PRICING.xAPI.userRead) +
				((usage.dmEventsRead || 0) * PRICING.xAPI.dmEventRead) +
				((usage.contentCreates || 0) * PRICING.xAPI.contentCreate) +
				((usage.dmInteractionCreates || 0) * PRICING.xAPI.dmInteractionCreate) +
				((usage.userInteractionCreates || 0) * PRICING.xAPI.userInteractionCreate);
			break;

		default:
			throw new Error(`Unknown service: ${service}`);
	}

	return cost;
}

/**
 * Get credit amount for a product
 * @param productId - Apple product ID
 * @param isTrial - Whether this is a trial period
 * @returns Credits amount in USD
 */
export function getCreditsForProduct(productId: string, isTrial: boolean): number {
	// No credits for trial periods
	if (isTrial) {
		return 0;
	}

	// Map product IDs to credit amounts
	switch (productId) {
		case 'com.grokmode.plus':
		case 'co.azizalbahar.TweetyXVoiceAssistant.plus':
			return 11.00;  // $11 in credits

		case 'com.grokmode.pro':
		case 'co.azizalbahar.TweetyXVoiceAssistant.pro':
			return 20.00;  // $20 in credits

		case 'com.grokmode.ultra':
		case 'co.azizalbahar.TweetyXVoiceAssistant.ultra':
			return 40.00;  // $40 in credits

		default:
			// For one-time credit purchases, could parse amount from product ID
			// e.g., 'com.grokmode.credits.10' -> 10.00
			if (productId.includes('.credits.')) {
				const amount = parseFloat(productId.split('.credits.')[1]);
				return isNaN(amount) ? 0 : amount;
			}
			return 0;
	}
}
