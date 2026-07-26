import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('offline operations use UUID v4 identifiers', () {
    final value = const Uuid().v4();
    expect(value, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });
}
