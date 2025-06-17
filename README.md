# Complete Setup Guide: n8n + Docker Model Runner

<img width="922" alt="image" src="https://github.com/user-attachments/assets/900e4c32-2558-4779-9262-6035b898a2b6" />



## Prerequisites

1. **Docker Desktop 4.40+** (Mac with Apple Silicon)
2. **Docker Compose** (included with Docker Desktop)
3. **Docker Model Runner enabled** in Docker Desktop

## Step 1: Enable Docker Model Runner

### Using Docker Desktop UI:
1. Open Docker Desktop Settings
2. Go to **Features in development** → **Beta**
3. Enable **"Enable Docker Model Runner"**
4. Optionally enable **"Enable host-side TCP support"** (port 12434)
5. Click **Apply & restart**

<img width="1125" alt="image" src="https://github.com/user-attachments/assets/50b61ba8-e84a-4321-98b6-87eb39fe656a" />


### Using CLI:
```bash
# Enable Model Runner
docker desktop enable model-runner

# Enable with TCP support (optional)
docker desktop enable model-runner --tcp 12434
```

## Step 2: Download AI Models

Pull your preferred models:

```bash
# Lightweight model (fast, good for testing)
docker model pull ai/llama3.2:1B-Q8_0

# Balanced model (recommended)
docker model pull ai/llama3.2:3B

# More capable model
docker model pull ai/gemma3:2B

# List downloaded models
docker model ls
```

## Step 3: Project Setup

Create your project directory:

```bash
mkdir n8n-ai-setup
cd n8n-ai-setup
```

Create the following files:

### 1. `docker-compose.yaml`
(Use the complete compose file provided above)

### 2. `.env`
(Use the .env file provided above - **IMPORTANT: Change the encryption key!**)

```
cp sample.env .env
```

### 3. Create shared directory
```bash
mkdir shared
```

This directory will be mounted to `/data/shared` in n8n for file operations.

## Step 4: Configure Environment

Edit the `.env` file:

1. **Change the encryption key**:
   ```bash
   # Generate a random key
   openssl rand -hex 32
   ```
   Replace `N8N_ENCRYPTION_KEY` with the generated key.

2. **Choose your model**:
   Set `N8N_AI_DEFAULT_MODEL` to one of your downloaded models.

3. **Set your timezone**:
   Update `GENERIC_TIMEZONE` to your timezone.

## Step 5: Start the Stack

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f n8n
```

## Step 6: Access n8n

1. Open your browser and go to: http://localhost:5678
2. Create your admin account when prompted
3. You're ready to build AI-powered workflows!

## Step 7: Test Model Runner Integration

### Quick Test Workflow:

1. **Create a new workflow** in n8n
2. **Add a Manual Trigger** node
3. **Add an HTTP Request** node with these settings:
   - **Method**: POST
   - **URL**: `http://model-runner.docker.internal/engines/llama.cpp/v1/chat/completions`
   - **Headers**: `Content-Type: application/json`
   - **Body**:
   ```json
   {
     "model": "ai/llama3.2:1B-Q8_0",
     "messages": [
       {
         "role": "user",
         "content": "Hello! Please introduce yourself."
       }
     ],
     "max_tokens": 100
   }
   ```
4. **Execute the workflow** and verify you get a response

### Using n8n's Built-in AI Nodes:

If n8n detects the environment variables correctly, you can also use:
- **OpenAI Chat Model** node (configure with local endpoint)
- **AI Agent** node
- **Text Classifier** node

## Step 8: Production Configuration

For production use, consider:

### Enable Queue Mode:
Uncomment the `n8n-worker` service in docker-compose.yml and set:
```bash
EXECUTIONS_MODE=queue
```

### Security Hardening:
1. Use strong passwords
2. Enable HTTPS with a reverse proxy
3. Set up proper firewall rules
4. Regular backups of volumes

### Resource Monitoring:
```bash
# Monitor resource usage
docker stats

# Check Model Runner status
docker model status

# View inference logs (Mac)
tail -f ~/Library/Containers/com.docker.docker/Data/log/host/inference-llama.cpp.log
```

## Troubleshooting

### Common Issues:

**1. Model Runner not accessible:**
```bash
# Check if Model Runner is enabled
docker model status

# Test direct connection
curl http://model-runner.docker.internal/engines/llama.cpp/v1/models
```

**2. n8n can't connect to database:**
```bash
# Check postgres health
docker compose logs postgres

# Restart if needed
docker compose restart postgres
```

**3. Models not loading:**
```bash
# Verify models are downloaded
docker model ls

# Check inference logs (Mac)
tail -f ~/Library/Containers/com.docker.docker/Data/log/host/inference-llama.cpp.log
```

**4. Permission issues with shared folder:**
```bash
# Fix permissions
chmod 755 ./shared
```

## Advanced Configuration

### Custom Model Configuration:

If you want to use different models for different workflows, you can create custom HTTP request templates:

```json
{
  "model": "ai/gemma3:2B",
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful coding assistant."
    },
    {
      "role": "user", 
      "content": "{{ $json.user_prompt }}"
    }
  ],
  "temperature": 0.1,
  "max_tokens": 500
}
```

### Load Balancing:

For high-volume workflows, you can run multiple n8n workers:

```bash
# Scale workers
docker compose up -d --scale n8n-worker=3
```

### Backup and Restore:

```bash
# Backup volumes
docker run --rm -v n8n-ai-setup_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup.tar.gz /data

# Restore volumes
docker run --rm -v n8n-ai-setup_n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-backup.tar.gz -C /
```

## Available Models Reference

| Model | Size | Use Case | Speed |
|-------|------|----------|-------|
| `ai/llama3.2:1B-Q8_0` | 1.2GB | Testing, simple tasks | Very Fast |
| `ai/llama3.2:3B` | 3GB | General purpose | Fast |
| `ai/gemma3:2B` | 2GB | Balanced performance | Fast |
| `ai/qwen2.5:7B` | 7GB | Complex reasoning | Slower |
| `ai/mistral:7B` | 7GB | Code & analysis | Slower |

## Next Steps

1. **Explore n8n AI nodes** - Try the built-in AI Agent and Text Classifier nodes
2. **Build workflows** - Create automated processes that leverage local AI
3. **Custom nodes** - Develop your own nodes that integrate with Model Runner
4. **Scale up** - Add more workers and models as needed
5. **Monitor performance** - Use Activity Monitor to watch GPU usage

You now have a complete local AI automation platform running entirely on your machine!
