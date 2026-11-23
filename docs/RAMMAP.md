# rammap — Limpeza de memória RAM

## O que faz

O `rammap` esvazia a memória RAM do Windows de forma equivalente ao RAMMap (Sysinternals):

- **Empty Working Sets** — remove páginas de memória dos working sets de todos os processos, forçando-os a recarregar apenas o que precisam
- **Empty Standby List** — limpa o cache de arquivos (standby list), liberando memória usada como cache

Usa `NtSetSystemInformation` com `SystemMemoryListInformation (0x50)` via P/Invoke — **não depende do RAMMap.exe**.

## Como funciona (técnico)

### P/Invoke

O script compila uma classe C# em tempo de execução (`Add-Type`) com:

- `NtSetSystemInformation` (ntdll.dll) — chamada principal
- `EmptyWorkingSet` (psapi.dll) — para processos individuais
- `OpenProcess` / `CloseHandle` (kernel32.dll) — handles de processo
- `OpenProcessToken` / `LookupPrivilegeValue` / `AdjustTokenPrivileges` (advapi32.dll) — habilitação de privilégio

### Comandos NtSetSystemInformation

| Valor | Operação |
|-------|----------|
| 2 | `MemoryEmptyWorkingSets` — esvazia working sets de todos os processos |
| 4 | `MemoryPurgeStandbyList` — esvazia a standby list (cache de arquivos) |

### Privilégio requerido

`SeProfileSingleProcessPrivilege` é habilitado antes da operação. Requer execução como Administrador.

## Targets

| Target | Descrição |
|--------|-----------|
| `All` | Working Sets + Standby List (padrão) |
| `WorkingSet` | Apenas Working Sets |
| `Standby` | Apenas Standby List |
| `Info` | Estatísticas de memória (sem alterar) |
| `List` | Lista os 15 processos com maior WorkingSet |

## Process filtering

```powershell
# Por nome
.\Clear-RAMMapCaches.ps1 -Target WorkingSet -ProcessName explorer

# Por PID
.\Clear-RAMMapCaches.ps1 -Target WorkingSet -ProcessId 1234
```

Quando um processo é especificado com `-Target All`, o target é automaticamente alterado para `WorkingSet` (pois a standby list é global, não por processo).

## DryRun

```powershell
.\Clear-RAMMapCaches.ps1 -Target All -DryRun
```

Mostra o que seria feito sem alterar nada. Útil para testar ou entender o comportamento.

## Before/After reporting

O script mede a memória antes e depois da operação usando `Win32_OperatingSystem`:

```
Antes: Total=31,94 GB | Livre=26,97 GB | Usado=4,97 GB | Uso=15,56%
Depois: Total=31,94 GB | Livre=27,33 GB | Usado=4,61 GB | Uso=14,43%
Liberado: ~0,36 GB
Concluido: 2 operacao(oes) OK, 0 falha(s)
```

## Auto-elevação

Se o script for executado sem privilégios de Administrador, ele automaticamente relança com UAC (`Start-Process -Verb RunAs`), passando `-NoElevate` para evitar loop. Se a elevação for cancelada, retorna código 1.

## Códigos de saída

| Código | Significado |
|--------|-------------|
| 0 | Sucesso |
| 1 | Falha (cancelamento de UAC, ou operação falhou) |

## Exemplos

```powershell
# Limpeza completa (auto-eleva via UAC)
.\Clear-RAMMapCaches.ps1 -Target All

# Apenas standby list
.\Clear-RAMMapCaches.ps1 -Target Standby

# Limpar working set do Chrome
.\Clear-RAMMapCaches.ps1 -Target WorkingSet -ProcessName chrome

# Simular limpeza completa
.\Clear-RAMMapCaches.ps1 -Target All -DryRun

# Estatísticas de memória
.\Clear-RAMMapCaches.ps1 -Target Info

# Listar processos com maior uso
.\Clear-RAMMapCaches.ps1 -Target List
```

## Via menu win

```powershell
win rammap 1.3 All          # limpeza completa
win rammap 1.3 WorkingSet   # apenas working sets
win rammap 1.3 Standby      # apenas standby list
win rammap 1.3 Info         # estatísticas
win rammap 1.3 List         # processos
win rammap 1.3 explorer     # limpa working set do explorer
win rammap 1.3 DryRun       # simulação
```

## Notas

- A medição de memória usa `Win32_OperatingSystem` (não `Win32_ComputerSystem`, que retornava 0)
- A standby list é recomposta automaticamente pelo Windows após a limpeza
- A diferença de memória pode ser pequena em sistemas com pouca carga
- O privilégio `SeProfileSingleProcessPrivilege` é necessário para `EmptyWorkingSet` em processos de outros usuários
