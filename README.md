# rammap

Limpeza de memória RAM no Windows, equivalente às ações **Empty Working Sets** e **Empty Standby List** do RAMMap (Sysinternals), sem depender do `RAMMap.exe`.

## Aviso

- Usa `NtSetSystemInformation` (classe `SystemMemoryListInformation`, 0x50) via P/Invoke.
- Para limpar é preciso executar como **Administrador**. Os modos `Info`, `List` e `DryRun` funcionam sem elevação.
- Não causa dano permanente: a memória é recarregada conforme os programas precisarem, o que pode deixar as próximas operações mais lentas por um tempo.
- Use por sua conta e risco.

## Uso

```
rammap.cmd
```

Veja os parâmetros disponíveis no cabeçalho de `scripts\rammap\Clear-RAMMapCaches.ps1` e na documentação em `docs\RAMMAP.md`.

## Requisitos

- Windows 10 ou superior.
- PowerShell 5.1 ou PowerShell 7 (`pwsh`).

## Estrutura

- `rammap.cmd`: atalho que chama o script, usando o caminho relativo ao próprio arquivo.
- `scripts\rammap\Clear-RAMMapCaches.ps1`: implementação.
- `docs\RAMMAP.md`: detalhes técnicos.

## Licença

MIT. Veja [LICENSE](LICENSE).
