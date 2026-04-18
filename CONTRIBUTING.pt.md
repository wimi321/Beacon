# Contribuindo para Beacon

> Este documento e o guia de contribuicao em portugues. Se houver divergencia de interpretacao, a referencia principal continua sendo [`CONTRIBUTING.md`](./CONTRIBUTING.md).

Obrigado por ajudar Beacon a ficar mais confiavel.

## Antes de abrir um PR

- Procure primeiro por issues existentes para evitar trabalho duplicado.
- Preferimos PRs pequenas e focadas em vez de grandes refactors.
- Inclua screenshots ou gravacoes em mudancas de UI.
- Para bugs de runtime, informe modelo do aparelho, versao do sistema e passos de reproducao.

## Ambiente local

```bash
npm install
npm test
dart test
```

Se estiver trabalhando nos shells moveis:

```bash
npm run mobile:build
```

## Checklist de Pull Request

- Mudancas que afetam comportamento de emergencia devem continuar faceis de revisar e validar.
- Nao introduza nenhum fallback de IA falso.
- Preserve o comportamento offline-first quando a rede estiver indisponivel.
- Se voce alterar composicao de prompt, memoria de sessao, retrieval ou fluxo UI, atualize tambem os testes.
- A linguagem visivel ao usuario deve continuar simples, direta e adequada para cenarios de panico.

## Contribuicoes para a base de conhecimento

- Priorize fontes medicas, de sobrevivencia, meteorologia e seguranca publica com autoridade.
- Respeite licencas e regras de redistribuicao de cada fonte.
- Novas fontes devem entrar por manifest e scripts de build, nao por edicao manual dos bundles gerados.

## Mudancas sensiveis de seguranca

Se sua mudanca tocar assinatura, empacotamento de modelos, bridges nativas ou guidance critica de seguranca, abra o PR com mais contexto e validacao.
