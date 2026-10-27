import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Whether [text] is printed in [pdf] (#94).
///
/// The application forms embed subset fonts and print glyph codes, two
/// bytes each, so their text cannot be read off the bytes. Each font
/// carries a ToUnicode map, though: [text] is encoded with every font's
/// map and looked for among the bytes of every string the content streams
/// draw, run together in order (so a text split over several show
/// operators is still found). A one-byte encoding (a standard font) is
/// tried too.
///
/// Throws a [FormatException] when a compressed stream cannot be
/// inflated or the PDF has no content to search, rather than answering
/// `false` for a PDF it could not read.
bool pdfShows(List<int> pdf, String text) {
  final document = PdfStrings.parse(pdf);
  return document.shows(text);
}

/// The drawn strings and font maps of a PDF, for [pdfShows].
class PdfStrings {
  PdfStrings._(this.drawn, this.fontMaps);

  /// Reads [pdf]'s streams: ToUnicode maps and the strings of the rest.
  factory PdfStrings.parse(List<int> pdf) {
    final bytes = Uint8List.fromList(pdf);
    final raw = latin1.decode(bytes);
    final drawn = BytesBuilder(copy: false);
    final maps = <Map<int, int>>[];
    var streams = 0;
    for (final m in _streamStart.allMatches(raw)) {
      final start = m.end;
      final dictStart = raw.lastIndexOf('obj', m.start);
      final dict = raw.substring(dictStart < 0 ? 0 : dictStart, m.start);
      final length = _directLength.firstMatch(dict);
      final int end;
      if (length != null) {
        end = start + int.parse(length.group(1)!);
      } else {
        final stop = raw.indexOf('endstream', start);
        if (stop < 0) throw const FormatException('stream without endstream');
        end = stop;
      }
      // Embedded font programs and images draw nothing.
      if (dict.contains('/Length1') || dict.contains('/Image')) {
        continue;
      }
      var data = bytes.sublist(start, end);
      if (dict.contains('/FlateDecode')) {
        try {
          data = Uint8List.fromList(ZLibDecoder().convert(data));
        } on FormatException catch (e) {
          throw FormatException('stream at $start does not inflate: $e');
        }
      }
      streams++;
      final body = latin1.decode(data);
      if (body.contains('begincmap')) {
        maps.add(_toUnicode(body));
      } else {
        _strings(data, drawn);
      }
    }
    if (streams == 0) throw const FormatException('no streams in the PDF');
    return PdfStrings._(drawn.takeBytes(), maps);
  }

  static final _streamStart = RegExp(r'(?<!end)stream\r?\n');
  static final _directLength = RegExp(r'/Length\s+(\d+)(?!\s+\d+\s+R)');

  /// Every string's bytes, in the order the content streams draw them.
  final Uint8List drawn;

  /// Each font's ToUnicode map, code point → glyph code.
  final List<Map<int, int>> fontMaps;

  /// Whether [text] is among [drawn] in any font's encoding.
  bool shows(String text) {
    for (final map in fontMaps) {
      final needle = <int>[];
      var encodable = true;
      for (final rune in text.runes) {
        final code = map[rune];
        if (code == null) {
          encodable = false;
          break;
        }
        needle.addAll([code >> 8, code & 0xFF]);
      }
      if (encodable && _contains(drawn, needle)) return true;
    }
    if (text.runes.every((r) => r < 256)) {
      return _contains(drawn, latin1.encode(text));
    }
    return false;
  }

  static bool _contains(Uint8List hay, List<int> needle) {
    if (needle.isEmpty) return true;
    outer:
    for (var i = 0; i + needle.length <= hay.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  static final _hex = RegExp('<([0-9A-Fa-f]+)>');
  static final _bfchar = RegExp(
    'beginbfchar(.*?)endbfchar',
    dotAll: true,
  );
  static final _bfrange = RegExp(
    'beginbfrange(.*?)endbfrange',
    dotAll: true,
  );
  static final _rangeLine = RegExp(
    r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]+>|\[[^\]]*\])',
  );

  /// A ToUnicode CMap as code point → glyph code, single code points only.
  static Map<int, int> _toUnicode(String cmap) {
    final map = <int, int>{};
    void put(int code, String dst) {
      if (dst.length != 4) return; // a ligature or a surrogate pair
      map.putIfAbsent(int.parse(dst, radix: 16), () => code);
    }

    for (final block in _bfchar.allMatches(cmap)) {
      final hexes = _hex.allMatches(block.group(1)!).toList();
      for (var i = 0; i + 1 < hexes.length; i += 2) {
        put(int.parse(hexes[i].group(1)!, radix: 16), hexes[i + 1].group(1)!);
      }
    }
    for (final block in _bfrange.allMatches(cmap)) {
      for (final line in _rangeLine.allMatches(block.group(1)!)) {
        final lo = int.parse(line.group(1)!, radix: 16);
        final hi = int.parse(line.group(2)!, radix: 16);
        final dst = line.group(3)!;
        if (dst.startsWith('[')) {
          final each = _hex.allMatches(dst).toList();
          for (var c = lo; c <= hi && c - lo < each.length; c++) {
            put(c, each[c - lo].group(1)!);
          }
        } else {
          final first = int.parse(dst.substring(1, dst.length - 1), radix: 16);
          for (var c = lo; c <= hi; c++) {
            put(c, (first + c - lo).toRadixString(16).padLeft(4, '0'));
          }
        }
      }
    }
    return map;
  }

  /// Appends the bytes of every literal `(…)` and hex `<…>` string in
  /// content stream [data] to [out].
  static void _strings(Uint8List data, BytesBuilder out) {
    var i = 0;
    while (i < data.length) {
      final c = data[i];
      if (c == 0x25) {
        // `%` comment, to the end of the line.
        while (i < data.length && data[i] != 0x0A && data[i] != 0x0D) {
          i++;
        }
      } else if (c == 0x28) {
        i = _literal(data, i + 1, out);
      } else if (c == 0x3C && i + 1 < data.length && data[i + 1] == 0x3C) {
        i += 2; // `<<` opens a dictionary, not a string
      } else if (c == 0x3C) {
        i = _hexString(data, i + 1, out);
      } else {
        i++;
      }
    }
  }

  static int _literal(Uint8List data, int from, BytesBuilder out) {
    var i = from;
    var depth = 1;
    while (i < data.length) {
      final c = data[i];
      if (c == 0x5C && i + 1 < data.length) {
        final e = data[i + 1];
        i += 2;
        switch (e) {
          case 0x6E:
            out.addByte(0x0A);
          case 0x72:
            out.addByte(0x0D);
          case 0x74:
            out.addByte(0x09);
          case 0x62:
            out.addByte(0x08);
          case 0x66:
            out.addByte(0x0C);
          case 0x0A:
          case 0x0D:
            break; // a line continuation
          default:
            if (e >= 0x30 && e <= 0x37) {
              var v = e - 0x30;
              for (var k = 0; k < 2 && i < data.length; k++) {
                final d = data[i];
                if (d < 0x30 || d > 0x37) break;
                v = v * 8 + d - 0x30;
                i++;
              }
              out.addByte(v & 0xFF);
            } else {
              out.addByte(e);
            }
        }
        continue;
      }
      if (c == 0x28) depth++;
      if (c == 0x29 && --depth == 0) return i + 1;
      out.addByte(c);
      i++;
    }
    return i;
  }

  static int _hexString(Uint8List data, int from, BytesBuilder out) {
    var i = from;
    final digits = StringBuffer();
    while (i < data.length && data[i] != 0x3E) {
      final ch = String.fromCharCode(data[i]);
      if (RegExp('[0-9A-Fa-f]').hasMatch(ch)) digits.write(ch);
      i++;
    }
    var hex = digits.toString();
    if (hex.length.isOdd) hex = '${hex}0';
    for (var k = 0; k < hex.length; k += 2) {
      out.addByte(int.parse(hex.substring(k, k + 2), radix: 16));
    }
    return i + 1;
  }
}
