# Claude Code + Ollama Local Setup

Run **Claude Code** completely locally on your Windows machine using **Ollama** models — no Anthropic subscription required.

---

## What This Does

The setup script (`setup-claude-code.ps1`) automatically:

1. Checks your system RAM to ensure compatibility
2. Installs **Ollama** (local AI model runner) if not present
3. Installs **Claude Code** (Anthropic's AI coding assistant) if not present
4. Downloads and tests AI models for tool calling compatibility
5. Configures Claude Code to use your local Ollama models
6. Falls back to cloud models via Ollama if local models don't work

---

## Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 | Windows 11 |
| RAM | 8 GB total | 16 GB+ |
| Free RAM | 6 GB | 10 GB+ |
| Storage | 5 GB free | 20 GB+ free |
| Internet | Required for setup | Not needed after setup |
| PowerShell | v5.1 | v7+ |

---

## Quick Start

### Step 1 — Allow PowerShell scripts to run

Open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Press `Y` when prompted.

### Step 2 — Run the setup script

```powershell
.\setup-claude-code.ps1
```

### Step 3 — First launch of Claude Code

After setup, run:

```powershell
claude
```

On the login screen:
- Select **option 2** → `Anthropic Console account · API usage billing`
- When asked for an API key, type `ollama` and press **Enter**

That's it! Claude Code is now running locally.

---

## Script Options

### Default (auto-select best local model)

```powershell
.\setup-claude-code.ps1
```

### Specify a preferred model

```powershell
.\setup-claude-code.ps1 -PreferredModel "llama3.1:8b"
```

### Force cloud model mode

```powershell
.\setup-claude-code.ps1 -UseCloudFallback
```

---

## Compatible Models

The script automatically tests models for **tool calling support**, which Claude Code requires. Not all Ollama models support this.

### Local Models (Tested & Working)

| Model | Size | Best For |
|---|---|---|
| `llama3.1:8b` | ~4.7 GB | Best compatibility, great all-rounder ✅ |
| `llama3.2:3b` | ~2.0 GB | Low RAM machines, fast responses |
| `mistral:7b` | ~4.1 GB | Strong general purpose |
| `gemma2:9b` | ~5.4 GB | Good reasoning tasks |
| `qwen2.5-coder:7b` | ~4.7 GB | Coding focused (may have tool issues) |

### Cloud Models (via Ollama, requires login)

| Model | Notes |
|---|---|
| `mistral-small3.1` | Requires `ollama login` |
| `llama3.3` | Requires `ollama login` |

---

## How It Works

### Why some models fail

Claude Code needs **tool calling** (also called function calling) to work. This lets Claude Code:
- Create and edit files
- Run terminal commands
- Navigate your project

Models that don't support tool calling will hang indefinitely when Claude Code sends requests. The script automatically tests each model before selecting it.

### The API bridge

Claude Code is designed to talk to Anthropic's cloud API. To use it locally, the script configures it to talk to **Ollama's Anthropic-compatible API** at `http://localhost:11434` instead.

### Settings file

The script writes your configuration to:
```
C:\Users\<YourName>\.claude\settings.json
```

Contents:
```json
{
  "autoUpdatesChannel": "latest",
  "env": {
    "ANTHROPIC_API_KEY": "ollama",
    "ANTHROPIC_BASE_URL": "http://localhost:11434"
  },
  "model": "llama3.1:8b"
}
```

---

## Daily Usage

### Starting Claude Code

1. Ollama starts automatically with Windows (no action needed)
2. Open PowerShell in your project folder
3. Run:
   ```powershell
   claude
   ```

### Switching models

Inside Claude Code:
```
/model
```

Or from command line:
```powershell
claude --model llama3.1:8b
```

### Useful Claude Code commands

| Command | Description |
|---|---|
| `/init` | Scan project and create CLAUDE.md instructions file |
| `/model` | Switch to a different AI model |
| `/help` | Show all available commands |
| `Esc` | Cancel current operation |
| `Ctrl+C` | Exit Claude Code |

### Keeping the model loaded (faster responses)

By default, Ollama unloads the model after 5 minutes of inactivity. To keep it loaded for 24 hours:

```powershell
[System.Environment]::SetEnvironmentVariable('OLLAMA_KEEP_ALIVE', '24h', 'User')
```

---

## Troubleshooting

### "Model requires more memory than is available"

Your RAM is too low for the model. Solutions:
- Close other applications to free RAM
- Use a smaller model: `ollama pull llama3.2:3b`
- Run the script with a smaller model: `.\setup-claude-code.ps1 -PreferredModel "llama3.2:3b"`

### Claude Code hangs on every request

This means the model doesn't support tool calling. Solutions:
- Run the setup script again — it will test and find a working model
- Try a confirmed working model: `ollama pull llama3.1:8b`

### "Only one usage of each socket address permitted"

Ollama is already running in the background. This is normal — just use Ollama directly:
```powershell
ollama list   # verify it's running
claude        # start Claude Code normally
```

### Claude Code is still hitting api.anthropic.com

Your settings file may not be loading. Fix it:
```powershell
# Delete old config and re-run setup
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
.\setup-claude-code.ps1
```

### "Both a token and API key are set" warning

Conflicting environment variables. Fix:
```powershell
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', $null, 'User')
```
Then re-run the setup script.

### First response is very slow

The first request always takes longer (30–60 seconds) while the model loads into RAM. Subsequent responses will be much faster.

### Invalid JSON in settings.json

Check the file for trailing commas (invalid in JSON):
```powershell
cat "$env:USERPROFILE\.claude\settings.json"
```

If broken, re-run the setup script to recreate it cleanly.

---

## Uninstalling

### Remove Claude Code only

```powershell
winget uninstall Anthropic.ClaudeCode
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
```

### Remove Ollama only

```powershell
winget uninstall Ollama.Ollama
Remove-Item "$env:USERPROFILE\.ollama" -Recurse -Force
```

### Remove everything

```powershell
winget uninstall Anthropic.ClaudeCode
winget uninstall Ollama.Ollama
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
Remove-Item "$env:USERPROFILE\.ollama" -Recurse -Force
```

---

## Performance Expectations

Local models are significantly slower than Anthropic's cloud API. Typical response times:

| Task | Expected Time |
|---|---|
| Simple question | 5–15 seconds |
| Write a function | 20–60 seconds |
| Review a file | 30–90 seconds |
| `/init` on a project | 1–3 minutes |

Performance depends heavily on your CPU, RAM speed, and whether you have a GPU.

### GPU acceleration (if available)

If you have an NVIDIA GPU, Ollama will automatically use it for much faster inference. Verify with:
```powershell
nvidia-smi   # Check GPU is detected
ollama run llama3.1:8b "hello"   # Should be significantly faster
```

---

## Adding More Models

```powershell
# Browse available models at https://ollama.com/library
# Then pull any model you want to try:
ollama pull <model-name>

# List all installed models
ollama list

# Remove a model you no longer need
ollama rm <model-name>

# Use a specific model with Claude Code
claude --model <model-name>
```

---

## Cloud Models via Ollama

If local models aren't powerful enough, you can use cloud models through Ollama without paying for Anthropic's API:

```powershell
# Login to Ollama
ollama login

# Pull a cloud model
ollama pull mistral-small3.1

# Re-run setup to configure Claude Code
.\setup-claude-code.ps1 -UseCloudFallback
```

---

## File Reference

| File | Location | Purpose |
|---|---|---|
| `setup-claude-code.ps1` | Current folder | Main setup script |
| `settings.json` | `~\.claude\settings.json` | Claude Code configuration |
| `config.json` | `~\.claude\config.json` | Claude Code login state (auto-created) |
| Ollama models | `~\.ollama\models\` | Downloaded AI models |
| Ollama logs | `~\.ollama\logs\server.log` | Ollama server logs for debugging |

---

## Support

- **Ollama documentation**: https://ollama.com
- **Claude Code documentation**: https://docs.anthropic.com/en/docs/claude-code
- **Ollama model library**: https://ollama.com/library
- **Ollama GitHub issues**: https://github.com/ollama/ollama/issues
#   C l a u d e - C o d e - S e t u p  
 