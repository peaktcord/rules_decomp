[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]] $Project
)

$source = Join-Path $PSScriptRoot '..\skills\decompilation-bazel'
$source = (Resolve-Path -LiteralPath $source).Path

foreach ($projectPath in $Project) {
    $resolvedProject = (Resolve-Path -LiteralPath $projectPath).Path
    $skillRoot = Join-Path $resolvedProject '.agents\skills'
    $destination = Join-Path $skillRoot 'decompilation-bazel'
    New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'SKILL.md') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $source 'agents') -Destination $destination -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $source 'references') -Destination $destination -Recurse -Force
    Write-Output "Synchronized decompilation-bazel to $destination"
}
