class AppConfig {
  const AppConfig._();

  // Deployment base URL passed at compile/runtime or defaults to aestheticinteriortech.com
  static const String _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.aestheticinteriortech.com',
  );

  /// Normalized API base URL without trailing slash.
  /// Automatically ensures https:// scheme, strips trailing slashes,
  /// fixes spelling variants, and targets the direct www host to avoid Vercel redirects.
  static String get apiBaseUrl {
    String url = _configuredUrl.trim();
    if (url.isEmpty) {
      url = 'https://www.aestheticinteriortech.com';
    }

    // Fix phonetic spelling variants if passed (e.g. aeshthetic -> aesthetic)
    if (url.contains('aeshthetic')) {
      url = url.replaceAll('aeshthetic', 'aesthetic');
    }

    // Ensure http/https scheme is present
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Route to www.aestheticinteriortech.com to avoid Vercel 308 redirect
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host == 'aestheticinteriortech.com') {
      url = uri.replace(host: 'www.aestheticinteriortech.com').toString();
    }

    // Remove any trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  static const String apiAuthToken = String.fromEnvironment(
    'API_AUTH_TOKEN',
    defaultValue: '',
  );
}
