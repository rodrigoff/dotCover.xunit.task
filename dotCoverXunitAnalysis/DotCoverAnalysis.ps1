param (
    [string]$searchPattern,
    [string]$outputDir,
    [string]$dotCoverTargetExecutable,
    [string]$dotCoverTargetArguments,
    [string]$dotCoverFilters,
    [string]$dotCoverAttributeFilters,
    [string]$dotCoverAdditionalArgs
)

Write-Verbose "Entering script $MyInvocation.MyCommand.Name"
Write-Verbose "Parameter Values"
foreach($key in $PSBoundParameters.Keys)
{
    Write-Verbose ($key + ' = ' + $PSBoundParameters[$key])
}

Write-Verbose "Importing modules"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

$dotCover = Get-Command -Name dotCover -ErrorAction Ignore
if(!$dotCover)
{
    throw "Unable to locate dotCover"
}

Write-Host "Checking if search pattern is specified"
if(!$searchPattern)
{
    throw (Get-LocalizedString -Key "Search Pattern parameter must be set")
}

if ($outputDir -and !(Test-Path $outputDir))
{
    Write-Host "Output folder used but doesn't exists, creating it"
    New-Item $outputDir -type directory
}

if ($searchPattern.Contains("*") -or $searchPattern.Contains("?"))
{
    Write-Host "Pattern found in solution parameter."
    Write-Host "Find-Files -SearchPattern $searchPattern"
    $foundFiles = Find-Files -SearchPattern $searchPattern
}
else
{
    Write-Host "No Pattern found in solution parameter."
    $foundFiles = ,$searchPattern
}

Write-Host "INFO: Executing code coverage"

$foundCount = $foundFiles.Count
Write-Host "Found files: $foundCount"
foreach ($fileToCover in $foundFiles)
{
    Write-Host "--File: $fileToCover"
}

foreach ($fileToCover in $foundFiles)
{
    Write-Host "Creating dotCover cover arguments:"
    $outputName = $(Get-ItemProperty -Path $fileToCover -Name 'Name').Name + ".snapshot"
    $coverArgs = "cover /TargetExecutable=`"$dotCoverTargetExecutable`" /TargetArguments=`"$fileToCover`" /Output=`"$outputDir\$outputName`""

    if ($dotCoverFilters)
    {
        $coverArgs = ($coverArgs + " /Filters=$dotCoverFilters")
    }

    if ($dotCoverAttributeFilters)
    {
        $coverArgs = ($coverArgs + " /AttributeFilters=$dotCoverAttributeFilters")
    }

    Write-Host "--ARGS: $coverArgs"
    Invoke-Tool -Path $dotCover.Path -Arguments $coverArgs
}

Write-Host "INFO: Merging snapshots"

$foundSnapshots = Find-Files -SearchPattern "$outputDir\**\*.snapshot"
$foundCount = $foundSnapshots.Count
$mergeArgs = "merge /Source="
Write-Host "Found files: $foundCount"
foreach ($snapshot in $foundSnapshots)
{
    Write-Host "--File: $snapshot"
    $mergeArgs = ($mergeArgs + ";`"$snapshot`"")
}
$mergeArgs = ($mergeArgs + " /Output=`"$outputDir\Coverage.snapshot`"")

Write-Host "INFO: Generating report"

Write-Host "--ARGS: $mergeArgs"
Invoke-Tool -Path $dotCover.Path -Arguments $mergeArgs

$reportArgs = "report /ReportType=HTML /Source=`"$outputDir\Coverage.snapshot`" /Output=`"$outputDir\Coverage.html`""

Write-Host "--ARGS: $reportArgs"
Invoke-Tool -Path $dotCover.Path -Arguments $reportArgs

Write-Host "INFO: Cleaning snapshots"

$deleteArgs = "delete /Source="
foreach ($snapshot in $foundSnapshots)
{
    Write-Host "--File: $snapshot"
    $deleteArgs = ($deleteArgs + ";`"$snapshot`"")
}
Write-Host "--ARGS: $deleteArgs"
Invoke-Tool -Path $dotCover.Path -Arguments $deleteArgs