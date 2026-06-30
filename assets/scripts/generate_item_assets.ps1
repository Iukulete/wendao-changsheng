param(
    [string]$Root = "C:\Users\jame\Desktop\3dyou\assets"
)

Add-Type -AssemblyName System.Drawing

$itemsDir = Join-Path $Root "items"
$weaponsDir = Join-Path $itemsDir "weapons"
$artifactsDir = Join-Path $itemsDir "artifacts"
$consumablesDir = Join-Path $itemsDir "consumables"
New-Item -ItemType Directory -Force -Path $itemsDir,$weaponsDir,$artifactsDir,$consumablesDir | Out-Null

function New-Canvas([int]$size = 512) {
    New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Save-Png($bmp, $path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Prep-Graphics($bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return $g
}

function Pt([int]$x, [int]$y) {
    New-Object System.Drawing.Point($x, $y)
}

function Fill-RadialGlow($g, $rect, $centerColor, $edgeColor) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($rect)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterColor = $centerColor
    $brush.SurroundColors = @($edgeColor)
    $g.FillEllipse($brush, $rect)
    $brush.Dispose()
    $path.Dispose()
}

function Draw-Ring($g, [int]$size, $ringColor) {
    $pen = New-Object System.Drawing.Pen($ringColor, 6)
    $g.DrawEllipse($pen, 22, 22, $size - 44, $size - 44)
    $pen.Dispose()
}

function Draw-Sword($outPath, $palette) {
    $bmp = New-Canvas
    $g = Prep-Graphics $bmp
    Fill-RadialGlow $g (New-Object System.Drawing.Rectangle 76, 76, 360, 360) $palette.GlowCenter $palette.GlowEdge
    Draw-Ring $g 512 $palette.Ring

    $bladeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((Pt 180 88),(Pt 332 382),$palette.BladeHi,$palette.BladeLo)
    $guardBrush = New-Object System.Drawing.SolidBrush($palette.Guard)
    $hiltBrush = New-Object System.Drawing.SolidBrush($palette.Hilt)
    $gemBrush = New-Object System.Drawing.SolidBrush($palette.Gem)
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210,24,18,18), 5)
    $outlinePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $blade = New-Object System.Drawing.Drawing2D.GraphicsPath
    $blade.AddPolygon(@(
        (Pt 262 78),
        (Pt 298 128),
        (Pt 276 356),
        (Pt 256 404),
        (Pt 236 356),
        (Pt 214 128)
    ))
    $guard = New-Object System.Drawing.Drawing2D.GraphicsPath
    $guard.AddPolygon(@(
        (Pt 180 284),
        (Pt 224 256),
        (Pt 288 256),
        (Pt 332 284),
        (Pt 288 302),
        (Pt 224 302)
    ))
    $hilt = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hilt.AddPolygon(@(
        (Pt 240 300),
        (Pt 272 300),
        (Pt 284 406),
        (Pt 256 444),
        (Pt 228 406)
    ))

    $g.FillPath($bladeBrush, $blade)
    $g.DrawPath($outlinePen, $blade)
    $g.FillPath($guardBrush, $guard)
    $g.DrawPath($outlinePen, $guard)
    $g.FillPath($hiltBrush, $hilt)
    $g.DrawPath($outlinePen, $hilt)
    $g.FillEllipse($gemBrush, 242, 268, 28, 28)

    Save-Png $bmp $outPath
    $blade.Dispose(); $guard.Dispose(); $hilt.Dispose(); $bladeBrush.Dispose(); $guardBrush.Dispose(); $hiltBrush.Dispose(); $gemBrush.Dispose(); $outlinePen.Dispose(); $g.Dispose(); $bmp.Dispose()
}

function Draw-Spear($outPath, $palette) {
    $bmp = New-Canvas
    $g = Prep-Graphics $bmp
    Fill-RadialGlow $g (New-Object System.Drawing.Rectangle 70, 70, 372, 372) $palette.GlowCenter $palette.GlowEdge
    Draw-Ring $g 512 $palette.Ring

    $shaftPen = New-Object System.Drawing.Pen($palette.Shaft, 12)
    $shaftPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $shaftPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200,24,18,18), 5)
    $bladeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((Pt 250 72),(Pt 320 186),$palette.BladeHi,$palette.BladeLo)
    $clothBrush = New-Object System.Drawing.SolidBrush($palette.Cloth)

    $g.DrawLine($shaftPen, 154, 404, 328, 124)
    $g.DrawLine($outlinePen, 154, 404, 328, 124)

    $blade = New-Object System.Drawing.Drawing2D.GraphicsPath
    $blade.AddPolygon(@(
        (Pt 320 84),
        (Pt 356 126),
        (Pt 302 200),
        (Pt 274 150)
    ))
    $cloth = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cloth.AddBezier(250, 180, 202, 188, 180, 236, 210, 258)
    $cloth.AddLine(210, 258, 246, 228)
    $cloth.CloseFigure()

    $g.FillPath($bladeBrush, $blade)
    $g.DrawPath($outlinePen, $blade)
    $g.FillPath($clothBrush, $cloth)
    $g.DrawPath($outlinePen, $cloth)

    Save-Png $bmp $outPath
    $blade.Dispose(); $cloth.Dispose(); $bladeBrush.Dispose(); $clothBrush.Dispose(); $shaftPen.Dispose(); $outlinePen.Dispose(); $g.Dispose(); $bmp.Dispose()
}

