
$ErrorActionPreference = 'Stop'

# ------------------------------------------
# Configuration
# ------------------------------------------

# Use the current working directory, NOT the script directory.
$ProjectRoot = (Get-Location).Path

$PolymodUrl = 'https://github.com/larsiusprime/polymod.git'
$PolymodCommit = '3204f48'

$RequiredComponents = @(
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
    'Microsoft.VisualStudio.Component.Windows11SDK.26100'
)

$Libraries = @(
    @{ Name = 'lime';          Version = '7.9.0' }
    @{ Name = 'openfl';        Version = '9.1.0' }
    @{ Name = 'hxcpp';         Version = '4.2.1' }
    @{ Name = 'flixel';        Version = '4.11.0' }
    @{ Name = 'flixel-addons'; Version = '2.11.0' }
    @{ Name = 'flixel-ui';     Version = '2.3.3' }
    @{ Name = 'hscript';       Version = '2.4.0' }
    @{ Name = 'newgrounds';    Version = '1.1.5' }
    @{ Name = 'haxeui-core';   Version = '1.7.0' }
    @{ Name = 'haxeui-flixel'; Version = '1.7.0' }
)

$VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$VsSetup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'

# ------------------------------------------
# Output helpers
# ------------------------------------------

function Write-Header {
    param([string]$Title)

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host '  ----------------------------------------' -ForegroundColor DarkGray
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Gray
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

# ------------------------------------------
# External command helpers
# ------------------------------------------

function Invoke-Native {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    & $Path @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$([IO.Path]::GetFileName($Path)) failed (exit code $LASTEXITCODE)."
    }
}

function Get-NativeOutput {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    $Output = & $Path @Arguments 2>$null

    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($Output | Where-Object { "$_".Trim() } |
        Select-Object -First 1).ToString().Trim()
}

# ------------------------------------------
# 1. Project validation
# ------------------------------------------

function Initialize-Project {
    Write-Header 'PROJECT VALIDATION'

    if (-not (Test-Path (Join-Path $ProjectRoot 'Project.xml'))) {
        throw "Project.xml was not found in $ProjectRoot"
    }

    $Source = Join-Path $ProjectRoot 'source'
    $ApiFile = Join-Path $Source 'APIStuff.hx'
    $RootApiFile = Join-Path $ProjectRoot 'APIStuff.hx'

    if (-not (Test-Path $Source)) {
        New-Item -ItemType Directory -Path $Source | Out-Null
    }

    if (-not (Test-Path $ApiFile)) {
        if (-not (Test-Path $RootApiFile)) {
            throw 'APIStuff.hx is missing from the repository.'
        }

        Write-Info 'Copying APIStuff.hx...'
        Copy-Item $RootApiFile $ApiFile -Force
    }

    Write-OK 'Project files verified.'
}

# ------------------------------------------
# 2. Required programs
# ------------------------------------------

function Initialize-Programs {
    Write-Header 'REQUIRED PROGRAMS'

    foreach ($Program in @('haxe', 'haxelib', 'git')) {
        $Command = Get-Command $Program -ErrorAction SilentlyContinue

        if (-not $Command) {
            throw "$Program is not installed or missing from PATH."
        }

        Write-OK "$Program found."
    }

    $script:Haxe = (Get-Command haxe).Source
    $script:Haxelib = (Get-Command haxelib).Source
    $script:Git = (Get-Command git).Source
}

# ------------------------------------------
# 3. Visual Studio Build Tools
# ------------------------------------------

function Initialize-VisualStudio {
    Write-Header 'VISUAL STUDIO BUILD TOOLS'

    if (-not (Test-Path $VsWhere)) {
        throw "vswhere.exe was not found: $VsWhere"
    }

    $Arguments = @(
        '-latest'
        '-products'
        'Microsoft.VisualStudio.Product.BuildTools'
        '-requires'
        $RequiredComponents[0]
        $RequiredComponents[1]
        '-property'
        'installationPath'
    )

    $CompletePath = Get-NativeOutput $VsWhere $Arguments

    if ($CompletePath) {
        Write-OK 'Build Tools and required components are installed.'
        return
    }

    # Look for Build Tools without requiring both components.
    $AnyPath = Get-NativeOutput $VsWhere @(
        '-latest'
        '-products'
        'Microsoft.VisualStudio.Product.BuildTools'
        '-property'
        'installationPath'
    )

    if ($AnyPath) {
        Write-Info "Found Build Tools: $AnyPath"

        if (-not (Test-Path $VsSetup)) {
            throw 'Visual Studio Installer setup.exe was not found.'
        }

        Write-Info 'Installing missing Visual Studio components...'

        $ComponentArguments = (
            'modify --installPath "{0}" --channelId VisualStudio.17.Release --add {1} --add {2} --quiet --norestart' -f
            $AnyPath,
            $RequiredComponents[0],
            $RequiredComponents[1]
        )

        $Process = Start-Process -FilePath $VsSetup `
            -ArgumentList $ComponentArguments `
            -Verb RunAs -Wait -PassThru

    } else {
        Write-Info 'Visual Studio 2022 Build Tools not found.'
        Write-Info 'Downloading installer...'

        $Bootstrapper = Join-Path $env:TEMP 'vs_BuildTools.exe'
        $DownloadUrl = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'

        Invoke-WebRequest -Uri $DownloadUrl -OutFile $Bootstrapper -UseBasicParsing

        $InstallArguments = (
            '--installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" ' +
            '--channelId VisualStudio.17.Release ' +
            '--add {0} --add {1} --passive --norestart --wait' -f
            $RequiredComponents[0],
            $RequiredComponents[1]
        )

        $Process = Start-Process -FilePath $Bootstrapper `
            -ArgumentList $InstallArguments `
            -Verb RunAs -Wait -PassThru
    }

    if ($Process.ExitCode -notin @(0, 3010, 1641)) {
        throw "Visual Studio installation failed (exit code $($Process.ExitCode))."
    }

    if ($Process.ExitCode -in @(3010, 1641)) {
        Write-Warn 'Visual Studio reports that Windows needs a restart.'
    }

    # Verify the installation again.
    $CompletePath = Get-NativeOutput $VsWhere $Arguments

    if (-not $CompletePath) {
        throw 'Visual Studio components could not be verified after installation.'
    }

    Write-OK 'Visual Studio configuration verified.'
}

