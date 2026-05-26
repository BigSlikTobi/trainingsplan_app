# T4L Trainer

This app no longer uses local exchange files. Use the same server-first workflow
as every agent:

```bash
t4l-server serve --data-dir ~/T4LServerData
```

Connect the iOS app with the printed server URL and API key, push fresh context
from Settings, then use the server MCP endpoint to read context and write
pending T4L Gym Bro results.

Important app files:

- `lib/src/state/fitness_controller.dart`
- `lib/src/services/local_bridge_service.dart`
- `lib/src/services/coach_payload_service.dart`
- `lib/src/models/fitness_models.dart`

Run `flutter test` and `flutter analyze` before handing off app changes.
