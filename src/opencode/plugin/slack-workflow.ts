/**
 * Slack Workflow Builder Integration
 * 
 * This plugin sends OpenCode events to Slack via Workflow Builder webhooks.
 * 
 * Setup Instructions:
 * 1. Copy this file to ~/.config/opencode/plugin/slack-workflow.ts
 * 2. Update the WEBHOOK_URL below with your Slack workflow webhook URL
 * 3. Restart OpenCode
 * 
 * To get your webhook URL:
 * - Open Slack → Workflow Builder → Create workflow
 * - Choose "Webhook" as the trigger
 * - Add variables: eventType, sessionId, timestamp, message, eventInfo
 * - Add a "Send message" step using those variables
 * - Publish and copy the webhook URL
 * 
 * Full guide: https://slack.com/help/articles/360041352714
 */

import type { Plugin } from '@opencode-ai/plugin';

// ============================================================================
// Configuration
// ============================================================================

const WEBHOOK_URL = '{{opencode_slack_webhook_url}}';

// ============================================================================
// Plugin Setup
// ============================================================================

// Export the plugin with explicit type annotation for OpenCode.
// When no webhook is configured, return a no-op plugin so OpenCode startup
// does not fail trying to resolve optional webhook dependencies.
const SlackWorkflowPlugin: Plugin = async (input) => {
  if (!WEBHOOK_URL) {
    return {};
  }

  const { createWebhookPlugin } = await import('opencode-webhooks');

  return createWebhookPlugin({
    webhooks: [
      {
        url: WEBHOOK_URL,

        // Which events to send
        events: [
          'session.created',
          'session.idle',
          'session.deleted',
          'session.error',
          'session.resumed',
          'message.updated',
          'message.part.updated',
        ],

        // Transform for Slack Workflow Builder
        transformPayload: (payload) => {
          const eventEmojis: Record<string, string> = {
            'session.created': '🆕',
            'session.idle': '💤',
            'session.deleted': '🗑️',
            'session.error': '❌',
            'session.resumed': '▶️',
            'message.updated': '💬',
            'message.part.updated': '✏️',
          };

          const eventDescriptions: Record<string, string> = {
            'session.created': 'A new OpenCode session has been created',
            'session.idle': 'The OpenCode session has become idle',
            'session.deleted': 'An OpenCode session has been deleted',
            'session.error': 'An error occurred in the OpenCode session',
            'session.resumed': 'The OpenCode session has resumed activity',
            'message.updated': 'A message has been updated',
            'message.part.updated': 'Part of a message has been updated',
          };

          const emoji = eventEmojis[payload.eventType] || '📢';
          const description = eventDescriptions[payload.eventType] || 'OpenCode event triggered';
          const availableKeys = Object.keys(payload);

          // Extract message content if available
          const messageContent = payload.content || payload.text || payload.message || '';
          const messagePreview = messageContent ? `\n\nMessage: ${messageContent.substring(0, 100)}${messageContent.length > 100 ? '...' : ''}` : '';

          // Flatten payload to top level for Slack Workflow Builder
          return {
            ...payload,
            eventType: payload.eventType,
            sessionId: payload.sessionId || 'N/A',
            timestamp: payload.timestamp,
            message: `${emoji} ${payload.eventType}`,
            eventInfo: `${description}${messagePreview}\n\nAvailable data: ${availableKeys.join(', ')}`,
            messageContent: messageContent,
          };
        },

        // Retry configuration
        retry: {
          maxAttempts: 3,
          delayMs: 1000,
        },

        timeoutMs: 5000,
      },
    ],

    // Enable debug logging (set to false in production)
    debug: false,
  })(input);
};

export default SlackWorkflowPlugin;
