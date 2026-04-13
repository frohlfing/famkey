// Conditional Import für die plattformspezifische Implementierung
export 'connection/connection_stub.dart'
  if (dart.library.ffi) 'connection/connection_native.dart'
  if (dart.library.js_interop) 'connection/connection_web.dart';