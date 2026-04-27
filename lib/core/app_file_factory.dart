// Conditional Export für die plattformspezifische Implementierung
export 'app_file/app_file_stub.dart'
  if (dart.library.ffi) 'app_file/app_file_native.dart'
  if (dart.library.js_interop) 'app_file/app_file_web.dart';
