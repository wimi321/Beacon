# Politica de Seguridad

> Este documento es la guia de seguridad en espanol. Si hay diferencias de interpretacion, la referencia principal es [`SECURITY.md`](./SECURITY.md).

## Alcance

Beacon maneja flujos de emergencia, bridges moviles nativos y entrega de guidance offline. Reporta vulnerabilidades de forma responsable.

## Como reportar

Hasta que exista un canal de seguridad dedicado, usa si es posible un GitHub Security Advisory privado. Si eso no esta disponible, abre un issue minimo sin detalles sensibles de explotacion e indica que necesitas un canal privado de seguimiento.

## Que incluir

- Plataforma afectada y version del sistema
- Modelo del dispositivo
- Pasos de reproduccion
- Resumen del impacto
- Si afecta inferencia offline, permisos nativos, empaquetado de modelos o entrega de conocimiento

## Objetivos de respuesta

- Confirmar recepcion lo antes posible
- Reproducir y evaluar severidad
- Corregir o mitigar antes de publicar todos los detalles

## Fuera de alcance

- Debates generales sobre calidad del modelo sin una falla concreta de seguridad o safety
- Problemas de terceros aguas arriba sin impacto especifico en Beacon
