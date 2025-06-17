#!/bin/bash

# ============================================
# n8n + Model Runner 
# Uses existing n8n setup if available
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Demo configuration
N8N_URL="http://localhost:5678"
MODEL_RUNNER_URL="http://localhost:12434"

echo -e "${BLUE}🚀 n8n + Docker Model Runner + MCP Toolkit Demo${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if service is running
check_service() {
    local url=$1
    local service_name=$2
    
    if curl -s "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${service_name} is already running${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  ${service_name} is not accessible at ${url}${NC}"
        return 1
    fi
}

# Function to run demo test
run_demo_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${BLUE}🧪 Running: ${test_name}${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ ${test_name} - SUCCESS${NC}"
    else
        echo -e "${RED}❌ ${test_name} - FAILED${NC}"
    fi
    echo ""
}

# Check prerequisites
echo -e "${BLUE}📋 Checking Prerequisites${NC}"
echo "================================"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Check Docker Desktop version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ Docker version: ${DOCKER_VERSION}${NC}"

# Check if Docker Model Runner is available
if docker model --help >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker Model Runner CLI available${NC}"
else
    echo -e "${YELLOW}⚠️  Docker Model Runner CLI not available (requires Docker Desktop 4.42+)${NC}"
fi

echo ""

# Check existing services
echo -e "${BLUE}🔍 Checking Existing Services${NC}"
echo "=============================="

# Check if n8n is already running
if check_service "$N8N_URL/healthz" "n8n"; then
    USE_EXISTING_N8N=true
    echo -e "${BLUE}💡 Using your existing n8n setup${NC}"
else
    USE_EXISTING_N8N=false
    echo -e "${YELLOW}⚠️  n8n not running - you may need to start it first${NC}"
    echo -e "${BLUE}💡 Try: cd to your n8n-model-runner directory and run 'docker compose up -d'${NC}"
fi

echo ""

# Check Model Runner availability
echo -e "${BLUE}🤖 Checking Model Runner${NC}"
echo "=========================="

if curl -s "$MODEL_RUNNER_URL/engines/v1/models" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Model Runner is accessible${NC}"
    
    # Get available models
    MODELS=$(curl -s "$MODEL_RUNNER_URL/engines/v1/models" | jq -r '.data[].id' 2>/dev/null || echo "")
    
    if [ -n "$MODELS" ]; then
        echo -e "${GREEN}📦 Available models:${NC}"
        echo "$MODELS" | while read -r model; do
            echo "  - $model"
        done
    else
        echo -e "${YELLOW}⚠️  No models currently loaded${NC}"
        echo -e "${BLUE}💡 Try: docker model pull ai/llama3.2:1B-Q8_0${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Model Runner not accessible at $MODEL_RUNNER_URL${NC}"
    echo -e "${BLUE}💡 Enable TCP host support in Docker Desktop:${NC}"
    echo -e "${BLUE}   Settings > Features in development > Beta > Enable host-side TCP support${NC}"
fi

echo ""

# Run demo tests
echo -e "${BLUE}🧪 Running Demo Tests${NC}"
echo "====================="

# Test 1: Basic API connectivity
if [ "$USE_EXISTING_N8N" = true ]; then
    run_demo_test "n8n API Health Check" \
        "curl -s -f '$N8N_URL/healthz' >/dev/null"
fi

# Test 2: Model Runner API (if available)
if curl -s "$MODEL_RUNNER_URL/engines/v1/models" >/dev/null 2>&1; then
    run_demo_test "Model Runner API Check" \
        "curl -s -f '$MODEL_RUNNER_URL/engines/v1/models' | jq '.data' >/dev/null"
        
    # Test 3: AI Inference (if models available)
    FIRST_MODEL=$(curl -s "$MODEL_RUNNER_URL/engines/v1/models" | jq -r '.data[0].id' 2>/dev/null)
    if [ "$FIRST_MODEL" != "null" ] && [ -n "$FIRST_MODEL" ]; then
        echo -e "${BLUE}🧠 Testing AI Inference with model: $FIRST_MODEL${NC}"
        
        INFERENCE_TEST=$(cat << EOF
curl -s -X POST '$MODEL_RUNNER_URL/engines/v1/chat/completions' \\
  -H 'Content-Type: application/json' \\
  -d '{
    "model": "$FIRST_MODEL",
    "messages": [{"role": "user", "content": "Say hello in one word"}],
    "max_tokens": 5
  }' | jq -r '.choices[0].message.content' 2>/dev/null | grep -i hello
