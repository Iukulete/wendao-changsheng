[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$FxPath,
    [Parameter(Mandatory = $true)][string]$PsdPath,
    [Parameter(Mandatory = $true)][string]$OutputPng,
    [Parameter(Mandatory = $true)][string]$AssetLabel,
    [int]$Brightness = 2,
    [int]$Contrast = 5,
    [double]$UnsharpAmount = 42.0,
    [double]$UnsharpRadius = 0.45,
    [int]$UnsharpThreshold = 2
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Ensure-Parent([string]$Path) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

Ensure-Parent $PsdPath
Ensure-Parent $OutputPng

$photoshop = New-Object -ComObject Photoshop.Application
$photoshop.Visible = $true
$doc = $null
$fxDoc = $null
$flat = $null
try {
    $doc = $photoshop.Open((Resolve-Path -LiteralPath $InputPath).Path)
    $photoshop.ActiveDocument = $doc
    $base = $doc.ArtLayers.Item(1)
    $base.Name = "Base_Source"

    $grade = $base.Duplicate()
    $grade.Name = "Base_Grade"
    $photoshop.ActiveDocument = $doc
    $doc.ActiveLayer = $grade
    $grade.AdjustBrightnessContrast($Brightness, $Contrast)
    $grade.ApplyUnSharpMask($UnsharpAmount, $UnsharpRadius, $UnsharpThreshold)
    $base.Visible = $false

    $fxDoc = $photoshop.Open((Resolve-Path -LiteralPath $FxPath).Path)
    $photoshop.ActiveDocument = $fxDoc
    $fxDoc.ActiveLayer.Copy()
    $photoshop.ActiveDocument = $doc
    $fxLayer = $doc.Paste()
    $fxLayer.Name = "FX_Local"
    $fxLayer.Opacity = 86
    $fxDoc.Close(2)
    $fxDoc = $null

    $psdOptions = New-Object -ComObject Photoshop.PhotoshopSaveOptions
    $psdFullPath = [IO.Path]::GetFullPath($PsdPath)
    $pngFullPath = [IO.Path]::GetFullPath($OutputPng)
    $photoshop.ActiveDocument = $doc
    $doc.SaveAs($psdFullPath, $psdOptions, $true, 2)

    $photoshop.ActiveDocument = $doc
    $flat = $doc.Duplicate("${AssetLabel}_flattened", $true)
    $photoshop.ActiveDocument = $flat
    $flat.Flatten()
    $pngOptions = New-Object -ComObject Photoshop.PNGSaveOptions
    $flat.SaveAs($pngFullPath, $pngOptions, $true, 2)
    $flat.Close(2)
    $flat = $null
    Write-Host "PHOTOSHOP_ART_ASSEMBLY_OK: $AssetLabel"
    Write-Host "  PSD=$PsdPath"
    Write-Host "  PNG=$OutputPng"
} finally {
    if ($flat -ne $null) { $flat.Close(2) }
    if ($fxDoc -ne $null) { $fxDoc.Close(2) }
    if ($doc -ne $null) { $doc.Close(2) }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($photoshop) | Out-Null
}
