import 'dart:convert';

import '../data/models.dart';

/// 撤销/重做：整份配方快照。配方只有几百字节，快照比命令模式简单可靠得多。
/// 滑杆一次拖动只提交一步（在 onChangeEnd 时提交），不会刷爆栈。
class History {
  History([this.limit = 30]);

  final int limit;
  final List<String> _stack = <String>[];
  int index = -1;

  void reset(Recipe snapshot) {
    _stack
      ..clear()
      ..add(jsonEncode(snapshot.toJson()));
    index = 0;
  }

  bool commit(Recipe snapshot) {
    final s = jsonEncode(snapshot.toJson());
    if (index >= 0 && index < _stack.length && _stack[index] == s) return false;
    if (index + 1 < _stack.length) {
      _stack.removeRange(index + 1, _stack.length);
    }
    _stack.add(s);
    if (_stack.length > limit) _stack.removeAt(0);
    index = _stack.length - 1;
    return true;
  }

  bool get canUndo => index > 0;
  bool get canRedo => index < _stack.length - 1;

  Recipe? undo() {
    if (!canUndo) return null;
    index--;
    return _decode(_stack[index]);
  }

  Recipe? redo() {
    if (!canRedo) return null;
    index++;
    return _decode(_stack[index]);
  }

  Recipe? _decode(String s) {
    final map = jsonDecode(s);
    if (map is Map) return Recipe.fromJson(map.cast<String, dynamic>());
    return null;
  }
}
