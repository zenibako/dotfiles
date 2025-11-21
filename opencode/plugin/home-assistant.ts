/**
 * Home Assistant Webhook Integration
 * 
 * This plugin sends OpenCode events to Home Assistant via webhook automation.
 * 
 * Setup Instructions:
 * 1. In Home Assistant, create a new automation:
 *    - Settings → Automations & Scenes → Create Automation
 *    - Add trigger: Webhook
 *    - Set a webhook ID (e.g., "opencode_events")
 *    - Copy the webhook URL
 * 2. Update WEBHOOK_ID in this file or set home_assistant_webhook_id variable in dotter
 * 3. Update HOME_ASSISTANT_URL if needed
 * 4. (Optional) Create a long-lived access token:
 *    - User Profile → Long-Lived Access Tokens → Create Token
 *    - Set home_assistant_token variable in dotter
 * 5. Deploy with dotter: `dotter deploy -f`
 * 
 * Example Automation Actions:
 * - Send a notification when an error occurs
 * - Turn on a light when a session starts
 * - Log events to a sensor or history
 * - Trigger other automations based on OpenCode activity
 * 
 * Full guide: https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger
 */

import { createWebhookPlugin } from 'opencode-webhooks';

// ============================================================================
// Configuration
// ============================================================================

const HOME_ASSISTANT_URL = '{{home_assistant_url}}';
const WEBHOOK_ID = '{{home_assistant_webhook_id}}';

// Optional: Uncomment and set if you need authentication
// const HOME_ASSISTANT_TOKEN = '{{home_assistant_token}}';

// Construct the webhook URL
const WEBHOOK_URL = `${HOME_ASSISTANT_URL}/api/webhook/${WEBHOOK_ID}`;

// ============================================================================
// Plugin Setup
// ============================================================================

export default createWebhookPlugin({
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
        'file.edited',
        'command.executed',
      ],
      
      // Transform for Home Assistant
      transformPayload: (payload) => {
        // Map event types to friendly names for Home Assistant
        const eventLabels: Record<string, string> = {
          'session.created': 'Session Started',
          'session.idle': 'Session Idle',
          'session.deleted': 'Session Ended',
          'session.error': 'Error Occurred',
          'session.resumed': 'Session Resumed',
          'file.edited': 'File Edited',
          'command.executed': 'Command Executed',
        };

        // Determine severity for conditional automations
        const severity = payload.eventType === 'session.error' ? 'error' : 'info';
        
        // Create a notification-friendly message
        let notificationMessage = `OpenCode: ${eventLabels[payload.eventType] || payload.eventType}`;
        if (payload.error) {
          notificationMessage += ` - ${payload.error}`;
        }

        // Return formatted payload for Home Assistant
        return {
          event_type: payload.eventType,
          event_label: eventLabels[payload.eventType] || payload.eventType,
          severity: severity,
          session_id: payload.sessionId || 'unknown',
          timestamp: payload.timestamp,
          notification_message: notificationMessage,
          // Include original payload for advanced automations
          raw_payload: payload,
        };
      },
      
      // Optional: Custom headers (uncomment if using authentication)
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': `Bearer ${HOME_ASSISTANT_TOKEN}`,
      },
      
      // Retry configuration
      retry: {
        maxAttempts: 3,
        delayMs: 2000,
      },
      
      timeoutMs: 5000,
    },
  ],
  
  // Enable debug logging (set to false in production)
  debug: false,
});
