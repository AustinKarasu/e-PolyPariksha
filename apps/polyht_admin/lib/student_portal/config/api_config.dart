class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-two-mauve-83.vercel.app/api',
  );
}
