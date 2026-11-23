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

## Usar com IA (skill)

Há uma skill pronta em `skills/rammap/SKILL.md`. Para usar em um agente compatível com skills, copie a pasta `skills/rammap` para o diretório de skills do agente (por exemplo, `~/.config/opencode/skills/`).

Para consultar o estado da memória de forma estruturada, use:

```
rammap.cmd -Target Info -Json
```

## Instalar o comando `rammap` (PATH)

Para usar `rammap` de qualquer pasta, adicione o clone ao PATH do usuário (não precisa de administrador):

```powershell
.\scripts\rammap\Install-RAMMapAlias.ps1
```n
Depois, abra um novo terminal. O script é idempotente e coloca o clone no início do PATH, então vence um `rammap.cmd` antigo.

## Licença

MIT. Veja [LICENSE](LICENSE).