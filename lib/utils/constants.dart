enum BackendSource {
  localIp,
  cloudflared,
}

class Constants {
  static const BackendSource backendSource = BackendSource.cloudflared;
  static const bool enableBackendFallback = true;

  static const String localBackendScheme = "http";
  static const String localBackendHost = "192.168.1.11";
  static const int localBackendPort = 8000;

  static const String cloudflaredBaseUrl =
      "https://api.presensatu.my.id";

  static const String localBaseUrl =
      "$localBackendScheme://$localBackendHost:$localBackendPort";

  static const String baseUrl = backendSource == BackendSource.cloudflared
      ? cloudflaredBaseUrl
      : localBaseUrl;

  static const List<String> fallbackBaseUrls =
      backendSource == BackendSource.cloudflared
          ? [cloudflaredBaseUrl, localBaseUrl]
          : [localBaseUrl, cloudflaredBaseUrl];

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:image/')) {
      return path;
    }
    if (path.startsWith('/')) return '$baseUrl$path';
    return path;
  }
}
