import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dart_sm/dart_sm.dart';

class StringProcessor {
  static String toCharStr(List<int> codes) {
    return String.fromCharCodes(codes);
  }

  static List<int> toOrdArray(String s) {
    return s.codeUnits;
  }

  static int jsShiftRight(int val, int n) {
    return (val & 0xFFFFFFFF) >>> n;
  }

  static String generateRandomBytes({int length = 3}) {
    List<String> generateByteSequence() {
      final _rd = Random().nextInt(10000);
      return [
        String.fromCharCode(((_rd & 255) & 170) | 1),
        String.fromCharCode(((_rd & 255) & 85) | 2),
        String.fromCharCode((jsShiftRight(_rd, 8) & 170) | 5),
        String.fromCharCode((jsShiftRight(_rd, 8) & 85) | 40),
      ];
    }

    final result = <String>[];
    for (var i = 0; i < length; i++) {
      result.addAll(generateByteSequence());
    }

    return result.join('');
  }
}

class CryptoUtility {
  final String salt;
  final List<String> base64Alphabet;
  late List<int> bigArray;

  CryptoUtility(this.salt, this.base64Alphabet) {
    // fmt: off
    bigArray = [
        121, 243,  55, 234, 103,  36,  47, 228,  30, 231, 106,   6, 115,  95,  78, 101, 250, 207, 198,  50,
        139, 227, 220, 105,  97, 143,  34,  28, 194, 215,  18, 100, 159, 160,  43,   8, 169, 217, 180, 120,
        247,  45,  90,  11,  27, 197,  46,   3,  84,  72,   5,  68,  62,  56, 221,  75, 144,  79,  73, 161,
        178,  81,  64, 187, 134, 117, 186, 118,  16, 241, 130,  71,  89, 147, 122, 129,  65,  40,  88, 150,
        110, 219, 199, 255, 181, 254,  48,   4, 195, 248, 208,  32, 116, 167,  69, 201,  17, 124, 125, 104,
         96,  83,  80, 127, 236, 108, 154, 126, 204,  15,  20, 135, 112, 158,  13,   1, 188, 164, 210, 237,
        222,  98, 212,  77, 253,  42, 170, 202,  26,  22,  29, 182, 251,  10, 173, 152,  58, 138,  54, 141,
        185,  33, 157,  31, 252, 132, 233, 235, 102, 196, 191, 223, 240, 148,  39, 123,  92,  82, 128, 109,
         57,  24,  38, 113, 209, 245,   2, 119, 153, 229, 189, 214, 230, 174, 232,  63,  52, 205,  86, 140,
         66, 175, 111, 171, 246, 133, 238, 193,  99,  60,  74,  91, 225,  51,  76,  37, 145, 211, 166, 151,
        213, 206,   0, 200, 244, 176, 218,  44, 184, 172,  49, 216,  93, 168,  53,  21, 183,  41,  67,  85,
        224, 155, 226, 242,  87, 177, 146,  70, 190,  12, 162,  19, 137, 114,  25, 165, 163, 192,  23,  59,
          9,  94, 179, 107,  35,   7, 142, 131, 239, 203, 149, 136,  61, 249,  14, 156
    ];
    // fmt: on
  }

