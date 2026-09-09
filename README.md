# Babft-Autobuild

Autobuilder keyless para **Build A Boat For Treasure** (`PlaceId 537413528`).

Este projeto é uma implementação original e independente. Ele não inclui nem redistribui o código do Butter.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Johnatafgfdgf/Babft-autobuild/main/main.lua"))()
```

## Recursos atuais

- Sem key system.
- UI própria compatível com mouse e toque.
- Exporta a construção atual para JSON.
- Copia o JSON para a área de transferência quando `setclipboard` existe.
- Salva e carrega blueprints locais quando o executor oferece `writefile`, `readfile`, `isfile`, `makefolder` e `isfolder`.
- Reconstrói blocos usando as ferramentas do próprio BABFT.
- Restaura posição/rotação, escala, cor, transparência e estado de anchored quando suportado.
- Progresso em tempo real.
- Cancelamento durante a construção.
- Delay configurável entre blocos.
- Formato próprio de blueprint versionado.

## Estrutura

- `main.lua`: loader mínimo.
- `src/autobuild.lua`: engine + UI.

## Formato de blueprint

O formato atual é JSON e usa `format = "babft-autobuild"` e `version = 1`.
Cada bloco registra nome, CFrame relativo à zona do jogador, tamanho, cor, transparência e Anchored.

## Observações

O funcionamento depende das ferramentas/remotes disponíveis no cliente do BABFT e das APIs oferecidas pelo executor. Se o jogo alterar o protocolo das ferramentas, a camada de construção pode precisar ser atualizada.
