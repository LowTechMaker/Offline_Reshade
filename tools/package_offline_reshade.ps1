# Builds a self-contained, redistributable folder for the Offline ReShade WinUI app and zips it.
#
# The recipient needs nothing pre-installed: the .NET runtime and the Windows App SDK are published
# alongside the app. Shaders are deliberately not included.
#
#   .\tools\package_offline_reshade.ps1                 # build, stage and zip into <repo>\dist
#   .\tools\package_offline_reshade.ps1 -SkipBuild      # reuse whatever is already in bin\x64\Release
#   .\tools\package_offline_reshade.ps1 -NoArchive      # leave the staged folder, skip the zip

Param(
	[string]
	$OutputDir = "",
	[switch]
	$SkipBuild,
	[switch]
	$NoArchive
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
$binDir = "$root\bin\x64\Release"
if ($OutputDir -eq "") {
	$OutputDir = "$root\dist"
}

function Find-MSBuild {
	# 'dotnet build' resolves $(MSBuildExtensionsPath) to the .NET SDK, where the Windows App SDK's
	# PRI tasks do not exist, so this has to be the Visual Studio MSBuild.
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (-not (Test-Path $vswhere)) {
		throw "vswhere.exe not found. Visual Studio 2022 or newer is required to package."
	}

	$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
	if (-not $vsPath) {
		throw "No Visual Studio installation with MSBuild was found."
	}

	$msbuild = Join-Path $vsPath "MSBuild\Current\Bin\MSBuild.exe"
	if (-not (Test-Path $msbuild)) {
		throw "MSBuild.exe not found under '$vsPath'."
	}

	return $msbuild
}

function Invoke-MSBuild {
	Param([string] $msbuild, [string[]] $arguments, [string] $what)

	& $msbuild @arguments /nologo /verbosity:minimal
	if ($LASTEXITCODE -ne 0) {
		throw "$what failed (MSBuild exit code $LASTEXITCODE)."
	}
}

$msbuild = Find-MSBuild

# Read the product version without bumping the build number (see update_version.ps1)
& "$PSScriptRoot\update_version.ps1" "$root\res\version.h"
# The archive is named after the product version alone. The build number climbs with every local
# Release build, which would make two identical packages look like different releases.
$version = "$($global:ReShadeVersion[0]).$($global:ReShadeVersion[1]).$($global:ReShadeVersion[2])"
$buildVersion = "$version.$($global:ReShadeVersion[3])"

$staging = "$OutputDir\OfflineReShade"

"Packaging Offline ReShade $version (build $buildVersion) ..."

# --------------------------------------------------------------------------------------- build
if (-not $SkipBuild) {
	"  building the solution ..."
	# Platform is named "64-bit" in this solution, not "x64"
	Invoke-MSBuild $msbuild @("$root\ReShade.sln", "/p:Configuration=Release", "/p:Platform=64-bit", "/maxcpucount") "Solution build"
}

# --------------------------------------------------------------------------------------- publish
"  publishing the app ..."
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Invoke-MSBuild $msbuild @(
	"$root\OfflineReShadeWinUI\OfflineReShadeWinUI.csproj",
	"/t:Restore;Publish",
	"/p:Configuration=Release",
	"/p:Platform=x64",
	"/p:RuntimeIdentifier=win-x64",
	"/p:SelfContained=true",
	"/p:PublishDir=$staging\"
) "Publish"

# --------------------------------------------------------------------------------------- stage
# Publish does not carry these: the native binaries are not project references, and the app's own
# resource index is left behind (without it the app dies at startup with a XamlParseException).
$extraFiles = @(
	"OfflineReShadePrototype.exe",
	"ReShade64.dll",
	"OfflineReShadePreviewBridge.dll",
	"OfflineReShadeWinUI.pri"
)

"  adding native binaries and resources ..."
foreach ($name in $extraFiles) {
	$source = Join-Path $binDir $name
	if (-not (Test-Path $source)) {
		throw "'$name' is missing from '$binDir'. Build the solution first, or drop -SkipBuild."
	}
	Copy-Item $source $staging -Force
}

# Folders the app looks for next to itself once it detects it is running packaged (see AppPaths)
foreach ($folder in @("Effects", "Effects\Textures", "Effects\Addons")) {
	New-Item -ItemType Directory -Force -Path (Join-Path $staging $folder) | Out-Null
}

Copy-Item "$PSScriptRoot\package\README.txt" $staging -Force

# Developer-only or machine-specific leftovers
Get-ChildItem $staging -Filter "*.pdb" -File | Remove-Item -Force
Remove-Item (Join-Path $staging "OfflineReShadeWinUI.settings.json") -Force -ErrorAction SilentlyContinue

# --------------------------------------------------------------------------------------- verify
# Catch an incomplete package here rather than on someone else's machine
$required = @(
	"OfflineReShadeWinUI.exe",
	"OfflineReShadeWinUI.dll",
	"OfflineReShadeWinUI.pri",
	"OfflineReShadeWinUI.runtimeconfig.json",
	"OfflineReShadePrototype.exe",
	"ReShade64.dll",
	"OfflineReShadePreviewBridge.dll",
	"Microsoft.UI.Xaml.dll",
	"Microsoft.WindowsAppRuntime.Bootstrap.dll",
	"hostfxr.dll",
	"coreclr.dll",
	"README.txt"
)

$missing = $required | Where-Object { -not (Test-Path (Join-Path $staging $_)) }
if ($missing) {
	throw "Package is incomplete, missing: $($missing -join ', ')"
}

$fileCount = (Get-ChildItem $staging -Recurse -File).Count
$sizeMB = [math]::Round((Get-ChildItem $staging -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
"  staged $fileCount files ($sizeMB MB) in '$staging'"

# --------------------------------------------------------------------------------------- archive
if ($NoArchive) {
	"Done. Staged folder left at '$staging'."
	return
}

$archive = "$OutputDir\OfflineReShade-$version-win-x64.zip"
Remove-Item $archive -Force -ErrorAction SilentlyContinue

"  compressing ..."
Compress-Archive -Path $staging -DestinationPath $archive -CompressionLevel Optimal

$item = Get-Item $archive
"Done."
"  archive: $($item.FullName)"
"  size:    $([math]::Round($item.Length / 1MB, 1)) MB"
"  sha256:  $((Get-FileHash $archive -Algorithm SHA256).Hash)"
