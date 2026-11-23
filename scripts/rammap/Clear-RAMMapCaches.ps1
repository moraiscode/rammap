#requires -Version 5.1
<#
.SYNOPSIS
    Limpeza de memoria RAM equivalente ao RAMMap "Empty Working Sets" e "Empty Standby List".

.DESCRIPTION
    Usa NtSetSystemInformation(SystemMemoryListInformation = 0x50) para:
      MemoryEmptyWorkingSets = 2  -> esvazia working sets de todos os processos
      MemoryPurgeStandbyList = 4  -> esvazia a standby list (cache de arquivos)

    Nao depende do RAMMap.exe. Requer elevacao (Administrador) para limpar;
    Info/List/DryRun funcionam sem elevacao.

.PARAMETER Target
    WorkingSet | Standby | All (padrao) | Info | List

.PARAMETER ProcessName
    Limita a limpeza de working set aos processos com esse nome.

.PARAMETER ProcessId
    Limita a limpeza de working set a um PID especifico.

.PARAMETER DryRun
    Mostra o que seria feito, sem alterar nada.

.PARAMETER NoElevate
    Nao tenta auto-elevar via UAC (uso interno / automacao).

.EXAMPLE
    rammap.cmd -Target All
    rammap.cmd -Target Standby
    rammap.cmd -Target WorkingSet -ProcessName explorer
    rammap.cmd -Target Info
    rammap.cmd -Target List
    rammap.cmd -Target All -DryRun
#>
[CmdletBinding()]
param(
    [ValidateSet('WorkingSet', 'Standby', 'All', 'Info', 'List')]
    [string]$Target = 'All',

    [string]$ProcessName,

    [int]$ProcessId = 0,

    [switch]$DryRun,

    [switch]$NoElevate,
    [switch]$Json
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# P/Invoke
# ---------------------------------------------------------------------------
if (-not ('RamMapNative' -as [type])) {
    $code = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class RamMapNative
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LUID { public uint LowPart; public int HighPart; }

    [StructLayout(LayoutKind.Sequential)]
    private struct LUID_AND_ATTRIBUTES { public LUID Luid; public uint Attributes; }

    [StructLayout(LayoutKind.Sequential)]
    private struct TOKEN_PRIVILEGES { public uint PrivilegeCount; public LUID_AND_ATTRIBUTES Privilege; }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool LookupPrivilegeValue(string system, string name, out LUID luid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll,
        ref TOKEN_PRIVILEGES newState, uint bufferLength, IntPtr previousState, IntPtr returnLength);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

    [DllImport("psapi.dll", SetLastError = true)]
    private static extern bool EmptyWorkingSet(IntPtr process);

    [DllImport("ntdll.dll")]
    private static extern int NtSetSystemInformation(int infoClass, ref int info, int length);

    private const uint TOKEN_ADJUST_PRIVILEGES = 0x20;
    private const uint TOKEN_QUERY = 0x8;
    private const uint SE_PRIVILEGE_ENABLED = 0x2;
    private const int SystemMemoryListInformation = 0x50;
    private const int ERROR_NOT_ALL_ASSIGNED = 1300;
    private const uint PROCESS_SET_QUOTA = 0x0100;
    private const uint PROCESS_QUERY_INFORMATION = 0x0400;

    public static void EnablePrivilege(string name)
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenProcessToken");

        try
        {
            LUID luid;
            if (!LookupPrivilegeValue(null, name, out luid))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "LookupPrivilegeValue: " + name);

            TOKEN_PRIVILEGES state = new TOKEN_PRIVILEGES();
            state.PrivilegeCount = 1;
            state.Privilege.Luid = luid;
            state.Privilege.Attributes = SE_PRIVILEGE_ENABLED;

            if (!AdjustTokenPrivileges(token, false, ref state, 0, IntPtr.Zero, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "AdjustTokenPrivileges: " + name);

            if (Marshal.GetLastWin32Error() == ERROR_NOT_ALL_ASSIGNED)
                throw new InvalidOperationException("Privilegio nao disponivel no token: " + name);
        }
        finally
        {
            CloseHandle(token);
        }
    }

    public static int Purge(int command)
    {
        int value = command;
        return NtSetSystemInformation(SystemMemoryListInformation, ref value, sizeof(int));
    }

    public static bool TrimProcess(int pid)
    {
        IntPtr handle = OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_INFORMATION, false, pid);
        if (handle == IntPtr.Zero) return false;
        try { return EmptyWorkingSet(handle); }
        finally { CloseHandle(handle); }
    }
}
'@
    Add-Type -TypeDefinition $code -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SystemMemorySummary {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB  = [math]::Round($totalGB - $freeGB, 2)
    $pct = 0
    if ($totalGB -gt 0) { $pct = [math]::Round(($usedGB / $totalGB) * 100, 2) }
    return [pscustomobject]@{
        TotalGB     = $totalGB
        AvailableGB = $freeGB
        UsedGB      = $usedGB
        UsagePct    = $pct
    }
}

