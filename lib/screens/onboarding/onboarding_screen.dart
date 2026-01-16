import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FA), // Light purple background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isCompact ? 12 : 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AppColors.purple,
                      ), // Placeholder for logo
                      SizedBox(width: 8),
                      Text(
                        'YetNew',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/auth'),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: AppColors.purple),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _WelcomePage(),
                  _TrackDevicesPage(),
                  _SmartHelpPage(),
                ],
              ),
            ),

            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _index == i
                        ? AppColors.purple
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),

            // Action Button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isCompact ? 16 : 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: isCompact ? 52 : 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_index < 2) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.of(context).pushReplacementNamed('/auth');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _index == 2 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (_index == 2)
              TextButton(
                onPressed: () => _controller.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(color: AppColors.purple),
                ),
              ),
            if (_index == 2) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Widget illustration;
  final String title;
  final String subtitle;
  final Widget? extraContent;

  const _ContentCard({
    required this.illustration,
    required this.title,
    required this.subtitle,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final illustrationH = (maxH * 0.38).clamp(160.0, 260.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: illustrationH,
                  child: Center(
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: illustration,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF757575),
                          height: 1.5,
                        ),
                      ),
                      if (extraContent != null) ...[
                        const SizedBox(height: 16),
                        extraContent!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      illustration: Image.asset(
        'assets/images/onboarding_1_img.jpg',
        fit: BoxFit.contain,
      ),
      title: 'Welcome to YetNew',
      subtitle: 'Create or join a household to organize everything together.',
    );
  }
}

class _TrackDevicesPage extends StatelessWidget {
  const _TrackDevicesPage();

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      illustration: const _DevicesDiagram(),
      title: 'Track Devices &\nStorage',
      subtitle: 'Add items, store them in boxes, and find them fast.',
      extraContent: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: const [
          _Chip(icon: Icons.camera_alt, label: 'Photos +\nNotes'),
          _Chip(icon: Icons.help_outline, label: 'Box &\nCompartment'),
        ],
      ),
    );
  }
}

class _SmartHelpPage extends StatelessWidget {
  const _SmartHelpPage();

  @override
  Widget build(BuildContext context) {
    return const _ContentCard(
      illustration: _ChatPreview(),
      title: 'Smart Help &\nActivity History',
      subtitle: 'Ask the assistant questions and see real household activity.',
    );
  }
}

// Custom Widget for "Track Devices" Diagram
class _DevicesDiagram extends StatelessWidget {
  const _DevicesDiagram();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting lines (simplified)
          Positioned(
            top: 60,
            child: Container(
              width: 140,
              height: 100,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                  right: BorderSide(
                    color: AppColors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                  top: BorderSide(
                    color: AppColors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Top Box (Box C)
          Positioned(
            top: 0,
            child: _DiagramBox(label: 'Box C', content: Icons.home),
          ),

          // Left Box (Box A)
          Positioned(
            bottom: 20,
            left: 0,
            child: _DiagramBox(label: 'Box A', content: Icons.microwave),
          ),

          // Right Box (Box B)
          Positioned(
            bottom: 20,
            right: 0,
            child: _DiagramBox(label: 'Box B', content: Icons.kitchen),
          ),
        ],
      ),
    );
  }
}

class _DiagramBox extends StatelessWidget {
  final String label;
  final IconData content;

  const _DiagramBox({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.purple, width: 1.5),
          ),
          child: Icon(content, color: AppColors.purple, size: 32),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2D2D2D)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D2D2D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Widget for "Chat & History" illustration
class _ChatPreview extends StatelessWidget {
  const _ChatPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: Stack(
        children: [
          // Chat bubble
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0B6FF), // Light purple
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'How can I help you today?',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Activity List
          Positioned(
            top: 80,
            right: 0,
            left: 60,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActivityItem(
                    icon: Icons.add_circle,
                    color: Colors.green,
                    title: 'Device added',
                    time: '2 min ago',
                  ),
                  const SizedBox(height: 8),
                  _ActivityItem(
                    icon: Icons.arrow_forward_rounded,
                    color: Colors.blue,
                    title: 'Moved to Box',
                    time: '1 hour ago',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
