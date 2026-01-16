import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import 'chat_bubble.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Dependencies
  final _deviceRepo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;

  // Gemini
  GenerativeModel? _model;
  // TODO: PASTE YOUR API KEY HERE IF NOT USING --dart-define
  static const String _hardcodedApiKey = 'AIzaSyC-0jwnfePHV_QtYL5MlXjlbSB9nMAAguY'; 
  
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _modelName = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static const List<String> _fallbackModels = <String>[
    // If you use Google AI Studio, pick the exact model id shown there and pass it via:
    // --dart-define=GEMINI_MODEL=...
    // These are common ids; availability depends on your key/project.
    'gemini-3-flash-preview',
    'gemini-3.0-flash-preview',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash-latest',
    'gemini-2.5-pro-latest',
    'gemini-2.0-flash',
    'gemini-2.0-pro',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro-latest',
  ];

  static const List<String> _quickPrompts = <String>[
    'What needs repair?',
    'Find power drill',
    'Show all power tools',
  ];

  @override
  void initState() {
    super.initState();
    final effectiveKey = _apiKey.trim().isNotEmpty ? _apiKey : _hardcodedApiKey;
    
    if (effectiveKey.trim().isNotEmpty) {
      _model = GenerativeModel(model: _modelName, apiKey: effectiveKey);
    }

    // Add initial greeting
    _messages.add(
      _ChatMessage(
        isUser: false,
        text: '',
        content: _buildAssistantReplyCards(
          'Hello! I\'m your YetNew Assistant. I can help you find items or manage your household inventory.',
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  String _stripMarkdownDecorations(String s) {
    var out = s;
    out = out.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^\)]+)\)'),
      (m) => m.group(1) ?? '',
    );
    out = out.replaceAll('**', '');
    out = out.replaceAll('__', '');
    out = out.replaceAll('`', '');
    return out;
  }

  ({String title, List<String> items}) _parseAssistantText(String raw) {
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return (title: 'Assistant', items: const <String>[]);

    final lines = text.split('\n');
    var idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) {
      idx++;
    }
    var title = 'Assistant';
    final items = <String>[];

    String firstNonEmptyLine = idx < lines.length ? lines[idx].trim() : '';
    if (firstNonEmptyLine.startsWith('#')) {
      title = firstNonEmptyLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
      idx++;
    } else if (firstNonEmptyLine.endsWith(':') &&
        firstNonEmptyLine.length <= 48) {
      title = firstNonEmptyLine
          .substring(0, firstNonEmptyLine.length - 1)
          .trim();
      idx++;
    }
    if (title.trim().isEmpty) title = 'Assistant';

    bool inCodeBlock = false;
    final buffer = StringBuffer();

    void flushBuffer() {
      final chunk = buffer.toString().trim();
      buffer.clear();
      if (chunk.isNotEmpty) items.add(_stripMarkdownDecorations(chunk));
    }

    for (; idx < lines.length; idx++) {
      final lineRaw = lines[idx];
      final line = lineRaw.trimRight();
      final t = line.trim();

      if (t.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (!inCodeBlock) {
        final bulletMatch = RegExp(
          r'^\s*(?:[-*•]|\d+\.)\s+(.*)$',
        ).firstMatch(line);
        if (bulletMatch != null) {
          flushBuffer();
          final content = (bulletMatch.group(1) ?? '').trim();
          if (content.isNotEmpty) items.add(_stripMarkdownDecorations(content));
          continue;
        }

        if (t.isEmpty) {
          flushBuffer();
          continue;
        }
      }

      buffer.writeln(lineRaw);
    }
    flushBuffer();

    final cleanedItems = items
        .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return (title: title, items: cleanedItems);
  }

  Widget _buildAssistantReplyCards(String raw) {
    final parsed = _parseAssistantText(raw);
    final title = parsed.title;
    final items = parsed.items.isNotEmpty
        ? parsed.items
        : <String>['I didn\'t understand that. Try asking in a different way.'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(_buildAssistantCardItem),
      ],
    );
  }

  Widget _buildAssistantCardItem(String text) {
    final match = RegExp(
      r'^\s*([A-Za-z][A-Za-z0-9 _\-/]{0,24}):\s+(.+)$',
    ).firstMatch(text);

    Widget child;
    if (match != null) {
      final k = (match.group(1) ?? '').trim();
      final v = (match.group(2) ?? '').trim();
      child = RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.neutral,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.deep,
              ),
            ),
            TextSpan(text: v),
          ],
        ),
      );
    } else {
      child = Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.neutral,
          height: 1.35,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: AppColors.purple, width: 4),
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  GenerativeModel _buildModel(String name) {
    final effectiveKey = _apiKey.trim().isNotEmpty ? _apiKey : _hardcodedApiKey;
    return GenerativeModel(model: name, apiKey: effectiveKey);
  }

  bool _looksLikeModelNotFound(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('not found') && msg.contains('models/');
  }

  bool _looksLikeNetworkOrDnsError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('unknownhostexception') ||
        msg.contains('unable to resolve host') ||
        msg.contains('failed host lookup') ||
        msg.contains('socketexception') ||
        msg.contains('eai_nodata');
  }

  Future<GenerateContentResponse> _generateWithFallback(String prompt) async {
    final content = [Content.text(prompt)];

    final primaryName = _modelName.trim();
    final tried = <String>{};

    Future<GenerateContentResponse> tryModel(String name) async {
      tried.add(name);
      return await _buildModel(name).generateContent(content);
    }

    try {
      return await tryModel(primaryName);
    } catch (e) {
      if (!_looksLikeModelNotFound(e)) rethrow;
      for (final alt in _fallbackModels) {
        final name = alt.trim();
        if (name.isEmpty || tried.contains(name)) continue;
        try {
          return await tryModel(name);
        } catch (e2) {
          if (_looksLikeModelNotFound(e2)) {
            continue;
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final effectiveKey = _apiKey.trim().isNotEmpty ? _apiKey : _hardcodedApiKey;

    if (_model == null || effectiveKey.trim().isEmpty) {
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: '',
            content: _buildAssistantReplyCards(
              'Gemini API key is missing.\n\nPlease add it to screens/chat/ai_chat_screen.dart (_hardcodedApiKey) or run with --dart-define=GEMINI_API_KEY=...',
            ),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      // 1. Fetch context (Inventory)
      final householdId = await _getHouseholdId();
      String contextInfo = '';
      List<DeviceRecord> devices = [];

      if (householdId != null) {
        devices = await _deviceRepo.getDevices(householdId);
        final boxes = await _deviceRepo.getStorageBoxes(householdId);

        contextInfo = 'Current Inventory:\n';
        for (var d in devices) {
          contextInfo +=
              '- ${d.name} (${d.category}): Status ${d.status.name}, Location: ${d.location}';
          if (d.storageBoxId != null) {
            contextInfo += ', Storage Box: ${d.storageBoxId}';
            if (d.compartmentNumber != null) {
              contextInfo += ', Compartment: ${d.compartmentNumber}';
            }
          }
          contextInfo += '\n';
        }
        contextInfo += '\nStorage Boxes:\n';
        for (var b in boxes) {
          contextInfo +=
              '- ${b.label}: ${b.location} (${b.itemCount} items, ${b.compartments} compartments)\n';
        }
      }

      // 2. Check for specific intents to show rich widgets
      Widget? richContent;
      String? assistantText;

      if (text.toLowerCase().contains('repair') ||
          text.toLowerCase().contains('broken') ||
          text.toLowerCase().contains('what needs repair')) {
        final brokenDevices = devices
            .where(
              (d) =>
                  d.status == DeviceStatus.needsRepair ||
                  d.status == DeviceStatus.broken,
            )
            .toList();
        if (brokenDevices.isNotEmpty) {
          richContent = _buildRepairList(brokenDevices);
          assistantText = '';
        }
      } else if (text.toLowerCase().contains('find') ||
          text.toLowerCase().contains('where') ||
          text.toLowerCase().contains('power drill')) {
        final searchTerm = text.toLowerCase();
        final foundDevices = devices.where((d) {
          return d.name.toLowerCase().contains(searchTerm) ||
              d.category.toLowerCase().contains(searchTerm);
        }).toList();
        if (foundDevices.isNotEmpty) {
          richContent = _buildLocationList(foundDevices);
          assistantText = '';
        }
      }

      // 3. Call Gemini for general queries
      if (richContent == null) {
        final prompt =
            '''You are a helpful assistant for a household inventory management app called YetNew.

Context about the user's inventory:
$contextInfo

User question: $text

Provide a helpful, concise response. If the user is asking about finding items, list their locations clearly. If asking about repairs, list items that need repair.''';

        final response = await _generateWithFallback(prompt);
        assistantText = '';
        richContent = _buildAssistantReplyCards(
          response.text ?? 'I didn\'t understand that.',
        );
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: assistantText ?? '',
            content: richContent,
          ),
        );
      });
    } catch (e) {
      setState(() {
        final effectiveKey = _apiKey.trim().isNotEmpty ? _apiKey : _hardcodedApiKey;
        final apiKeyMissing = effectiveKey.trim().isEmpty;
        final isModelNotFound = _looksLikeModelNotFound(e);
        final isNetwork = _looksLikeNetworkOrDnsError(e);

        String tip;
        if (apiKeyMissing) {
          tip =
              'Tip: Missing Gemini key. Add to _hardcodedApiKey in ai_chat_screen.dart or run with --dart-define...';
        } else if (isNetwork) {
          tip =
              'Tip: Network/DNS issue. Your emulator/device can\'t reach Google APIs (e.g. firestore.googleapis.com / generativelanguage.googleapis.com).\n\nTry: restart the emulator, disable VPN/proxy, or test on web: flutter run -d chrome';
        } else if (isModelNotFound) {
          tip =
              'Tip: Model id not available for this key. In AI Studio, copy the exact model id and run with: --dart-define=GEMINI_MODEL=THAT_ID\n\nCommon options: gemini-2.5-flash, gemini-2.5-pro, gemini-3-flash-preview';
        } else {
          tip =
              'Tip: Ensure GEMINI_API_KEY is set, then try an explicit model: --dart-define=GEMINI_MODEL=gemini-2.5-flash';
        }

        _messages.add(
          _ChatMessage(
            isUser: false,
            text: '',
            content: _buildAssistantReplyCards(
              'Error: ${e.toString()}\n\n$tip',
            ),
          ),
        );
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _sendQuickPrompt(String prompt) {
    _controller.text = prompt;
    _sendMessage();
  }

  Future<String?> _getHouseholdId() async {
    if (_user == null) return null;
    return await _householdService.getUserHouseholdId(_user.uid);
  }

  Widget _buildRepairList(List<DeviceRecord> devices) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items Needing Repair:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 12),
          ...devices.map(
            (d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: d.status == DeviceStatus.broken
                        ? AppColors.danger
                        : AppColors.warning,
                    width: 4,
                  ),
                ),
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Issue: ${d.status == DeviceStatus.broken ? "Broken" : "Needs repair"}',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Location: ${d.location}',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationList(List<DeviceRecord> devices) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your ${devices.first.name} is located in:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 12),
          ...devices.map(
            (d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.deep,
                          ),
                        ),
                        if (d.storageBoxId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Storage Box: ${d.storageBoxId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.neutral,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppColors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              d.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE3DBEC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.deep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YetNew Assistant',
              style: TextStyle(
                color: AppColors.deep,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  final msg = _messages[index];
                  return ChatBubble(
                    isUser: msg.isUser,
                    text: msg.text,
                    content: msg.content,
                  );
                }

                // Typing indicator at the end
                return const ChatBubble(isUser: false, isTyping: true);
              },
            ),
          ),
          _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickPrompts
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _PromptChip(
                    label: p,
                    onTap: () => _sendQuickPrompt(p),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.paleLavender)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: TextStyle(color: Color(0xFF9C9AAF)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.purple,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.isUser, required this.text, this.content});

  final bool isUser;
  final String text;
  final Widget? content;
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3DBEC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.deep,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
