# =============================================================================
# Claude Code + Ollama Setup Script
# =============================================================================
# Run directly on any Windows machine via:
#
#   iwr https://raw.githubusercontent.com/Bimzee/ClaudeCodeSetup/main/Setup-ClaudeCode.ps1 | iex
#
# Or download and run locally:
#   .\Setup-ClaudeCode.ps1
#   .\Setup-ClaudeCode.ps1 -PreferredModel "llama3.2:3b"
#   .\Setup-ClaudeCode.ps1 -UseCloudFallback
#   .\Setup-ClaudeCode.ps1 -SkipModelSetup
# =============================================================================

param(
    [string]$PreferredModel  = "",
    [switch]$UseCloudFallback,
    [switch]$SkipModelSetup
)

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

# Models confirmed compatible with Claude Code tool calling — best first
$COMPATIBLE_MODELS = @(
    @{ Name = "llama3.1:8b";      SizeGB = 4.7; Description = "Best compatibility, great for coding" },
    @{ Name = "llama3.2:3b";      SizeGB = 2.0; Description = "Lightweight, fast responses" },
    @{ Name = "mistral:7b";       SizeGB = 4.1; Description = "Strong general purpose model" },
    @{ Name = "gemma2:9b";        SizeGB = 5.4; Description = "Google model, good reasoning" },
    @{ Name = "qwen2.5-coder:7b"; SizeGB = 4.7; Description = "Coding focused (may have tool issues)" }
)

# Cloud fallback models (require ollama login)
$CLOUD_MODELS = @(
    @{ Name = "mistral-small3.1"; Description = "Mistral cloud model" },
    @{ Name = "llama3.3";         Description = "Meta cloud model" }
)

$OLLAMA_API      = "http://localhost:11434"
$CLAUDE_SETTINGS = "$env:USERPROFILE\.claude\settings.json"
$MIN_FREE_RAM_GB = 6

# ─────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Step   { param([string]$T); Write-Host ""; Write-Host "  ▶ $T" -ForegroundColor Yellow }
function Write-Success{ param([string]$T); Write-Host "  ✔ $T" -ForegroundColor Green }
function Write-Failure{ param([string]$T); Write-Host "  ✘ $T" -ForegroundColor Red }
function Write-Info   { param([string]$T); Write-Host "  ℹ $T" -ForegroundColor Gray }

function Get-FreeRAMGB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [math]::Round($os.FreePhysicalMemory / 1MB, 1)
}

