import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Manages authentication state via Google Sign-In (no Firebase).
///
/// Exposes reactive [user] and [isLoggedIn] so the UI can respond
/// instantly when the auth state changes (login, logout).
/// User data is stored locally — cloud sync uses Google Drive.
class AuthService extends GetxService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Current signed-in account — null when signed out.
  final Rx<GoogleSignInAccount?> user = Rx<GoogleSignInAccount?>(null);

  /// Whether a sign-in is in progress (drives loading spinners).
  final RxBool isLoading = false.obs;

  bool get isLoggedIn => user.value != null;

  /// Convenience getters for user profile data.
  String? get displayName => user.value?.displayName;
  String? get email => user.value?.email;
  String? get photoUrl => user.value?.photoUrl;
  String? get userId => user.value?.id;

  /// Initialises the service — sets up Google Sign-In and attempts
  /// to restore the previous session silently.
  static Future<AuthService> init() async {
    final service = AuthService();

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '999687772055-v2b76t4i62rma2u2t5o51a2f1dvkrj0j.apps.googleusercontent.com',
      );

      // Listen to auth events (sign-in / sign-out)
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            service.user.value = event.user;
          case GoogleSignInAuthenticationEventSignOut():
            service.user.value = null;
        }
      });

      // Try to restore previous session without user interaction
      await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('Google Sign-In init error: $e');
    }

    return service;
  }

  /// Signs in with Google interactively.
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      isLoading.value = true;
      final account = await _googleSignIn.authenticate();
      return account;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs out of Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
