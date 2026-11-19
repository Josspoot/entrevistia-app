/// URL base de la API de Spring Boot.
/// Se inyecta en tiempo de compilación con --dart-define:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.114:8090
///
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8090',
);