function Get-TotalRAMGB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-OllamaRunning {
    try {
        Invoke-RestMethod -Uri "$OLLAMA_API/api/tags" -TimeoutSec 5 -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Start-OllamaService {
    Write-Step "Starting Ollama service..."
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
    for ($i = 0; $i -lt 10; $i++) {
        if (Test-OllamaRunning) { Write-Success "Ollama service is running"; return $true }
        Start-Sleep -Seconds 2
    }
    Write-Failure "Ollama service failed to start"
    return $false
}

function Test-ModelExists {
    param([string]$ModelName)
    try {
        $response = Invoke-RestMethod -Uri "$OLLAMA_API/api/tags" -ErrorAction Stop
        foreach ($m in $response.models) { if ($m.name -eq $ModelName) { return $true } }
        return $false
    } catch { return $false }
}

function Install-OllamaModel {
    param([string]$ModelName)
    Write-Step "Pulling model: $ModelName"
    Write-Info "This may take several minutes depending on your internet speed..."
    $process = Start-Process -FilePath "ollama" -ArgumentList "pull", $ModelName -PassThru -Wait -NoNewWindow
    return $process.ExitCode -eq 0
}

function Test-ModelToolSupport {
    param([string]$ModelName)
    Write-Info "Testing tool calling support for: $ModelName (up to 30s)..."

    $body = @{
        model      = $ModelName
        max_tokens = 50
        messages   = @(@{ role = "user"; content = "reply with just the word hello" })
        tools      = @(@{
            type     = "function"
            function = @{
                name        = "test_tool"
                description = "A test tool"
                parameters  = @{
                    type       = "object"
                    properties = @{ input = @{ type = "string"; description = "input" } }
                    required   = @("input")
                }
            }
        })
    } | ConvertTo-Json -Depth 10

    try {
        $ollamaApi = $OLLAMA_API
        $job = Start-Job -ScriptBlock {
            param($Uri, $Body)
            try {
                Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Body $Body -ErrorAction Stop
                return "success"
            } catch { return "error: $_" }
        } -ArgumentList "$ollamaApi/v1/messages", $body

        $result = Wait-Job $job -Timeout 30
        if ($result.State -eq "Completed") {
            $output = Receive-Job $job
            Remove-Job $job -Force
            if ($output -like "error*") { Write-Info "Tool call returned error"; return $false }
            return $true
        } else {
            Stop-Job $job; Remove-Job $job -Force
            Write-Info "Tool call timed out — model does not support tools"
            return $false
        }
    } catch { return $false }
}

function Save-ClaudeSettings {
    param([string]$ModelName, [string]$BaseUrl = $OLLAMA_API)
    $claudeDir = "$env:USERPROFILE\.claude"
    if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
    $settings = "{`"autoUpdatesChannel`":`"latest`",`"env`":{`"ANTHROPIC_API_KEY`":`"ollama`",`"ANTHROPIC_BASE_URL`":`"$BaseUrl`"},`"model`":`"$ModelName`"}"
    Set-Content -Path $CLAUDE_SETTINGS -Value $settings -Encoding UTF8
    Write-Success "Settings saved: $CLAUDE_SETTINGS"
}

function Show-FinalInstructions {
    param([string]$ModelName, [bool]$IsCloud = $false)

    Write-Header "Setup Complete!"
    Write-Host ""
    Write-Host "  Model : " -NoNewline -ForegroundColor White
    Write-Host $ModelName -ForegroundColor Green
    Write-Host "  Mode  : " -NoNewline -ForegroundColor White
    if ($IsCloud) {
        Write-Host "Cloud via Ollama" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  NOTE: Ensure you stay logged in to Ollama:" -ForegroundColor Yellow
        Write-Host "        ollama login" -ForegroundColor White
    } else {
        Write-Host "Local (fully offline)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  ─── HOW TO START ───────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  1. Open a new PowerShell window" -ForegroundColor White
    Write-Host "  2. Run:  claude" -ForegroundColor Cyan
    Write-Host "  3. Select option 2  (Anthropic Console · API usage billing)" -ForegroundColor White
    Write-Host "  4. When asked for an API key, type:  ollama" -ForegroundColor White
    Write-Host ""
    Write-Host "  ─── USEFUL COMMANDS ────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  claude                    Start Claude Code" -ForegroundColor White
    Write-Host "  claude --model <name>     Use a specific model" -ForegroundColor White
    Write-Host "  ollama list               List installed models" -ForegroundColor White
    Write-Host "  ollama pull <name>        Download a model" -ForegroundColor White
    Write-Host ""
}

# ─────────────────────────────────────────────
# MAIN SCRIPT
# ─────────────────────────────────────────────

# Set execution policy so iwr | iex works on fresh machines
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue

Clear-Host
Write-Host ""
Write-Host "  ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗" -ForegroundColor Cyan
Write-Host " ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝" -ForegroundColor Cyan
Write-Host " ██║     ██║     ███████║██║   ██║██║  ██║█████╗  " -ForegroundColor Cyan
Write-Host " ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  " -ForegroundColor Cyan
Write-Host " ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗" -ForegroundColor Cyan
Write-Host "  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "     Claude Code + Ollama  —  Local Setup" -ForegroundColor White
Write-Host ""

# ─── STEP 1: System Check ───────────────────
Write-Header "Step 1: System Check"

$totalRAM = Get-TotalRAMGB
$freeRAM  = Get-FreeRAMGB

Write-Info "Total RAM : $totalRAM GB"
Write-Info "Free RAM  : $freeRAM GB"

if ($freeRAM -lt $MIN_FREE_RAM_GB) {
    Write-Failure "Not enough free RAM ($freeRAM GB free, $MIN_FREE_RAM_GB GB required)."
    Write-Host "  Please close other applications and run the setup again." -ForegroundColor Yellow
    exit 1
}
Write-Success "RAM check passed"

# Leave 4 GB headroom for OS and background processes
$maxModelSize = [math]::Floor($freeRAM - 4)
Write-Info "Will consider models up to $maxModelSize GB"

# ─── STEP 2: Install Ollama ─────────────────
Write-Header "Step 2: Ollama Installation"

if (Test-CommandExists "ollama") {
    $ver = (ollama --version 2>&1)
    Write-Success "Ollama already installed: $ver"
} else {
    Write-Step "Installing Ollama via winget..."
    winget install Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements

    # Refresh PATH in current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")

    if (-not (Test-CommandExists "ollama")) {
        Write-Failure "Ollama installed but not found in PATH."
        Write-Host "  Open a new PowerShell window and run the setup again." -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Ollama installed successfully"
}

# ─── STEP 3: Start Ollama ───────────────────
Write-Header "Step 3: Starting Ollama Service"

if (Test-OllamaRunning) {
    Write-Success "Ollama is already running"
} else {
    if (-not (Start-OllamaService)) {
        Write-Failure "Could not start Ollama. Run 'ollama serve' manually and retry."
        exit 1
    }
}

# ─── STEP 4: Install Claude Code ────────────
Write-Header "Step 4: Claude Code Installation"

if (Test-CommandExists "claude") {
    $ver = (claude --version 2>&1)
    Write-Success "Claude Code already installed: $ver"
} else {
    Write-Step "Installing Claude Code via native installer..."
    try {
        Invoke-Expression (Invoke-RestMethod -Uri "https://claude.ai/install.ps1")

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")

        if (Test-CommandExists "claude") {
            Write-Success "Claude Code installed successfully"
        } else {
            Write-Failure "Claude Code installer ran but 'claude' not found in PATH."
            Write-Host "  Open a new PowerShell window and run the setup again." -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Failure "Native installer failed. Trying npm fallback..."
        if (Test-CommandExists "npm") {
            npm install -g @anthropic-ai/claude-code
            if (Test-CommandExists "claude") {
                Write-Success "Claude Code installed via npm"
            } else {
                Write-Failure "npm install failed. Please install Claude Code manually."
                exit 1
            }
        } else {
            Write-Failure "Neither native installer nor npm available."
            Write-Host "  Install Node.js from https://nodejs.org then run the setup again." -ForegroundColor Yellow
            exit 1
        }
    }
}

# ─── STEP 5: Model Selection ────────────────
if ($SkipModelSetup) {
    Write-Header "Step 5: Model Setup (Skipped)"
    Write-Info "Skipping model setup as requested (-SkipModelSetup)"
    Write-Info "Run 'ollama pull llama3.1:8b' manually to install a model"
    $selectedModel = "llama3.1:8b"
    $useCloud = $false
} else {
    Write-Header "Step 5: Model Selection and Installation"

    $selectedModel = ""
    $useCloud      = $false

    # Try preferred model first if specified
    if ($PreferredModel -ne "") {
        Write-Info "Preferred model specified: $PreferredModel"
        if (-not (Test-ModelExists $PreferredModel)) {
            $ok = Install-OllamaModel -ModelName $PreferredModel
            if (-not $ok) { Write-Failure "Could not pull $PreferredModel — falling back to auto-selection" }
        }
        if (Test-ModelExists $PreferredModel) {
            if (Test-ModelToolSupport -ModelName $PreferredModel) {
                $selectedModel = $PreferredModel
                Write-Success "$PreferredModel is compatible and selected!"
            } else {
                Write-Failure "$PreferredModel does not support tool calling — trying other models..."
            }
        }
    }

    # Auto-select best compatible local model
    if ($selectedModel -eq "" -and -not $UseCloudFallback) {
        Write-Step "Finding best compatible local model..."

        foreach ($model in $COMPATIBLE_MODELS) {
            if ($model.SizeGB -gt $maxModelSize) {
                Write-Info "Skipping $($model.Name) ($($model.SizeGB) GB) — too large for available RAM"
                continue
            }

            Write-Info "Trying: $($model.Name) — $($model.Description)"

            if (-not (Test-ModelExists $model.Name)) {
                $ok = Install-OllamaModel -ModelName $model.Name
                if (-not $ok) { Write-Failure "Failed to pull $($model.Name) — trying next..."; continue }
            } else {
                Write-Info "$($model.Name) already installed"
            }

            if (Test-ModelToolSupport -ModelName $model.Name) {
                $selectedModel = $model.Name
                Write-Success "$($model.Name) supports tool calling — selected!"
                break
            } else {
                Write-Failure "$($model.Name) does not support tool calling — trying next..."
            }
        }
    }

    # Cloud fallback
    if ($selectedModel -eq "" -or $UseCloudFallback) {
        Write-Host ""
        if ($UseCloudFallback) {
            Write-Info "Cloud fallback requested via -UseCloudFallback"
        } else {
            Write-Host "  No suitable local model found." -ForegroundColor Yellow
            $answer = Read-Host "  Use cloud models via Ollama instead? (requires ollama login) [Y/N]"
            if ($answer -notmatch "^[Yy]$") {
                Write-Failure "Setup cancelled. Free up RAM or use -PreferredModel with a smaller model."
                exit 1
            }
        }

        Write-Header "Step 5b: Cloud Model Setup"
        Write-Host ""
        Write-Host "  Run this in a separate terminal window, then return here:" -ForegroundColor Yellow
        Write-Host "        ollama login" -ForegroundColor Cyan
        Write-Host ""
        $loginDone = Read-Host "  Have you completed ollama login? [Y/N]"

        if ($loginDone -match "^[Yy]$") {
            foreach ($model in $CLOUD_MODELS) {
                Write-Info "Trying cloud model: $($model.Name)"
                $ok = Install-OllamaModel -ModelName $model.Name
                if ($ok -and (Test-ModelToolSupport -ModelName $model.Name)) {
                    $selectedModel = $model.Name
                    $useCloud      = $true
                    Write-Success "Cloud model $($model.Name) is working!"
                    break
                }
            }
        }

        if ($selectedModel -eq "") {
            Write-Failure "Could not set up any working model."
            Write-Host ""
            Write-Host "  Options to try:" -ForegroundColor Yellow
            Write-Host "  • Free up RAM and run the setup again" -ForegroundColor White
            Write-Host "  • Use a smaller model:" -ForegroundColor White
            Write-Host "      .\Setup-ClaudeCode.ps1 -PreferredModel 'llama3.2:3b'" -ForegroundColor Cyan
            Write-Host "  • Browse models: https://ollama.com/library" -ForegroundColor White
            exit 1
        }
    }
}

# ─── STEP 6: Configure Claude Code ──────────
Write-Header "Step 6: Configuring Claude Code"

Write-Step "Clearing conflicting environment variables..."
foreach ($var in @("ANTHROPIC_AUTH_TOKEN","ANTHROPIC_API_KEY","ANTHROPIC_BASE_URL","ANTHROPIC_MODEL")) {
    [System.Environment]::SetEnvironmentVariable($var, $null, "User")
    Remove-Item "Env:$var" -ErrorAction SilentlyContinue
}
Write-Success "Environment variables cleared"

Write-Step "Writing Claude Code settings..."
Save-ClaudeSettings -ModelName $selectedModel -BaseUrl $OLLAMA_API

Write-Step "Clearing old login state..."
$configPath = "$env:USERPROFILE\.claude\config.json"
if (Test-Path $configPath) {
    Remove-Item $configPath -Force
    Write-Info "Removed config.json — fresh login required on first run"
}

# ─── STEP 7: Verify ─────────────────────────
Write-Header "Step 7: Verification"

$allGood = $true

if (Test-OllamaRunning) {
    Write-Success "Ollama is running at $OLLAMA_API"
} else {
    Write-Failure "Ollama is not responding — run 'ollama serve' manually"
    $allGood = $false
}

if (Test-Path $CLAUDE_SETTINGS) {
    $content = Get-Content $CLAUDE_SETTINGS -Raw | ConvertFrom-Json
    Write-Success "Settings file written"
    Write-Info "  Model    : $($content.model)"
    Write-Info "  Base URL : $($content.env.ANTHROPIC_BASE_URL)"
} else {
    Write-Failure "Settings file not found"
    $allGood = $false
}

if (Test-CommandExists "claude") {
    Write-Success "Claude Code is in PATH and ready"
} else {
    Write-Failure "Claude Code not found in PATH"
    $allGood = $false
}

if (-not $allGood) {
    Write-Host ""
    Write-Host "  One or more checks failed. Review the errors above and re-run the setup." -ForegroundColor Yellow
}

# ─── DONE ───────────────────────────────────
Show-FinalInstructions -ModelName $selectedModel -IsCloud $useCloud
