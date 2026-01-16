import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Widget? content; // For rich widgets like cards
  final bool isTyping;

  const ChatBubble({
    super.key,
    this.text = '',
    required this.isUser,
    this.content,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        constraints: BoxConstraints(maxWidth: maxW * 0.75),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isUser)
              // User messages: purple rounded rectangles on the right
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              // AI messages: white rounded rectangles on the left with avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar - woman icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.softLavender,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: AppColors.deep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
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
                          if (isTyping)
                            const _TypingDots()
                          else if (text.isNotEmpty)
                            Text(
                              text,
                              style: const TextStyle(
                                color: AppColors.deep,
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          if (content != null) ...[
                            if (!isTyping && text.isNotEmpty)
                              const SizedBox(height: 12),
                            content!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        String dots;
        if (t < 0.33) {
          dots = '•';
        } else if (t < 0.66) {
          dots = '••';
        } else {
          dots = '•••';
        }
        return Text(
          dots,
          style: const TextStyle(
            color: AppColors.deep,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        );
      },
    );
  }
}
