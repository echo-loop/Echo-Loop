import 'dart:typed_data';

import 'package:image/image.dart' as img;

final shareTestPng = Uint8List.fromList(
  img.encodePng(
    img.Image(width: 1, height: 1)..setPixelRgba(0, 0, 228, 197, 154, 255),
  ),
);

Map<String, Object?> cardJson({bool word = false}) => {
  'id': 'b29c448f-8e26-4a8c-b20e-e1f7bb679732',
  'imageUrl': 'https://cdn.test/background.jpg',
  'textColors': {'top': '#53331f', 'bottom': '#53331f'},
  'content': word
      ? {
          'type': 'word',
          'word': 'serendipity',
          'phonetic': '/ˌserənˈdɪpəti/',
          'meaning': {'zh-CN': '意外的美好', 'zh-TW': '意外的美好'},
        }
      : {
          'type': 'sentence',
          'en': 'Catch of the day!',
          'translation': {'zh-CN': '今日最佳收获！'},
        },
};
