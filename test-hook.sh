#!/bin/bash

# Test your n8n workflow with the correct webhook URL
echo "🚀 Testing n8n Complete Stack Workflow"
echo "======================================"
echo ""

# Use the Test URL from your n8n webhook configuration
WEBHOOK_URL="http://localhost:5678/webhook-test/stack-demo"

echo "📡 Sending test request to: $WEBHOOK_URL"
echo ""

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "repo_name": "ajeetraina/n8n-model-runner",
    "user": "dashboard-test",
    "message": "Testing complete AI stack integration",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'"
  }' \
  -w "\n\n⚡ Response Time: %{time_total}s\n⚡ HTTP Status: %{http_code}\n" \
  | head -50

echo ""
echo "✅ Test completed!"
echo ""
echo "🎯 What to check next:"
echo "1. Go back to your n8n workflow canvas"
echo "2. You should see nodes executing (lighting up)"
echo "3. Check each node for green checkmarks ✅"
echo "4. Click nodes to see their output data"
echo "5. Look for the AI analysis in the '🤖 AI Repository Analysis' node"
echo ""
echo "📊 Or go to the Executions tab to see detailed results!"
