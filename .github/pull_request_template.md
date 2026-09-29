Issue: #<number>

Checklist, matching CI. Run in the repository root:

- [ ] `flutter pub get`
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter analyze`
- [ ] `flutter test --exclude-tags demo`
- [ ] `flutter test --tags demo test/reduced_motion_capture_test.dart`
- [ ] `flutter test --tags demo test/sync_capture_test.dart`

Run in `example/`:

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `CHANGELOG.md` entry added
