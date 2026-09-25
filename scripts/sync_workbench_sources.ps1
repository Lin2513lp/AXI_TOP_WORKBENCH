param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$workbenchPath = Join-Path $ProjectRoot 'AXI_TOP_WORKBENCH.html'
$sourcePaths = @(
    'rtl/AXI_M_TOP.sv',
    'rtl/AXI_S_TOP.sv',
    'rtl/axi_top.sv',
    'rtl/axi2fifo.sv',
    'rtl/fifo_in.sv',
    'rtl/fifo_out.sv',
    'rtl/fifo2axi.sv',
    'tb/tb_AXI_M_TOP.sv',
    'tb/tb_axi2fifo_fifo_in.sv',
    'tb/tb_AXI_S_TOP.sv'
)

$codeSources = [ordered]@{}
foreach ($relativePath in $sourcePaths) {
    $absolutePath = Join-Path $ProjectRoot $relativePath
    $codeSources[$relativePath] = Get-Content -Raw -LiteralPath $absolutePath
}

$replacement = '    const codeSources = ' + ($codeSources | ConvertTo-Json -Compress) + ';'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]](Get-Content -LiteralPath $workbenchPath))
$sourceLine = -1
for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^\s*const codeSources = ') {
        $sourceLine = $index
        break
    }
}

if ($sourceLine -lt 0) {
    throw 'Unable to locate the codeSources declaration in AXI_TOP_WORKBENCH.html.'
}

$lines[$sourceLine] = $replacement
[System.IO.File]::WriteAllLines($workbenchPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated embedded workbench sources from $($sourcePaths.Count) canonical files."
