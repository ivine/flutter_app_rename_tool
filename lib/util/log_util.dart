log(String text, {bool record = true, bool newLine = false}) {
  LogUtil.instance.addLog(text, record: record, newLine: newLine);
}

logSkipping(String text) {
  LogUtil.instance.addLog("$text, skipping...", record: false);
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
    String newText = "${DateTime.now().millisecondsSinceEpoch}, flutter_app_rename_tool: $text";
    print(newText);
    if (record) {
      logs.add(newText);
    }
  }
}
