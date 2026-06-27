import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// On-demand Google Sign-In service (offline-first architecture).
///
/// The SDK is initialised lazily on the first call to [ensureInitialized].
/// No sign-in attempt is made at app startup — authentication only happens
/// when the user explicitly triggers it from the Sync screen.
class AuthService extends GetxService {
  bool _sdkReady = false;

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

  static Future<AuthService> init() async => AuthService();

  /// Initialises the Google Sign-In SDK (once). Called before any auth action.
  Future<void> ensureInitialized() async {
    if (_sdkReady) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '999687772055-v2b76t4i62rma2u2t5o51a2f1dvkrj0j.apps.googleusercontent.com',
      );

      GoogleSignIn.instance.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            user.value = event.user;
          case GoogleSignInAuthenticationEventSignOut():
            user.value = null;
        }
      });

      // Restore previous session silently if available.
      await GoogleSignIn.instance.attemptLightweightAuthentication();
      _sdkReady = true;
    } catch (e) {
      debugPrint('Google Sign-In init error: $e');
    }
  }

  /// Signs in with Google interactively. Initialises SDK if needed.
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
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
    await GoogleSignIn.instance.signOut();
  }
}
