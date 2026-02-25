import 'dart:typed_data';

import 'web_image_picker_stub.dart'
    if (dart.library.html) 'web_image_picker_html.dart';

Future<Uint8List?> pickWebImageBytes({required bool useCamera}) {
  return pickWebImageImpl(useCamera: useCamera);
}


