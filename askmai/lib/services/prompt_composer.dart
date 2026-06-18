import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../models/exports.dart';
import 'preferences_service.dart';

class PromptComposer {
  static String defaultPromptTemplate = '''{if_question}【原问题】
{question}

{endif}{each_response}【{ai_name} 的回答】
{response_text}

{endeach}请综合分析以上回答的异同与优劣，给出最终建议。''';

  final PreferencesService _prefsService;

  PromptComposer(this._prefsService);

  /// 异步加载 assets 中的默认模版配置
  Future<void> loadDefaultTemplates() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/prompt_template.json');
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (decoded.containsKey('promptTemplate')) {
        defaultPromptTemplate = decoded['promptTemplate'] as String;
      }
      developer.log('Successfully loaded default prompt templates from assets.', name: 'PromptComposer');
    } catch (e) {
      developer.log('Failed to load default prompt templates from assets, using hardcoded fallback.', name: 'PromptComposer', error: e);
    }
  }

  String compose({
    String? originalQuestion,
    required List<TabResponse> responses,
  }) {
    final promptTemplate = _prefsService.getPromptTemplate() ?? defaultPromptTemplate;

    // 1. 替换原问题（支持 {if_question}...{endif} 条件渲染）
    String result = promptTemplate;
    final hasQuestion = originalQuestion != null && originalQuestion.trim().isNotEmpty;
    if (hasQuestion) {
      result = result.replaceAll('{if_question}', '').replaceAll('{endif}', '');
      result = result.replaceAll('{question}', originalQuestion.trim());
    } else {
      result = result.replaceAll(RegExp(r'\{if_question\}[\s\S]*?\{endif\}'), '');
    }

    // 2. 解析循环块 {each_response}...{endeach} 并循环渲染 AI 回答
    final loopRegex = RegExp(r'\{each_response\}([\s\S]*?)\{endeach\}');
    final match = loopRegex.firstMatch(result);
    if (match != null) {
      final itemTemplate = match.group(1) ?? '';
      
      final formattedList = responses.map((r) {
        return itemTemplate
            .replaceAll('{ai_name}', r.aiName)
            .replaceAll('{response_text}', r.text.trim());
      }).join(''); // 直接拼接，循环体内的换行由用户模板内定义
      
      result = result.replaceFirst(loopRegex, formattedList);
    } else {
      // 容错处理：如果用户删除了循环标记，我们直接按默认格式追加在末尾
      const fallbackItemTemplate = '【{ai_name} 的回答】\n{response_text}\n\n';
      final formattedList = responses.map((r) {
        return fallbackItemTemplate
            .replaceAll('{ai_name}', r.aiName)
            .replaceAll('{response_text}', r.text.trim());
      }).join('');
      result = '$result\n\n$formattedList';
    }

    return result;
  }
}
