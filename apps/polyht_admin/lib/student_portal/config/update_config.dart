class UpdateConfig {
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/AustinKarasu/e-PolyPariksha/main/website/releases/polyht_latest.json',
  );

  static const fallbackManifestUrl = String.fromEnvironment(
    'UPDATE_FALLBACK_MANIFEST_URL',
    defaultValue: 'https://github.com/AustinKarasu/e-PolyPariksha/releases/latest/download/polyht_latest.json',
  );
}
