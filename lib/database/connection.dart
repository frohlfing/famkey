// Conditional Import für die plattformspezifische Implementierung
export 'connections/connection_stub.dart'
  if (dart.library.ffi) 'connections/connection_native.dart'
  if (dart.library.js_interop) 'connections/connection_web.dart';