EOF
        )
        
        run_demo_test "AI Inference Test" "$INFERENCE_TEST"
    else
        echo -e "${YELLOW}⚠️  No models available for inference test${NC}"
        echo -e "${BLUE}💡 Pull a model first: docker model pull ai/llama3.2:1B-Q8_0${NC}"
    fi
fi

echo ""

# Create sample workflows for import
echo -e "${BLUE}📝 Creating Sample Workflows for Import${NC}"
echo "========================================"

# Create workflows directory
mkdir -p demo-workflows

# Simple AI Test Workflow
cat > demo-workflows/simple-ai-test.json << 'EOF'
{
  "name": "Simple AI Test - Local Model Runner",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "ai-test",
        "options": {}
      },
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [240, 300],
      "webhookId": "simple-ai-test"
    },
    {
      "parameters": {
        "url": "http://model-runner.docker.internal/engines/v1/chat/completions",
        "method": "POST",
        "headers": {
          "Content-Type": "application/json"
        },
        "body": {
          "model": "ai/llama3.2:1B-Q8_0",
          "messages": [
            {
              "role": "user",
              "content": "={{ $json.prompt || 'Hello! Please respond with a brief greeting.' }}"
            }
          ],
          "max_tokens": 100,
          "temperature": 0.7
        }
      },
      "name": "Local AI Request",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 3,
      "position": [460, 300]
    },
    {
      "parameters": {
        "jsCode": "// Extract AI response and format\nconst aiResponse = $input.all()[0].json;\nconst response = {\n  success: true,\n  model_used: aiResponse.model,\n  ai_response: aiResponse.choices[0].message.content,\n  tokens_used: aiResponse.usage?.total_tokens || 0,\n  timestamp: new Date().toISOString()\n};\n\nreturn [{ json: response }];"
      },
      "name": "Format Response",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [680, 300]
    }
  ],
  "connections": {
    "Webhook Trigger": {
      "main": [[{"node": "Local AI Request", "type": "main", "index": 0}]]
    },
    "Local AI Request": {
      "main": [[{"node": "Format Response", "type": "main", "index": 0}]]
    }
  }
}
EOF

# AI Code Review Workflow
cat > demo-workflows/ai-code-review.json << 'EOF'
{
  "name": "AI Code Review - GitHub Integration",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "github-pr-review",
        "options": {}
      },
      "name": "GitHub Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [240, 300],
      "webhookId": "github-pr-review"
    },
    {
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.action }}",
              "operation": "equal",
              "value2": "opened"
            }
          ]
        }
      },
      "name": "Check PR Action",
      "type": "n8n-nodes-base.if",
      "typeVersion": 1,
      "position": [460, 300]
    },
    {
      "parameters": {
        "url": "http://model-runner.docker.internal/engines/v1/chat/completions",
        "method": "POST",
        "headers": {
          "Content-Type": "application/json"
        },
        "body": {
          "model": "ai/codellama:7b",
          "messages": [
            {
              "role": "system",
              "content": "You are a senior software engineer reviewing code. Analyze for:\n1. Security vulnerabilities\n2. Performance issues\n3. Code quality\n4. Best practices\n\nReturn JSON: {\"score\": 1-10, \"issues\": [\"issue1\", \"issue2\"], \"suggestions\": [\"suggestion1\"]}"
            },
            {
              "role": "user",
              "content": "Review this PR:\n\nTitle: {{ $json.pull_request.title }}\nDescription: {{ $json.pull_request.body }}\n\nFiles changed: {{ $json.pull_request.changed_files }}"
            }
          ],
          "max_tokens": 1000,
          "temperature": 0.1
        }
      },
      "name": "AI Code Analysis",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 3,
      "position": [680, 300]
    }
  ],
  "connections": {
    "GitHub Webhook": {
      "main": [[{"node": "Check PR Action", "type": "main", "index": 0}]]
    },
    "Check PR Action": {
      "main": [[{"node": "AI Code Analysis", "type": "main", "index": 0}]]
    }
  }
}
EOF