function Draw-Gourd($outPath, $palette) {
    $bmp = New-Canvas
    $g = Prep-Graphics $bmp
    Fill-RadialGlow $g (New-Object System.Drawing.Rectangle 76, 76, 360, 360) $palette.GlowCenter $palette.GlowEdge
    Draw-Ring $g 512 $palette.Ring

    $bodyBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((Pt 180 116),(Pt 316 404),$palette.BodyHi,$palette.BodyLo)
    $sealBrush = New-Object System.Drawing.SolidBrush($palette.Seal)
    $neckBrush = New-Object System.Drawing.SolidBrush($palette.Neck)
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210,24,18,18), 5)
    $outlinePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(182, 120, 148, 132)
    $path.AddEllipse(146, 212, 220, 184)
    $g.FillPath($bodyBrush, $path)
    $g.DrawPath($outlinePen, $path)
    $g.FillRectangle($neckBrush, 232, 94, 48, 42)
    $g.DrawRectangle($outlinePen, 232, 94, 48, 42)
    $g.FillEllipse($sealBrush, 216, 248, 80, 80)

    Save-Png $bmp $outPath
    $path.Dispose(); $bodyBrush.Dispose(); $sealBrush.Dispose(); $neckBrush.Dispose(); $outlinePen.Dispose(); $g.Dispose(); $bmp.Dispose()
}

function Draw-PillBottle($outPath, $palette) {
    $bmp = New-Canvas
    $g = Prep-Graphics $bmp
    Fill-RadialGlow $g (New-Object System.Drawing.Rectangle 76, 76, 360, 360) $palette.GlowCenter $palette.GlowEdge
    Draw-Ring $g 512 $palette.Ring

    $glassBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((Pt 178 116),(Pt 330 396),$palette.GlassHi,$palette.GlassLo)
    $liquidBrush = New-Object System.Drawing.SolidBrush($palette.Liquid)
    $capBrush = New-Object System.Drawing.SolidBrush($palette.Cap)
    $labelBrush = New-Object System.Drawing.SolidBrush($palette.Label)
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205,26,20,18), 5)

    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddArc(182, 126, 148, 34, 180, 180)
    $body.AddLine(330, 143, 330, 374)
    $body.AddArc(182, 356, 148, 34, 0, 180)
    $body.AddLine(182, 374, 182, 143)
    $body.CloseFigure()

    $g.FillPath($glassBrush, $body)
    $g.DrawPath($outlinePen, $body)
    $g.FillRectangle($liquidBrush, 196, 278, 120, 78)
    $g.FillRectangle($labelBrush, 204, 204, 104, 50)
    $g.FillRectangle($capBrush, 206, 90, 100, 46)
    $g.DrawRectangle($outlinePen, 206, 90, 100, 46)

    Save-Png $bmp $outPath
    $body.Dispose(); $glassBrush.Dispose(); $liquidBrush.Dispose(); $capBrush.Dispose(); $labelBrush.Dispose(); $outlinePen.Dispose(); $g.Dispose(); $bmp.Dispose()
}

function Draw-JadeSlip($outPath, $palette) {
    $bmp = New-Canvas
    $g = Prep-Graphics $bmp
    Fill-RadialGlow $g (New-Object System.Drawing.Rectangle 76, 76, 360, 360) $palette.GlowCenter $palette.GlowEdge
    Draw-Ring $g 512 $palette.Ring

    $jadeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((Pt 162 112),(Pt 350 390),$palette.JadeHi,$palette.JadeLo)
    $linePen = New-Object System.Drawing.Pen($palette.Glyph, 4)
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205,20,18,18), 5)
    $outlinePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $slip = New-Object System.Drawing.Drawing2D.GraphicsPath
    $slip.AddPolygon(@(
        (Pt 190 118),
        (Pt 340 146),
        (Pt 320 394),
        (Pt 170 366)
    ))
    $g.FillPath($jadeBrush, $slip)
    $g.DrawPath($outlinePen, $slip)
    $g.DrawLine($linePen, 214, 170, 292, 184)
    $g.DrawLine($linePen, 208, 212, 286, 226)
    $g.DrawLine($linePen, 202, 254, 280, 268)
    $g.DrawLine($linePen, 196, 296, 274, 310)

    Save-Png $bmp $outPath
    $slip.Dispose(); $jadeBrush.Dispose(); $linePen.Dispose(); $outlinePen.Dispose(); $g.Dispose(); $bmp.Dispose()
}

