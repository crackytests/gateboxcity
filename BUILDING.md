# Building GATEBOX BREACH

This project expects Redot 26.1, detected from `project.godot`:

```ini
config/features=PackedStringArray("26.1", "Forward Plus", "Redot")
```

## Local Builds

Local exports use `scripts/build.sh`. The script requires a real `export_presets.cfg` at the project root and a `REDOT_BIN` environment variable pointing to your Redot editor executable.

```bash
REDOT_BIN=/path/to/redot ./scripts/build.sh
```

By default, the script looks for these export preset names:

```bash
CI Windows Desktop
CI Linux
CI macOS
```

Override them if your local presets use different names:

```bash
REDOT_BIN=/path/to/redot \
WINDOWS_PRESET="Windows Desktop" \
LINUX_PRESET="Linux" \
MACOS_PRESET="macOS" \
./scripts/build.sh
```

The script fails before exporting if Redot is missing, `export_presets.cfg` is missing, or any preset name cannot be found.

## GitHub Actions

CI is defined in `.github/workflows/build-redot.yml`.

It runs on:

- pushes to `main`
- version tags like `v0.1.0`
- manual `workflow_dispatch`

The workflow:

- detects the Redot version from `project.godot`
- reports whether `export_presets.cfg` exists and lists preset names when present
- downloads the Redot 26.1 editor and export templates from the Redot GitHub release
- imports the project headlessly
- exports Windows, Linux, and macOS builds
- uploads all builds as GitHub Actions artifacts
- publishes a GitHub Release with zipped builds when the run was triggered by a `v*` tag

If `export_presets.cfg` is not committed, CI generates temporary Windows, Linux, and macOS presets for that run. Local builds do not do this; they require your real presets.

macOS exports are unsigned by default. Playtesters may need to right-click Open or approve the app in macOS security settings. Public distribution without warnings requires Apple code signing and notarization.

## Updating Redot

When updating Redot versions:

1. Open the project in the new Redot version so `project.godot` records the new feature/version metadata.
2. Update these values in `.github/workflows/build-redot.yml`:

```yaml
REDOT_RELEASE_TAG: redot-26.1-stable
REDOT_RELEASE_API: https://api.github.com/repos/Redot-Engine/redot-engine/releases/tags/redot-26.1-stable
```

3. Confirm the export templates install path still matches the version printed by:

```bash
$REDOT_BIN --headless --version
```

4. Run a local export before relying on CI.

If Redot changes release asset names, set these GitHub Actions repository variables instead of editing the workflow download logic:

- `REDOT_EDITOR_URL`
- `REDOT_EXPORT_TEMPLATES_URL`

No secrets are required for public Redot release downloads.

## Publishing Releases

To publish builds for playtesters, push a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The GitHub Action will build Windows, Linux, and macOS, package each target as a zip, create a GitHub Release named after the tag, and attach the zip files.

Use a new tag for each public build. If you need to replace a broken release, delete or move the tag intentionally, then rerun the workflow.

## Adding Export Targets

To add another platform:

1. Create and test the export preset in Redot.
2. Commit `export_presets.cfg` if you want CI to use your real presets.
3. Add a new preset variable and export command to `scripts/build.sh`.
4. Add a matching export step, archive command, `actions/upload-artifact` step, and release asset entry to `.github/workflows/build-redot.yml`.
5. Make sure the Redot export templates include that platform.

Keep preset names stable; both the local script and CI select exports by preset name.
