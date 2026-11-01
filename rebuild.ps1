# 合并分卷 + 校验 + 解包
# 用法:  .\rebuild.ps1                -> 还原到 .\out\
#        .\rebuild.ps1 -OutDir D:\fw  -> 还原到指定目录

param([string]$OutDir = (Join-Path $PSScriptRoot 'out'))

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$manifest = Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$archive  = Join-Path $PSScriptRoot 'boot-images.tar.gz'

Write-Host "`n=== 1/4 合并分卷 ===" -ForegroundColor Cyan
$parts = Get-ChildItem (Join-Path $PSScriptRoot 'parts') -Filter 'boot-images.tar.gz.part-*' | Sort-Object Name
if ($parts.Count -eq 0) { throw '找不到分卷文件（parts/ 目录）' }

if (Test-Path $archive) { Remove-Item $archive -Force }
$out = [System.IO.File]::Create($archive)
try {
    foreach ($p in $parts) {
        Write-Host ("   + {0}  ({1:N2} MB)" -f $p.Name, ($p.Length/1MB))
        $in = [System.IO.File]::OpenRead($p.FullName)
        try { $in.CopyTo($out) } finally { $in.Dispose() }
    }
} finally { $out.Dispose() }

$size = (Get-Item $archive).Length
Write-Host ("   合并后: {0:N2} MB" -f ($size/1MB))

Write-Host "`n=== 2/4 校验 SHA256 ===" -ForegroundColor Cyan
$hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
Write-Host "   实际: $hash"
Write-Host "   期望: $($manifest.archive.sha256)"
if ($hash -ne $manifest.archive.sha256) { throw 'SHA256 不匹配！分卷可能损坏或缺失，请重新下载' }
Write-Host '   ✓ 校验通过' -ForegroundColor Green

Write-Host "`n=== 3/4 解包 ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
tar -xzf $archive -C $OutDir
if ($LASTEXITCODE -ne 0) { throw '解包失败（需要系统自带 tar，Windows 10+ 可用）' }

Write-Host "`n=== 4/4 逐文件校验 ===" -ForegroundColor Cyan
$bad = 0
foreach ($f in $manifest.files) {
    $p = Join-Path $OutDir $f.name
    if (-not (Test-Path $p)) { Write-Host "   ✗ 缺失 $($f.name)" -ForegroundColor Red; $bad++; continue }
    $h = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $f.sha256) { Write-Host "   ✗ 哈希不符 $($f.name)" -ForegroundColor Red; $bad++ }
}
if ($bad -eq 0) {
    Write-Host "   ✓ 全部 $($manifest.files.Count) 个分区镜像校验通过" -ForegroundColor Green
    Write-Host "`n还原完成，文件位于: $OutDir`n" -ForegroundColor Green
    Write-Host "写回设备示例（进入 BROM 后）:" -ForegroundColor Yellow
    Write-Host "  .\spd_dump.exe --wait 120 --reconnect exec_addr2 0x65017f08 ``" -ForegroundColor Gray
    Write-Host "    fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0xbefffe00 ``" -ForegroundColor Gray
    Write-Host "    exec w uboot_a <OutDir>\uboot_a.bin reset" -ForegroundColor Gray
} else {
    Write-Host "`n有 $bad 个文件校验失败`n" -ForegroundColor Red
    exit 1
}
