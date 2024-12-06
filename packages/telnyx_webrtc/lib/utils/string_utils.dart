import 'dart:math';

int randomBetween(int from, int to) {
  if (from > to) throw Exception('$from cannot be > $to');
  final rand = Random();
  return ((to - from) * rand.nextDouble()).toInt() + from;
}

String randomString(int length, {int from = 33, int to = 126}) {
  return String.fromCharCodes(
    List.generate(length, (index) => randomBetween(from, to)),
  );
}

String randomNumeric(int length) => randomString(length, from: 48, to: 57);
