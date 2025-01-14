import 'dart:convert';

// import 'package:encrypt/encrypt.dart';

class EncryptData {
//for AES Algorithms

  // static Encrypted? encrypted;
  static dynamic decrypted;

  // static Future<String> encryptAES1(plainText) async {
  //   final key = Key.fromUtf8('KHDNHYShd8638hdnAEDKCGEUgs74sn46');
  //   final iv = IV.fromLength(16);
  //   final encrypter = Encrypter(AES(key));
  //   encrypted = encrypter.encrypt(plainText, iv: iv);
  //   //log(encrypted!.base64);
  //   return encrypted!.base64;
  // }

  // static Future<String> decryptAES1(plainText) async {
  //   final key = Key.fromUtf8('KHDNHYShd8638hdnAEDKCGEUgs74sn46');
  //   final iv = IV.fromLength(16);
  //   final encrypter = Encrypter(AES(key));
  //   decrypted = encrypter.decrypt64(plainText!, iv: iv);
  //   return decrypted;
  // }

  static String encryptData(String password) {
    String encoded = base64.encode(utf8.encode(password));
    return encoded;
  }

  static String decryptData(String encryptPwd) {
    List<int> toDecodeBytes = base64.decode(encryptPwd);
    String decoded = utf8.decode(toDecodeBytes);
    return decoded;
  }
}
