#requires -Version 5.1
<#
.SYNOPSIS
    Torna o comando "rammap" global, adicionando a pasta do clone ao PATH do usuario.

.DESCRIPTION
    Remove a pasta do PATH do usuario (se ja existir) e a coloca no inicio, para vencer
    outros rammap.cmd antigos. Nao precisa de administrador. Idempotente.
    Abra um novo terminal depois de rodar.

.EXAMPLE
    .\scripts\rammap\Install-RAMMapAlias.ps1
#>

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'rammap.cmd'))) {
    Write-Host "rammap.cmd nao encontrado em $root" -ForegroundColor Red
    exit 1
}

$atual = [Environment]::GetEnvironmentVariable('Path', 'User')
$itens = @($atual -split ';' | Where-Object { $_ -ne '' })
$semRammap = @($itens | Where-Object { $_.TrimEnd('\') -ine $root.TrimEnd('\') })
$novo = (@($root) + $semRammap) -join ';'
[Environment]::SetEnvironmentVariable('Path', $novo, 'User')

Write-Host "PATH do usuario atualizado (primeiro): $root" -ForegroundColor Green
Write-Host "Abra um novo terminal e teste: rammap -Target Info" -ForegroundColor DarkGray
exit 0
