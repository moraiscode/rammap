---
name: rammap
description: "Limpa ou consulta a memoria RAM do Windows (Empty Working Sets e Empty Standby List), equivalente ao RAMMap da Sysinternals, sem o RAMMap.exe. Use quando pedirem para liberar RAM, limpar standby list, esvaziar working sets, ver uso de memoria, ou reproduzir o RAMMap em script. Trigger - rammap, empty working sets, empty standby list, standby list, liberar ram, limpar memoria, uso de memoria."
---

# Skill: rammap

Script em `scripts/rammap/Clear-RAMMapCaches.ps1`, chamado pelo atalho `rammap.cmd` na raiz do repositório. Não depende do `RAMMap.exe`.

## Quando usar

- Ver o estado da memória (total, livre, usada, percentual).
- Liberar memória sob demanda (standby list ou working sets).
- Automatizar a limpeza em um script.

Não use como otimização recorrente: o efeito é temporário e pode deixar as leituras de arquivo mais lentas logo depois, até o cache ser repovoado.

## Comandos

Consulta, sem administrador e sem alterar nada:

```
rammap.cmd -Target Info -Json
```

Saída (uma linha de JSON):

```
{"TotalGB":31.64,"AvailableGB":15.84,"UsedGB":15.8,"UsagePct":49.94}
```

Outros alvos:

| Comando | Efeito | Exige administrador |
| --- | --- | --- |
| `rammap.cmd -Target Info` | Resumo em texto | Não |
| `rammap.cmd -Target List` | Top 15 processos por working set | Não |
| `rammap.cmd -Target All -DryRun` | Simula a limpeza | Não |
| `rammap.cmd -Target Standby` | Esvazia a standby list | Sim |
| `rammap.cmd -Target WorkingSet` | Esvazia working sets de todos os processos | Sim |
| `rammap.cmd -Target All` | Os dois anteriores | Sim |
| `rammap.cmd -Target WorkingSet -ProcessName <nome>` | Limpa só um processo | Sim |

## Códigos de saída

- `0`: sucesso.
- `1`: falha (por exemplo, sem administrador ou sem privilégio disponível).

Para ler o código no PowerShell, use `$LASTEXITCODE` logo após o comando:

```
.\rammap.cmd -Target Info -Json
$LASTEXITCODE
```

Confirme o código antes de dizer que a ação deu certo.

## Cuidados

- Para limpar é preciso um terminal **elevado** (administrador). Sem isso, o script informa e sai com código `1`. Não tente contornar o UAC.
- Antes de executar `-Target All` ou `-Target Standby`, confirme com o usuário. A ação altera a memória do sistema inteiro.
- Use `-DryRun` quando não tiver certeza.
- Os endereços e comportamentos internos valem para o RAMMap 1.63. Detalhes em `docs/RAMMAP.md`.
