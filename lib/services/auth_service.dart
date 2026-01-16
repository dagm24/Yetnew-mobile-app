import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Use Firebase popup flow on web; avoids needing a meta client_id tag.
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    } else {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw Exception('Google sign-in was cancelled');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return _auth.signInWithCredential(credential);
      } on PlatformException catch (e) {
        final msg = (e.message ?? '').toLowerCase();

        final isApi10 = msg.contains('apiexception') && msg.contains('10');
        final isDeveloperError =
            msg.contains('developer_error') || msg.contains('devel');
        final isNoPlayServices =
            msg.contains('unknown calling package name') ||
            msg.contains('com.google.android.gms');
        final isNetwork = msg.contains('network') || msg.contains('timeout');
        final isCanceled =
            e.code == 'sign_in_canceled' || msg.contains('cancel');

        if (isCanceled) {
          throw Exception('Google sign-in was cancelled');
        }

        if (e.code == 'sign_in_failed' && isApi10) {
          throw Exception(
            'Google Sign-In failed (ApiException 10).\n\n'
            'Most common fix (Android/Firebase config):\n'
            '1) Firebase Console → Project settings → Your apps → Android\n'
            '2) Add SHA-1 and SHA-256 for your keystore (debug + release)\n'
            '3) Download the updated google-services.json and place it in android/app\n'
            '4) Run flutter clean, then rebuild\n',
          );
        }

        if (isNoPlayServices || isDeveloperError) {
          throw Exception(
            'Google Sign-In is not supported on this device right now.\n\n'
            'This usually happens when Google Play services are missing/outdated, the device is not Google-certified, or the Google apps framework is broken (common on some devices).\n\n'
            'Try:\n'
            '- Update Google Play services + Play Store\n'
            '- Make sure the device has Google services installed and you are signed into a Google account\n'
            '- If it still fails, use Email/Password sign-in on this device\n',
          );
        }

        if (isNetwork) {
          throw Exception(
            'Network issue prevented Google Sign-In. Check your internet/VPN/DNS and try again.',
          );
        }

        throw Exception('Google Sign-In failed: ${e.message ?? e.code}');
      }
    }
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return _auth.signInWithCredential(oauth);
  }

  Future<UserCredential> signInDemo() async {
    return _auth.signInAnonymously();
  }

  Future<void> sendPasswordReset(String email) {
    // Professional flow: email link opens the app (Android/iOS) and routes
    // to /reset-password (web also supported).
    // Note: the domain must be in Firebase Auth → Authorized domains.
    const continueUrl = 'https://yetnew-home-device.web.app/reset-password';
    return _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.example.yetnew_app',
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: 'com.example.yetnewApp',
      ),
    );
  }

  Future<void> confirmPasswordReset(String code, String newPassword) {
    return _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