  static List<int> sm3ToArray(dynamic inputData) {
    Uint8List inputDataBytes;
    if (inputData is String) {
      inputDataBytes = utf8.encode(inputData);
    } else if (inputData is List<int>) {
      inputDataBytes = Uint8List.fromList(inputData);
    } else {
      throw ArgumentError("Input data must be a String or List<int>");
    }
    final hexResult = SM3.hashBytes(inputDataBytes);
    final result = <int>[];
    for (var i = 0; i < hexResult.length; i += 2) {
      result.add(int.parse(hexResult.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  String addSalt(String param) {
    return param + salt;
  }

  dynamic processParam(dynamic param, bool addSaltFlag) {
    if (param is String && addSaltFlag) {
      return addSalt(param);
    }
    return param;
  }

  List<int> paramsToArray(dynamic param, {bool addSalt = true}) {
    final processedParam = processParam(param, addSalt);
    return sm3ToArray(processedParam);
  }

  String transformBytes(List<int> bytesList) {
    final bytesStr = StringProcessor.toCharStr(bytesList);
    final resultStr = <String>[];
    var indexB = bigArray[1];
    var initialValue = 0;
    var valueE = 0; // To hold the value for the next iteration

    for (var index = 0; index < bytesStr.length; index++) {
      final char = bytesStr[index];
      var sumInitial = 0;

      if (index == 0) {
        initialValue = bigArray[indexB];
        sumInitial = indexB + initialValue;

        bigArray[1] = initialValue;
        bigArray[indexB] = indexB;
      } else {
        sumInitial = initialValue + valueE;
      }

      final charValue = char.codeUnitAt(0);
      sumInitial %= bigArray.length;
      final valueF = bigArray[sumInitial];
      final encryptedChar = charValue ^ valueF;
      resultStr.add(String.fromCharCode(encryptedChar));

      valueE = bigArray[(index + 2) % bigArray.length];
      sumInitial = (indexB + valueE) % bigArray.length;
      initialValue = bigArray[sumInitial];
      bigArray[sumInitial] = bigArray[(index + 2) % bigArray.length];
      bigArray[(index + 2) % bigArray.length] = initialValue;
      indexB = sumInitial;
    }

    return resultStr.join('');
  }

  String base64Encode(String inputString, {int selectedAlphabet = 0}) {
    var binaryString = inputString.codeUnits
        .map((c) => c.toRadixString(2).padLeft(8, '0'))
        .join('');

    final paddingLength = (6 - binaryString.length % 6) % 6;
    binaryString += '0' * paddingLength;

    final base64Indices = <int>[];
    for (var i = 0; i < binaryString.length; i += 6) {
      base64Indices.add(int.parse(binaryString.substring(i, i + 6), radix: 2));
    }

    var outputString = base64Indices
        .map((index) => base64Alphabet[selectedAlphabet][index])
        .join('');

    outputString += '=' * (paddingLength ~/ 2);
    return outputString;
  }

  String abogusEncode(String abogusBytesStr, int selectedAlphabet) {
    final abogus = <String>[];
    final alphabet = base64Alphabet[selectedAlphabet];

    for (var i = 0; i < abogusBytesStr.length; i += 3) {
      int n;
      if (i + 2 < abogusBytesStr.length) {
        n = (abogusBytesStr.codeUnitAt(i) << 16) |
            (abogusBytesStr.codeUnitAt(i + 1) << 8) |
            abogusBytesStr.codeUnitAt(i + 2);
      } else if (i + 1 < abogusBytesStr.length) {
        n = (abogusBytesStr.codeUnitAt(i) << 16) |
            (abogusBytesStr.codeUnitAt(i + 1) << 8);
      } else {
        n = abogusBytesStr.codeUnitAt(i) << 16;
      }

      final shifts = [18, 12, 6, 0];
      final masks = [0xFC0000, 0x03F000, 0x0FC0, 0x3F];

      for (var j = 0; j < shifts.length; j++) {
        if (shifts[j] == 6 && i + 1 >= abogusBytesStr.length) break;
        if (shifts[j] == 0 && i + 2 >= abogusBytesStr.length) break;
        abogus.add(alphabet[(n & masks[j]) >> shifts[j]]);
      }
    }

    abogus.add('=' * ((4 - abogus.length % 4) % 4));
    return abogus.join('');
  }

  static Uint8List rc4Encrypt(Uint8List key, String plaintext) {
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
    }

    var i = 0;
    j = 0;
    final ciphertext = <int>[];
    for (final char in plaintext.codeUnits) {
      i = (i + 1) % 256;
      j = (j + s[i]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
      final k = s[(s[i] + s[j]) % 256];
      ciphertext.add(char ^ k);
    }

    return Uint8List.fromList(ciphertext);
  }
}

class BrowserFingerprintGenerator {
  static String generateFingerprint({String browserType = "Edge"}) {
    final browsers = {
      "Chrome": generateChromeFingerprint,
      "Firefox": generateFirefoxFingerprint,
      "Safari": generateSafariFingerprint,
      "Edge": generateEdgeFingerprint,
    };
    return (browsers[browserType] ?? generateChromeFingerprint)();
  }

  static String generateChromeFingerprint() => _generateFingerprint(platform: "Win32");
  static String generateFirefoxFingerprint() => _generateFingerprint(platform: "Win32");
  static String generateSafariFingerprint() => _generateFingerprint(platform: "MacIntel");
  static String generateEdgeFingerprint() => _generateFingerprint(platform: "Win32");

  static String _generateFingerprint({required String platform}) {
    final random = Random();
    final innerWidth = 1024 + random.nextInt(1920 - 1024 + 1);
    final innerHeight = 768 + random.nextInt(1080 - 768 + 1);
    final outerWidth = innerWidth + (24 + random.nextInt(32 - 24 + 1));
    final outerHeight = innerHeight + (75 + random.nextInt(90 - 75 + 1));
    const screenX = 0;
    final screenY = [0, 30][random.nextInt(2)];
    final sizeWidth = 1024 + random.nextInt(1920 - 1024 + 1);
    final sizeHeight = 768 + random.nextInt(1080 - 768 + 1);
    final availWidth = 1280 + random.nextInt(1920 - 1280 + 1);
    final availHeight = 800 + random.nextInt(1080 - 800 + 1);

    return "$innerWidth|$innerHeight|$outerWidth|$outerHeight|"
        "$screenX|$screenY|0|0|$sizeWidth|$sizeHeight|"
        "$availWidth|$availHeight|$innerWidth|$innerHeight|24|24|$platform";
  }
}

class ABogus {
  final String userAgent;
  final String browserFp;
  final List<int> options;

  final int aid = 6383;
  final int pageId = 0;
  final String salt = "cus";
  final bool boe = false;
  final double ddrt = 8.5;
  final double ic = 8.5;
  final List<String> paths = [
    "^/webcast/",
    "^/aweme/v1/",
    "^/aweme/v2/",
    "/v1/message/send",
    "^/live/",
    "^/captcha/",
    "^/ecom/",
  ];
  final Uint8List uaKey = Uint8List.fromList([0, 1, 14]);

  final String character = "Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe";
  final String character2 = "ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe";
  late final List<String> characterList;
  late final CryptoUtility cryptoUtility;

  // fmt: off
  final List<int> sortIndex = [
      18, 20, 52, 26, 30, 34, 58, 38, 40, 53, 42, 21, 27, 54, 55, 31, 35, 57, 39, 41, 43, 22, 28,
      32, 60, 36, 23, 29, 33, 37, 44, 45, 59, 46, 47, 48, 49, 50, 24, 25, 65, 66, 70, 71
  ];
  final List<int> sortIndex2 = [
      18, 20, 26, 30, 34, 38, 40, 42, 21, 27, 31, 35, 39, 41, 43, 22, 28, 32, 36, 23, 29, 33, 37,
      44, 45, 46, 47, 48, 49, 50, 24, 25, 52, 53, 54, 55, 57, 58, 59, 60, 65, 66, 70, 71
  ];
  // fmt: on

  ABogus({String? fp, String? userAgent, List<int>? options})
      : userAgent = userAgent != null && userAgent.isNotEmpty
            ? userAgent
            : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
        browserFp = fp != null && fp.isNotEmpty
            ? fp
            : BrowserFingerprintGenerator.generateFingerprint(browserType: "Edge"),
        options = options ?? [0, 1, 14] {
    characterList = [character, character2];
    cryptoUtility = CryptoUtility(salt, characterList);
  }

  String encodeData(String data, {int alphabetIndex = 0}) {
    return cryptoUtility.abogusEncode(data, alphabetIndex);
  }

  List<String> generateAbogus(String params, {String body = ""}) {
    final abDir = <int, dynamic>{
      8: 3,
      15: {
        "aid": aid,
        "pageId": pageId,
        "boe": boe,
        "ddrt": ddrt,
        "paths": paths,
        "track": {"mode": 0, "delay": 300, "paths": []},
        "dump": true,
        "rpU": "",
      },
      18: 44,
      19: [1, 0, 1, 0, 1],
      66: 0,
      69: 0,
      70: 0,
      71: 0,
    };

    final startEncryption = DateTime.now().millisecondsSinceEpoch;

    final array1 = cryptoUtility.paramsToArray(cryptoUtility.paramsToArray(params));
    final array2 = cryptoUtility.paramsToArray(cryptoUtility.paramsToArray(body));
    final array3 = cryptoUtility.paramsToArray(
      cryptoUtility.base64Encode(
        StringProcessor.toCharStr(
          CryptoUtility.rc4Encrypt(uaKey, userAgent),
        ),
        selectedAlphabet: 1,
      ),
      addSalt: false,
    );

    final endEncryption = DateTime.now().millisecondsSinceEpoch;

    abDir[20] = (startEncryption >> 24) & 255;
    abDir[21] = (startEncryption >> 16) & 255;
    abDir[22] = (startEncryption >> 8) & 255;
    abDir[23] = startEncryption & 255;
    abDir[24] = StringProcessor.jsShiftRight(startEncryption, 32);
    abDir[25] = StringProcessor.jsShiftRight(startEncryption, 40);

    abDir[26] = (options[0] >> 24) & 255;
    abDir[27] = (options[0] >> 16) & 255;
    abDir[28] = (options[0] >> 8) & 255;
    abDir[29] = options[0] & 255;

    abDir[30] = (options[1] ~/ 256) & 255;
    abDir[31] = (options[1] % 256) & 255;
    abDir[32] = (options[1] >> 24) & 255;
    abDir[33] = (options[1] >> 16) & 255;

    abDir[34] = (options[2] >> 24) & 255;
    abDir[35] = (options[2] >> 16) & 255;
    abDir[36] = (options[2] >> 8) & 255;
    abDir[37] = options[2] & 255;

    abDir[38] = array1[21];
    abDir[39] = array1[22];
    abDir[40] = array2[21];
    abDir[41] = array2[22];
    abDir[42] = array3[23];
    abDir[43] = array3[24];

    abDir[44] = (endEncryption >> 24) & 255;
    abDir[45] = (endEncryption >> 16) & 255;
    abDir[46] = (endEncryption >> 8) & 255;
    abDir[47] = endEncryption & 255;
    abDir[48] = abDir[8];
    abDir[49] = StringProcessor.jsShiftRight(endEncryption, 32);
    abDir[50] = StringProcessor.jsShiftRight(endEncryption, 40);

    abDir[51] = (pageId >> 24) & 255;
    abDir[52] = (pageId >> 16) & 255;
    abDir[53] = (pageId >> 8) & 255;
    abDir[54] = pageId & 255;
    abDir[55] = pageId;
    abDir[56] = aid;
    abDir[57] = aid & 255;
    abDir[58] = (aid >> 8) & 255;
    abDir[59] = (aid >> 16) & 255;
    abDir[60] = (aid >> 24) & 255;

    abDir[64] = browserFp.length;
    abDir[65] = browserFp.length;

    final sortedValues = sortIndex.map((i) => abDir[i] ?? 0).toList().cast<int>();
    final edgeFpArray = StringProcessor.toOrdArray(browserFp);

    var abXor = 0;
    for (var index = 0; index < sortIndex2.length; index++) {
      if (index == 0) {
        abXor = abDir[sortIndex2[index]] ?? 0;
      } else {
        abXor ^= (abDir[sortIndex2[index]] ?? 0);
      }
    }
    sortedValues.addAll(edgeFpArray);
    sortedValues.add(abXor);

    final abogusBytesStr = StringProcessor.generateRandomBytes() +
        cryptoUtility.transformBytes(sortedValues);

    final abogus = cryptoUtility.abogusEncode(abogusBytesStr, 0);
    final finalParams = "$params&a_bogus=$abogus";
    return [finalParams, abogus, userAgent, body];
  }
}

