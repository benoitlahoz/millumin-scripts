# Contributing to Millumin Scripts

Thank you for your interest in contributing! This document covers how to add or modify scripts, and how the release pipeline works.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Adding a Script](#adding-a-script)
- [manifest.json Reference](#manifestjson-reference)
- [CI & Release Pipeline](#ci--release-pipeline)
- [Forking & Required Secrets](#forking--required-secrets)

---

## Project Structure

```
.
├── scripts/
│   └── my-script/
│       ├── my-script.js
│       └── manifest.json
└── installer/
    └── build.sh
```

Each script lives in its own subdirectory under `scripts/`. The build system discovers them automatically at build time.

---

## Adding a Script

1. Create a new folder under `scripts/` named after your script.
2. Add a single `.js` file — its filename is used as the installed file name.
3. Add a `manifest.json` (see below).
4. Open a pull request against `master`.

The script will be included in the next release automatically once merged.

---

## manifest.json Reference

```json
{
  "name": "My Script",
  "description": "A short description of what the script does.",
  "version": "1.0.0",
  "author": "Your Name",
  "category": "Text",
  "install": true
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Display name shown in the installer UI |
| `description` | string | no | Short description of what the script does |
| `version` | string | no | Defaults to `1.0.0` |
| `author` | string | no | Name of the script author |
| `category` | string | no | Category used to group scripts (e.g. `Text`, `Media`) |
| `install` | boolean | no | Set to `false` to exclude from the installer |

---

## CI & Release Pipeline

Releases are fully automated via GitHub Actions. You never need to build or sign the installer manually.

### Trigger

The pipeline runs automatically on every push to `master` that touches either `scripts/**` or `installer/build.sh`. It can also be triggered manually from the **Actions** tab via `workflow_dispatch`.

### What the pipeline does

```
push to master
    │
    ├─ build.sh           → builds one .pkg component per script
    │                       and assembles them into a single
    │                       Millumin-Scripts-Unsigned.pkg
    │
    ├─ productsign        → signs the package with a
    │                       Developer ID Installer certificate
    │
    ├─ notarytool         → submits to Apple's notary service
    │                       and waits for approval
    │
    ├─ stapler            → staples the notarization ticket
    │                       onto the .pkg
    │
    └─ GitHub Release     → creates a versioned release (YYYY.MM.DD.HHmm)
                            and attaches the signed .pkg as an asset
```

### Install location

Scripts are installed to:

```
~/Library/Millumin/Scripts/io.benoitlahoz.millumin.scripts/
```

The installer will create this directory if it does not exist and will never delete or overwrite files already present there.

### Release versioning

Releases are versioned by build timestamp: `YYYY.MM.DD.HHmm`. There is no manual version bump required — merging to `master` is enough.

---

## Forking & Required Secrets

If you fork this repository and want the CI pipeline to produce signed and notarized releases, you need to configure the following secrets in your fork under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `MAC_CERTIFICATE` | Base64-encoded Developer ID Installer certificate (`.p12`) |
| `MAC_CERTIFICATE_PASSWORD` | Password for the `.p12` file |
| `ASC_PRIVATE_KEY` | Apple App Store Connect API private key (`.p8` file contents, with real newlines) |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |

> **Important — `ASC_PRIVATE_KEY` format:** the `.p8` key must be stored with real newlines, not escaped `\n` sequences. Copy the full contents of your `.p8` file as-is when creating the secret.

If any of these secrets are missing, the pipeline will fail early with a clear error message indicating which secret is absent.

If you only want to build an unsigned installer without signing or notarization, you can remove the **Import certificate**, **Sign package**, **Notarize package**, and **Staple notarization** steps from the workflow and use the `Millumin-Scripts-Unsigned.pkg` artifact directly.
