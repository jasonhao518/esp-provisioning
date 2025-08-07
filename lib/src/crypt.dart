// import 'dart:async';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class Crypt {
  late final Uint8List _key;
  late final Uint8List _iv;
  static late final StreamCipher _cipher;

  void init(Uint8List key, Uint8List iv) {
    _key = key;
    _iv = iv;
    final params = ParametersWithIV(KeyParameter(_key), _iv);
    _cipher = StreamCipher('AES/CTR')
      ..init(true, params);
  }

  Uint8List crypt(Uint8List data) {
    return _cipher.process(data);
  }
}