# ------------------------------------------
# 4. Local Haxelib repository
# ------------------------------------------

function Initialize-Haxelib {
    Write-Header 'HAXELIB DEPENDENCIES'

    $LocalRepo = Join-Path $ProjectRoot '.haxelib'

    if (-not (Test-Path $LocalRepo)) {
        Write-Info 'Creating project-local Haxelib repository...'
        Invoke-Native $Haxelib @('newrepo')
    }

    $CurrentRepo = Get-NativeOutput $Haxelib @('config')

    if (-not $CurrentRepo) {
        throw 'Could not determine the active Haxelib repository.'
    }

    $Expected = [IO.Path]::GetFullPath($LocalRepo).TrimEnd('\', '/')
    $Actual = [IO.Path]::GetFullPath($CurrentRepo).TrimEnd('\', '/')

    if ($Expected -ine $Actual) {
        throw "Haxelib is using the wrong repository: $CurrentRepo"
    }

    Write-OK "Local repository: $CurrentRepo"

    foreach ($Library in $Libraries) {
        $Name = $Library.Name
        $Version = $Library.Version

        Write-Info "Checking $Name $Version..."

        & $Haxelib path "${Name}:${Version}" *> $null

        if ($LASTEXITCODE -ne 0) {
            Write-Info "Installing $Name $Version..."
            Invoke-Native $Haxelib @('install', $Name, $Version)
        }

        Invoke-Native $Haxelib @('set', $Name, $Version)

        Write-OK "$Name $Version ready."
    }
}

# ------------------------------------------
# 5. Polymod revision verification
# ------------------------------------------

function Initialize-Polymod {
    Write-Header 'POLYMOD'

    $PolymodPath = Get-NativeOutput $Haxelib @('libpath', 'polymod')

    if ($PolymodPath) {
        $ActualCommit = Get-NativeOutput $Git @(
            '-C', $PolymodPath, 'rev-parse', 'HEAD'
        )

        if ($ActualCommit -and
            $ActualCommit.StartsWith(
                $PolymodCommit,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            Write-OK "Correct revision installed: $PolymodCommit"
            return
        }

        Write-Warn 'Incorrect Polymod revision detected.'
        Write-Info 'Removing existing installation...'

        Invoke-Native $Haxelib @('dev', 'polymod')
        Invoke-Native $Haxelib @('remove', 'polymod')
    }

    Write-Info "Installing Polymod $PolymodCommit..."

    Invoke-Native $Haxelib @(
        'git'
        'polymod'
        $PolymodUrl
        $PolymodCommit
    )

    # Verify the newly installed revision.
    $PolymodPath = Get-NativeOutput $Haxelib @('libpath', 'polymod')

    if (-not $PolymodPath) {
        throw 'Could not locate the installed Polymod library.'
    }

    $ActualCommit = Get-NativeOutput $Git @(
        '-C', $PolymodPath, 'rev-parse', 'HEAD'
    )

    if (-not $ActualCommit -or
        -not $ActualCommit.StartsWith(
            $PolymodCommit,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Polymod revision verification failed. Expected $PolymodCommit."
    }

    Write-OK "Polymod verified: $ActualCommit"
}

# ------------------------------------------
# MAIN
# ------------------------------------------

$ExitCode = 0

try {
    Clear-Host

    Write-Host ''
    Write-Host '  ==========================================' -ForegroundColor Cyan
    Write-Host '       BEASTLOOP DEVELOPMENT SETUP' -ForegroundColor White
    Write-Host '  ==========================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Info "Project root: $ProjectRoot"

    Initialize-Project
    Initialize-Programs
    Initialize-VisualStudio
    Initialize-Haxelib
    Initialize-Polymod

    Write-Header 'SETUP COMPLETED'

    Write-OK 'Development environment is ready.'

    Write-Host ''
    Write-Host '  Haxe version:' -ForegroundColor Gray
    Invoke-Native $Haxe @('--version')

    Write-Host ''
    Write-Host '  Installed Haxelibs:' -ForegroundColor Gray
    Invoke-Native $Haxelib @('list')

    Write-Host ''
    Write-Host '  Local repository:' -ForegroundColor Gray
    Invoke-Native $Haxelib @('config')

    Write-Host ''
    Write-Host '  Next step:' -ForegroundColor Gray
    Write-Host '  haxelib run lime test windows -debug' -ForegroundColor Cyan
    Write-Host ''

} catch {
    $ExitCode = 1

    Write-Host ''
    Write-Host '  ==========================================' -ForegroundColor Red
    Write-Host '                SETUP FAILED' -ForegroundColor Red
    Write-Host '  ==========================================' -ForegroundColor Red
    Write-Fail $_.Exception.Message
    Write-Host ''
}

if ($ExitCode -eq 0) {
    Write-Host '  Setup finished successfully.' -ForegroundColor Green
} else {
    Write-Host '  Fix the error above before continuing.' -ForegroundColor Yellow
}

Write-Host ''
Read-Host 'Press Enter to close' | Out-Null

exit $ExitCode
