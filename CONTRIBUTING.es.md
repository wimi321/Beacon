# Contribuir a Beacon

> Este documento es la guia de colaboracion en espanol. Si hay diferencias de interpretacion, manda [`CONTRIBUTING.md`](./CONTRIBUTING.md).

Gracias por ayudar a que Beacon sea mas fiable.

## Antes de abrir un PR

- Revisa primero los issues existentes para evitar trabajo duplicado.
- Preferimos PR pequenos y enfocados antes que refactors muy amplios.
- Incluye capturas o grabaciones cuando cambies la UI.
- Para bugs de runtime, anade modelo del dispositivo, version del sistema y pasos de reproduccion.

## Entorno local

```bash
npm install
npm test
dart test
```

Si trabajas en los shells moviles:

```bash
npm run mobile:build
```

## Lista de revision para Pull Request

- Los cambios que afecten comportamientos de emergencia deben ser faciles de revisar y validar.
- No introduzcas ningun fallback de IA falso.
- Mantén el comportamiento offline-first cuando no haya red.
- Si cambias la composicion del prompt, memoria de sesion, retrieval o flujo UI, actualiza tambien las pruebas.
- El lenguaje visible para usuarios debe seguir siendo simple, directo y apto para situaciones de panico.

## Contribuciones a la base de conocimiento

- Prioriza fuentes medicas, de supervivencia, meteorologia y seguridad publica con autoridad.
- Respeta licencias y condiciones de redistribucion de cada fuente.
- Anade nuevas fuentes por manifest y scripts de build, no editando a mano los bundles generados.

## Cambios sensibles de seguridad

Si tu cambio toca firma, empaquetado de modelos, bridges nativos o guidance de seguridad critica, abre el PR con mas detalle para facilitar una revision cuidadosa.
