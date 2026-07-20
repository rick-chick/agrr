#!/usr/bin/env node
/**
 * Print the one-click apply URL for the live Delivery Agent automation.
 * User opens the URL and clicks Save — webhook URL/key stay unchanged.
 */
import { buildDeliveryAgentAutomationApplyUrl } from './delivery-agent-automation-prompt-lib.mjs';

console.log(buildDeliveryAgentAutomationApplyUrl());
