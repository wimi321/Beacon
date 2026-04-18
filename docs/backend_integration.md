# Beacon Backend Integration Notes

## Integration priorities

1. Keep all emergency flows offline-first.
2. Prefer direct category hits and lexical evidence retrieval before every inference.
3. If authoritative evidence is missing, still call the real local model and return limited-evidence guidance instead of fake fallback text.
4. Prefer `E2B` automatically under doomsday power mode.
5. Build SOS packets so they can be relayed without a central server.

## Frontend-facing flow

### Triage request

The UI should collect:

- user free text
- optional image bytes from camera
- optional category shortcut such as `snake bite` or `heavy bleeding`
- current power mode

Then call `BeaconBackend.triage()` with an `EmergencyRequest`.

### SOS request

The UI should collect:

- local device id
- latest GPS fix
- short injury summary from triage result

Then call `BeaconBackend.broadcastSos()`.

## Safety policy enforced in prompts

- no invented medicine or dosage
- real local-model output with limited-evidence labeling if authoritative evidence misses
- concise numbered steps for panicked users
- explicit handoff to human professionals when signal returns

## Retrieval architecture

- direct category hits from tags and aliases
- lexical retrieval over structured first-aid cards
- evidence bundle assembly before model inference
- no fake fallback template when grounding is weak; continue with real on-device model generation

## Recommended next adapter files

- `lib/adapters/litert_model_runtime.dart`
- `lib/adapters/isar_knowledge_store.dart`
- `lib/adapters/mesh_network_transport.dart`
- `lib/adapters/resumable_http_downloader.dart`
