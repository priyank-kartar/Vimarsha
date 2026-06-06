/// Immutable app configuration. For now just the backend location; the client
/// points at localhost (local MPS backend) by default and can be repointed at a
/// LAN/RunPod URL.
class AppSettings {
  const AppSettings({this.backendBaseUrl = 'http://localhost:8000'});

  final String backendBaseUrl;
}
