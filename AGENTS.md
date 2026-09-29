# Project guidance

macdissey 3d is a native macOS menu bar app for the Samsung Odyssey 3D G90XF.
Read README.md for build requirements, private assets, and architecture.

- Use `bd` for task tracking when a local Beads workspace is present. Read the
  project or global Beads skill and run `bd prime` to recover context. Keep local
  task history and personal research outside Git.
- Preserve factory calibration, tracking arithmetic, and native-pixel rendering
  behavior when refactoring. A build or lens-off check is not optical validation.
- Run `sh scripts/check.sh` for regression checks and `sh scripts/build-app.sh`
  for the release bundle. Hardware integration is opt-in; see README.md.
- Format Swift with `swift-format` and C++ with `clang-format`. Preserve upstream
  attribution and license headers.
- Never commit vendor models, recovered shaders, calibration, monitor identities,
  packet captures, VMs, credentials, or local absolute paths.
- Do not publish, push, or change the project license without an explicit request.
- Keep this guidance consistent with CLAUDE.md.
