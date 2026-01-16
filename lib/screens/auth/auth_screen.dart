import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../family/setup_household_screen.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final AuthService _auth = AuthService(FirebaseAuth.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _checkHouseholdAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final householdId = await _householdService.getUserHouseholdId(user.uid);
    if (!mounted) return;
    if (householdId == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupHouseholdScreen()),
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_mode == AuthMode.signIn) {
        await _auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _auth.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (!mounted) return;
      await _checkHouseholdAndNavigate();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      await _checkHouseholdAndNavigate();
    } catch (e) {
      final raw = e.toString();
      setState(
        () => _error = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInWithApple();
      if (!mounted) return;
      await _checkHouseholdAndNavigate();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSignIn = _mode == AuthMode.signIn;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.authGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _AuthHeader(mode: _mode),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deep.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Email', style: textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            hintText: 'Enter your email',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Password', style: textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            hintText: 'Minimum 6 characters',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (isSignIn)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed('/forgot-password');
                                    },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        PrimaryButton(
                          label: isSignIn ? 'Sign In' : 'Create Account',
                          onPressed: _loading ? null : _submit,
                        ),
                        const SizedBox(height: 12),
                        SocialButton(
                          label: isSignIn
                              ? 'Continue with Google'
                              : 'Sign up with Google',
                          icon: Icons.g_mobiledata,
                          onPressed: _loading ? null : _google,
                        ),
                        if (_showApple) ...[
                          const SizedBox(height: 10),
                          SocialButton(
                            label: isSignIn
                                ? 'Continue with Apple'
                                : 'Sign up with Apple',
                            icon: Icons.apple,
                            dark: true,
                            onPressed: _loading ? null : _apple,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _mode = isSignIn
                                          ? AuthMode.signUp
                                          : AuthMode.signIn;
                                    });
                                  },
                            child: Text(
                              isSignIn
                                  ? "Don't have an account? Sign up"
                                  : 'Already have an account? Login',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.08),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.mode});

  final AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final isSignIn = mode == AuthMode.signIn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.search, color: AppColors.purple),
              ),
              SizedBox(width: 12),
              Text(
                'YetNew',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isSignIn ? 'Welcome Back' : 'Create Account',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSignIn ? 'Sign in to continue' : 'Join YetNew and get organized',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? Colors.black : Colors.white;
    final foreground = dark ? Colors.white : AppColors.deep;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: foreground),
      label: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: dark ? Colors.black : AppColors.paleLavender),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: dark ? 2 : 0,
        shadowColor: dark ? Colors.black26 : Colors.transparent,
      ),
    );
  }
}