$swordPalettes = @(
    @{ File="weapon_sword_astral.png"; BladeHi=[System.Drawing.Color]::FromArgb(255,232,246,255); BladeLo=[System.Drawing.Color]::FromArgb(255,118,166,214); Guard=[System.Drawing.Color]::FromArgb(255,172,124,62); Hilt=[System.Drawing.Color]::FromArgb(255,78,60,54); Gem=[System.Drawing.Color]::FromArgb(255,124,241,255); Ring=[System.Drawing.Color]::FromArgb(210,214,184,108); GlowCenter=[System.Drawing.Color]::FromArgb(160,120,238,255); GlowEdge=[System.Drawing.Color]::FromArgb(0,18,34,42) },
    @{ File="weapon_sword_crimson.png"; BladeHi=[System.Drawing.Color]::FromArgb(255,255,236,228); BladeLo=[System.Drawing.Color]::FromArgb(255,214,106,88); Guard=[System.Drawing.Color]::FromArgb(255,176,126,54); Hilt=[System.Drawing.Color]::FromArgb(255,86,42,36); Gem=[System.Drawing.Color]::FromArgb(255,255,166,130); Ring=[System.Drawing.Color]::FromArgb(210,220,170,92); GlowCenter=[System.Drawing.Color]::FromArgb(150,255,122,84); GlowEdge=[System.Drawing.Color]::FromArgb(0,28,18,18) }
)

$spearPalette = @{ File="weapon_spear_storm.png"; Shaft=[System.Drawing.Color]::FromArgb(255,124,92,56); BladeHi=[System.Drawing.Color]::FromArgb(255,236,248,255); BladeLo=[System.Drawing.Color]::FromArgb(255,118,184,232); Cloth=[System.Drawing.Color]::FromArgb(255,84,142,208); Ring=[System.Drawing.Color]::FromArgb(210,214,184,108); GlowCenter=[System.Drawing.Color]::FromArgb(150,142,224,255); GlowEdge=[System.Drawing.Color]::FromArgb(0,18,34,42) }

$gourdPalette = @{ File="artifact_spirit_gourd.png"; BodyHi=[System.Drawing.Color]::FromArgb(255,112,74,168); BodyLo=[System.Drawing.Color]::FromArgb(255,58,34,90); Seal=[System.Drawing.Color]::FromArgb(255,196,150,74); Neck=[System.Drawing.Color]::FromArgb(255,84,58,40); Ring=[System.Drawing.Color]::FromArgb(210,214,184,108); GlowCenter=[System.Drawing.Color]::FromArgb(150,166,112,255); GlowEdge=[System.Drawing.Color]::FromArgb(0,18,18,36) }

$pillPalette = @{ File="consumable_pill_bottle_emerald.png"; GlassHi=[System.Drawing.Color]::FromArgb(255,214,246,232); GlassLo=[System.Drawing.Color]::FromArgb(255,106,162,134); Liquid=[System.Drawing.Color]::FromArgb(210,70,168,108); Cap=[System.Drawing.Color]::FromArgb(255,124,88,54); Label=[System.Drawing.Color]::FromArgb(190,244,230,190); Ring=[System.Drawing.Color]::FromArgb(210,214,184,108); GlowCenter=[System.Drawing.Color]::FromArgb(150,126,224,174); GlowEdge=[System.Drawing.Color]::FromArgb(0,18,28,22) }

$jadePalette = @{ File="artifact_jade_slip_ancient.png"; JadeHi=[System.Drawing.Color]::FromArgb(255,218,248,232); JadeLo=[System.Drawing.Color]::FromArgb(255,90,156,128); Glyph=[System.Drawing.Color]::FromArgb(220,240,255,230); Ring=[System.Drawing.Color]::FromArgb(210,214,184,108); GlowCenter=[System.Drawing.Color]::FromArgb(150,164,244,214); GlowEdge=[System.Drawing.Color]::FromArgb(0,18,28,24) }

foreach ($pal in $swordPalettes) { Draw-Sword (Join-Path $weaponsDir $pal.File) $pal }
Draw-Spear (Join-Path $weaponsDir $spearPalette.File) $spearPalette
Draw-Gourd (Join-Path $artifactsDir $gourdPalette.File) $gourdPalette
Draw-PillBottle (Join-Path $consumablesDir $pillPalette.File) $pillPalette
Draw-JadeSlip (Join-Path $artifactsDir $jadePalette.File) $jadePalette

Get-ChildItem -Recurse $itemsDir | Select-Object FullName,Length
