import 'package:llama_dart/llama_dart.dart';

void main() {
  final awesome = Awesome();
  final systemInfo = awesome.getSystemInfo();
  print('systemInfo: $systemInfo');
}
