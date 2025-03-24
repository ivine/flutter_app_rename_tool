log(String text, {bool record = true, bool newLine = false}) {
  LogUtil.instance.addLog(text, record: record, newLine: newLine);
}

class LogUtil {
  static final LogUtil instance = LogUtil._();
  LogUtil._();

  List<String> logs = [];

  addLog(String text, {bool record = true, bool newLine = false}) {
    if (newLine) {
      print("\n");
      logs.add("-----------------------------------------------------------");
    }
    String newText = "flutter_app_rename_tool_${DateTime.now().millisecondsSinceEpoch}: $text";
    print(newText);
    if (record) {
      logs.add(newText);
    }
  }
}
