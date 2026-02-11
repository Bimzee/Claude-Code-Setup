# ClaudeCodeSetup

Automated installation and configuration of **Claude Code** with local AI models via **Ollama**. No Anthropic subscription or API key required.

## Quick Start

Run this one-liner in PowerShell to automatically configure your machine:

```powershell
iwr https://raw.githubusercontent.com/Bimzee/ClaudeCodeSetup/main/Setup-ClaudeCode.ps1 | iex
```

Or download and run locally:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Bimzee/ClaudeCodeSetup/main/Setup-ClaudeCode.ps1" -OutFile "Setup-ClaudeCode.ps1"
.\Setup-ClaudeCode.ps1
```

## What Does This Do?

The `Setup-ClaudeCode.ps1` script automatically:

✅ Checks available RAM and skips models too large for your machine  
✅ Installs **Ollama** (local AI model runner) via winget if not present  
✅ Starts the Ollama service if it isn't running  
✅ Installs **Claude Code** via the official native installer  
✅ Pulls AI models and **tests each one for tool calling compatibility** before selecting  
✅ Falls back to Ollama cloud models if no local model passes the test  
✅ Clears conflicting environment variables that would break Claude Code  
✅ Writes the correct `settings.json` so Claude Code talks to your local Ollama  
✅ Verifies the full setup before finishing  

## First Launch

After the script finishes, open a **new PowerShell window** and run:

```powershell
claude
```

On the login screen:

1. Select **option 2** → `Anthropic Console account · API usage billing`
2. When asked for an API key, type `ollama` and press **Enter**

Claude Code is now running on your local machine.

## Script Parameters

### Default — auto-select best local model

```powershell
.\Setup-ClaudeCode.ps1
```

### Specify a preferred model

```powershell
.\Setup-ClaudeCode.ps1 -PreferredModel "llama3.1:8b"
```

Tries your preferred model first. Falls back to auto-selection if it fails the tool calling test.

### Use cloud models via Ollama

```powershell
.\Setup-ClaudeCode.ps1 -UseCloudFallback
```

Skips local models entirely and sets up cloud models via Ollama. Requires `ollama login`.

### Skip model setup

```powershell
.\Setup-ClaudeCode.ps1 -SkipModelSetup
```

Installs Ollama and Claude Code only, without pulling or testing any models. Useful if you want to manage models separately.

### Custom preferred model with cloud fallback

```powershell
.\Setup-ClaudeCode.ps1 -PreferredModel "mistral:7b" -UseCloudFallback
```

## Compatible Models

The script tests each model for **tool calling support** before selecting it. Tool calling is what Claude Code uses to create files, run commands, and interact with your project — models that don't support it will hang indefinitely.

### Local Models (auto-tested by the script)

| Model | Size | Notes |
|---|---|---|
| `llama3.1:8b` | ~4.7 GB | **Best choice.** Excellent tool support, great for coding |
| `llama3.2:3b` | ~2.0 GB | Best for low-RAM machines, fast responses |
| `mistral:7b` | ~4.1 GB | Strong general purpose model |
| `gemma2:9b` | ~5.4 GB | Good reasoning |
| `qwen2.5-coder:7b` | ~4.7 GB | Coding focused — may fail tool calling test |

### Cloud Models (via Ollama, requires `ollama login`)

| Model | Notes |
|---|---|
| `mistral-small3.1` | Fast Mistral cloud model |
| `llama3.3` | Meta's larger cloud model |

## Example Usage

```powershell
# Start Claude Code
claude

# Use a specific model
claude --model llama3.2:3b

# Switch model inside Claude Code
/model

# Scan project and create CLAUDE.md
/init

# List installed Ollama models
ollama list

# Pull an additional model
ollama pull llama3.2:3b

# Remove a model you no longer need
ollama rm llama3.2:3b
```

## Safety Features

✅ **RAM Check:** Measures free RAM at startup and skips models that won't fit  
✅ **Tool Compatibility Test:** Every model is tested for tool calling before being selected  
✅ **Idempotent:** Safe to run multiple times — skips steps already completed  
✅ **Conflict Cleanup:** Removes any `ANTHROPIC_*` environment variables that would cause auth errors  
✅ **Verification:** Confirms Ollama, settings, and Claude Code are all working before finishing  
✅ **Fallback Chain:** Native installer → npm → manual instructions  

## Requirements

- Windows 10 or later with PowerShell 5.1+
- **winget** available (pre-installed on Windows 11; update App Installer from Microsoft Store on Windows 10)
- At least **6 GB free RAM** at setup time
- Internet connection (for downloading Ollama, Claude Code, and models)

If winget is not installed, download it from: https://github.com/microsoft/winget-cli/releases

## File Structure

```
ClaudeCodeSetup/
├── Setup-ClaudeCode.ps1     # Main installation script
└── README.md                # This file
```

## Troubleshooting

### "Cannot be loaded because running scripts is disabled"

Run this command to enable script execution:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Not enough free RAM"

Close other applications to free memory, then run the setup again. Or force a smaller model:

```powershell
.\Setup-ClaudeCode.ps1 -PreferredModel "llama3.2:3b"
```

### All models fail the tool calling test

Ollama's messages API may not be working on your install. Reinstall Ollama and try again:

```powershell
winget uninstall Ollama.Ollama
winget install Ollama.Ollama
.\Setup-ClaudeCode.ps1
```

Or switch to cloud models:

```powershell
.\Setup-ClaudeCode.ps1 -UseCloudFallback
```

### Claude Code still contacts api.anthropic.com

Settings are not being read. Reset and re-run:

```powershell
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
.\Setup-ClaudeCode.ps1
```

Or via the one-liner:

```powershell
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
iwr https://raw.githubusercontent.com/Bimzee/ClaudeCodeSetup/main/Setup-ClaudeCode.ps1 | iex
```

### "Both a token and API key are set" warning in Claude Code

Leftover environment variables are conflicting. The setup script clears these automatically, but if you see it after a manual install:

```powershell
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', $null, 'User')
```

Then run the setup again.

### "Only one usage of each socket address" when running `ollama serve`

Ollama is already running in the background — this is not an error. Just run `claude` directly.

### First response takes 30–60 seconds

Normal — the model is loading into RAM for the first time. Subsequent responses in the same session will be much faster.

To keep the model loaded between sessions (avoids the cold-start delay):

```powershell
[System.Environment]::SetEnvironmentVariable('OLLAMA_KEEP_ALIVE', '24h', 'User')
```

Restart PowerShell after running this.

### Changes Not Appearing

After running the script, open a fresh PowerShell window:

```powershell
claude
```

## Manual Installation

If you prefer to set things up manually:

**1. Install Ollama**

```powershell
winget install Ollama.Ollama
```

**2. Pull a compatible model**

```powershell
ollama pull llama3.1:8b
```

**3. Install Claude Code**

```powershell
iex (irm https://claude.ai/install.ps1)
```

**4. Write the settings file**

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.claude" -Force | Out-Null
Set-Content -Path "$env:USERPROFILE\.claude\settings.json" -Value '{"autoUpdatesChannel":"latest","env":{"ANTHROPIC_API_KEY":"ollama","ANTHROPIC_BASE_URL":"http://localhost:11434"},"model":"llama3.1:8b"}'
```

**5. Start Claude Code**

```powershell
claude
```

Select option 2 on the login screen and enter `ollama` as the API key.

Or simply run the automated script above for automatic handling.

## Contributing

Feel free to fork and customise for your own use! This is a personal configuration repository.

## License

Public domain — use freely!
