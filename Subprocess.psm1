using namespace System.Diagnostics
using namespace System.IO

# Define the Terminal configuration structure
class TerminalConfig {
    [string[]]$Args
    [string[]]$Exts

    TerminalConfig([string[]]$args, [string[]]$exts) {
        $this.Args = $args
        $this.Exts = $exts
    }
}

# Define the global terminal mappings
$script:TerminalMap = @{
    'cmd'    = [TerminalConfig]::new(@('cmd', '/c'), @('exe', 'bat'))
    'ps'     = [TerminalConfig]::new(@('Powershell', '-Command'), @())
    'psfile' = [TerminalConfig]::new(@('Powershell', '-File'), @('ps1'))
    'py'     = [TerminalConfig]::new(@("$PSHOME\powershell.exe"), @('py')) # Fallback executable placeholder
    'pym'    = [TerminalConfig]::new(@("$PSHOME\powershell.exe", '-m'), @())
    'vbs'    = [TerminalConfig]::new(@('wscript'), @('vbs'))
}

# Dynamically fix the python executable path if python is available
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pyExe = (Get-Command python).Source
    $script:TerminalMap['py'].Args = @($pyExe)
    $script:TerminalMap['pym'].Args = @($pyExe, '-m')
}

class SubProcess {
    hidden [bool]$_hide
    hidden [bool]$_wait
    hidden [Process]$_process
    
    [int]$Pid
    [StreamReader]$StandardOutput
    [StreamReader]$StandardError

    SubProcess([string[]]$arguments, [string]$terminal, [string]$dir) {
        # Determine terminal mapping
        if ([string]::IsNullOrEmpty($terminal)) {
            $ext = [Path]::GetExtension($arguments[0]).TrimStart('.')
            $found = $null
            foreach ($key in $script:TerminalMap.Keys) {
                if ($script:TerminalMap[$key].Exts -contains $ext) {
                    $found = $script:TerminalMap[$key]
                    break
                }
            }
            $targetTerminal = if ($null -ne $found) { $found } else { $script:TerminalMap['cmd'] }
        } else {
            $targetTerminal = $script:TerminalMap[$terminal]
        }

        # Build execution arguments
        $runArgs = [System.Collections.Generic.List[string]]::new()
        # Add the terminal shells' specific parameter args (skipping the main application binary)
        if ($targetTerminal.Args.Count -gt 1) {
            for ($i = 1; $i -lt $targetTerminal.Args.Count; $i++) {
                $runArgs.Add($targetTerminal.Args[$i])
            }
        }
        foreach ($arg in $arguments) { $runArgs.Add($arg) }

        # Setup Process Start Info
        $psi = [ProcessStartInfo]::new()
        $psi.FileName = $targetTerminal.Args[0]
        $psi.Arguments = [string]::Join(" ", ($runArgs | ForEach-Object { 
            if ($_.Contains(" ")) { """$_""" } else { $_ } 
        }))
        $psi.WorkingDirectory = if ([string]::IsNullOrEmpty($dir)) { $PWD.Path } else { $dir }
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $this MortifyWindow($this MortifyState())

        # Verbose Logging simulation
        Write-Verbose "Running Subprocess: Args=$($psi.FileName) $($psi.Arguments) | Dir=$($psi.WorkingDirectory) | Hide=$($this._hide) | Wait=$($this._wait)"

        # Start Process
        $this._process = [Process]::Start($psi)
        $this.Pid = $this._process.Id
        $this.StandardOutput = $this._process.StandardOutput
        $this.StandardError = $this._process.StandardError

        if (-not $this._hide) {
            $this.PrintAsync()
        }

        if ($this._wait) {
            $this.Wait()
        }
    }

    [bool] MortifyWindow([string]$state) { return ($state -eq "hidden") }
    [string] MortifyState() { return "visible" }

    # Properties
    [bool] get_Running() {
        if ($null -eq $this._process) { return $false }
        return -not $this._process.HasExited
    }

    [bool] get_Finished() {
        return -not $this.get_Running()
    }

    # Methods
    [void] Wait() {
        if ($null -ne $this._process) {
            $this._process.WaitForExit()
        }
    }

    [void] Stop() {
        if ($this.get_Running()) {
            $this._process.Kill()
        }
    }

    [string] Output([string]$format, [string]$stream) {
        $reader = if ($stream -eq 'err') { $this.StandardError } else { $this.StandardOutput }
        $text = $reader.ReadToEnd()

        if ($format -eq 'json') {
            return ($text | ConvertFrom-Json)
        } elseif ($format -eq 'hex') {
            # Simple hex decoding representation if requested
            $bytes = [System.Convert]::FromHexString($text.Trim())
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        }
        return $text
    }

    hidden [void] PrintAsync() {
        # Asynchronously pipe process streams to the host terminal screen
        $action = {
            param($reader, $isError)
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ($isError) {
                    Write-Error $line
                } else {
                    Write-Host $line
                }
            }
        }
        Start-ThreadJob -ScriptBlock $action -ArgumentList $this.StandardOutput, $false
        Start-ThreadJob -ScriptBlock $action -ArgumentList $this.StandardError, $true
    }
}

# Inherited Child Classes mimicking Python configurations
class Run : SubProcess {
    Run([string[]]$arguments, [string]$terminal, [string]$dir) : base($arguments, $terminal, $dir) {
        $this._hide = $false
        $this._wait = $true
    }
}

class RunHidden : SubProcess {
    RunHidden([string[]]$arguments, [string]$terminal, [string]$dir) : base($arguments, $terminal, $dir) {
        $this._hide = $true
        $this._wait = $true
    }
}

class Start : SubProcess {
    Start([string[]]$arguments, [string]$terminal, [string]$dir) : base($arguments, $terminal, $dir) {
        $this._hide = $false
        $this._wait = $false
    }
}

class StartHidden : SubProcess {
    StartHidden([string[]]$arguments, [string]$terminal, [string]$dir) : base($arguments, $terminal, $dir) {
        $this._hide = $true
        $this._wait = $false
    }
}

# Export elements explicitly to allow standard PowerShell importing
Export-ModuleMember -Variable TerminalMap
