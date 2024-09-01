import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController textEditingController = TextEditingController();

  static final key = encrypt.Key.fromUtf8(
      '123456789-123456789-123456789-12'); // 32 characters = 256 bits

  final iv = encrypt.IV(Uint8List(16));

  final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: null));

  var encrypted;

  String encryptedText = '';
  String xorText = '';
  List<int> keyXor = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      textEditingController.text = prefs.getString('keyText') ?? '';
      encryptedText = prefs.getString('encryptedText') ?? '';
    });
  }

  Future<void> _saveData(String keyText, String encryptedText) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('keyText', keyText);
    await prefs.setString('encryptedText', encryptedText);
  }

  Uint8List _addPadding(Uint8List data) {
    int pad = 16 - (data.length % 16);
    return Uint8List.fromList(data + List<int>.filled(pad, pad));
  }

  Uint8List _removePadding(Uint8List paddedData) {
    int pad = paddedData.last;
    return Uint8List.sublistView(paddedData, 0, paddedData.length - pad);
  }

  String xorStrings(String str1, String str2, String str3) {
    const String base64Chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    List<int> result = [];
    List<int> key = [];

    for (int i = 0; i < str1.length; i++) {
      if (str1[i] != '=') {
        int xorValue = str1.codeUnitAt(i % str1.length) ^
            str2.codeUnitAt(i % str2.length) ^
            str3.codeUnitAt(i % str3.length);

        int adjustedValue = xorValue % 64;
        result.add(base64Chars.codeUnitAt(adjustedValue));
        key.add((xorValue / 64).floor());
      } else {
        result.add('='.codeUnitAt(0));
      }
    }

    keyXor = key;
    return String.fromCharCodes(result);
  }

  String decodeXorString(String encodedString, String str2, String str3) {
    const String base64Chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    List<int> result = [];

    for (int i = 0; i < encodedString.length; i++) {
      if (encodedString[i] != '=') {
        int originUnit = base64Chars.indexOf(encodedString[i]) + 64 * keyXor[i];
        // Reverse the XOR operation
        int originalValue = originUnit ^
            str2.codeUnitAt(i % str2.length) ^
            str3.codeUnitAt(i % str3.length);

        result.add(originalValue);
      } else {
        result.add('='.codeUnitAt(0));
      }
    }

    return String.fromCharCodes(result);
  }

  String encryptText(String text) {
    Uint8List plaintext = Uint8List.fromList(text.codeUnits);

    Uint8List paddedPlaintext = _addPadding(plaintext);

    final encrypted = encrypter.encryptBytes(paddedPlaintext, iv: iv);

    return encrypted.base64;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Encryption Test'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9]'),
                    )
                  ],
                  decoration: const InputDecoration(hintText: 'Nhập Key'),
                  controller: textEditingController,
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text('kết quả:'),
                if (textEditingController.text.isNotEmpty)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          encryptedText,
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: encryptedText));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép')));
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                if (textEditingController.text.isEmpty) const Text(''),
                const SizedBox(
                  height: 10,
                ),
                const Text('kết quả bộ 3:'),
                Text(xorText),
                ElevatedButton(
                  onPressed: () {
                    String str1 = textEditingController.text;
                    String str2 = str1.substring((str1.length / 3).ceil()) +
                        str1.substring(0, (str1.length / 3).floor());
                    String str3 = str2.substring((str2.length / 3).ceil()) +
                        str2.substring(0, (str2.length / 3).floor());

                    str1 = encryptText(str1);
                    str2 = encryptText(str2);
                    str3 = encryptText(str3);

                    setState(() {
                      xorText = xorStrings(str1, str2, str3);
                      encryptedText = str1;
                    });

                    print("xorrrrr: ${decodeXorString(xorText, str2, str3)}");

                    _saveData(textEditingController.text, encryptedText);
                  },
                  child: const Text('Tạo key'),
                ),
              ],
            ),
          ),
        ));
  }
}
