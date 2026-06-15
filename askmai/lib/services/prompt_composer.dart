import '../models/exports.dart';

class PromptComposer {
  String compose({
    String? originalQuestion,
    required List<TabResponse> responses,
  }) {
    final buf = StringBuffer();

    if (originalQuestion != null && originalQuestion.trim().isNotEmpty) {
      buf.writeln('【原问题】');
      buf.writeln(originalQuestion.trim());
      buf.writeln();
    }

    for (final r in responses) {
      buf.writeln('【${r.aiName} 的回答】');
      buf.writeln(r.text.trim());
      buf.writeln();
    }

    buf.writeln('请综合分析以上回答的异同与优劣，给出最终建议。');
    return buf.toString();
  }
}