function Write-MemorySummary {
    param([string]$Label)
    $m = Get-SystemMemorySummary
    Write-Host ("{0}: Total={1} GB | Livre={2} GB | Usado={3} GB | Uso={4}%" -f $Label, $m.TotalGB, $m.AvailableGB, $m.UsedGB, $m.UsagePct)
    return $m
}

function Get-TargetProcesses {
    $procs = @()
    if ($ProcessName) {
        $procs = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    }
    if ($ProcessId -gt 0) {
        $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($p) { $procs += $p }
    }
    return $procs
}

function Show-ProcessList {
    $items = @()
    if ($ProcessName -or $ProcessId -gt 0) {
        $items = Get-TargetProcesses
    } else {
        $items = @(Get-Process -ErrorAction SilentlyContinue)
    }

    $rows = foreach ($p in $items) {
        [pscustomobject]@{
            Id           = $p.Id
            Processo     = $p.ProcessName
            'WorkingSetMB' = [math]::Round($p.WorkingSet64 / 1MB, 2)
        }
    }

    $rows | Sort-Object WorkingSetMB -Descending | Select-Object -First 15 | Format-Table -AutoSize
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if (-not $Json) { Write-Host "rammap - alvo: $Target" -ForegroundColor Cyan }

if ($Target -eq 'Info' -and $Json) {
    Get-SystemMemorySummary | ConvertTo-Json -Compress
    exit 0
}

if ($Target -eq 'Info') {
    $null = Write-MemorySummary 'Memoria'
    Write-Host ""
    Write-Host "Para limpar (requer Administrador):  rammap.cmd -Target All" -ForegroundColor DarkGray
    exit 0
}

if ($Target -eq 'List') {
    Show-ProcessList
    Write-Host ""
    Write-Host "Limpar working set de um processo:  rammap.cmd -Target WorkingSet -ProcessName <nome>" -ForegroundColor DarkGray
    exit 0
}

if ($DryRun) {
    Write-Host "Modo Dry-Run: nada sera alterado." -ForegroundColor Yellow
    if ($Target -eq 'WorkingSet' -or $Target -eq 'All') {
        if ($ProcessName -or $ProcessId -gt 0) {
            Write-Host ("Seria feito TrimProcess em: {0}{1}" -f $ProcessName, $(if ($ProcessId -gt 0) { " (PID $ProcessId)" } else { "" }))
        } else {
            Write-Host "Seria executado NtSetSystemInformation(0x50, 2) - Empty Working Sets (sistema inteiro)"
        }
    }
    if ($Target -eq 'Standby' -or $Target -eq 'All') {
        Write-Host "Seria executado NtSetSystemInformation(0x50, 4) - Empty Standby List"
    }
    exit 0
}

$filtroProcesso = ($ProcessName -or $ProcessId -gt 0)
if ($filtroProcesso -and $Target -in @('WorkingSet', 'All') -and -not $DryRun -and @(Get-TargetProcesses).Count -eq 0) {
    Write-Host ("Nenhum processo encontrado para '{0}'{1}. Nada foi alterado." -f $ProcessName, $(if ($ProcessId -gt 0) { " (PID $ProcessId)" } else { "" })) -ForegroundColor Yellow
    exit 1
}

$isAdmin = Test-Administrator

if (-not $isAdmin) {
    if ($NoElevate) {
        Write-Host "Sem privilegios de Administrador. Reexecute como Administrador." -ForegroundColor Yellow
        exit 1
    }

    $exe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Target', $Target, '-NoElevate')
    if ($ProcessName) { $argList += @('-ProcessName', $ProcessName) }
    if ($ProcessId -gt 0) { $argList += @('-ProcessId', "$ProcessId") }

    Write-Host "Elevando via UAC..." -ForegroundColor Yellow
    try {
        $proc = Start-Process -FilePath $exe -Verb RunAs -Wait -PassThru -ArgumentList $argList -ErrorAction Stop
        exit $proc.ExitCode
    } catch {
        Write-Host "Elevacao cancelada: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$before = Write-MemorySummary 'Antes'

try {
    [RamMapNative]::EnablePrivilege('SeProfileSingleProcessPrivilege')
} catch {
    Write-Host "Aviso: $($_.Exception.Message)" -ForegroundColor Yellow
}

$ok = 0
$fail = 0

if ($Target -eq 'WorkingSet' -or $Target -eq 'All') {
    $targets = Get-TargetProcesses
    $filtroProcesso = ($ProcessName -or $ProcessId -gt 0)

    # Nome/PID informado mas nenhum processo casou: NAO cair no purge global
    # (um typo em "win 1.3 <nome>" esvaziaria os working sets do sistema inteiro).
    if ($filtroProcesso -and $targets.Count -eq 0) {
        Write-Host ("Nenhum processo encontrado para '{0}'{1}. Nada foi alterado." -f $ProcessName, $(if ($ProcessId -gt 0) { " (PID $ProcessId)" } else { "" })) -ForegroundColor Yellow
        exit 1
    }

    if ($targets.Count -gt 0) {
        Write-Host ("Esvaziando working set de {0} processo(s)..." -f $targets.Count) -ForegroundColor Cyan
        foreach ($p in $targets) {
            if ([RamMapNative]::TrimProcess($p.Id)) { $ok++ } else { $fail++ }
        }
    } else {
        Write-Host "Empty Working Sets (sistema inteiro)..." -ForegroundColor Cyan
        $status = [RamMapNative]::Purge(2)
        if ($status -eq 0) { $ok++ } else {
            $fail++
            Write-Host ("Empty Working Sets falhou: NTSTATUS 0x{0:X8}" -f $status) -ForegroundColor Red
        }
    }
}

if ($Target -eq 'Standby' -or $Target -eq 'All') {
    Write-Host "Empty Standby List..." -ForegroundColor Cyan
    $status = [RamMapNative]::Purge(4)
    if ($status -eq 0) { $ok++ } else {
        $fail++
        Write-Host ("Empty Standby List falhou: NTSTATUS 0x{0:X8}" -f $status) -ForegroundColor Red
    }
}

$after = Write-MemorySummary 'Depois'

$diff = [math]::Round($before.UsedGB - $after.UsedGB, 2)
if ($diff -gt 0) {
    Write-Host ("Liberado: ~{0} GB" -f $diff) -ForegroundColor Green
} else {
    Write-Host "Sem diferenca significativa no uso total (normal: standby e cache sao recompostos)." -ForegroundColor DarkYellow
}

Write-Host ("Concluido: {0} operacao(oes) OK, {1} falha(s)" -f $ok, $fail) -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }
exit 0
