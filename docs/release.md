# e-PolyPariksha HP App Release Flow

## GitHub Variables

Set these repository variables in GitHub:

- `API_BASE_URL`: production backend URL, for example `https://api.yourdomain.com/api`
- `WEBSITE_BASE_URL`: public website URL where APKs and update JSON are hosted

## GitHub Secrets

For signed production APKs, create one Android keystore and add:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

Create the base64 value locally:

```bash
base64 -w 0 release.jks
```

## Build a New Release

1. Open GitHub Actions.
2. Run `Release Apps`.
3. Enter a new `versionName` and a higher `buildNumber`.
4. The workflow builds one combined Android APK from `apps/e-PolyPariksha HP_admin`, creates a GitHub Release, attaches the APK plus unsigned iOS `.ipa` artifact, and publishes:
   - `/releases/e-PolyPariksha HP_latest.json`
   - one combined `e-PolyPariksha HP-v<version>+<build>.apk` file

The iOS artifacts are unsigned because Apple requires a macOS signing identity and provisioning profile for device-installable `.ipa` files. Add Apple signing secrets and a signed export step before using the iOS files for normal App Store/TestFlight/device distribution.

## App Update Button

The combined app has an update button in the main app bar. Android does not allow normal apps to silently self-install APKs, so the button opens the newest APK download link from the update manifest.
