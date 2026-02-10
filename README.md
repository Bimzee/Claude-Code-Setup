# Claude Code + Ollama Local Setup

Run **Claude Code** locally on any Windows machine using **Ollama** AI models — no Anthropic subscription or API key required.

---

## Contents

- [Quick Install](#quick-install)
- [What This Does](#what-this-does)
- [Requirements](#requirements)
- [Installation Options](#installation-options)
- [What Happens During Setup](#what-happens-during-setup)
- [First Launch of Claude Code](#first-launch-of-claude-code)
- [Compatible Models](#compatible-models)
- [Daily Usage](#daily-usage)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)
- [File Reference](#file-reference)

---

## Quick Install

Open **PowerShell** and run this single command:

```powershell
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

> Replace `YOUR_REPO` with the actual GitHub path where you host the script.

That's it. The script installs and configures everything automatically. No files to download, no steps to follow manually.

---

## What This Does

The setup script runs fully in-memory via `iex` and handles everything in one go:

- Sets the PowerShell execution policy so the script can run
- Checks your available RAM and skips models that won't fit
- Installs **Ollama** (local AI model runner) if not already present
- Starts the Ollama service if it isn't running
- Installs **Claude Code** if not already present
- Pulls AI models one by one and **tests each for tool calling compatibility** before selecting it
- Falls back to Ollama cloud models if no local model passes the test
- Clears any conflicting environment variables that would break Claude Code
- Writes the correct `settings.json` so Claude Code talks to your local Ollama
- Verifies the full setup before finishing

---

## Requirements

| Item | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 | Windows 11 |
| RAM (total) | 8 GB | 16 GB+ |
| RAM (free at setup time) | 6 GB | 10 GB+ |
| Disk space | 5 GB free | 20 GB+ free |
| Internet | Required during setup | Not needed after setup |
| PowerShell | v5.1 | v7+ |
| winget | Required | Pre-installed on Windows 11 |

**Before running:** close browsers, video editors, or other memory-heavy apps so Ollama has enough free RAM to load a model.

**winget** is required to install Ollama. It comes pre-installed on Windows 11. On Windows 10, update **App Installer** from the Microsoft Store or download winget from https://github.com/microsoft/winget-cli/releases.

---

## Installation Options

### Default — auto-select best local model

```powershell
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

The script automatically finds and installs the best model that fits your RAM and passes the tool calling test.

### Specify a preferred model

Set an environment variable **before** running the `iex` command:

```powershell
$env:CLAUDE_PREFERRED_MODEL = "llama3.1:8b"
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

The script tries your preferred model first. If it fails the compatibility test, it falls back to auto-selection.

### Use cloud models via Ollama

Use this if your machine has limited RAM or you want faster cloud-backed responses. Requires an Ollama account.

```powershell
$env:CLAUDE_USE_CLOUD = "true"
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

During the run, the script will pause and ask you to run `ollama login` in a separate terminal.

### Combine both options

```powershell
$env:CLAUDE_PREFERRED_MODEL = "mistral:7b"
$env:CLAUDE_USE_CLOUD = "true"
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

---

## Environment Variables

These must be set **in the same PowerShell session** before running the `iex` command. They are automatically cleared from your system environment after setup completes — they are only used to pass options into the script.

| Variable | Values | Description |
|---|---|---|
| `CLAUDE_PREFERRED_MODEL` | Any Ollama model name | Model to try first before auto-selection |
| `CLAUDE_USE_CLOUD` | `"true"` | Skip local models, use Ollama cloud models |

---

## What Happens During Setup

The script runs 7 steps. Here is exactly what each one does.

### Step 1 — System Check

Reads total and free RAM. Exits immediately if free RAM is below 6 GB. Calculates the maximum model size to attempt: `free RAM − 4 GB` (leaving headroom for the OS and background processes).

### Step 2 — Ollama Installation

Checks if `ollama` is in PATH. If not, installs it silently:

```powershell
winget install Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
```

Refreshes PATH in the current session so `ollama` is usable immediately without restarting PowerShell.

### Step 3 — Start Ollama Service

Checks if Ollama is already responding at `http://localhost:11434`. If not, starts it in the background and waits up to 20 seconds for it to become available.

### Step 4 — Claude Code Installation

Checks if `claude` is in PATH. If not, runs the official native installer:

```powershell
iex (irm https://claude.ai/install.ps1)
```

If the native installer fails, falls back to npm:

```powershell
npm install -g @anthropic-ai/claude-code
```

### Step 5 — Model Selection and Installation

This is the most critical step. The script works through this list of models in order:

```
llama3.1:8b  →  llama3.2:3b  →  mistral:7b  →  gemma2:9b  →  qwen2.5-coder:7b
```

For each model it:

1. Skips it if it is larger than the available RAM headroom
2. Pulls it via `ollama pull` if not already installed
3. Sends a real API request **with a tool definition** to `http://localhost:11434/v1/messages` and waits up to 30 seconds
4. If the request times out or returns an error, marks the model as incompatible and moves to the next
5. Selects the first model that responds successfully

> **Why this matters:** Claude Code needs tool calling to create files, run terminal commands, and interact with your project. Models that don't support it hang forever — this test catches that before you ever open Claude Code.

If no local model passes, the script prompts you to switch to cloud models (Step 5b).

### Step 5b — Cloud Model Fallback *(only if needed)*

If triggered by `CLAUDE_USE_CLOUD=true` or if all local models failed, the script pauses and asks you to run `ollama login` in a separate terminal. After you confirm, it pulls and tests:

```
mistral-small3.1  →  llama3.3
```

### Step 6 — Configure Claude Code

Permanently clears any environment variables that could cause auth conflicts in Claude Code:

```
ANTHROPIC_AUTH_TOKEN  ANTHROPIC_API_KEY  ANTHROPIC_BASE_URL  ANTHROPIC_MODEL
```

Writes the settings file at `C:\Users\<you>\.claude\settings.json`:

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

Deletes `config.json` if present so Claude Code shows a fresh login prompt on first launch and picks up the new settings.

### Step 7 — Verification

Confirms three things before finishing:
- Ollama is responding at `http://localhost:11434`
- `settings.json` exists and contains the correct model and URL
- `claude` is available in PATH

---

## First Launch of Claude Code

After setup completes, open a **new PowerShell window** and run:

```powershell
claude
```

You will see a login screen:

```
Select login method:
  1. Claude account with subscription
❯ 2. Anthropic Console account · API usage billing
  3. 3rd-party platform
```

**Select option 2.** When asked for an API key, type:

```
ollama
```

and press **Enter**. Complete the theme prompt and you are ready.

> On every subsequent launch, Claude Code skips the login screen and opens directly.

---

## Compatible Models

### Local Models (auto-tested by the script)

| Model | Disk Size | RAM Needed | Notes |
|---|---|---|---|
| `llama3.1:8b` | ~4.7 GB | ~6 GB | **Best choice.** Excellent tool support, great for coding |
| `llama3.2:3b` | ~2.0 GB | ~4 GB | Best for low-RAM machines |
| `mistral:7b` | ~4.1 GB | ~6 GB | Strong general purpose model |
| `gemma2:9b` | ~5.4 GB | ~7 GB | Good reasoning |
| `qwen2.5-coder:7b` | ~4.7 GB | ~6 GB | Coding-focused but may fail the tool test |

### Cloud Models (via Ollama, requires `ollama login`)

| Model | Notes |
|---|---|
| `mistral-small3.1` | Fast Mistral cloud model |
| `llama3.3` | Meta's larger cloud model |

### Testing any model manually

Before using a custom model with Claude Code, test if it supports tool calling:

```powershell
$body = '{"model":"<model-name>","max_tokens":50,"messages":[{"role":"user","content":"hello"}],"tools":[{"type":"function","function":{"name":"test","description":"test","parameters":{"type":"object","properties":{"x":{"type":"string"}},"required":["x"]}}}]}'
Invoke-RestMethod -Uri "http://localhost:11434/v1/messages" -Method Post -ContentType "application/json" -Body $body
```

If it responds within 30 seconds → compatible. If it hangs → not compatible.

---

## Daily Usage

### Start Claude Code

Ollama starts automatically with Windows. Just open PowerShell in your project folder and run:

```powershell
claude
```

### Switch models

```powershell
# From command line
claude --model llama3.2:3b

# From inside Claude Code
/model
```

### Claude Code commands

| Command | Description |
|---|---|
| `/init` | Scan project and create a `CLAUDE.md` instructions file |
| `/model` | Switch AI model |
| `/help` | Show all slash commands |
| `Esc` | Cancel current operation |
| `Ctrl+C` | Exit Claude Code |

### Keep model loaded between sessions

By default Ollama unloads a model after 5 minutes idle. To keep it ready for 24 hours:

```powershell
[System.Environment]::SetEnvironmentVariable('OLLAMA_KEEP_ALIVE', '24h', 'User')
```

Restart PowerShell after running this.

### Manage models

```powershell
ollama list                 # List installed models
ollama pull llama3.2:3b     # Download a model
ollama rm llama3.2:3b       # Remove a model
```

---

## Troubleshooting

### "iex" or "irm" not recognised

You are on an older PowerShell. Update PowerShell from the Microsoft Store, or run:

```powershell
winget install Microsoft.PowerShell
```

### Setup fails with "not enough free RAM"

Close other applications and run the setup again. Or specify a small model:

```powershell
$env:CLAUDE_PREFERRED_MODEL = "llama3.2:3b"
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

### All local models fail the tool calling test

Ollama's `/v1/messages` endpoint may not be working on your install. Try:

```powershell
# Reinstall Ollama
winget uninstall Ollama.Ollama
winget install Ollama.Ollama

# Then run setup with cloud fallback
$env:CLAUDE_USE_CLOUD = "true"
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

### Claude Code is still contacting `api.anthropic.com`

Settings are not being read. Reset and re-run:

```powershell
Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

### "Both a token and API key are set" warning

Leftover environment variables. Clear them:

```powershell
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', $null, 'User')
```

Then run setup again.

### "Only one usage of each socket address" when running `ollama serve`

Ollama is already running — this is not an error. Just run `claude` directly.

### Claude Code hangs on every request

The model may not have initialised tool calling properly. Clear login state and re-login:

```powershell
Remove-Item "$env:USERPROFILE\.claude\config.json" -Force -ErrorAction SilentlyContinue
claude
```

Select option 2 on the login screen and enter `ollama` as the API key.

### First response takes 30–60 seconds

Normal — the model is loading into RAM for the first time. Subsequent responses in the same session are much faster. Setting `OLLAMA_KEEP_ALIVE` (see Daily Usage) prevents this on future sessions.

### settings.json gives "Invalid or malformed JSON"

Re-run the setup to recreate the file correctly:

```powershell
iex (irm https://raw.githubusercontent.com/YOUR_REPO/main/setup-claude-code.ps1)
```

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

## File Reference

| File | Path | Purpose |
|---|---|---|
| Setup script | `setup-claude-code.ps1` | The installer — run via `iex` |
| Claude Code settings | `~\.claude\settings.json` | Model and API config (written by script) |
| Claude Code login state | `~\.claude\config.json` | Auth state (auto-created on first launch) |
| Ollama models | `~\.ollama\models\` | Downloaded AI model files |
| Ollama server log | `~\.ollama\logs\server.log` | Debug log for Ollama issues |

---

## Performance

Local models are slower than Anthropic's cloud API. Expected times on an 8–16 GB RAM machine:

| Task | Typical Time |
|---|---|
| Simple question | 5–20 seconds |
| Write a function | 20–45 seconds |
| Review a file | 30–90 seconds |
| `/init` on a project | 1–3 minutes |

If you have an **NVIDIA GPU**, Ollama uses it automatically for significantly faster responses.

---

## Resources

- Ollama model library: https://ollama.com/library
- Claude Code docs: https://docs.anthropic.com/en/docs/claude-code
- Ollama GitHub: https://github.com/ollama/ollama
- winget docs: https://learn.microsoft.com/en-us/windows/package-manager/winget
