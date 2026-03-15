import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../formulation/data/formulation_repository.dart';
import '../data/analyst_context.dart';

class AnalystTab extends ConsumerStatefulWidget {
  const AnalystTab({super.key});

  @override
  ConsumerState<AnalystTab> createState() => _AnalystTabState();
}

class _ScenarioPreset {
  final String label;
  final String scenarioType;
  final Map<String, dynamic>? parameters;

  const _ScenarioPreset({
    required this.label,
    required this.scenarioType,
    this.parameters,
  });
}

class _AnalystTabState extends ConsumerState<AnalystTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesController = ScrollController();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 2,
  );

  List<AiThread> _threads = const [];
  List<AiChatMessage> _messages = const [];
  List<AiModelOption> _modelOptions = const [];
  String? _defaultModelId;

  String? _selectedThreadId;
  String? _selectedModelId;
  bool _streamEnabled = true;

  bool _loadingThreads = true;
  bool _loadingMessages = false;
  bool _loadingModels = true;
  bool _sending = false;
  bool _runningScenario = false;
  bool _showQuickScenarios = false;
  bool _creatingThreadFromContext = false;
  String? _pageStatus;
  bool _pageStatusIsError = false;
  String? _lastAppliedContextIdentity;

  final List<_ScenarioPreset> _presets = const [
    _ScenarioPreset(
      label: 'If maize price +10%',
      scenarioType: 'maize_price_increase',
      parameters: {'priceIncreasePct': 10},
    ),
    _ScenarioPreset(
      label: 'If protein target +1%',
      scenarioType: 'protein_target_increase',
      parameters: {'deltaPct': 1},
    ),
    _ScenarioPreset(
      label: 'If sorghum max = 15%',
      scenarioType: 'sorghum_max',
      parameters: {'maxPct': 15},
    ),
    _ScenarioPreset(
      label: 'Try alternatives',
      scenarioType: 'try_alternatives_expensive',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadModels(), _loadThreads()]);
    if (!mounted) return;
    final pending = ref.read(analystContextProvider);
    if (pending != null) {
      await _handleIncomingContext(pending);
    }
  }

  AiThread? _selectedThread() {
    final selected = _selectedThreadId;
    if (selected == null) return null;
    for (final thread in _threads) {
      if (thread.id == selected) return thread;
    }
    return null;
  }

  bool _modelExists(String? modelId) {
    if (modelId == null || modelId.trim().isEmpty) return false;
    return _modelOptions.any((model) => model.id == modelId);
  }

  String? _pickModelId(String? preferred) {
    if (preferred != null && preferred.trim().isNotEmpty) {
      if (_modelOptions.isEmpty || _modelExists(preferred)) return preferred;
    }
    if (_defaultModelId != null && _modelExists(_defaultModelId)) {
      return _defaultModelId;
    }
    if (_modelOptions.isNotEmpty) {
      return _modelOptions.first.id;
    }
    return preferred;
  }

  void _applySelectedThreadRuntime(AiThread? thread) {
    final nextModelId = _pickModelId(thread?.selectedModelId ?? _selectedModelId);
    setState(() {
      _selectedModelId = nextModelId;
      _streamEnabled = thread?.streamEnabled ?? true;
    });
  }

  void _setPageStatus(String? value, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _pageStatus = value?.trim().isEmpty == true ? null : value?.trim();
      _pageStatusIsError = isError;
    });
  }

  Future<void> _loadModels() async {
    if (!mounted) return;
    setState(() {
      _loadingModels = true;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final catalog = await repo.getAiModels();
      if (!mounted) return;
      final currentThread = _selectedThread();
      setState(() {
        _modelOptions = catalog.models;
        _defaultModelId = catalog.defaultModelId;
        _selectedModelId = _pickModelId(
          currentThread?.selectedModelId ?? _selectedModelId ?? catalog.defaultModelId,
        );
      });
    } catch (_) {
      if (!mounted) return;
      _setPageStatus('Unable to load AI model options.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingModels = false;
        });
      }
    }
  }

  Future<void> _loadThreads({bool preserveSelection = true}) async {
    if (!mounted) return;
    setState(() {
      _loadingThreads = true;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final threads = await repo.getAiThreads();
      String? nextSelected;
      if (preserveSelection &&
          _selectedThreadId != null &&
          threads.any((thread) => thread.id == _selectedThreadId)) {
        nextSelected = _selectedThreadId;
      } else if (threads.isNotEmpty) {
        nextSelected = threads.first.id;
      }

      AiThread? selectedThread;
      if (nextSelected != null) {
        for (final thread in threads) {
          if (thread.id == nextSelected) {
            selectedThread = thread;
            break;
          }
        }
      }

      setState(() {
        _threads = threads;
        _selectedThreadId = nextSelected;
        _selectedModelId = _pickModelId(
          selectedThread?.selectedModelId ?? _selectedModelId,
        );
        _streamEnabled = selectedThread?.streamEnabled ?? true;
      });

      if (nextSelected != null) {
        await _loadMessages(nextSelected);
      } else {
        setState(() {
          _messages = const [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      _setPageStatus('Unable to load analyst chats.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingThreads = false;
        });
      }
    }
  }

  Future<void> _loadMessages(String threadId) async {
    if (!mounted) return;
    setState(() {
      _loadingMessages = true;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final messages = await repo.getAiThreadMessages(threadId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _setPageStatus('Unable to load chat messages.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingMessages = false;
        });
      }
    }
  }

  void _upsertThread(AiThread updated) {
    final updatedThreads = _threads.map((thread) {
      if (thread.id == updated.id) return updated;
      return thread;
    }).toList();
    setState(() {
      _threads = updatedThreads;
      _selectedThreadId = updated.id;
      _selectedModelId = _pickModelId(updated.selectedModelId);
      _streamEnabled = updated.streamEnabled;
    });
  }

  Future<String?> _createThread({
    String? title,
    AnalystContext? contextDefaults,
  }) async {
    try {
      final repo = ref.read(formulationProvider.notifier);
      final thread = await repo.createAiThread(
        title: title,
        formulationId: contextDefaults?.formulationId,
        feedType: contextDefaults?.feedType,
        stageCode: contextDefaults?.stageCode,
      );
      if (!mounted) return null;
      setState(() {
        _threads = [thread, ..._threads];
        _selectedThreadId = thread.id;
        _messages = const [];
        _selectedModelId = _pickModelId(thread.selectedModelId);
        _streamEnabled = thread.streamEnabled;
      });
      return thread.id;
    } catch (_) {
      if (!mounted) return null;
      _setPageStatus('Unable to create a new chat.', isError: true);
      return null;
    }
  }

  Future<void> _handleIncomingContext(AnalystContext contextDefaults) async {
    if (!mounted) return;
    if (_creatingThreadFromContext) return;
    final identity = contextDefaults.identity;
    if (identity == _lastAppliedContextIdentity) return;
    _creatingThreadFromContext = true;
    _lastAppliedContextIdentity = identity;

    final threadId = await _createThread(
      title: 'Ask About This Mix',
      contextDefaults: contextDefaults,
    );
    if (threadId != null) {
      await _loadMessages(threadId);
      _setPageStatus('Mix context attached to this chat.');
    }
    if (!mounted) {
      _creatingThreadFromContext = false;
      return;
    }
    ref.read(analystContextProvider.notifier).clear();
    _creatingThreadFromContext = false;
  }

  Future<void> _ensureActiveThread() async {
    if (_selectedThreadId != null) return;
    final threadId = await _createThread(title: 'Formulation Assistant');
    if (threadId != null) {
      await _loadMessages(threadId);
    }
  }

  void _replaceMessageById(String id, AiChatMessage updated) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    final next = List<AiChatMessage>.from(_messages);
    next[index] = updated;
    setState(() {
      _messages = next;
    });
  }

  void _removeMessageById(String id) {
    setState(() {
      _messages = _messages.where((message) => message.id != id).toList();
    });
  }

  List<AiSource> _parseSources(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => AiSource.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  AiChatMessage _buildLocalAssistantMessage({
    required String id,
    required String threadId,
    required String text,
    List<AiSource>? sources,
    List<Map<String, dynamic>>? toolTrace,
    String? reasoningSummary,
  }) {
    return AiChatMessage(
      id: id,
      conversationId: threadId,
      role: 'assistant',
      text: text,
      rawContent: text,
      answerContent: text,
      thoughtProcess: reasoningSummary,
      answerMarkdown: text,
      citations: const [],
      numericClaims: const [],
      toolTrace: toolTrace ?? const [],
      sources: sources ?? const [],
      responseBlocks: const [],
      followUpPrompts: const [],
      reasoningSummary: reasoningSummary,
      modelId: _selectedModelId,
      createdAt: DateTime.now(),
    );
  }

  void _showAiCostFromMeta(dynamic rawMeta) {}

  Future<AiChatMessage?> _consumeJobStream({
    required String jobId,
    required String localAssistantId,
    required String threadId,
  }) async {
    final repo = ref.read(formulationProvider.notifier);
    var currentText = '';
    var currentReasoning = '';
    var currentSources = <AiSource>[];
    var currentToolTrace = <Map<String, dynamic>>[];
    var receivedAnswerDelta = false;

    try {
      await for (final event in repo.streamAiJob(jobId)) {
        if (!mounted) return null;
        switch (event.type) {
          case 'delta':
            if (receivedAnswerDelta) {
              break;
            }
            final nextText = event.payload['currentText']?.toString();
            final delta = event.payload['textDelta']?.toString() ?? '';
            if (nextText != null && nextText.trim().isNotEmpty) {
              currentText = nextText;
            } else if (delta.trim().isNotEmpty) {
              currentText = currentText.isEmpty ? delta.trim() : '$currentText ${delta.trim()}';
            }
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary: currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            _scrollToBottom();
            break;
          case 'answer_delta':
            receivedAnswerDelta = true;
            final nextText = event.payload['currentText']?.toString();
            final delta = event.payload['textDelta']?.toString() ?? '';
            if (nextText != null && nextText.trim().isNotEmpty) {
              currentText = nextText;
            } else if (delta.trim().isNotEmpty) {
              currentText = currentText.isEmpty ? delta.trim() : '$currentText ${delta.trim()}';
            }
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary: currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            _scrollToBottom();
            break;
          case 'thought_delta':
            final nextThought = event.payload['currentText']?.toString();
            final delta = event.payload['textDelta']?.toString() ?? '';
            if (nextThought != null && nextThought.trim().isNotEmpty) {
              currentReasoning = nextThought;
            } else if (delta.trim().isNotEmpty) {
              currentReasoning = currentReasoning.isEmpty
                  ? delta.trim()
                  : '$currentReasoning ${delta.trim()}';
            }
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary:
                    currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            break;
          case 'sources':
            currentSources = _parseSources(event.payload['sources']);
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary: currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            break;
          case 'tool_trace':
            final trace = event.payload['toolTrace'] as List?;
            currentToolTrace = (trace ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary: currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            break;
          case 'reasoning_summary':
            currentReasoning =
                event.payload['reasoningSummary']?.toString().trim() ?? '';
            _replaceMessageById(
              localAssistantId,
              _buildLocalAssistantMessage(
                id: localAssistantId,
                threadId: threadId,
                text: currentText,
                sources: currentSources,
                toolTrace: currentToolTrace,
                reasoningSummary:
                    currentReasoning.isEmpty ? null : currentReasoning,
              ),
            );
            break;
          case 'done':
            final rawAssistant = event.payload['assistantMessage'];
            _showAiCostFromMeta(event.payload['meta']);
            if (rawAssistant is Map) {
              final assistant = AiChatMessage.fromJson(
                Map<String, dynamic>.from(rawAssistant),
              );
              _replaceMessageById(localAssistantId, assistant);
              _scrollToBottom();
              return assistant;
            }
            final fallback = _buildLocalAssistantMessage(
              id: localAssistantId,
              threadId: threadId,
              text: currentText,
              sources: currentSources,
              toolTrace: currentToolTrace,
              reasoningSummary:
                  currentReasoning.isEmpty ? null : currentReasoning,
            );
            _replaceMessageById(localAssistantId, fallback);
            _scrollToBottom();
            return fallback;
          case 'error':
            return null;
          default:
            break;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AiChatMessage> _pollJobUntilComplete(String jobId) async {
    final repo = ref.read(formulationProvider.notifier);
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      final status = await repo.getAiJobStatus(jobId);
      if (status.status == 'completed') {
        final message = status.assistantMessage;
        if (message != null) return message;
        throw Exception('AI completed with no response body');
      }
      if (status.status == 'failed') {
        throw Exception(status.errorMessage ?? 'AI request failed');
      }
      if (status.status == 'cancelled') {
        throw Exception('AI request cancelled');
      }
      await Future.delayed(const Duration(milliseconds: 900));
    }
    throw Exception('AI response took too long. Please try again.');
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    await _ensureActiveThread();
    final thread = _selectedThread();
    final threadId = thread?.id;
    if (threadId == null) return;

    final localUserMessage = AiChatMessage(
      id: 'local-user-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: threadId,
      role: 'user',
      text: message,
      rawContent: message,
      answerContent: message,
      thoughtProcess: null,
      citations: const [],
      numericClaims: const [],
      toolTrace: const [],
      sources: const [],
      responseBlocks: const [],
      followUpPrompts: const [],
      createdAt: DateTime.now(),
    );

    final localAssistantId =
        'local-assistant-${DateTime.now().millisecondsSinceEpoch}';
    final localAssistant = _buildLocalAssistantMessage(
      id: localAssistantId,
      threadId: threadId,
      text: '',
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, localUserMessage, localAssistant];
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final repo = ref.read(formulationProvider.notifier);
      final submit = await repo.submitAiThreadMessage(
        threadId: threadId,
        message: message,
        formulationId: thread?.formulationId,
        feedType: thread?.feedType,
        stageCode: thread?.stageCode,
        modelId: _selectedModelId,
        stream: _streamEnabled,
      );

      if (!mounted) return;
      if (submit.thread != null) {
        _upsertThread(submit.thread!);
      }

      AiChatMessage? assistant;
      if (_streamEnabled) {
        assistant = await _consumeJobStream(
          jobId: submit.jobId,
          localAssistantId: localAssistantId,
          threadId: threadId,
        );
      }

      if (assistant == null) {
        final polledAssistant = await _pollJobUntilComplete(submit.jobId);
        if (!mounted) return;
        _replaceMessageById(localAssistantId, polledAssistant);
      }

      await _loadThreads();
    } catch (error) {
      if (!mounted) return;
      _removeMessageById(localAssistantId);
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _setPageStatus(
        msg.isEmpty ? 'Unable to send message to analyst.' : msg,
        isError: true,
      );
      await _loadThreads();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _runScenario(_ScenarioPreset preset) async {
    if (_runningScenario) return;
    await _ensureActiveThread();
    final thread = _selectedThread();
    final threadId = thread?.id;
    if (threadId == null) return;

    setState(() {
      _runningScenario = true;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final scenarioResult = await repo.runAiScenario(
        threadId: threadId,
        scenarioType: preset.scenarioType,
        formulationId: thread?.formulationId,
        feedType: thread?.feedType,
        stageCode: thread?.stageCode,
        parameters: preset.parameters,
      );
      if (!mounted) return;
      await _loadThreads();
      if (!mounted) return;
      final delta = scenarioResult.scenario.costPerKgDelta;
      final deltaText = delta == null ? '' : ' Δ/kg: ${_currency.format(delta)}';
      _setPageStatus('${scenarioResult.scenario.title}$deltaText');
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _setPageStatus(
        msg.isEmpty ? 'Unable to run this scenario.' : msg,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _runningScenario = false;
        });
      }
    }
  }

  Future<void> _updateThreadModel(String modelId) async {
    final threadId = _selectedThreadId;
    if (threadId == null || _sending) return;
    setState(() {
      _selectedModelId = modelId;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final updated = await repo.updateAiThreadSettings(
        threadId: threadId,
        modelId: modelId,
      );
      if (!mounted) return;
      _upsertThread(updated);
      _setPageStatus('Model updated for this chat.');
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _setPageStatus(
        msg.isEmpty ? 'Unable to update model.' : msg,
        isError: true,
      );
      _applySelectedThreadRuntime(_selectedThread());
    }
  }

  Future<void> _updateStreamToggle(bool enabled) async {
    final threadId = _selectedThreadId;
    if (threadId == null || _sending) return;
    setState(() {
      _streamEnabled = enabled;
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final updated = await repo.updateAiThreadSettings(
        threadId: threadId,
        streamEnabled: enabled,
      );
      if (!mounted) return;
      _upsertThread(updated);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _setPageStatus(
        msg.isEmpty ? 'Unable to update stream setting.' : msg,
        isError: true,
      );
      _applySelectedThreadRuntime(_selectedThread());
    }
  }

  void _onPromptTap(String prompt) {
    _messageController.text = prompt;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesController.hasClients) return;
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  String _prettyModelName(AiModelOption model) {
    final base = model.name.trim().isEmpty ? model.id : model.name;
    return model.isFree ? '$base (Free)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final pendingContext = ref.watch(analystContextProvider);
    if (pendingContext != null &&
        pendingContext.identity != _lastAppliedContextIdentity &&
        !_creatingThreadFromContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleIncomingContext(pendingContext);
      });
    }

    final selectedThread = _selectedThread();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Senior Analyst',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.black,
                        ),
                      ),
                      Text(
                        'Ask anything about feed mixes, farms, and costs.',
                        style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final threadId = await _createThread(title: 'New chat');
                    if (threadId != null) {
                      await _loadMessages(threadId);
                    }
                  },
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: _loadingThreads
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      final selected = thread.id == _selectedThreadId;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          thread.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onSelected: (_) async {
                          setState(() {
                            _selectedThreadId = thread.id;
                          });
                          _applySelectedThreadRuntime(thread);
                          await _loadMessages(thread.id);
                        },
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: _threads.length,
                  ),
          ),
          if (selectedThread != null &&
              (selectedThread.feedType != null ||
                  selectedThread.stageCode != null ||
                  selectedThread.formulationId != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (selectedThread.feedType != null)
                    _contextChip('Feed: ${selectedThread.feedType}'),
                  if (selectedThread.stageCode != null)
                    _contextChip('Stage: ${selectedThread.stageCode}'),
                  if (selectedThread.formulationId != null)
                    _contextChip('Mix attached'),
                ],
              ),
            ),
          if (selectedThread != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.grey200),
                      ),
                      child: _loadingModels
                          ? const SizedBox(
                              height: 42,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _modelExists(_selectedModelId)
                                    ? _selectedModelId
                                    : null,
                                hint: const Text('Select model'),
                                icon: const Icon(Icons.expand_more_rounded),
                                items: _modelOptions
                                    .map(
                                      (model) => DropdownMenuItem<String>(
                                        value: model.id,
                                        child: Text(
                                          _prettyModelName(model),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (_sending || _modelOptions.isEmpty)
                                    ? null
                                    : (value) {
                                        if (value == null ||
                                            value == _selectedModelId) {
                                          return;
                                        }
                                        _updateThreadModel(value);
                                      },
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Stream',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Switch.adaptive(
                          value: _streamEnabled,
                          onChanged: _sending ? null : _updateStreamToggle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_pageStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _pageStatus!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _pageStatusIsError ? AppTheme.warning : AppTheme.grey600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: _loadingMessages
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start by asking a formulation or farm question.',
                        style: TextStyle(color: AppTheme.grey600, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: _messagesController,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: _TypingBubble(),
                            ),
                          );
                        }
                        final message = _messages[index];
                        return _MessageBubble(
                          message: message,
                          onPromptTap: _onPromptTap,
                        );
                      },
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.grey200)),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _showQuickScenarios = !_showQuickScenarios;
                    }),
                    icon: Icon(
                      _showQuickScenarios
                          ? Icons.expand_less
                          : Icons.auto_graph_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _showQuickScenarios
                          ? 'Hide quick scenarios'
                          : 'Show quick scenarios',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
                if (_showQuickScenarios) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final preset = _presets[index];
                        return ActionChip(
                          onPressed: _runningScenario
                              ? null
                              : () => _runScenario(preset),
                          label: Text(
                            preset.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          avatar: const Icon(Icons.auto_graph, size: 16),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText:
                              'Ask about feed quality, farm decisions, or mix cost...',
                          filled: true,
                          fillColor: AppTheme.grey100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.grey600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;
  final ValueChanged<String>? onPromptTap;

  const _MessageBubble({required this.message, this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? AppTheme.primary : AppTheme.grey100;
    final textColor = isUser ? Colors.white : AppTheme.black;
    final thoughtText = (message.thoughtProcess ?? message.reasoningSummary)?.trim();
    final body = !isUser &&
            message.answerContent != null &&
            message.answerContent!.trim().isNotEmpty
        ? message.answerContent!.trim()
        : !isUser &&
              message.answerMarkdown != null &&
              message.answerMarkdown!.trim().isNotEmpty
        ? message.answerMarkdown!.trim()
        : message.text;
    final fallbackText = message.fallbackMessage?.trim();
    final shouldShowFallback = !isUser &&
        fallbackText != null &&
        fallbackText.isNotEmpty &&
        fallbackText != body.trim();

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 332),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.45),
            ),
            if (!isUser && message.responseBlocks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.responseBlocks.take(3).map(
                (block) => _ResponseBlockCard(block: block),
              ),
            ],
            if (!isUser && message.verificationStatus != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: message.verificationStatus == 'passed'
                      ? AppTheme.success.withValues(alpha: 0.14)
                      : AppTheme.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  message.verificationStatus == 'passed'
                      ? 'Verified Numbers'
                      : 'Safe Fallback',
                  style: TextStyle(
                    fontSize: 10,
                    color: message.verificationStatus == 'passed'
                        ? AppTheme.success
                        : AppTheme.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (!isUser && thoughtText != null && thoughtText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Reasoning Summary',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppTheme.grey600,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        thoughtText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isUser && message.toolTrace.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Diagnostics',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppTheme.grey600,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: message.toolTrace.take(8).map((entry) {
                          final name = entry['name']?.toString() ?? 'tool';
                          final status = entry['status']?.toString() ?? '';
                          final type = entry['type']?.toString() ?? '';
                          final detail = [type, name, status]
                              .where((part) => part.trim().isNotEmpty)
                              .join(' • ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $detail',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey600,
                                height: 1.4,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isUser && message.numericClaims.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.numericClaims.take(5).map(
                (claim) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${claim.label}: ${_formatClaimValue(claim.value)}${claim.unit == null ? '' : ' ${claim.unit}'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                ),
              ),
            ],
            if (!isUser && message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.sources.take(3).map((source) {
                final title = source.title?.trim().isNotEmpty == true
                    ? source.title!.trim()
                    : (source.reference ?? source.type ?? 'Source');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $title',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                );
              }),
            ],
            if (!isUser && message.followUpPrompts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: message.followUpPrompts.take(3).map((prompt) {
                  final canTap = onPromptTap != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: canTap ? () => onPromptTap!(prompt) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $prompt',
                          style: TextStyle(
                            fontSize: 11,
                            color: canTap ? AppTheme.primary : AppTheme.grey600,
                            decoration: canTap ? TextDecoration.underline : TextDecoration.none,
                            decorationColor: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (shouldShowFallback) ...[
              const SizedBox(height: 6),
              Text(
                fallbackText,
                style: const TextStyle(fontSize: 11, color: AppTheme.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatClaimValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    if (value.abs() >= 1000) {
      return value.toStringAsFixed(2);
    }
    return value.toStringAsFixed(3);
  }
}

class _ResponseBlockCard extends StatelessWidget {
  final AiResponseBlock block;

  const _ResponseBlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null && block.title!.trim().isNotEmpty)
            Text(
              block.title!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
          if (block.content != null && block.content!.trim().isNotEmpty) ...[
            if (block.title != null && block.title!.trim().isNotEmpty)
              const SizedBox(height: 4),
            Text(
              block.content!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey600,
                height: 1.4,
              ),
            ),
          ],
          if (block.rows.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...block.rows.take(6).map((row) {
              final entries = row.entries.toList();
              if (entries.isEmpty) return const SizedBox.shrink();
              final first = entries.first;
              final second = entries.length > 1 ? entries[1] : null;
              final left = '${first.key}: ${first.value}';
              final right = second == null ? '' : '${second.key}: ${second.value}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  right.isEmpty ? left : '$left • $right',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey600,
                    height: 1.35,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const SizedBox(
        width: 40,
        child: LinearProgressIndicator(minHeight: 3),
      ),
    );
  }
}
