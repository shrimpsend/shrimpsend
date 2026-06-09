# Third-Party Notices

ShrimpSend / 虾传 is licensed under **AGPL-3.0-or-later**. See [LICENSE](LICENSE).

This file lists **direct dependencies** and their SPDX-style license identifiers. Transitive dependencies inherit licenses from their upstream packages; regenerate this list when upgrading major dependencies.

## Backend (`backend/`)

Declared in [backend/build.gradle.kts](backend/build.gradle.kts):

| Component | Version (managed) | License |
| --- | --- | --- |
| Spring Boot | 3.2.0 | Apache-2.0 |
| Spring Framework / Security / Data JPA | (via Boot BOM) | Apache-2.0 |
| MySQL Connector/J (`mysql-connector-j`) | (runtime) | GPL-2.0-only WITH Universal FOSS Exception |
| AWS SDK for Java S3 | 2.21.0 | Apache-2.0 |
| Stripe Java SDK | 24.16.0 | MIT |
| JJWT (jjwt-api / impl / jackson) | 0.12.3 | Apache-2.0 |
| Alipay Java SDK | 4.40.272.ALL | Proprietary — [Alipay Open Platform](https://open.alipay.com/) terms; not redistributable as open source |
| Tencent Cloud SMS SDK | 3.1.1124 | Apache-2.0 |
| Lombok | (compileOnly) | MIT |
| JUnit / Spring Test | (test) | Apache-2.0 / EPL-2.0 |

**Note:** Centrifugo runs as a **separate process** (not bundled). Upstream Centrifugo is MIT-licensed.

## Web (`web/`)

Declared in [web/package.json](web/package.json) `dependencies`:

| Package | License |
| --- | --- |
| `@base-ui/react` | MIT |
| `@openpanel/web` | MIT |
| `@tanstack/react-virtual` | MIT |
| `centrifuge` | MIT |
| `class-variance-authority` | Apache-2.0 |
| `clsx` | MIT |
| `js-sha256` | MIT |
| `lucide-react` | ISC |
| `next` | MIT |
| `next-themes` | MIT |
| `qrcode.react` | ISC |
| `react` / `react-dom` | MIT |
| `react-markdown` | MIT |
| `remark-gfm` | MIT |
| `shadcn` | MIT |
| `sonner` | MIT |
| `tailwind-merge` | MIT |
| `tw-animate-css` | MIT |

Dev dependencies (`eslint`, `tailwindcss`, `typescript`, etc.) are not shipped in production builds.

## Flutter app (`app/`)

Declared in [app/pubspec.yaml](app/pubspec.yaml) `dependencies` (representative; see `pubspec.lock` for resolved versions):

| Package | Typical license |
| --- | --- |
| `flutter` / `flutter_localizations` | BSD-3-Clause |
| `centrifuge` | MIT |
| `flutter_chat_core` / `flutter_chat_ui` | MIT |
| `flutter_riverpod` | MIT |
| `flutter_webrtc` | MIT |
| `http` | BSD-3-Clause |
| `path_provider` / `shared_preferences` / `sqflite` | BSD-3-Clause |
| `purchases_flutter` (RevenueCat) | MIT |
| `tobias` (Alipay) | Apache-2.0 |
| `pdfrx` | MIT |
| `super_clipboard` / `super_drag_and_drop` / `super_native_extensions` | MIT |
| `flutter_desktop_updater` (path) | MIT |
| `openpanel_flutter` (path) | MIT |
| `tray_manager` (path) | MIT |
| `flutter_sharing_intent` (path) | MIT |

**Fonts:** Windows builds may bundle **WenYuan Sans SC** (OFL-1.1). See [tools/fonts/README.md](tools/fonts/README.md).

## Regenerating

```bash
# Backend direct deps
cd backend && ./gradlew dependencies --configuration runtimeClasspath

# Web
cd web && npm ls --depth=0

# Flutter
cd app && flutter pub deps --style=compact
```

For license compliance questions about a specific transitive package, inspect the package metadata in Gradle/Maven, `node_modules/<pkg>/package.json`, or `~/.pub-cache`.

## Contact

Questions about ShrimpSend licensing (not third-party packages): see [LICENSE-Commercial.md](LICENSE-Commercial.md) or [LICENSE.zh-CN.md](LICENSE.zh-CN.md).
