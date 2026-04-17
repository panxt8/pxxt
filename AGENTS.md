# Repository Guidelines

## Aim
从kotlin重构一个打卡签到app到flutter，不再保留“好友”，“作业”功能。可在android和ios运行。暂时只关注android。尽量省tokens

## Project Structure & Module Organization
This repository is a Flutter app with feature-first organization.

- `lib/app/`: app bootstrap and top-level wiring.
- `lib/core/`: shared models, networking, storage, and constants (`models/`, `network/`, `storage/`, `constants/`).
- `lib/features/`: user-facing modules (`auth/`, `home/`, `course_sign/`, `profile/`) with page/controller/repository split.
- Platform folders: `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`.
- Generated output: `build/` (never commit manual edits).
- 
## Old Project
这个是老的程序的目录

- `old_proj/Doraemon-main/app/src/main/java/com/cofbro/qian/data/URL.kt`: 包含几乎所有需要用到的网络请求
- `old_proj/Doraemon-main/app/src/main/java/com/cofbro/qian/wrapper/task/TaskFragment.kt`: 签到的主要逻辑
- `old_proj/Doraemon-main/app/src/main/java/com/cofbro/qian/utils/HtmlParser.kt`: 用于html请求解析
- `old_proj/Doraemon-main/app/src/main/java/com/cofbro/qian`: 老项目的全部逻辑代码，非必要不用全部读取

## Build, Test, and Development Commands
Use Flutter directly or through FVM (`.fvmrc` is set to `stable`).

- `fvm flutter pub get`: install dependencies.
- `fvm flutter run`: run locally on a connected device/emulator.
- `fvm flutter analyze`: run static analysis using `flutter_lints`.
- `fvm flutter test`: run all tests in `test/`.
- `fvm flutter test test/widget_test.dart`: run a single test file.
- `fvm flutter build apk` (or `flutter build web`): produce release artifacts.

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (`package:flutter_lints/flutter.yaml`).
- Use 2-space indentation and format with `dart format .` before PRs.
- File names: `snake_case.dart`.
- Classes/widgets: `PascalCase`; methods/variables: `camelCase`; constants: `lowerCamelCase` unless truly global static constants.
- Keep feature boundaries clean: feature-specific logic stays in `lib/features/<feature>/`; shared logic belongs in `lib/core/`.

## Testing Guidelines
- Framework: `flutter_test`.
- Prefer fast widget/unit tests over slow integration-only checks.
- Name tests by behavior (example: `shows home and profile tabs`).
- Keep test files as `*_test.dart` and mirror source structure where practical.
- Run `flutter analyze && flutter test` before opening a PR.

## Commit & Pull Request Guidelines
Git history is not available in this workspace snapshot, so use this standard:

- Commit style: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`).
- Keep commits focused; avoid mixing refactors with behavior changes.
- PRs should include: purpose, key changes, test evidence, and screenshots/GIFs for UI changes.
- Link related issues/tasks and note any platform-specific impact (Android/iOS/Web/Desktop).
