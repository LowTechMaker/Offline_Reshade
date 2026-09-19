Param(
	[Parameter(Mandatory = $true)][string]
	$path,
	[string]
	$config = "",
	[string]
	$platform = ""
)

$exists = Test-Path $path
$version = 0,0,0,0

# This fork carries its own tags rather than upstream's "vX.Y.Z" ones, so 'git describe' below finds no
# version to parse. Leaving it at 0.0.0 makes the runtime define '__RESHADE__' as 0, and every shader
# that includes ReShade.fxh then fails with "ReShade 3.0+ is required to use this header file".
# Fall back to the upstream release this fork is based on.
$fallback = 6,8,0

# Get version from existing file
if ($exists -and $(Get-Content $path | Out-String) -match "VERSION_FULL (\d+).(\d+).(\d+).(\d+)") {
	$version = [int]::Parse($matches[1]), [int]::Parse($matches[2]), [int]::Parse($matches[3]), [int]::Parse($matches[4])
}
elseif ($(git describe --tags) -match "v(\d+)\.(\d+)\.(\d+)(-\d+-\w+)?") {
	$version = [int]::Parse($matches[1]), [int]::Parse($matches[2]), [int]::Parse($matches[3]), 0
}

# Also recover from a version file that was already written with the bogus 0.0.0
if ($version[0] -eq 0 -and $version[1] -eq 0 -and $version[2] -eq 0) {
	$version = $fallback[0], $fallback[1], $fallback[2], $version[3]
}

$global:ReShadeVersion = $version

# Increment build version for release builds
if (($config -eq "Release") -or
    ($config -eq "Release Signed")) {
	$version[3] += 1
	"Updating version to $([string]::Join('.', $version)) ..."
}
elseif ($exists) {
	return
}

$official = Test-Path "$path\..\sign.pfx"

# Update version file with the new version information
@"
#pragma once

#define VERSION_FULL $([string]::Join('.', $version))
#define VERSION_MAJOR $($version[0])
#define VERSION_MINOR $($version[1])
#define VERSION_REVISION $($version[2])
#define VERSION_BUILD $($version[3])

#define VERSION_STRING_FILE "$([string]::Join('.', $version))"
#define VERSION_STRING_PRODUCT "$($version[0]).$($version[1]).$($version[2])$(if (-not $official) { " UNOFFICIAL" })"
"@ | Out-File -FilePath $path -Encoding ASCII
