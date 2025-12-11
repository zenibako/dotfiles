/**
 * Home Assistant Webhook Integration
 * 
 * Sends a notification to Home Assistant when the OpenCode agent completes work.
 * 
 * Setup Instructions:
 * 1. Copy this file to ~/.config/opencode/plugin/home-assistant.ts
 * 2. In Home Assistant, create a new automation (see example below)
 * 3. Update WEBHOOK_URL below with your Home Assistant webhook URL
 * 4. Restart OpenCode
 * 
 * ============================================================================
 * Example Home Assistant Automation (automations.yaml):
 * ============================================================================
 * 
 * - id: opencode_agent_completed
 *   alias: "OpenCode Agent Completed"
 *   trigger:
 *     - platform: webhook
 *       webhook_id: {{home_assistant_webhook_id}}
 *       allowed_methods:
 *         - POST
 *       local_only: false
 *   conditions:
 *     - condition: template
 *       value_template: "\{{ trigger.json.event_type == 'opencode_agent_completed' }}"
 *   action:
 *     - service: notify.mobile_app_chandler_s_iphone
 *       data:
 *         title: "\{{ trigger.json.notification_title }}"
 *         message: "\{{ trigger.json.notification_message }}"
 *         data:
 *           notification_icon: mdi:robot
 *           tag: opencode_completed
 *           group: opencode
 *           color: green
 *           push:
 *             interruption-level: time-sensitive
 *     - service: persistent_notification.create
 *       data:
 *         title: "\{{ trigger.json.notification_title }}"
 *         message: |
 *           **Session:** \{{ trigger.json.session_title }}
 *           **Tokens:** \{{ trigger.json.tokens_total }} ($\{{ "%.4f" | format(trigger.json.cost | default(0)) }})
 *           **Time:** \{{ trigger.json.timestamp }}
 *           
 *           ---
 *           
 *           \{{ trigger.json.message_full }}
 *         notification_id: "opencode_\{{ trigger.json.session_id }}"
 *     - service: logbook.log
 *       data:
 *         name: OpenCode
 *         message: >-
 *           Agent completed in "\{{ trigger.json.session_title }}" - 
 *           \{{ trigger.json.tokens_total }} tokens ($\{{ "%.4f" | format(trigger.json.cost | default(0)) }})
 *         entity_id: automation.opencode_agent_completed
 * 
 * ============================================================================
 * Webhook Payload Structure:
 * ============================================================================
 * 
 * {
 *   "event_type": "opencode_agent_completed",
 *   "session_id": "ses_abc123",
 *   "session_title": "My Session",
 *   "message_id": "msg_xyz789",
 *   "message_preview": "I've completed the task... (truncated to 500 chars)",
 *   "message_full": "Full agent response text...",
 *   "tokens_input": 1500,
 *   "tokens_output": 800,
 *   "tokens_total": 2300,
 *   "cost": 0.025,
 *   "notification_title": "OpenCode: My Session",
 *   "notification_message": "I've completed the task...",
 *   "timestamp": "2025-01-01T12:00:00.000Z"
 * }
 * 
 * ============================================================================
 * Available Template Variables in Home Assistant:
 * ============================================================================
 * 
 * - \{{ trigger.json.session_title }} - Human-readable session name
 * - \{{ trigger.json.notification_title }} - Ready-to-use notification title
 * - \{{ trigger.json.notification_message }} - Truncated message (500 chars)
 * - \{{ trigger.json.message_full }} - Full agent response
 * - \{{ trigger.json.tokens_total }} - Total tokens used
 * - \{{ trigger.json.cost }} - Cost in dollars (if available)
 * 
 * Full guide: https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger
 */

import type { Plugin } from '@opencode-ai/plugin';
// @ts-ignore - Using local dev version
import { createAgentNotificationPlugin } from '/Users/chanderson/Projects/opencode-webhooks/dist/index.js';

// ============================================================================
// Configuration (Preserved from your dotfiles)
// ============================================================================

const HOME_ASSISTANT_URL = '{{home_assistant_url}}'; 
const WEBHOOK_ID = '{{home_assistant_webhook_id}}';

// Optional: Uncomment and set if you need authentication
const HOME_ASSISTANT_TOKEN = '{{home_assistant_token}}';

// Construct the webhook URL
const WEBHOOK_URL = `${HOME_ASSISTANT_URL}/api/webhook/${WEBHOOK_ID}`;

// ============================================================================
// Plugin Setup
// ============================================================================

// @ts-ignore - Using local dev version
const HomeAssistantPlugin: Plugin = createAgentNotificationPlugin({
  webhooks: [{
    url: WEBHOOK_URL,
    
    // Transform for Home Assistant - includes all useful fields
    transformPayload: (payload) => ({
      // Event identification
      event_type: 'opencode_agent_completed',
      
      // Session info
      session_id: payload.sessionId,
      session_title: payload.sessionTitle,
      
      // Message content
      message_id: payload.messageId,
      message_preview: payload.messageContent.substring(0, 500),
      message_full: payload.messageContent,
      
      // Usage stats (for advanced automations/tracking)
      tokens_input: payload.tokens?.input,
      tokens_output: payload.tokens?.output,
      tokens_total: payload.tokens ? payload.tokens.input + payload.tokens.output : undefined,
      cost: payload.cost,
      
      // Notification-ready fields (ready to use in Home Assistant notifications)
      notification_title: `OpenCode: ${payload.sessionTitle}`,
      notification_message: payload.messageContent.substring(0, 500),
      
      // Metadata
      timestamp: payload.timestamp,
    }),
    
    // Optional: Custom headers (authentication if needed)
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${HOME_ASSISTANT_TOKEN}`,
    },
    
    // Retry configuration
    retry: {
      maxAttempts: 3,
      delayMs: 2000,
    },
    
    timeoutMs: 5000,
  }],
  
  // Enable debug logging (set to false in production)
  debug: false,
});

export default HomeAssistantPlugin;
