<#
.SYNOPSIS
    Invokes MATLAB startup accelerator.

.DESCRIPTION
    Invokes MATLAB startup accelerator.

.PARAMETER MATLABRoot
    (Required) Root folder for MATLAB.

.EXAMPLE
    Invoke-MATLABStartupAccelerator -MATLABRoot "<MATLAB_ROOT_FOLDER>"

.NOTES
    Copyright 2022-2025 The MathWorks, Inc.
#>

function Invoke-MATLABStartupAccelerator {

    param(
        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot
    )

    Write-Output 'Starting Invoke-MATLABStartupAccelerator...'

    if ($MATLABRoot) {
        & "$MATLABRoot\bin\win64\MATLABStartupAccelerator.exe" 64 $MATLABRoot "$Env:ProgramData\MathWorks\msa.ini" "$Env:ProgramData\MathWorks\msa.log"
        (Get-Item "$MATLABRoot\toolbox\local\toolbox_cache-win64.xml").LastWriteTime = Get-Date
    }

    Write-Output 'Done with Invoke-MATLABStartupAccelerator.'
}



try {
    Invoke-MATLABStartupAccelerator -MATLABRoot $Env:MATLABRoot
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "WARNING - An error occurred while running script '40_WarmUp-MATLAB': $ScriptPath. Error: $_"
}
