Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$fd = New-Object System.Windows.Forms.OpenFileDialog
$fd.Filter = "Images|*.jpg;*.jpeg;*.png;*.bmp"
if($fd.ShowDialog() -ne 'OK') { exit }

$wIn = [Microsoft.VisualBasic.Interaction]::InputBox("Ширина:", "Настройки", 120)
$width = 120; [int]::TryParse($wIn, [ref]$width) | Out-Null

$img = [System.Drawing.Image]::FromFile($fd.FileName)
# Принудительный double для расчёта, чтобы не обнулилось
$height = [int](([double]$width * $img.Height / $img.Width) * 0.5)
if($height -lt 1) { $height = 1 }

Write-Host "Изображение: $($img.Width)x$($img.Height) -> ASCII: ${width}x$height"

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, $width, $height)

# 8 символов от темного к светлому
$chars = [char[]]"█▓▒░⁞□⸗ "
$outPath = $fd.FileName -replace '\.\w+$', '_ascii.txt'

# Очищаем файл перед записью
Set-Content -Path $outPath -Value "" -Encoding ASCII

for($y=0; $y -lt $height; $y++) {
    $line = ""
    for($x=0; $x -lt $width; $x++) {
        $c = $bmp.GetPixel($x,$y)
        $b = 0.2126*$c.R + 0.7152*$c.G + 0.0722*$c.B
        $idx = [int]($b / 255 * ($chars.Length - 1))
        $line += $chars[$idx]
    }
    # Запись построчно, чтобы не зависеть от памяти
    Add-Content -Path $outPath -Value $line -Encoding UTF8
    Write-Progress -Activity "Конвертация" -PercentComplete (($y/$height)*100)
}

$img.Dispose(); $bmp.Dispose(); $g.Dispose()
Write-Host "Готово: $outPath" -ForegroundColor Green