echo -e "${GREEN}✅ Created demo workflows:${NC}"
echo "  - demo-workflows/simple-ai-test.json"
echo "  - demo-workflows/ai-code-review.json"

echo ""

# Performance test
echo -e "${BLUE}🔬 Quick Performance Test${NC}"
echo "========================="

if curl -s "$MODEL_RUNNER_URL/engines/v1/models" >/dev/null 2>&1; then
    FIRST_MODEL=$(curl -s "$MODEL_RUNNER_URL/engines/v1/models" | jq -r '.data[0].id' 2>/dev/null)
    
    if [ "$FIRST_MODEL" != "null" ] && [ -n "$FIRST_MODEL" ]; then
        echo "Testing model: $FIRST_MODEL"
        
        # Simple performance test
        echo "Running 3 quick inference tests..."
        
        for i in {1..3}; do
            start_time=$(date +%s%3N)
            
            response=$(curl -s -X POST "$MODEL_RUNNER_URL/engines/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{
                    \"model\": \"$FIRST_MODEL\",
                    \"messages\": [{\"role\": \"user\", \"content\": \"Say the number $i\"}],
                    \"max_tokens\": 5
                }")
            
            end_time=$(date +%s%3N)
            latency=$((end_time - start_time))
            
            if echo "$response" | jq . >/dev/null 2>&1; then
                tokens=$(echo "$response" | jq -r '.usage.total_tokens // 0')
                echo "  Test $i: ${latency}ms, ${tokens} tokens"
            else
                echo "  Test $i: Failed"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No models available for performance test${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Model Runner not accessible${NC}"
fi

echo ""

# Display results and next steps
echo -e "${BLUE}🎉 Demo Complete!${NC}"
echo "=================="
echo ""

if [ "$USE_EXISTING_N8N" = true ]; then
    echo -e "${GREEN}✅ Your n8n is running at: $N8N_URL${NC}"
    echo ""
    echo -e "${BLUE}🚀 Ready to test AI workflows:${NC}"
    echo "1. Open n8n: $N8N_URL"
    echo "2. Import a demo workflow:"
    echo "   - Go to Workflows > Import from File"
    echo "   - Select demo-workflows/simple-ai-test.json"
    echo "3. Execute the workflow to test local AI"
    echo ""
else
    echo -e "${YELLOW}⚠️  n8n is not running. Start it first:${NC}"
    echo "   cd /path/to/your/n8n-model-runner"
    echo "   docker compose up -d"
    echo ""
fi

if curl -s "$MODEL_RUNNER_URL/engines/v1/models" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Model Runner is ready for AI workloads${NC}"
else
    echo -e "${YELLOW}⚠️  Model Runner setup needed:${NC}"
    echo "1. Enable in Docker Desktop:"
    echo "   Settings > Features in development > Beta"
    echo "   ✓ Enable Docker Model Runner"
    echo "   ✓ Enable host-side TCP support"
    echo "2. Pull a model: docker model pull ai/llama3.2:1B-Q8_0"
fi

echo ""
echo -e "${BLUE}📝 Test Commands:${NC}"
echo ""
echo "# Test Model Runner directly:"
echo "curl -X POST $MODEL_RUNNER_URL/engines/v1/chat/completions \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"model\": \"ai/llama3.2:1B-Q8_0\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""
echo "# Test n8n webhook (after importing workflow):"
echo "curl -X POST $N8N_URL/webhook/ai-test \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"prompt\": \"Tell me about Docker Model Runner\"}'"
echo ""
echo -e "${BLUE}📁 Demo Files Created:${NC}"
echo "  - demo-workflows/simple-ai-test.json (ready to import)"
echo "  - demo-workflows/ai-code-review.json (GitHub integration example)"
echo ""
echo -e "${GREEN}🎯 You have a complete local AI development environment!${NC}"
echo -e "${BLUE}   No cloud APIs • No rate limits • Complete privacy • Zero costs${NC}"
