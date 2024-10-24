log({required String text, bool record = true, bool newLine = false}) {
  LogUtil.instance.addLog(text: text, record: record, newLine: newLine);
}

class LogUtil {
  static final LogUtil instance = LogUtil._();
  LogUtil._();

  List<String> logs = [];

  addLog({required String text, bool record = true, bool newLine = false}) {
    if (newLine) {
      print("\n");
      logs.add("-----------------------------------------------------------");
    }
    String newText = "far_${DateTime.now().millisecondsSinceEpoch}: $text";
    print(newText);
    if (record) {
      logs.add(newText);
    }
  }
}
