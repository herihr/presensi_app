enum BackendSource {
  localIp,
  cloudflared,
}

class Constants {
  static const BackendSource backendSource = BackendSource.localIp;

  static const String localBackendScheme = "http";
  static const String localBackendHost = "192.168.1.20";
  static const int localBackendPort = 8000;

  static const String cloudflaredBaseUrl =
      "https://portraits-arms-pubmed-pas.trycloudflare.co";

  static const String localBaseUrl =
      "$localBackendScheme://$localBackendHost:$localBackendPort";

  static const String baseUrl = backendSource == BackendSource.localIp
      ? localBaseUrl
      : cloudflaredBaseUrl;
}
