import 'dart:io';

// 需要所有字段有 //tag n 注释方便定位-多行编辑生成
// 可以自动生成这个tag,懒得弄了
final fieldRegex = RegExp(
  r'^\s*(\w+(?:<[^>]+>)?)\s+(\w+)\s*=\s*[^;]+;\s*//\s*tag\s*(\d+)',
);
final classRegex = RegExp(r'class\s+(\w+)\s+extends\s+TarsStruct');

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tars_codegen.dart <file.dart>');
    exit(1);
  }

  final file = File(args[0]);
  final lines = file.readAsLinesSync();

  final fields = <Field>[];
  for (final line in lines) {
    final m = classRegex.firstMatch(line);
    if (m != null) {
      className = m.group(1);
      break;
    }
  }
  if (className == null) {
    throw Exception('No class extends TarsStruct found');
  }
  for (final line in lines) {
    final match = fieldRegex.firstMatch(line);
    if (match != null) {
      fields.add(Field(
        type: match.group(1)!,
        name: match.group(2)!,
        tag: int.parse(match.group(3)!),
      ));
    }
  }

  fields.sort((a, b) => a.tag.compareTo(b.tag));

  print(generate(fields));
}

String generate(List<Field> fields) {
  final sb = StringBuffer();

  // readFrom
  sb.writeln('@override');
  sb.writeln('void readFrom(TarsInputStream _is) {');
  for (final f in fields) {
    sb.writeln(
      '  ${padRight(f.name, 20)} = _is.read(${f.name}, ${f.tag}, false);',
    );
  }
  sb.writeln('}\n');

  // writeTo
  sb.writeln('@override');
  sb.writeln('void writeTo(TarsOutputStream _os) {');
  for (final f in fields) {
    sb.writeln('  _os.write(${f.name}, ${f.tag});');
  }
  sb.writeln('}\n');

  // deepCopy
  sb.writeln('@override');
  sb.writeln('TarsStruct deepCopy() {');
  sb.writeln('  return $className()');
  for (final f in fields) {
    sb.writeln('    ..${f.name} = ${f.name}');
  }
  sb.writeln('  ;');
  sb.writeln('}\n');

  // display
  sb.writeln('@override');
  sb.writeln('displayAsString(StringBuffer sb, int level) {');
  sb.writeln('  TarsDisplayer _ds = TarsDisplayer(sb, level: level);');

  for (final f in fields) {
    sb.writeln(
      '  _ds.${displayMethod(f.type)}(${f.name}, "${f.name}");',
    );
  }
  sb.writeln('}');

  return sb.toString();
}

String displayMethod(String type) {
  if (type.startsWith('List')) return 'DisplayList';
  if (type.startsWith('Map')) return 'DisplayMap';
  if (type == 'String') return 'DisplayString';
  if (type == 'int') return 'DisplayInt';
  return 'DisplayTarsStruct';
}

String padRight(String s, int width) => s + ' ' * (width - s.length);

late String? className;

class Field {
  final String type;
  final String name;
  final int tag;

  Field({
    required this.type,
    required this.name,
    required this.tag,
  });
}
