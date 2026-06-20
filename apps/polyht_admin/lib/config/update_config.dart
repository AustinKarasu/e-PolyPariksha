class UpdateConfig {
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/AustinKarasu/e-PolyPariksha/main/website/releases/polyht_latest.json',
  );

  static const fallbackManifestUrl = String.fromEnvironment(
    'UPDATE_FALLBACK_MANIFEST_URL',
    defaultValue: 'http://150.242.202.246/downloads/polyht_latest.json',
  );
}
