enum BackendSource {
  localIp,
  cloudflared,
}

class Constants {
  static const BackendSource backendSource = BackendSource.localIp;

  static const String localBackendScheme = "http";
  static const String localBackendHost = "192.168.1.10";
  static const int localBackendPort = 8000;

  static const String cloudflaredBaseUrl =
      "https://injured-commitment-algorithms-motel.trycloudflare.com";

  static const String localBaseUrl =
      "$localBackendScheme://$localBackendHost:$localBackendPort";

  static const String baseUrl = backendSource == BackendSource.localIp
      ? localBaseUrl
      : cloudflaredBaseUrl;
}
