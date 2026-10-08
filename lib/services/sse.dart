import 'dart:convert';

class ApiEvent {
  final String type;
  final Map<String, dynamic> data;
  ApiEvent(this.type, this.data);
}

/// Native clients can connect directly. The upstream currently emits Python
/// literals in SSE data; accept only the JSON-compatible literal subset.
Map<String, dynamic> decodeEventData(String text) {
  if (text.length > 1024 * 1024) throw const FormatException('事件过大');
  dynamic value;
  try {
    value = jsonDecode(text);
  } on FormatException {
    value = _LiteralReader(text).parse();
  }
  if (value is! Map) throw const FormatException('事件必须是对象');
  return Map<String, dynamic>.from(value);
}

Stream<ApiEvent> decodeSse(Stream<List<int>> bytes) async* {
  var event = '', data = <String>[], size = 0;
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    size += line.length;
    if (size > 1024 * 1024) throw const FormatException('事件过大');
    if (line.isEmpty) {
      if (data.isNotEmpty &&
          ['citations', 'delta', 'done', 'error'].contains(event)) {
        yield ApiEvent(event, decodeEventData(data.join('\n')));
      }
      event = '';
      data = [];
      size = 0;
    } else if (!line.startsWith(':')) {
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') event = value;
      if (field == 'data') data.add(value);
    }
  }
  // Never flush a trailing unframed event as a completed response.
}

class _LiteralReader {
  final String text;
  int pos = 0, depth = 0;
  _LiteralReader(this.text);
  Never fail() => throw const FormatException('不支持的事件格式');
  void space() {
    while (pos < text.length && ' \n\r\t'.contains(text[pos])) {
      pos++;
    }
  }

  bool take(String token) {
    space();
    if (text.startsWith(token, pos)) {
      pos += token.length;
      return true;
    }
    return false;
  }

  dynamic parse() {
    final value = read();
    space();
    if (pos != text.length) fail();
    return value;
  }

  dynamic read() {
    if (++depth > 64) fail();
    try {
      space();
      if (pos >= text.length) fail();
      if (text[pos] == '"' || text[pos] == "'") return string();
      if (take('{')) {
        final map = <String, dynamic>{};
        if (take('}')) return map;
        while (true) {
          space();
          if (pos >= text.length || !['"', "'"].contains(text[pos])) fail();
          final key = string();
          if (!take(':')) fail();
          map[key] = read();
          if (take('}')) return map;
          if (!take(',')) fail();
          if (take('}')) return map;
        }
      }
      if (take('[')) {
        final list = <dynamic>[];
        if (take(']')) return list;
        while (true) {
          list.add(read());
          if (take(']')) return list;
          if (!take(',')) fail();
          if (take(']')) return list;
        }
      }
      if (take('None') || take('null')) return null;
      if (take('True') || take('true')) return true;
      if (take('False') || take('false')) return false;
      final match = RegExp(
        r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?',
      ).matchAsPrefix(text, pos);
      if (match == null) fail();
      pos = match.end;
      final number = num.parse(match.group(0)!);
      if (!number.isFinite) fail();
      return number;
    } finally {
      depth--;
    }
  }

  String string() {
    final quote = text[pos++], out = StringBuffer();
    while (pos < text.length) {
      final c = text[pos++];
      if (c == quote) return out.toString();
      if (c != r'\') {
        if (c.codeUnitAt(0) < 32) fail();
        out.write(c);
        continue;
      }
      if (pos >= text.length) fail();
      final escaped = text[pos++];
      const basic = {
        'n': '\n',
        'r': '\r',
        't': '\t',
        'b': '\b',
        'f': '\f',
        'v': '\u000b',
        'a': '\u0007',
        "'": "'",
        '"': '"',
        r'\': r'\',
        '/': '/',
      };
      if (basic.containsKey(escaped)) {
        out.write(basic[escaped]);
        continue;
      }
      final count = switch (escaped) {
        'x' => 2,
        'u' => 4,
        'U' => 8,
        _ => 0,
      };
      if (count == 0 || pos + count > text.length) fail();
      final code = int.tryParse(text.substring(pos, pos + count), radix: 16);
      if (code == null || code > 0x10ffff) fail();
      pos += count;
      out.writeCharCode(code);
    }
    fail();
  }
}
