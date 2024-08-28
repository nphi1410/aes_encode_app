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
                ElevatedButton(
                  onPressed: () {
                    Uint8List plaintext = Uint8List.fromList(
                        textEditingController.text.codeUnits);
                    Uint8List paddedPlaintext = _addPadding(plaintext);

                    encrypted = encrypter.encryptBytes(paddedPlaintext, iv: iv);
                    setState(() {
                      encryptedText = encrypted.base64;
                    });

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
