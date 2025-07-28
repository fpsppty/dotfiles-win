# Set the cursor to a solid bar
Write-Output "`e[6 q"

# Disable the "make the prompt red during parse error" because it conflicts with oh-my-posh
Set-PSReadLineOption -PromptText ''

# This function needs to be defined prior to the idle work, otherwise
# `Push-Location` will be for the wrong runspace.
function Invoke-PsFzfAltCCommandHandler
{
    param($Location)

    Push-Location -Path $Location
}

function prompt {
    # oh-my-posh will override this prompt, however because we're loading it async we want to communicate that the
    # real prompt is still loading.
    "[async init]: PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
}

# Load modules asynchronously to reduce shell startup time
[System.Collections.Queue]$__initQueue = @(
    {
        New-Module -ScriptBlock {
            function Set-PoshJobInfo {
                $jobs = @(Get-Job)
                $running = @($jobs | Where-Object { $_.State -eq "Running"}).Count
                if ($running -gt 0)
                {
                    $env:POSH_JOBS_RUNNING = $running
                }
                else
                {
                    Remove-Item ENV:\POSH_JOBS_RUNNING -ErrorAction SilentlyContinue
                }

                $finished = ($jobs.Count - $running)
                if ($finished -gt 0)
                {
                    $env:POSH_JOBS_FINISHED = $finished
                }
                else
                {
                    Remove-Item ENV:\POSH_JOBS_FINISHED -ErrorAction SilentlyContinue
                }
            }

            function Set-PoshContexts {
                Set-PoshJobInfo
            }

            # Set-PoshContext is a function called before the prompt is rendered.
            New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshContexts' -Scope Global -Force
        } | Import-Module -Global

        oh-my-posh init pwsh --config (Join-Path (Split-Path $PROFILE) theme.omp.json) | Invoke-Expression
        oh-my-posh completion powershell | Out-String | Invoke-Expression
        $Env:POSH_GIT_ENABLED = $true
    },
    {
        # This must be loaded _after_ omp, as zoxide hooks the prompt function
        New-Module -Name zoxide -ScriptBlock { Invoke-Expression (& { (zoxide init powershell | Out-String) }) } | Import-Module -Global
    },
    {
        Import-Module -Name Microsoft.WinGet.CommandNotFound -Global
    },
    {
        $Env:FZF_ALT_C_COMMAND = "fd --type dir --hidden --exclude .git"
        $ENV:FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always --icons=always {}'"
        $Env:FZF_CTRL_T_OPTS = "--preview 'bat -n --color=always --line-range :500 {}'"

        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        Set-PsFzfOption -TabExpansion
        Set-PsFzfOption -AltCCommand ${function:Invoke-PsFzfAltCCommandHandler}
    },
    {
        $Env:EZA_CONFIG_DIR = "$env:USERPROFILE/.config/eza"
    },
    {
        $Env:BAT_CONFIG_DIR="$Env:USERPROFILE/.config/bat"
        $Env:BAT_CONFIG_PATH="$Env:USERPROFILE/.config/bat/bat.conf"
    },
    {
        Import-Module -Name (Join-Path (Split-Path $PROFILE) scripts UserScripts.psd1) -Global
    },
    {
        # PowerShell parameter completion shim for the dotnet CLI
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
                dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    },
    {
        $Env:PYTHONIOENCODING='utf-8'
        New-Module -Name thefuck -ScriptBlock { iex "$(thefuck --alias fix)" } | Import-Module -Global
    }
)

Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
    if ($__initQueue.Count -gt 0) {
        & $__initQueue.Dequeue()
    } else {
        Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
        Remove-Variable -Name '__initQueue' -Scope Global -Force
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}
