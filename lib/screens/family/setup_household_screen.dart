import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';

enum SetupStep { choose, create, join, successCreate, successJoin }

class SetupHouseholdScreen extends StatefulWidget {
  const SetupHouseholdScreen({super.key});

  @override
  State<SetupHouseholdScreen> createState() => _SetupHouseholdScreenState();
}

class _SetupHouseholdScreenState extends State<SetupHouseholdScreen> {
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  User? get _user => FirebaseAuth.instance.currentUser;

  SetupStep _currentStep = SetupStep.choose;
  bool _isLoading = false;
  String? _generatedCode;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // Generate code based on name (will be finalized on creation)
    final tempCode = _generateTempCode(name);
    setState(() => _generatedCode = tempCode);
  }

  String _generateTempCode(String name) {
    final year = DateTime.now().year.toString().substring(2); // Last 2 digits
    final namePart = name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final cleanName = namePart.length > 4
        ? namePart.substring(0, 4)
        : namePart.padRight(4, 'X');
    final random = (DateTime.now().millisecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    final randomPart = random.substring(0, 2);
    return 'YN-$cleanName$year-$randomPart';
  }

  Future<void> _createHousehold() async {
    final user = _user;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to create a household.');
      return;
    }
    if (user.email == null) {
      setState(
        () => _errorMessage =
            'Please use Email/Google sign-in (demo accounts can\'t create households).',
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a household name');
      return;
    }

    final codeToUse = (_generatedCode ?? _generateTempCode(name))
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9-]'), '');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final householdId = await _householdService.createHousehold(
        userId: user.uid,
        householdName: name,
        userName: user.displayName ?? user.email!.split('@').first,
        userEmail: user.email!,
        householdCode: codeToUse,
      );

      // Get the actual generated code
      final household = await _householdService.getHousehold(householdId);
      if (mounted) {
        setState(() {
          _generatedCode = household?.code;
          _currentStep = SetupStep.successCreate;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error creating household: ${_formatFirebaseError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinHousehold() async {
    final user = _user;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to join a household.');
      return;
    }
    if (user.email == null) {
      setState(
        () => _errorMessage =
            'Please use Email/Google sign-in (demo accounts can\'t join households).',
      );
      return;
    }
    final code = _codeController.text.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a household code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _householdService.joinHousehold(
        userId: user.uid,
        householdCode: code,
        userName: user.displayName ?? user.email!.split('@').first,
        userEmail: user.email!,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _currentStep = SetupStep.successJoin;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Household not found. Please check the code.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error joining household: ${_formatFirebaseError(e)}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatFirebaseError(Object e) {
    if (e is FirebaseException) {
      final message = e.message ?? e.code;
      return '[${e.code}] $message';
    }
    return e.toString();
  }

  void _copyCode() {
    if (_generatedCode != null) {
      Clipboard.setData(ClipboardData(text: _generatedCode!));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Household code copied!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildCurrentStep()),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case SetupStep.choose:
        return _buildChooseStep();
      case SetupStep.create:
        return _buildCreateStep();
      case SetupStep.join:
        return _buildJoinStep();
      case SetupStep.successCreate:
        return _buildSuccessCreate();
      case SetupStep.successJoin:
        return _buildSuccessJoin();
    }
  }

  Widget _buildChooseStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          _buildIllustration(),
          const SizedBox(height: 40),
          const Text(
            'Set Up Your Household',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Create your own household or join an existing one.',
            style: TextStyle(fontSize: 16, color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _HouseholdOptionCard(
            icon: Icons.add_circle_outline,
            title: 'Create New Household',
            subtitle: 'Start fresh with your family',
            isPrimary: true,
            onTap: () => setState(() => _currentStep = SetupStep.create),
          ),
          const SizedBox(height: 16),
          _HouseholdOptionCard(
            icon: Icons.group_add,
            title: 'Join Existing Household',
            subtitle: 'Use an invitation code',
            isPrimary: false,
            onTap: () => setState(() => _currentStep = SetupStep.join),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.deep),
            onPressed: () => setState(() {
              _currentStep = SetupStep.choose;
              _errorMessage = null;
              _generatedCode = null;
            }),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create New Household',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 32),
          _buildHouseholdNameField(),
          const SizedBox(height: 24),
          _buildHouseholdCodeField(),
          const SizedBox(height: 24),
          _buildRoleInfo(),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildJoinStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.deep),
            onPressed: () => setState(() {
              _currentStep = SetupStep.choose;
              _errorMessage = null;
              _codeController.clear();
            }),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join Existing Household',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 32),
          _buildCodeInputField(),
          const SizedBox(height: 8),
          Text(
            'Example: YN-84K2-LP',
            style: TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildJoinButton(),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _currentStep = SetupStep.create;
                _errorMessage = null;
                _codeController.clear();
              }),
              child: const Text(
                'Create a new household instead',
                style: TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCreate() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Household Created 🎉',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You\'re now the admin of this household',
            style: TextStyle(fontSize: 16, color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessJoin() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to the Household!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You\'ve successfully joined',
            style: TextStyle(fontSize: 16, color: AppColors.neutral),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.light, AppColors.softLavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.home, size: 100, color: AppColors.purple),
          Positioned(
            bottom: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, size: 32, color: AppColors.purple),
                const SizedBox(width: 4),
                Icon(Icons.person, size: 32, color: AppColors.purple),
                const SizedBox(width: 4),
                Icon(Icons.person, size: 32, color: AppColors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Household Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deep,
              ),
            ),
            Text('*', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g., Sarah\'s Family Home',
            helperText: 'This name will be visible to family members',
            helperStyle: TextStyle(color: AppColors.neutral, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple, width: 2),
            ),
          ),
          onChanged: (_) {
            setState(() {
              _errorMessage = null;
            });
            _generateCode();
          },
        ),
      ],
    );
  }

  Widget _buildHouseholdCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Household Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.paleLavender),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _generatedCode ?? 'Code will be generated...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _generatedCode != null
                        ? AppColors.deep
                        : AppColors.neutral,
                  ),
                ),
              ),
              if (_generatedCode != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.copy,
                    color: AppColors.purple,
                    size: 20,
                  ),
                  onPressed: _copyCode,
                  tooltip: 'Copy code',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Share this code to invite family members',
          style: TextStyle(fontSize: 12, color: AppColors.neutral),
        ),
      ],
    );
  }

  Widget _buildRoleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You will be the household admin',
              style: TextStyle(fontSize: 14, color: AppColors.deep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputField() {
    return TextField(
      controller: _codeController,
      decoration: InputDecoration(
        hintText: 'Enter household code',
        prefixIcon: const Icon(Icons.vpn_key, color: AppColors.purple),
        suffixIcon: IconButton(
          icon: const Icon(Icons.paste, color: AppColors.purple),
          onPressed: () async {
            final data = await Clipboard.getData('text/plain');
            if (data?.text != null) {
              _codeController.text = data!.text!.toUpperCase();
            }
          },
          tooltip: 'Paste code',
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.paleLavender),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.paleLavender),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
        ),
        errorBorder: _errorMessage != null
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              )
            : null,
      ),
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) {
        setState(() => _errorMessage = null);
      },
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _nameController.text.trim().isNotEmpty && !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canCreate ? _createHousehold : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          disabledBackgroundColor: AppColors.paleLavender,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Create Household',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildJoinButton() {
    final canJoin = _codeController.text.trim().isNotEmpty && !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canJoin ? _joinHousehold : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          disabledBackgroundColor: AppColors.paleLavender,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Join Household',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _HouseholdOptionCard extends StatelessWidget {
  const _HouseholdOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [AppColors.purple, AppColors.mid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: AppColors.purple, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.paleLavender.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.softLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? Colors.white : AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPrimary ? Colors.white70 : AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: isPrimary ? Colors.white : AppColors.deep,
            ),
          ],
        ),
      ),
    );
  }
}
