import 'dart:typed_data';
import 'dart:html' as html;

Future<Uint8List?> pickWebImageImpl({required bool useCamera}) async {
  final input = html.FileUploadInputElement();
  input.accept = 'image/*';
  if (useCamera) {
    input.setAttribute('capture', 'environment');
  } else {
    input.attributes.remove('capture');
  }
  input.click();

  await input.onChange.first;

  final file = input.files?.first;
  if (file == null) {
    return null;
  }

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  final result = reader.result;
  if (result is Uint8List) {
    return result;
  }

  if (result is ByteBuffer) {
    return result.asUint8List();
  }

  return null;
}


