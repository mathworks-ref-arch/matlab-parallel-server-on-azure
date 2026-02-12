<#
.SYNOPSIS
    Generates MATLAB Toolbox Path Cache file and imports MSA.

.LINK
    https://www.mathworks.com/help/matlab/matlab_env/toolbox-path-caching-in-the-matlab-program.html

.DESCRIPTION
    Generates MATLAB Toolbox Path Cache file and imports MSA ini file for faster MATLAB startup.

.NOTES
    Copyright 2020-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function New-ToolboxCacheXML {
    param(
        [Parameter(Mandatory = $true)]
        [string] $MatlabRoot
    )
    Write-Output "Generate Toolbox cache xml for MATLAB installation at $MatlabRoot"
    $ToolboxCachePath = Join-Path "$MatlabRoot" -ChildPath 'toolbox\local'
    & 'C:\Program Files\Python\python.exe' C:\Windows\Temp\config\matlab\generate_toolbox_cache.py "$MatlabRoot" "$ToolboxCachePath"
}

function Import-MSAFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $MSAFileUrl
    )

    Write-Output 'Fetch MSA file'
    Invoke-WebRequest $MSAFileUrl -OutFile 'C:\Windows\Temp\msa.ini'
     
    Write-Output 'Move msa.ini file for Startup Accelerator'
    if (-not (Test-Path -Path 'C:\ProgramData\MathWorks')) {
        New-Item -ItemType 'directory' -Path 'C:\ProgramData\MathWorks'
    }
    Copy-Item 'C:\Windows\Temp\msa.ini' -Destination 'C:\ProgramData\MathWorks\msa.ini'   
}

function Optimize-MATLAB {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $MatlabRoot,
        
        [Parameter(Mandatory = $true)]
        [string] $MSAFileUrl
    )
    
    if ($Release -ge 'R2021b') {
        New-ToolboxCacheXML -MatlabRoot $MatlabRoot
        Import-MSAFile -MSAFileUrl $MSAFileUrl
    }
    else {
        Write-Output "Unable to generate Toolbox cache xml as version $Release is less than R2021b."
    }
    Write-Output 'Done with Initialize-MATLAB.'
}

try {
    $ErrorActionPreference = 'Stop'
    Optimize-MATLAB -Release $Env:RELEASE -MatlabRoot $Env:MATLAB_ROOT -MSAFileUrl $Env:MSA_URL
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Optimize-MATLAB': $ScriptPath. Error: $_"
    throw
}
