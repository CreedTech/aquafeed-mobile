import 'dart:async';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../../../core/networking/dio_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

part 'formulation_repository.g.dart';

String _extractApiErrorMessage(
  Object error, {
  String fallback = 'Request failed',
}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String message = fallback;

    if (data is Map) {
      final body = Map<String, dynamic>.from(data);
      final directError = body['error']?.toString();
      final directMessage = body['message']?.toString();
      final details = body['details']?.toString();
      if (directMessage != null && directMessage.trim().isNotEmpty) {
        message = directMessage.trim();
      } else if (directError != null && directError.trim().isNotEmpty) {
        message = directError.trim();
      } else if (details != null && details.trim().isNotEmpty) {
        message = details.trim();
      }
    } else if (error.message != null && error.message!.trim().isNotEmpty) {
      message = error.message!.trim();
    }

    if (status != null) {
      return '$message (HTTP $status)';
    }
    return message;
  }

  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? fallback : text;
}

String? _extractStructuredText(
  dynamic value, {
  List<String> keys = const ['prompt', 'text', 'label', 'action', 'title', 'content'],
}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == '[object object]') {
      return null;
    }
    return trimmed;
  }
  if (value is num || value is bool) {
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
  if (value is Map) {
    for (final key in keys) {
      final candidate = _extractStructuredText(value[key], keys: keys);
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
  }
  return null;
}

List<String> _extractStructuredTextList(dynamic value) {
  if (value is! List) return const [];
  final seen = <String>{};
  final items = <String>[];
  for (final item in value) {
    final text = _extractStructuredText(item);
    if (text == null || text.isEmpty || !seen.add(text)) continue;
    items.add(text);
  }
  return items;
}

/// Exception thrown when payment is required for access
class PaymentRequiredException implements Exception {
  final String message;
  final double amount;

  PaymentRequiredException({required this.message, required this.amount});

  @override
  String toString() => message;
}

class ConstraintViolation {
  final String constraintId;
  final String type;
  final String? nutrient;
  final double current;
  final double required;
  final double gap;
  final String unit;
  final String message;

  ConstraintViolation({
    required this.constraintId,
    required this.type,
    this.nutrient,
    required this.current,
    required this.required,
    required this.gap,
    required this.unit,
    required this.message,
  });

  factory ConstraintViolation.fromJson(Map<String, dynamic> json) {
    return ConstraintViolation(
      constraintId: json['constraintId'] ?? '',
      type: json['type'] ?? '',
      nutrient: json['nutrient'],
      current: (json['current'] ?? 0).toDouble(),
      required: (json['required'] ?? 0).toDouble(),
      gap: (json['gap'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class RecommendedAction {
  final String actionType;
  final String label;
  final String description;
  final Map<String, dynamic> patch;
  final double estimatedCostDelta;
  final double estimatedComplianceDelta;
  final double confidence;

  RecommendedAction({
    required this.actionType,
    required this.label,
    required this.description,
    required this.patch,
    required this.estimatedCostDelta,
    required this.estimatedComplianceDelta,
    required this.confidence,
  });

  factory RecommendedAction.fromJson(Map<String, dynamic> json) {
    return RecommendedAction(
      actionType: json['actionType'] ?? '',
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      patch: Map<String, dynamic>.from(json['patch'] ?? {}),
      estimatedCostDelta: (json['estimatedCostDelta'] ?? 0).toDouble(),
      estimatedComplianceDelta: (json['estimatedComplianceDelta'] ?? 0)
          .toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class InfeasibleFormulationException implements Exception {
  final String message;
  final String suggestion;
  final List<ConstraintViolation> violations;
  final List<RecommendedAction> recommendedActions;

  InfeasibleFormulationException({
    required this.message,
    required this.suggestion,
    required this.violations,
    required this.recommendedActions,
  });

  @override
  String toString() => message;
}

class PreviewResult {
  final bool feasible;
  final FormulationResult? bestOption;
  final List<FormulationResult> options;
  final double? estimatedCostDelta;
  final double? estimatedComplianceDelta;

  PreviewResult({
    required this.feasible,
    this.bestOption,
    required this.options,
    this.estimatedCostDelta,
    this.estimatedComplianceDelta,
  });

  factory PreviewResult.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as List? ?? [];
    final parsedOptions = optionsJson
        .map((o) => FormulationResult.fromJson(Map<String, dynamic>.from(o)))
        .toList();
    final bestOptionJson = json['bestOption'];
    return PreviewResult(
      feasible: json['feasible'] ?? false,
      bestOption: bestOptionJson != null
          ? FormulationResult.fromJson(
              Map<String, dynamic>.from(bestOptionJson),
            )
          : null,
      options: parsedOptions,
      estimatedCostDelta: json['estimatedCostDelta']?.toDouble(),
      estimatedComplianceDelta: json['estimatedComplianceDelta']?.toDouble(),
    );
  }
}

class CalculationEquationRow {
  final String factId;
  final String label;
  final String equation;
  final double value;
  final String unit;

  CalculationEquationRow({
    required this.factId,
    required this.label,
    required this.equation,
    required this.value,
    required this.unit,
  });

  factory CalculationEquationRow.fromJson(Map<String, dynamic> json) {
    return CalculationEquationRow(
      factId: json['factId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      equation: json['equation']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }
}

class CalculationNutrientRow {
  final String nutrient;
  final String unit;
  final double? targetMin;
  final double? targetMax;
  final double actual;
  final double? deltaToMin;
  final double? deltaToMax;
  final String status;

  CalculationNutrientRow({
    required this.nutrient,
    required this.unit,
    this.targetMin,
    this.targetMax,
    required this.actual,
    this.deltaToMin,
    this.deltaToMax,
    required this.status,
  });

  factory CalculationNutrientRow.fromJson(Map<String, dynamic> json) {
    return CalculationNutrientRow(
      nutrient: json['nutrient']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      targetMin: (json['targetMin'] as num?)?.toDouble(),
      targetMax: (json['targetMax'] as num?)?.toDouble(),
      actual: (json['actual'] as num?)?.toDouble() ?? 0,
      deltaToMin: (json['deltaToMin'] as num?)?.toDouble(),
      deltaToMax: (json['deltaToMax'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'no_target',
    );
  }
}

class CalculationLedger {
  final String formulationId;
  final String batchName;
  final String feedType;
  final String? stageCode;
  final String? stageLabel;
  final String? strategy;
  final double targetWeightKg;
  final double qualityMatchPercentage;
  final String complianceColor;
  final List<CalculationEquationRow> equationRows;
  final List<CalculationNutrientRow> nutrientRows;

  CalculationLedger({
    required this.formulationId,
    required this.batchName,
    required this.feedType,
    this.stageCode,
    this.stageLabel,
    this.strategy,
    required this.targetWeightKg,
    required this.qualityMatchPercentage,
    required this.complianceColor,
    required this.equationRows,
    required this.nutrientRows,
  });

  factory CalculationLedger.fromJson(Map<String, dynamic> json) {
    final equationRows = (json['equationRows'] as List? ?? [])
        .whereType<Map>()
        .map(
          (row) =>
              CalculationEquationRow.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
    final nutrientRows = (json['nutrientRows'] as List? ?? [])
        .whereType<Map>()
        .map(
          (row) =>
              CalculationNutrientRow.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
    return CalculationLedger(
      formulationId: json['formulationId']?.toString() ?? '',
      batchName: json['batchName']?.toString() ?? '',
      feedType: json['feedType']?.toString() ?? '',
      stageCode: json['stageCode']?.toString(),
      stageLabel: json['stageLabel']?.toString(),
      strategy: json['strategy']?.toString(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 0,
      qualityMatchPercentage:
          (json['qualityMatchPercentage'] as num?)?.toDouble() ?? 0,
      complianceColor: json['complianceColor']?.toString() ?? '',
      equationRows: equationRows,
      nutrientRows: nutrientRows,
    );
  }
}

class AiNumericClaim {
  final String label;
  final double value;
  final String? unit;
  final String factId;

  AiNumericClaim({
    required this.label,
    required this.value,
    this.unit,
    required this.factId,
  });

  factory AiNumericClaim.fromJson(Map<String, dynamic> json) {
    return AiNumericClaim(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString(),
      factId: json['factId']?.toString() ?? '',
    );
  }
}

class AiAnalystResult {
  final String answer;
  final List<String> citations;
  final List<AiNumericClaim> numericClaims;
  final String verificationStatus; // passed | failed | not_applicable
  final String? fallbackMessage;
  final String policyStatus;
  final String? policyReason;
  final Map<String, dynamic>? redirectTarget;
  final String? groundingMode;
  final String? modelUsed;
  final double? estimatedCostUsd;
  final double? estimatedCostNgn;
  final String? pricingSource;

  AiAnalystResult({
    required this.answer,
    required this.citations,
    required this.numericClaims,
    required this.verificationStatus,
    this.fallbackMessage,
    this.policyStatus = 'allowed',
    this.policyReason,
    this.redirectTarget,
    this.groundingMode,
    this.modelUsed,
    this.estimatedCostUsd,
    this.estimatedCostNgn,
    this.pricingSource,
  });

  factory AiAnalystResult.fromJson(Map<String, dynamic> json) {
    final claims = (json['numericClaims'] as List? ?? [])
        .whereType<Map>()
        .map((item) => AiNumericClaim.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final citations = (json['citations'] as List? ?? [])
        .map((item) => item.toString())
        .toList();
    return AiAnalystResult(
      answer: json['answer']?.toString() ?? '',
      citations: citations,
      numericClaims: claims,
      verificationStatus: json['verificationStatus']?.toString() ?? 'failed',
      fallbackMessage: json['fallbackMessage']?.toString(),
      policyStatus: json['policyStatus']?.toString() ?? 'allowed',
      policyReason: json['policyReason']?.toString(),
      redirectTarget: json['redirectTarget'] is Map
          ? Map<String, dynamic>.from(json['redirectTarget'])
          : null,
      groundingMode: json['groundingMode']?.toString(),
      modelUsed: (json['meta'] as Map?)?['modelUsed']?.toString(),
      estimatedCostUsd: ((json['meta'] as Map?)?['estimatedCostUsd'] as num?)
          ?.toDouble(),
      estimatedCostNgn: ((json['meta'] as Map?)?['estimatedCostNgn'] as num?)
          ?.toDouble(),
      pricingSource: (json['meta'] as Map?)?['pricingSource']?.toString(),
    );
  }
}

class AiThread {
  final String id;
  final String title;
  final bool archived;
  final String? firstQuestion;
  final String? firstAnswer;
  final String? selectedModelId;
  final bool streamEnabled;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? formulationId;
  final String? feedType;
  final String? stageCode;

  AiThread({
    required this.id,
    required this.title,
    required this.archived,
    this.firstQuestion,
    this.firstAnswer,
    this.selectedModelId,
    this.streamEnabled = true,
    this.lastMessageAt,
    this.lastMessageText,
    this.formulationId,
    this.feedType,
    this.stageCode,
  });

  AiThread copyWith({
    String? title,
    bool? archived,
    String? firstQuestion,
    String? firstAnswer,
    String? selectedModelId,
    bool? streamEnabled,
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? formulationId,
    String? feedType,
    String? stageCode,
  }) => AiThread(
    id: id,
    title: title ?? this.title,
    archived: archived ?? this.archived,
    firstQuestion: firstQuestion ?? this.firstQuestion,
    firstAnswer: firstAnswer ?? this.firstAnswer,
    selectedModelId: selectedModelId ?? this.selectedModelId,
    streamEnabled: streamEnabled ?? this.streamEnabled,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastMessageText: lastMessageText ?? this.lastMessageText,
    formulationId: formulationId ?? this.formulationId,
    feedType: feedType ?? this.feedType,
    stageCode: stageCode ?? this.stageCode,
  );

  factory AiThread.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['lastMessage'] as Map<String, dynamic>?;
    final contextDefaults = json['contextDefaults'] as Map<String, dynamic>?;
    final firstQuestion = json['first_question']?.toString();
    final firstAnswer = json['first_answer']?.toString();
    final guideTitle = firstQuestion != null && firstQuestion.trim().isNotEmpty
        ? firstQuestion.trim()
        : null;
    return AiThread(
      id: json['id']?.toString() ?? json['uuid']?.toString() ?? '',
      title:
          guideTitle ?? json['title']?.toString() ?? 'Formulation Assistant',
      archived: json['archived'] == true || json['is_deleted'] == true,
      firstQuestion: firstQuestion,
      firstAnswer: firstAnswer,
      selectedModelId: json['selectedModelId']?.toString(),
      streamEnabled: json['streamEnabled'] != false,
      lastMessageAt: DateTime.tryParse(
        json['lastMessageAt']?.toString() ??
            json['updated_at']?.toString() ??
            '',
      ),
      lastMessageText: lastMessage?['text']?.toString(),
      formulationId: contextDefaults?['formulationId']?.toString(),
      feedType: contextDefaults?['feedType']?.toString(),
      stageCode: contextDefaults?['stageCode']?.toString(),
    );
  }
}

class AiSource {
  final String? type;
  final String? title;
  final String? reference;

  AiSource({this.type, this.title, this.reference});

  factory AiSource.fromJson(Map<String, dynamic> json) => AiSource(
    type: json['type']?.toString(),
    title: json['title']?.toString(),
    reference: json['reference']?.toString(),
  );
}

class AiResponseBlock {
  final String type;
  final String? title;
  final String? content;
  final List<Map<String, dynamic>> rows;

  AiResponseBlock({
    required this.type,
    this.title,
    this.content,
    required this.rows,
  });

  factory AiResponseBlock.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return AiResponseBlock(
      type: json['type']?.toString() ?? 'summary',
      title: _extractStructuredText(json['title']) ??
          _extractStructuredText(json['heading']),
      content: _extractStructuredText(json['content']) ??
          _extractStructuredText(json['text']),
      rows: rows,
    );
  }
}

class AiChatMessage {
  final String id;
  final String conversationId;
  final String role;
  final String text;
  final String? rawContent;
  final String? answerContent;
  final String? thoughtProcess;
  final String? answerMarkdown;
  final List<String> citations;
  final List<AiNumericClaim> numericClaims;
  final List<Map<String, dynamic>> toolTrace;
  final List<AiSource> sources;
  final List<AiResponseBlock> responseBlocks;
  final List<String> followUpPrompts;
  final double? confidence;
  final String? reasoningSummary;
  final String? requestId;
  final String? jobId;
  final String? modelId;
  final String? verificationStatus;
  final String? fallbackMessage;
  final String policyStatus;
  final String? policyReason;
  final Map<String, dynamic>? redirectTarget;
  final String? groundingMode;
  final Map<String, dynamic>? scenario;
  final DateTime? createdAt;

  AiChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    this.rawContent,
    this.answerContent,
    this.thoughtProcess,
    this.answerMarkdown,
    required this.citations,
    required this.numericClaims,
    required this.toolTrace,
    required this.sources,
    required this.responseBlocks,
    required this.followUpPrompts,
    this.confidence,
    this.reasoningSummary,
    this.requestId,
    this.jobId,
    this.modelId,
    this.verificationStatus,
    this.fallbackMessage,
    this.policyStatus = 'allowed',
    this.policyReason,
    this.redirectTarget,
    this.groundingMode,
    this.scenario,
    this.createdAt,
  });

  bool get isUser => role.toLowerCase() == 'user';

  AiChatMessage copyWith({
    String? text,
    String? rawContent,
    String? answerContent,
    String? thoughtProcess,
    String? answerMarkdown,
    List<String>? citations,
    List<AiNumericClaim>? numericClaims,
    List<Map<String, dynamic>>? toolTrace,
    List<AiSource>? sources,
    List<AiResponseBlock>? responseBlocks,
    List<String>? followUpPrompts,
    double? confidence,
    String? reasoningSummary,
    String? requestId,
    String? jobId,
    String? modelId,
    String? verificationStatus,
    String? fallbackMessage,
    String? policyStatus,
    String? policyReason,
    Map<String, dynamic>? redirectTarget,
    String? groundingMode,
    Map<String, dynamic>? scenario,
    DateTime? createdAt,
  }) {
    return AiChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      text: text ?? this.text,
      rawContent: rawContent ?? this.rawContent,
      answerContent: answerContent ?? this.answerContent,
      thoughtProcess: thoughtProcess ?? this.thoughtProcess,
      answerMarkdown: answerMarkdown ?? this.answerMarkdown,
      citations: citations ?? this.citations,
      numericClaims: numericClaims ?? this.numericClaims,
      toolTrace: toolTrace ?? this.toolTrace,
      sources: sources ?? this.sources,
      responseBlocks: responseBlocks ?? this.responseBlocks,
      followUpPrompts: followUpPrompts ?? this.followUpPrompts,
      confidence: confidence ?? this.confidence,
      reasoningSummary: reasoningSummary ?? this.reasoningSummary,
      requestId: requestId ?? this.requestId,
      jobId: jobId ?? this.jobId,
      modelId: modelId ?? this.modelId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      fallbackMessage: fallbackMessage ?? this.fallbackMessage,
      policyStatus: policyStatus ?? this.policyStatus,
      policyReason: policyReason ?? this.policyReason,
      redirectTarget: redirectTarget ?? this.redirectTarget,
      groundingMode: groundingMode ?? this.groundingMode,
      scenario: scenario ?? this.scenario,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final claims = (json['numericClaims'] as List? ?? [])
        .whereType<Map>()
        .map((item) => AiNumericClaim.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final sources = (json['sources'] as List? ?? [])
        .whereType<Map>()
        .map((item) => AiSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final responseBlocks = (json['responseBlocks'] as List? ?? [])
        .whereType<Map>()
        .map((item) => AiResponseBlock.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final citations = (json['citations'] as List? ?? [])
        .map((item) => item.toString())
        .toList();
    final toolTrace = (json['toolTrace'] as List? ??
            json['tool_trace'] as List? ??
            const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final followUps = _extractStructuredTextList(json['followUpPrompts']);
    final role = json['role']?.toString() ??
        ((json['type']?.toString().toUpperCase() == 'INPUT')
            ? 'user'
            : 'assistant');
    final text = json['text']?.toString() ??
        json['content']?.toString() ??
        json['answer_content']?.toString() ??
        '';
    return AiChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId:
          json['conversationId']?.toString() ??
          json['conversation_uuid']?.toString() ??
          '',
      role: role,
      text: text,
      rawContent: json['rawContent']?.toString() ?? json['content']?.toString(),
      answerContent: json['answerContent']?.toString() ??
          json['answer_content']?.toString(),
      thoughtProcess: json['thoughtProcess']?.toString() ??
          json['thought_process']?.toString(),
      answerMarkdown: json['answerMarkdown']?.toString() ??
          json['answer_content']?.toString(),
      citations: citations,
      numericClaims: claims,
      toolTrace: toolTrace,
      sources: sources,
      responseBlocks: responseBlocks,
      followUpPrompts: followUps,
      confidence: (json['confidence'] as num?)?.toDouble(),
      reasoningSummary: json['reasoningSummary']?.toString(),
      requestId: json['requestId']?.toString(),
      jobId: json['jobId']?.toString(),
      modelId: json['modelId']?.toString(),
      verificationStatus: json['verificationStatus']?.toString() ??
          json['verification_status']?.toString(),
      fallbackMessage: json['fallbackMessage']?.toString() ??
          json['fallback_message']?.toString(),
      policyStatus: json['policyStatus']?.toString() ??
          json['policy_status']?.toString() ??
          'allowed',
      policyReason: json['policyReason']?.toString() ??
          json['policy_reason']?.toString(),
      redirectTarget: json['redirectTarget'] is Map
          ? Map<String, dynamic>.from(json['redirectTarget'])
          : json['redirect_target'] is Map
          ? Map<String, dynamic>.from(json['redirect_target'])
          : null,
      groundingMode: json['groundingMode']?.toString() ??
          json['grounding_mode']?.toString(),
      scenario: json['scenario'] is Map
          ? Map<String, dynamic>.from(json['scenario'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class AiScenarioResult {
  final String scenarioType;
  final String title;
  final String summary;
  final double? totalCostDelta;
  final double? costPerKgDelta;
  final double? qualityMatchDelta;
  final String? complianceBefore;
  final String? complianceAfter;
  final List<String> violations;
  final List<String> recommendations;

  AiScenarioResult({
    required this.scenarioType,
    required this.title,
    required this.summary,
    this.totalCostDelta,
    this.costPerKgDelta,
    this.qualityMatchDelta,
    this.complianceBefore,
    this.complianceAfter,
    required this.violations,
    required this.recommendations,
  });

  factory AiScenarioResult.fromJson(Map<String, dynamic> json) {
    final deltas = json['deltas'] is Map<String, dynamic>
        ? json['deltas'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AiScenarioResult(
      scenarioType: json['scenarioType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      totalCostDelta: (deltas['totalCost'] as num?)?.toDouble(),
      costPerKgDelta: (deltas['costPerKg'] as num?)?.toDouble(),
      qualityMatchDelta: (deltas['qualityMatch'] as num?)?.toDouble(),
      complianceBefore: deltas['complianceBefore']?.toString(),
      complianceAfter: deltas['complianceAfter']?.toString(),
      violations: (json['violations'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      recommendations: (json['recommendations'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class AiModelOption {
  final String id;
  final String name;
  final bool isFree;
  final int? contextLength;

  AiModelOption({
    required this.id,
    required this.name,
    required this.isFree,
    this.contextLength,
  });

  factory AiModelOption.fromJson(Map<String, dynamic> json) => AiModelOption(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['id']?.toString() ?? '',
    isFree: json['isFree'] == true,
    contextLength: (json['contextLength'] as num?)?.toInt(),
  );
}

class AiModelCatalog {
  final String defaultModelId;
  final List<AiModelOption> models;

  AiModelCatalog({required this.defaultModelId, required this.models});
}

class AiJobStatusResult {
  final String id;
  final String status;
  final String requestId;
  final AiChatMessage? assistantMessage;
  final String? errorMessage;

  AiJobStatusResult({
    required this.id,
    required this.status,
    required this.requestId,
    this.assistantMessage,
    this.errorMessage,
  });
}

class AiStreamEvent {
  final String type;
  final Map<String, dynamic> payload;

  AiStreamEvent({required this.type, required this.payload});
}

/// Ingredient model
class Ingredient {
  final String id;
  final String name;
  final String category;
  final double defaultPrice;
  final String unit;
  final double? bagWeight;
  final Map<String, double> nutrients;

  Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultPrice,
    required this.unit,
    this.bagWeight,
    required this.nutrients,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'OTHER',
      defaultPrice: (json['defaultPrice'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'kg',
      bagWeight: json['bagWeight']?.toDouble(),
      nutrients: _parseNutrients(json['nutrients']),
    );
  }

  static Map<String, double> _parseNutrients(dynamic nutrientsData) {
    if (nutrientsData == null) return {};
    if (nutrientsData is! Map) return {};
    return Map<String, double>.from(
      nutrientsData.map((k, v) => MapEntry(k.toString(), (v ?? 0).toDouble())),
    );
  }
}

/// Feed Standard model
class FeedStandard {
  final String id;
  final String name;
  final String brand;
  final String stage;
  final String? stageCode;
  final String? ageGuidance;
  final String? pelletSize;
  final String feedCategory;
  final String? feedType;
  final String? fishSubtype;
  final String? poultryType;
  final int tolerance;

  FeedStandard({
    required this.id,
    required this.name,
    required this.brand,
    required this.stage,
    this.stageCode,
    this.ageGuidance,
    this.pelletSize,
    required this.feedCategory,
    this.feedType,
    this.fishSubtype,
    this.poultryType,
    required this.tolerance,
  });

  factory FeedStandard.fromJson(Map<String, dynamic> json) {
    return FeedStandard(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      stage: json['stage'] ?? '',
      stageCode: json['stageCode'],
      ageGuidance: json['ageGuidance'],
      pelletSize: json['pelletSize'],
      feedCategory:
          json['feedCategory'] ??
          ((json['feedType'] == 'poultry') ? 'Poultry' : 'Catfish'),
      feedType: json['feedType'],
      fishSubtype: json['fishSubtype'],
      poultryType: json['poultryType'],
      tolerance: json['tolerance'] ?? 2,
    );
  }
}

/// Feed Template model for Quick Mix
class FeedTemplate {
  final String id;
  final String name;
  final String description;
  final String feedCategory;
  final String? poultryType;
  final List<String> ingredientNames;

  FeedTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.feedCategory,
    this.poultryType,
    required this.ingredientNames,
  });

  factory FeedTemplate.fromJson(Map<String, dynamic> json) {
    return FeedTemplate(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      feedCategory: json['feedCategory'] ?? 'Catfish',
      poultryType: json['poultryType'],
      ingredientNames: List<String>.from(json['ingredientNames'] ?? []),
    );
  }
}

/// Formulation request
class FormulationRequest {
  final double targetWeightKg;
  final String standardId;
  final List<SelectedIngredient> selectedIngredients;
  final double overheadCost; // Milling, processing, transport
  final Map<String, Map<String, double>>? targetOverrides;

  FormulationRequest({
    required this.targetWeightKg,
    required this.standardId,
    required this.selectedIngredients,
    this.overheadCost = 0,
    this.targetOverrides,
  });

  Map<String, dynamic> toJson() => {
    'targetWeightKg': targetWeightKg,
    'standardId': standardId,
    'selectedIngredients': selectedIngredients.map((i) => i.toJson()).toList(),
    'overheadCost': overheadCost,
    if (targetOverrides != null) 'targetOverrides': targetOverrides,
  };
}

class SelectedIngredient {
  final String ingredientId;
  final double? customPrice;
  final double? minInclusionPct;
  final double? maxInclusionPct;
  final String? alternativeIngredientId;

  SelectedIngredient({
    required this.ingredientId,
    this.customPrice,
    this.minInclusionPct,
    this.maxInclusionPct,
    this.alternativeIngredientId,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    if (customPrice != null) 'customPrice': customPrice,
    if (minInclusionPct != null) 'minInclusionPct': minInclusionPct,
    if (maxInclusionPct != null) 'maxInclusionPct': maxInclusionPct,
    if (alternativeIngredientId != null)
      'alternativeIngredientId': alternativeIngredientId,
  };
}

/// Nutrient status for per-nutrient compliance display
class NutrientStatus {
  final String nutrient;
  final double actual;
  final double? targetMin;
  final double? targetMax;
  final double targetValue;
  final double deviationPercent;
  final String status; // 'Below', 'Within', 'Above'

  NutrientStatus({
    required this.nutrient,
    required this.actual,
    this.targetMin,
    this.targetMax,
    required this.targetValue,
    required this.deviationPercent,
    required this.status,
  });

  factory NutrientStatus.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    double? targetMin;
    double? targetMax;
    double targetValue;

    if (target is Map) {
      targetMin = (target['min'] ?? 0).toDouble();
      targetMax = (target['max'] ?? 0).toDouble();
      targetValue = ((targetMin ?? 0) + (targetMax ?? 0)) / 2;
    } else {
      targetValue = (target ?? 0).toDouble();
    }

    return NutrientStatus(
      nutrient: json['nutrient'] ?? '',
      actual: (json['actual'] ?? 0).toDouble(),
      targetMin: targetMin,
      targetMax: targetMax,
      targetValue: targetValue,
      deviationPercent: (json['deviationPercent'] ?? 0).toDouble(),
      status: json['status'] ?? 'Within',
    );
  }
}

/// Formulation result
class FormulationResult {
  final String? strategy; // LEAST_COST, BALANCED, PREMIUM
  final String? formulationId;
  final String complianceColor; // GREEN, YELLOW, RED
  final double qualityMatch;
  final double totalCost;
  final double costPerKg;
  final Map<String, double> actualNutrients;
  final List<NutrientStatus> nutrientStatuses; // Per-nutrient comparison
  final bool isUnlocked;
  final bool isDemo;
  final double? effectiveWeightKg;
  final List<IngredientUsed>? ingredientsUsed;

  FormulationResult({
    this.strategy,
    this.formulationId,
    required this.complianceColor,
    required this.qualityMatch,
    required this.totalCost,
    required this.costPerKg,
    required this.actualNutrients,
    required this.nutrientStatuses,
    required this.isUnlocked,
    this.isDemo = false,
    this.effectiveWeightKg,
    this.ingredientsUsed,
  });

  factory FormulationResult.fromJson(Map<String, dynamic> json) {
    return FormulationResult(
      strategy: json['strategy'],
      formulationId: json['formulationId'],
      complianceColor: json['complianceColor'] ?? 'YELLOW',
      qualityMatch: (json['qualityMatch'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      costPerKg: (json['costPerKg'] ?? 0).toDouble(),
      actualNutrients: Ingredient._parseNutrients(json['actualNutrients']),
      nutrientStatuses: json['nutrientStatuses'] != null
          ? (json['nutrientStatuses'] as List)
                .map((s) => NutrientStatus.fromJson(s))
                .toList()
          : [],
      isUnlocked: json['isUnlocked'] ?? false,
      isDemo: json['isDemo'] ?? false,
      effectiveWeightKg: json['effectiveWeightKg']?.toDouble(),
      ingredientsUsed: json['recipe'] != null
          ? (json['recipe'] as List)
                .map((i) => IngredientUsed.fromJson(i))
                .toList()
          : (json['ingredientsUsed'] != null
                ? (json['ingredientsUsed'] as List)
                      .map((i) => IngredientUsed.fromJson(i))
                      .toList()
                : null),
    );
  }
}

class IngredientUsed {
  final String name;
  final double qtyKg;
  final int bags;
  final double priceAtMoment;
  final bool isAutoCalculated; // True for Vitamin C (400mg/kg)

  IngredientUsed({
    required this.name,
    required this.qtyKg,
    required this.bags,
    required this.priceAtMoment,
    this.isAutoCalculated = false,
  });

  factory IngredientUsed.fromJson(Map<String, dynamic> json) {
    return IngredientUsed(
      name: json['name'] ?? '',
      qtyKg: (json['qtyKg'] ?? 0).toDouble(),
      bags: json['bags'] ?? 0,
      priceAtMoment: (json['priceAtMoment'] ?? 0).toDouble(),
      isAutoCalculated: json['isAutoCalculated'] ?? false,
    );
  }
}

/// Ingredients provider
@riverpod
Future<List<Ingredient>> ingredients(Ref ref) async {
  final dio = await ref.read(dioProvider.future);
  final response = await dio.get('/ingredients');
  final data = response.data['ingredients'] as List? ?? [];
  return data.map((i) => Ingredient.fromJson(i)).toList();
}

/// Feed standards provider
@riverpod
Future<List<FeedStandard>> feedStandards(Ref ref) async {
  final dio = await ref.read(dioProvider.future);
  final response = await dio.get('/standards');
  final data = response.data['standards'] as List? ?? [];
  return data.map((s) => FeedStandard.fromJson(s)).toList();
}

/// Feed templates provider
@riverpod
Future<List<FeedTemplate>> feedTemplates(Ref ref) async {
  final dio = await ref.read(dioProvider.future);
  final response = await dio.get('/templates');
  final data = response.data as List? ?? [];
  return data.map((t) => FeedTemplate.fromJson(t)).toList();
}

/// Formulation notifier for managing the formulation flow
@Riverpod(keepAlive: true)
class FormulationNotifier extends _$FormulationNotifier {
  FormulationRequest? _lastRequest;

  FormulationRequest? get lastRequest => _lastRequest;

  @override
  AsyncValue<List<FormulationResult>?> build() => const AsyncData(null);

  Future<void> calculate(FormulationRequest request) async {
    state = const AsyncLoading();
    _lastRequest = request;

    try {
      final dio = await ref.read(dioProvider.future);
      final response = await dio.post(
        '/formulations/calculate',
        data: request.toJson(),
      );

      if (response.data['status'] == 'infeasible') {
        final msg = response.data['message'] ?? 'Formulation infeasible';
        final suggestion = response.data['suggestion'] ?? '';
        final violationsJson = response.data['violations'] as List? ?? [];
        final actionsJson = response.data['recommendedActions'] as List? ?? [];
        throw InfeasibleFormulationException(
          message: msg,
          suggestion: suggestion,
          violations: violationsJson
              .map(
                (v) =>
                    ConstraintViolation.fromJson(Map<String, dynamic>.from(v)),
              )
              .toList(),
          recommendedActions: actionsJson
              .map(
                (a) => RecommendedAction.fromJson(Map<String, dynamic>.from(a)),
              )
              .toList(),
        );
      }

      final List<dynamic> optionsJson = response.data['options'] ?? [];
      final bool isDemo = response.data['isDemo'] ?? false;
      final double? effectiveWeightKg = response.data['effectiveWeightKg']
          ?.toDouble();

      final results = optionsJson.map((o) {
        final map = Map<String, dynamic>.from(o);
        map['isDemo'] = isDemo;
        map['effectiveWeightKg'] = effectiveWeightKg;
        map['formulationId'] = response.data['formulationId'];
        return FormulationResult.fromJson(map);
      }).toList();

      state = AsyncData(results);
    } on DioException catch (e, stack) {
      // Handle 403 - Payment Required
      if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        if (data is Map && data['requiresPayment'] == true) {
          state = AsyncError(
            PaymentRequiredException(
              message: data['message'] ?? 'Payment required',
              amount: (data['amount'] ?? 10000).toDouble(),
            ),
            stack,
          );
          return;
        }
      }

      // Handle other errors
      String errorMessage = e.toString();
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        errorMessage = data['message'];
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      state = AsyncError(errorMessage, stack);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<PreviewResult> previewFix({
    required FormulationRequest originalRequest,
    required RecommendedAction action,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final response = await dio.post(
      '/formulations/preview-fix',
      data: {
        'originalRequest': originalRequest.toJson(),
        'action': {'actionType': action.actionType, 'patch': action.patch},
      },
    );

    if (response.data['status'] == 'preview_infeasible' ||
        response.data['status'] == 'infeasible') {
      final msg = response.data['message'] ?? 'Still infeasible';
      final suggestion = response.data['suggestion'] ?? '';
      final violationsJson = response.data['violations'] as List? ?? [];
      final actionsJson = response.data['recommendedActions'] as List? ?? [];
      throw InfeasibleFormulationException(
        message: msg,
        suggestion: suggestion,
        violations: violationsJson
            .map(
              (v) => ConstraintViolation.fromJson(Map<String, dynamic>.from(v)),
            )
            .toList(),
        recommendedActions: actionsJson
            .map(
              (a) => RecommendedAction.fromJson(Map<String, dynamic>.from(a)),
            )
            .toList(),
      );
    }

    final previewJson = Map<String, dynamic>.from(
      response.data['preview'] ?? {},
    );
    return PreviewResult.fromJson(previewJson);
  }

  Future<FormulationResult?> unlock(
    String formulationId, {
    String? strategy,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final response = await dio.post(
      '/formulations/$formulationId/unlock',
      data: {
        if (strategy != null && strategy.trim().isNotEmpty)
          'strategy': strategy.trim(),
      },
    );
    final payload = response.data['formulation'] as Map<String, dynamic>? ?? {};
    final payloadStrategy = payload['strategy']?.toString();
    final normalizedStrategy = (payloadStrategy ?? strategy)
        ?.trim()
        .toUpperCase();

    final payloadIngredients = payload['recipe'] ?? payload['ingredientsUsed'];
    final parsedIngredients = payloadIngredients is List
        ? payloadIngredients
              .map((i) => IngredientUsed.fromJson(Map<String, dynamic>.from(i)))
              .toList()
        : null;

    FormulationResult? unlockedResult;
    final currentResults = state.value;
    if (currentResults != null) {
      FormulationResult mergeResult(FormulationResult r) {
        final merged = FormulationResult(
          strategy: payloadStrategy ?? r.strategy,
          formulationId:
              payload['formulationId']?.toString() ??
              payload['_id']?.toString() ??
              r.formulationId ??
              formulationId,
          complianceColor:
              payload['complianceColor']?.toString() ?? r.complianceColor,
          qualityMatch:
              (payload['qualityMatch'] as num?)?.toDouble() ?? r.qualityMatch,
          totalCost: (payload['totalCost'] as num?)?.toDouble() ?? r.totalCost,
          costPerKg: (payload['costPerKg'] as num?)?.toDouble() ?? r.costPerKg,
          actualNutrients: payload['actualNutrients'] is Map<String, dynamic>
              ? Ingredient._parseNutrients(payload['actualNutrients'])
              : r.actualNutrients,
          nutrientStatuses: r.nutrientStatuses,
          isUnlocked: true,
          isDemo: r.isDemo,
          effectiveWeightKg: r.effectiveWeightKg,
          ingredientsUsed: parsedIngredients ?? r.ingredientsUsed,
        );
        unlockedResult = merged;
        return merged;
      }

      bool didUpdate = false;
      var updatedResults = currentResults.map((r) {
        if (r.formulationId != formulationId) return r;
        final rowStrategy = r.strategy?.trim().toUpperCase();
        final strategyMatches =
            normalizedStrategy == null || normalizedStrategy.isEmpty
            ? true
            : (rowStrategy != null && rowStrategy == normalizedStrategy);
        if (!strategyMatches) return r;
        didUpdate = true;
        return mergeResult(r);
      }).toList();

      // Fallback for legacy data that may not include strategy tags per option.
      if (!didUpdate) {
        bool patchedFirst = false;
        updatedResults = updatedResults.map((r) {
          if (patchedFirst || r.formulationId != formulationId) return r;
          patchedFirst = true;
          return mergeResult(r);
        }).toList();
      }

      state = AsyncData(updatedResults);
    }

    unlockedResult ??= FormulationResult(
      strategy: payloadStrategy,
      formulationId:
          payload['formulationId']?.toString() ??
          payload['_id']?.toString() ??
          formulationId,
      complianceColor: payload['complianceColor']?.toString() ?? 'Blue',
      qualityMatch: (payload['qualityMatch'] as num?)?.toDouble() ?? 0,
      totalCost: (payload['totalCost'] as num?)?.toDouble() ?? 0,
      costPerKg: (payload['costPerKg'] as num?)?.toDouble() ?? 0,
      actualNutrients: payload['actualNutrients'] is Map<String, dynamic>
          ? Ingredient._parseNutrients(payload['actualNutrients'])
          : <String, double>{},
      nutrientStatuses: const <NutrientStatus>[],
      isUnlocked: true,
      ingredientsUsed: parsedIngredients,
    );

    ref.invalidate(dashboardRepositoryProvider);
    return unlockedResult;
  }

  Future<CalculationLedger> getCalculationLedger(String formulationId) async {
    final dio = await ref.read(dioProvider.future);
    final response = await dio.get(
      '/formulations/$formulationId/calculation-ledger',
    );
    final payload = response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
    return CalculationLedger.fromJson(payload);
  }

  Future<AiAnalystResult> askAnalyst({
    String? formulationId,
    required String question,
    bool whatIf = false,
    String? feedType,
    String? stageCode,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final path = whatIf
        ? '/ai/formulation-analyst/what-if'
        : '/ai/formulation-analyst/query';
    final payload = <String, dynamic>{'question': question.trim()};
    if (formulationId != null && formulationId.trim().isNotEmpty) {
      payload['formulationId'] = formulationId.trim();
    }
    if (feedType != null && feedType.trim().isNotEmpty) {
      payload['feedType'] = feedType.trim().toLowerCase();
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      payload['stageCode'] = stageCode.trim().toUpperCase();
    }
    final response = await dio.post(path, data: payload);
    final responsePayload = response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
    return AiAnalystResult.fromJson(responsePayload);
  }

  Future<AiThread> createAiThread({
    String? title,
    String? formulationId,
    String? feedType,
    String? stageCode,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final payload = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      payload['title'] = title.trim();
    }
    final contextDefaults = <String, dynamic>{};
    if (formulationId != null && formulationId.trim().isNotEmpty) {
      contextDefaults['formulationId'] = formulationId.trim();
    }
    if (feedType != null && feedType.trim().isNotEmpty) {
      contextDefaults['feedType'] = feedType.trim().toLowerCase();
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      contextDefaults['stageCode'] = stageCode.trim().toUpperCase();
    }
    if (contextDefaults.isNotEmpty) {
      payload['contextDefaults'] = contextDefaults;
    }
    try {
      final response = await dio.post(
        '/ai/formulation-analyst/threads',
        data: payload,
      );
      final threadJson = response.data['thread'] is Map
          ? Map<String, dynamic>.from(response.data['thread'])
          : <String, dynamic>{};
      return AiThread.fromJson(threadJson);
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(error, fallback: 'Unable to create AI chat'),
      );
    }
  }

  Future<AiModelCatalog> getAiModels() async {
    final dio = await ref.read(dioProvider.future);
    try {
      final response = await dio.get('/ai/formulation-analyst/models');
      final models = (response.data['models'] as List? ?? [])
          .whereType<Map>()
          .map((item) => AiModelOption.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final defaultModelId = response.data['defaultModelId']?.toString() ?? '';
      return AiModelCatalog(defaultModelId: defaultModelId, models: models);
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(error, fallback: 'Unable to load AI models'),
      );
    }
  }

  Future<List<AiThread>> getAiThreads() async {
    final dio = await ref.read(dioProvider.future);
    try {
      final response = await dio.get('/ai/conversations');
      return (response.data['data'] as List? ?? [])
          .whereType<Map>()
          .map((item) => AiThread.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      try {
        final fallback = await dio.get('/ai/formulation-analyst/threads');
        return (fallback.data['threads'] as List? ?? [])
            .whereType<Map>()
            .map((item) => AiThread.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        throw Exception(
          _extractApiErrorMessage(error, fallback: 'Unable to load AI chats'),
        );
      }
    }
  }

  Future<AiThread> updateAiThreadSettings({
    required String threadId,
    String? modelId,
    bool? streamEnabled,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final payload = <String, dynamic>{};
    if (modelId != null && modelId.trim().isNotEmpty) {
      payload['modelId'] = modelId.trim();
    }
    if (streamEnabled != null) {
      payload['streamEnabled'] = streamEnabled;
    }
    try {
      final response = await dio.patch(
        '/ai/formulation-analyst/threads/$threadId/settings',
        data: payload,
      );
      final threadJson = response.data['thread'] is Map
          ? Map<String, dynamic>.from(response.data['thread'])
          : <String, dynamic>{};
      return AiThread.fromJson(threadJson);
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(
          error,
          fallback: 'Unable to update AI thread settings',
        ),
      );
    }
  }

  Future<List<AiChatMessage>> getAiThreadMessages(String threadId) async {
    final dio = await ref.read(dioProvider.future);
    try {
      final response = await dio.get('/ai/conversations/$threadId');
      final data = response.data['data'] is Map
          ? Map<String, dynamic>.from(response.data['data'])
          : <String, dynamic>{};
      return (data['messages'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => AiChatMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (error) {
      try {
        final fallback = await dio.get(
          '/ai/formulation-analyst/threads/$threadId/messages',
        );
        return (fallback.data['messages'] as List? ?? [])
            .whereType<Map>()
            .map(
              (item) => AiChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } catch (_) {
        throw Exception(
          _extractApiErrorMessage(error, fallback: 'Unable to load messages'),
        );
      }
    }
  }

  Future<
    ({
      AiChatMessage assistantMessage,
      double? estimatedCostUsd,
      double? estimatedCostNgn,
      String? modelUsed,
    })
  >
  sendAiThreadMessage({
    required String threadId,
    required String message,
    String? formulationId,
    String? feedType,
    String? stageCode,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final payload = <String, dynamic>{'message': message.trim()};
    if (formulationId != null && formulationId.trim().isNotEmpty) {
      payload['formulationId'] = formulationId.trim();
    }
    if (feedType != null && feedType.trim().isNotEmpty) {
      payload['feedType'] = feedType.trim().toLowerCase();
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      payload['stageCode'] = stageCode.trim().toUpperCase();
    }
    try {
      final response = await dio.post(
        '/ai/formulation-analyst/threads/$threadId/messages',
        data: payload,
      );
      final assistantJson = response.data['assistantMessage'] is Map
          ? Map<String, dynamic>.from(response.data['assistantMessage'])
          : <String, dynamic>{};
      final meta = response.data['meta'] is Map
          ? Map<String, dynamic>.from(response.data['meta'])
          : <String, dynamic>{};
      return (
        assistantMessage: AiChatMessage.fromJson(assistantJson),
        estimatedCostUsd: (meta['estimatedCostUsd'] as num?)?.toDouble(),
        estimatedCostNgn: (meta['estimatedCostNgn'] as num?)?.toDouble(),
        modelUsed: meta['modelUsed']?.toString(),
      );
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(
          error,
          fallback: 'Unable to send analyst message',
        ),
      );
    }
  }

  Future<
    ({String jobId, String requestId, AiChatMessage? userMessage, AiThread? thread})
  >
  submitAiThreadMessage({
    required String threadId,
    required String message,
    String? formulationId,
    String? feedType,
    String? stageCode,
    String? modelId,
    bool? stream,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final payload = <String, dynamic>{'message': message.trim()};
    if (formulationId != null && formulationId.trim().isNotEmpty) {
      payload['formulationId'] = formulationId.trim();
    }
    if (feedType != null && feedType.trim().isNotEmpty) {
      payload['feedType'] = feedType.trim().toLowerCase();
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      payload['stageCode'] = stageCode.trim().toUpperCase();
    }
    if (modelId != null && modelId.trim().isNotEmpty) {
      payload['modelId'] = modelId.trim();
    }
    if (stream != null) {
      payload['stream'] = stream;
    }
    try {
      final response = await dio.post(
        '/ai/formulation-analyst/threads/$threadId/messages/submit',
        data: payload,
      );
      final job = response.data['job'] is Map
          ? Map<String, dynamic>.from(response.data['job'])
          : <String, dynamic>{};
      final userMessageJson = response.data['userMessage'] is Map
          ? Map<String, dynamic>.from(response.data['userMessage'])
          : null;
      final threadJson = response.data['thread'] is Map
          ? Map<String, dynamic>.from(response.data['thread'])
          : null;
      return (
        jobId: job['id']?.toString() ?? '',
        requestId: response.data['requestId']?.toString() ?? '',
        userMessage: userMessageJson != null
            ? AiChatMessage.fromJson(userMessageJson)
            : null,
        thread: threadJson != null ? AiThread.fromJson(threadJson) : null,
      );
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(
          error,
          fallback: 'Unable to submit analyst message',
        ),
      );
    }
  }

  Future<AiJobStatusResult> getAiJobStatus(String jobId) async {
    final dio = await ref.read(dioProvider.future);
    try {
      final response = await dio.get('/ai/formulation-analyst/jobs/$jobId');
      final jobJson = response.data['job'] is Map
          ? Map<String, dynamic>.from(response.data['job'])
          : <String, dynamic>{};
      final assistantMessageJson = response.data['assistantMessage'] is Map
          ? Map<String, dynamic>.from(response.data['assistantMessage'])
          : null;
      return AiJobStatusResult(
        id: jobJson['id']?.toString() ?? jobId,
        status: jobJson['status']?.toString() ?? 'queued',
        requestId: jobJson['requestId']?.toString() ?? '',
        assistantMessage: assistantMessageJson != null
            ? AiChatMessage.fromJson(assistantMessageJson)
            : null,
        errorMessage: jobJson['errorMessage']?.toString(),
      );
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(
          error,
          fallback: 'Unable to fetch AI job status',
        ),
      );
    }
  }

  Stream<AiStreamEvent> streamAiJob(String jobId) async* {
    final dio = await ref.read(dioProvider.future);
    final response = await dio.get(
      '/ai/formulation-analyst/jobs/$jobId/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final responseBody = response.data;
    if (responseBody is! ResponseBody) {
      throw Exception('Invalid stream response');
    }

    String eventType = 'message';
    final dataLines = <String>[];
    await for (final line in responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith(':')) {
        continue;
      }
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final dataText = dataLines.join('\n');
          Map<String, dynamic> payload = <String, dynamic>{};
          if (dataText.isNotEmpty) {
            try {
              final decoded = jsonDecode(dataText);
              if (decoded is Map<String, dynamic>) {
                payload = decoded;
              }
            } catch (_) {
              payload = {'raw': dataText};
            }
          }
          yield AiStreamEvent(type: eventType, payload: payload);
        }
        eventType = 'message';
        dataLines.clear();
        continue;
      }
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
  }

  Future<({AiChatMessage assistantMessage, AiScenarioResult scenario})>
  runAiScenario({
    required String threadId,
    required String scenarioType,
    String? formulationId,
    String? feedType,
    String? stageCode,
    Map<String, dynamic>? parameters,
  }) async {
    final dio = await ref.read(dioProvider.future);
    final payload = <String, dynamic>{
      'scenarioType': scenarioType,
      if (parameters != null) 'parameters': parameters,
    };
    if (formulationId != null && formulationId.trim().isNotEmpty) {
      payload['formulationId'] = formulationId.trim();
    }
    if (feedType != null && feedType.trim().isNotEmpty) {
      payload['feedType'] = feedType.trim().toLowerCase();
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      payload['stageCode'] = stageCode.trim().toUpperCase();
    }

    try {
      final response = await dio.post(
        '/ai/formulation-analyst/threads/$threadId/scenario',
        data: payload,
      );
      final assistantJson = response.data['assistantMessage'] is Map
          ? Map<String, dynamic>.from(response.data['assistantMessage'])
          : <String, dynamic>{};
      final scenarioJson = response.data['scenario'] is Map
          ? Map<String, dynamic>.from(response.data['scenario'])
          : <String, dynamic>{};
      return (
        assistantMessage: AiChatMessage.fromJson(assistantJson),
        scenario: AiScenarioResult.fromJson(scenarioJson),
      );
    } catch (error) {
      throw Exception(
        _extractApiErrorMessage(
          error,
          fallback: 'Unable to run analyst scenario',
        ),
      );
    }
  }

  Future<double> getUnlockFee() async {
    try {
      final dio = await ref.read(dioProvider.future);
      final response = await dio.get('/formulations/unlock-fee');
      return (response.data['formulationFee'] ?? 10000).toDouble();
    } catch (_) {
      return 10000;
    }
  }

  void usePreviewResult(PreviewResult preview) {
    if (preview.options.isEmpty) return;
    state = AsyncData(preview.options);
  }

  void reset() {
    _lastRequest = null;
    state = const AsyncData(null);
  }

  bool canCreateFormula() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;
    return user.canCreateFormula;
  }
}
