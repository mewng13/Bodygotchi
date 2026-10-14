# bodygotchi

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI features (Claude API key)

The AI trainer reads its key at build time and never from source:

```sh
cp secrets.example.json secrets.json   # then put your key in secrets.json (gitignored)
flutter run --dart-define-from-file=secrets.json
```

Without a key, the app falls back to local, non-AI recommendations.
