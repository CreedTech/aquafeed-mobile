import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../formulation/data/formulation_repository.dart';
import '../data/analyst_context.dart';

class AnalystTab extends ConsumerStatefulWidget {
  const AnalystTab({super.key});

  @override
  ConsumerState<AnalystTab> createState() => _AnalystTabState();
}

class _AnalystTabState extends ConsumerState<AnalystTab> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messagesController = ScrollController();

  List<AiThread> _threads = const [];
  List<AiChatMessage> _messages = const [];
  List<AiModelOption> _modelOptions = const [];
  String? _defaultModelId;

  String? _selectedThreadId;
  String? _selectedModelId;

  bool _loadingThreads = true;
  bool _loadingMessages = false;
  bool _loadingModels = true;
  bool _sending = false;
  bool _creatingThreadFromContext = false;
  String? _pageStatus;
  bool _pageStatusIsError = false;
  String? _lastAppliedContextIdentity;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
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
    });
  }

  void _setPageStatus(String? value, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _pageStatus = value?.trim().isEmpty == true ? null : value?.trim();
      _pageStatusIsError = isError;
    });
  }

  void _logAnalyst(String event, [Map<String, Object?> details = const {}]) {
    if (!kDebugMode) return;
    final suffix = details.isEmpty ? '' : ' $details';
    debugPrint('[Analyst][$event]$suffix');
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
    final exists = _threads.any((thread) => thread.id == updated.id);
    final updatedThreads = _threads.map((thread) {
      if (thread.id == updated.id) return updated;
      return thread;
    }).toList();
    setState(() {
      _threads = exists ? updatedThreads : [updated, ...updatedThreads];
      _selectedThreadId = updated.id;
      _selectedModelId = _pickModelId(updated.selectedModelId);
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

  String _summarizeAssistantText(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Formulation Assistant';
    final firstSentence =
        cleaned.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
    if (firstSentence.length <= 72) return firstSentence;
    return '${firstSentence.substring(0, 69)}...';
  }

  void _syncThreadPreview({
    required String threadId,
    required AiChatMessage assistant,
    AiThread? serverThread,
  }) {
    AiThread? existing;
    for (final thread in _threads) {
      if (thread.id == threadId) {
        existing = thread;
        break;
      }
    }
    final fallback = existing ??
        AiThread(
          id: threadId,
          title: 'Formulation Assistant',
          archived: false,
        );
    final preview =
        assistant.answerContent?.trim().isNotEmpty == true
            ? assistant.answerContent!.trim()
            : assistant.text.trim();
    final summary = _summarizeAssistantText(preview);
    final merged = (serverThread ?? fallback).copyWith(
      title: (serverThread?.title.trim().isNotEmpty == true &&
              serverThread!.title != 'Formulation Assistant')
          ? serverThread.title
          : (fallback.title == 'Formulation Assistant' ? summary : fallback.title),
      firstQuestion: fallback.firstQuestion ?? summary,
      firstAnswer: fallback.firstAnswer ?? preview,
      lastMessageAt: assistant.createdAt ?? DateTime.now(),
      lastMessageText: preview,
      selectedModelId: serverThread?.selectedModelId ?? _selectedModelId,
    );
    _upsertThread(merged);
  }

  void _handleRedirectTarget(Map<String, dynamic>? redirectTarget) {
    final targetType = redirectTarget?['type']?.toString() ?? 'none';
    if (targetType == 'unlock_formulation' || targetType == 'open_formulation') {
      context.push('/formulation');
      return;
    }
    _messageFocusNode.requestFocus();
  }

  AiChatMessage _buildLocalAssistantMessage({
    required String id,
    required String threadId,
    required String text,
  }) {
    return AiChatMessage(
      id: id,
      conversationId: threadId,
      role: 'assistant',
      text: text,
      rawContent: text,
      answerContent: text,
      thoughtProcess: null,
      answerMarkdown: text,
      citations: const [],
      numericClaims: const [],
      toolTrace: const [],
      sources: const [],
      responseBlocks: const [],
      followUpPrompts: const [],
      reasoningSummary: null,
      modelId: _selectedModelId,
      createdAt: DateTime.now(),
    );
  }

  String? _streamTextFromPayload(Map<String, dynamic> payload) {
    final value =
        payload['currentText'] ??
        payload['text'] ??
        payload['textDelta'] ??
        payload['raw'];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == '[object object]') {
        return null;
      }
      return value;
    }
    if (value is num || value is bool) {
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  Future<AiChatMessage> _pollJobUntilComplete(
    String jobId, {
    Duration timeout = const Duration(seconds: 90),
    Duration interval = const Duration(milliseconds: 900),
  }) async {
    final repo = ref.read(formulationProvider.notifier);
    final deadline = DateTime.now().add(timeout);
    var pollCount = 0;
    while (DateTime.now().isBefore(deadline)) {
      pollCount += 1;
      final status = await repo.getAiJobStatus(jobId);
      _logAnalyst('job.poll', {
        'jobId': jobId,
        'poll': pollCount,
        'status': status.status,
        'hasAssistantMessage': status.assistantMessage != null,
        'errorMessage': status.errorMessage,
      });
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
      await Future.delayed(interval);
    }
    throw Exception('AI response took too long. Please try again.');
  }

  Future<AiChatMessage> _streamJobUntilComplete({
    required String jobId,
    required String threadId,
    required String localAssistantId,
  }) async {
    final repo = ref.read(formulationProvider.notifier);
    var streamedAssistant = _buildLocalAssistantMessage(
      id: localAssistantId,
      threadId: threadId,
      text: '',
    );
    AiChatMessage? finalFromDone;

    try {
      await for (final event in repo
          .streamAiJob(jobId)
          .timeout(const Duration(seconds: 75))) {
        if (!mounted) {
          throw Exception('Analyst chat is no longer active.');
        }

        switch (event.type) {
          case 'thought_delta':
            final thoughtText = _streamTextFromPayload(event.payload);
            if (thoughtText == null) continue;
            streamedAssistant = streamedAssistant.copyWith(
              thoughtProcess: thoughtText,
            );
            _replaceMessageById(localAssistantId, streamedAssistant);
            _scrollToBottom();
            break;
          case 'answer_delta':
            final answerText = _streamTextFromPayload(event.payload);
            if (answerText == null) continue;
            streamedAssistant = streamedAssistant.copyWith(
              text: answerText,
              rawContent: answerText,
              answerContent: answerText,
              answerMarkdown: answerText,
            );
            _replaceMessageById(localAssistantId, streamedAssistant);
            _scrollToBottom();
            break;
          case 'done':
            if (event.payload['assistantMessage'] is Map) {
              final assistantJson = Map<String, dynamic>.from(
                event.payload['assistantMessage'] as Map,
              );
              finalFromDone = AiChatMessage.fromJson(assistantJson);
            }
            final status = await _pollJobUntilComplete(
              jobId,
              timeout: const Duration(seconds: 12),
              interval: const Duration(milliseconds: 300),
            );
            return status;
          case 'error':
            final message =
                event.payload['error']?.toString().trim().isNotEmpty == true
                ? event.payload['error']!.toString().trim()
                : 'AI request failed';
            throw Exception(message);
          default:
            break;
        }
      }

      if (finalFromDone != null) {
        return finalFromDone;
      }
    } catch (error) {
      final streamError = error.toString().replaceFirst('Exception: ', '').trim();
      _logAnalyst('stream.failed', {
        'jobId': jobId,
        'error': streamError.isEmpty ? error.toString() : streamError,
      });
    }

    return _pollJobUntilComplete(jobId);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    await _ensureActiveThread();
    final thread = _selectedThread();
    final threadId = thread?.id;
    if (threadId == null) return;

    _logAnalyst('send.start', {
      'threadId': threadId,
      'modelId': _selectedModelId,
      'feedType': thread?.feedType,
      'stageCode': thread?.stageCode,
      'hasFormulationId': thread?.formulationId != null,
      'message': message,
    });

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
        stream: true,
      );

      if (!mounted) return;
      if (submit.thread != null) {
        _upsertThread(submit.thread!);
      }
      _logAnalyst('send.accepted', {
        'threadId': threadId,
        'jobId': submit.jobId,
        'requestId': submit.requestId,
        'serverThreadReturned': submit.thread != null,
      });

      final assistant = await _streamJobUntilComplete(
        jobId: submit.jobId,
        threadId: threadId,
        localAssistantId: localAssistantId,
      );
      if (!mounted) return;
      _replaceMessageById(localAssistantId, assistant);
      _syncThreadPreview(
        threadId: threadId,
        assistant: assistant,
        serverThread: submit.thread,
      );
      _logAnalyst('send.completed', {
        'threadId': threadId,
        'jobId': assistant.jobId,
        'policyStatus': assistant.policyStatus,
        'verificationStatus': assistant.verificationStatus,
        'groundingMode': assistant.groundingMode,
        'answerPreview': (assistant.answerContent ?? assistant.text)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .substring(
              0,
              ((assistant.answerContent ?? assistant.text)
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim()
                          .length) >
                      180
                  ? 180
                  : (assistant.answerContent ?? assistant.text)
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim()
                      .length,
            ),
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _removeMessageById(localAssistantId);
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _logAnalyst('send.failed', {
        'threadId': threadId,
        'error': msg.isEmpty ? error.toString() : msg,
      });
      _setPageStatus(
        msg.isEmpty ? 'Unable to send message to analyst.' : msg,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
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
    _logAnalyst('model.update.start', {
      'threadId': threadId,
      'modelId': modelId,
    });
    try {
      final repo = ref.read(formulationProvider.notifier);
      final updated = await repo.updateAiThreadSettings(
        threadId: threadId,
        modelId: modelId,
      );
      if (!mounted) return;
      _upsertThread(updated);
      _logAnalyst('model.update.success', {
        'threadId': threadId,
        'modelId': updated.selectedModelId,
      });
      _setPageStatus('Model updated for this chat.');
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      _logAnalyst('model.update.failed', {
        'threadId': threadId,
        'modelId': modelId,
        'error': msg.isEmpty ? error.toString() : msg,
      });
      _setPageStatus(
        msg.isEmpty ? 'Unable to update model.' : msg,
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
                        'Ask about feed guidance, fish or poultry care, farm operations, or how to use AquaFeed.',
                        style: TextStyle(color: AppTheme.grey600, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: _messagesController,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _MessageBubble(
                          message: message,
                          onPromptTap: _onPromptTap,
                          onRedirectTap: _handleRedirectTarget,
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText:
                              'Ask about feed quality, farm decisions, or AquaFeed help...',
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
  final ValueChanged<Map<String, dynamic>?>? onRedirectTap;

  const _MessageBubble({
    required this.message,
    this.onPromptTap,
    this.onRedirectTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? AppTheme.primary : Colors.white;
    final textColor = isUser ? Colors.white : AppTheme.black;
    final thoughtText = _sanitizeThoughtText(
      (message.thoughtProcess ?? message.reasoningSummary)?.trim(),
    );
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
    final showVerificationChip = !isUser &&
        (message.groundingMode == 'system_verified' ||
            message.groundingMode == 'deterministic_formulation') &&
        (message.verificationStatus == 'passed' ||
            message.verificationStatus == 'failed');
    final visiblePrompts = !isUser
        ? message.followUpPrompts
              .map(_sanitizePromptText)
              .whereType<String>()
              .toList()
        : const <String>[];
    final visibleResponseBlocks = !isUser
        ? message.responseBlocks.where((block) {
            if (_isRedundantSummaryBlock(block, body)) return false;
            if (_isVerifiedNumbersBlock(block)) return false;
            return true;
          }).toList()
        : const <AiResponseBlock>[];

    if (!isUser &&
        body.trim().isEmpty &&
        visibleResponseBlocks.isEmpty &&
        visiblePrompts.isEmpty &&
        !shouldShowFallback) {
      return Align(
        alignment: alignment,
        child: const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _TypingBubble(),
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 332),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.policyStatus != 'allowed') ...[
              _PolicyNoticeCard(
                policyStatus: message.policyStatus,
                policyReason: message.policyReason,
                redirectTarget: message.redirectTarget,
                onRedirectTap: onRedirectTap,
              ),
              if (body.trim().isNotEmpty) const SizedBox(height: 10),
            ],
            if (body.trim().isNotEmpty)
              isUser
                  ? Text(
                      body,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    )
                  : _MiniMarkdownBody(text: body, color: textColor),
            if (!isUser && visibleResponseBlocks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...visibleResponseBlocks.take(3).map(
                (block) => _ResponseBlockCard(block: block),
              ),
            ],
            if (showVerificationChip) ...[
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
                    'Thought Process',
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
                      child: _MiniMarkdownBody(
                        text: thoughtText,
                        color: AppTheme.grey600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isUser && visiblePrompts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: visiblePrompts.take(3).map((prompt) {
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
                            decoration: canTap
                                ? TextDecoration.underline
                                : TextDecoration.none,
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  fallbackText,
                  style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _sanitizeThoughtText(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && line.toLowerCase() != '[object object]',
        )
        .join('\n')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String? _sanitizePromptText(String? value) {
    if (value == null) return null;
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == '[object object]') {
      return null;
    }
    return cleaned;
  }

  bool _isRedundantSummaryBlock(AiResponseBlock block, String body) {
    if (block.type != 'summary') return false;
    final blockTitle = block.title?.trim().toLowerCase() ?? '';
    final normalizedBlock = (block.content ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    final normalizedBody = body.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (blockTitle == 'assistant summary') return true;
    return normalizedBlock.isNotEmpty && normalizedBlock == normalizedBody;
  }

  bool _isVerifiedNumbersBlock(AiResponseBlock block) {
    final title = block.title?.trim().toLowerCase() ?? '';
    if (block.type == 'numbers_table' && title == 'verified numbers') {
      return true;
    }
    final rows = block.rows;
    if (rows.isEmpty) return false;
    return rows.every((row) {
      final keys = row.keys.map((key) => key.toLowerCase()).toSet();
      return keys.contains('metric') && keys.contains('value');
    }) && title.contains('verified');
  }
}

class _PolicyNoticeCard extends StatelessWidget {
  final String policyStatus;
  final String? policyReason;
  final Map<String, dynamic>? redirectTarget;
  final ValueChanged<Map<String, dynamic>?>? onRedirectTap;

  const _PolicyNoticeCard({
    required this.policyStatus,
    this.policyReason,
    this.redirectTarget,
    this.onRedirectTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBlocked = policyStatus == 'blocked';
    final title = isBlocked
        ? 'Exact Formulation Is Locked'
        : 'Supported Topics Only';
    final body = isBlocked
        ? 'Exact formulations, ingredient percentages, kg allocations, and costed mix outputs are only available in the paid formulation workflow.'
        : 'This assistant is for feed guidance, fish and poultry management, farm operations, and AquaFeed app help.';
    final buttonLabel = _buttonLabel();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isBlocked
            ? AppTheme.warning.withValues(alpha: 0.08)
            : AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked
              ? AppTheme.warning.withValues(alpha: 0.24)
              : AppTheme.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlocked ? Icons.lock_outline_rounded : Icons.info_outline,
                size: 16,
                color: isBlocked ? AppTheme.warning : AppTheme.grey600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isBlocked ? AppTheme.warning : AppTheme.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.grey600,
              height: 1.4,
            ),
          ),
          if (buttonLabel != null && onRedirectTap != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => onRedirectTap!(redirectTarget),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(buttonLabel),
            ),
          ],
        ],
        ),
    );
  }

  String? _buttonLabel() {
    final type = redirectTarget?['type']?.toString() ?? 'none';
    switch (type) {
      case 'unlock_formulation':
        return 'Open formulation';
      case 'open_formulation':
        return 'Go to formulation';
      case 'supported_topics':
        return 'Focus supported topics';
      default:
        return null;
    }
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
        color: AppTheme.grey100.withValues(alpha: 0.9),
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
            _MiniMarkdownBody(
              text: block.content!,
              color: AppTheme.grey600,
              fontSize: 11,
            ),
          ],
          if (block.rows.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...block.rows.take(6).map((row) {
              final entries = row.entries
                  .where((entry) => entry.key.toLowerCase() != 'factid')
                  .toList();
              if (entries.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.take(4).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.grey600,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: '${_humanizeKey(entry.key)}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.black,
                              ),
                            ),
                            TextSpan(text: '${entry.value}'),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _humanizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
  }
}

class _MiniMarkdownBody extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const _MiniMarkdownBody({
    required this.text,
    required this.color,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];
    var index = 0;

    while (index < lines.length) {
      final trimmed = lines[index].trimRight();
      final clean = trimmed.trim();

      if (clean.isEmpty) {
        if (children.isNotEmpty && children.last is! SizedBox) {
          children.add(const SizedBox(height: 8));
        }
        index += 1;
        continue;
      }

      if (_isTableLine(clean)) {
        final tableLines = <String>[];
        while (index < lines.length && _isTableLine(lines[index].trim())) {
          tableLines.add(lines[index].trim());
          index += 1;
        }
        children.add(_MarkdownTable(lines: tableLines));
        children.add(const SizedBox(height: 8));
        continue;
      }

      if (_isListLine(clean)) {
        final listLines = <String>[];
        while (index < lines.length && _isListLine(lines[index].trim())) {
          listLines.add(lines[index].trim());
          index += 1;
        }
        children.addAll(
          listLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _MarkdownListItem(
                line: line,
                color: color,
                fontSize: fontSize,
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 4));
        continue;
      }

      if (clean.startsWith('#')) {
        final level = clean.split('').takeWhile((char) => char == '#').length;
        final heading = clean.substring(level).trim();
        children.add(
          RichText(
            text: _inlineSpan(
              heading,
              TextStyle(
                color: AppTheme.black,
                fontSize: level <= 1
                    ? fontSize + 4
                    : level == 2
                    ? fontSize + 2
                    : fontSize + 1,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 6));
        index += 1;
        continue;
      }

      final paragraphLines = <String>[];
      while (index < lines.length) {
        final current = lines[index].trim();
        if (current.isEmpty ||
            _isTableLine(current) ||
            _isListLine(current) ||
            current.startsWith('#')) {
          break;
        }
        paragraphLines.add(current);
        index += 1;
      }
      final paragraph = paragraphLines.join(' ');
      children.add(
        RichText(
          text: _inlineSpan(
            paragraph,
            TextStyle(
              color: color,
              fontSize: fontSize,
              height: 1.45,
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
    }

    while (children.isNotEmpty && children.last is SizedBox) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  bool _isListLine(String line) {
    return line.startsWith('- ') ||
        line.startsWith('* ') ||
        RegExp(r'^\d+\.\s+').hasMatch(line);
  }

  bool _isTableLine(String line) {
    return line.startsWith('|') && line.endsWith('|') && line.contains('|');
  }

  InlineSpan _inlineSpan(String input, TextStyle baseStyle) {
    final pattern = RegExp(r'(\*\*.+?\*\*|`.+?`)');
    final matches = pattern.allMatches(input);
    if (matches.isEmpty) {
      return TextSpan(text: input, style: baseStyle);
    }

    final children = <InlineSpan>[];
    var last = 0;
    for (final match in matches) {
      if (match.start > last) {
        children.add(
          TextSpan(
            text: input.substring(last, match.start),
            style: baseStyle,
          ),
        );
      }
      final token = match.group(0) ?? '';
      if (token.startsWith('**')) {
        children.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        children.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppTheme.grey100,
            ),
          ),
        );
      }
      last = match.end;
    }
    if (last < input.length) {
      children.add(
        TextSpan(text: input.substring(last), style: baseStyle),
      );
    }
    return TextSpan(children: children, style: baseStyle);
  }
}

class _MarkdownListItem extends StatelessWidget {
  final String line;
  final Color color;
  final double fontSize;

  const _MarkdownListItem({
    required this.line,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(line);
    final prefix = match != null
        ? '${match.group(1)} '
        : (line.startsWith('* ') ? '• ' : '• ');
    final body = match != null ? (match.group(2) ?? '') : line.substring(2).trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                height: 1.45,
              ),
              children: [_inlineTextSpan(body, color, fontSize)],
            ),
          ),
        ),
      ],
    );
  }

  InlineSpan _inlineTextSpan(String input, Color color, double fontSize) {
    final pattern = RegExp(r'(\*\*.+?\*\*|`.+?`)');
    final matches = pattern.allMatches(input);
    final baseStyle = TextStyle(color: color, fontSize: fontSize, height: 1.45);
    if (matches.isEmpty) {
      return TextSpan(text: input, style: baseStyle);
    }

    final children = <InlineSpan>[];
    var last = 0;
    for (final match in matches) {
      if (match.start > last) {
        children.add(TextSpan(text: input.substring(last, match.start), style: baseStyle));
      }
      final token = match.group(0) ?? '';
      if (token.startsWith('**')) {
        children.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        children.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppTheme.grey100,
            ),
          ),
        );
      }
      last = match.end;
    }
    if (last < input.length) {
      children.add(TextSpan(text: input.substring(last), style: baseStyle));
    }
    return TextSpan(children: children, style: baseStyle);
  }
}

class _MarkdownTable extends StatelessWidget {
  final List<String> lines;

  const _MarkdownTable({required this.lines});

  @override
  Widget build(BuildContext context) {
    final parsedRows = lines
        .map(
          (line) => line
              .split('|')
              .map((cell) => cell.trim())
              .where((cell) => cell.isNotEmpty)
              .toList(),
        )
        .where((row) => row.isNotEmpty)
        .toList();
    if (parsedRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasSeparator = parsedRows.length > 1 &&
        parsedRows[1].every((cell) => RegExp(r'^:?-{2,}:?$').hasMatch(cell));
    final header = parsedRows.first;
    final rows = hasSeparator ? parsedRows.skip(2).toList() : parsedRows.skip(1).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        children: [
          _MarkdownTableRow(cells: header, isHeader: true),
          ...rows.map((row) => _MarkdownTableRow(cells: row)),
        ],
      ),
    );
  }
}

class _MarkdownTableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;

  const _MarkdownTableRow({
    required this.cells,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? Colors.white : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.grey200,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells.map((cell) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(
                cell,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                  color: isHeader ? AppTheme.black : AppTheme.grey600,
                ),
              ),
            ),
          );
        }).toList(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: const SizedBox(
        width: 40,
        child: LinearProgressIndicator(minHeight: 3),
      ),
    );
  }
}
