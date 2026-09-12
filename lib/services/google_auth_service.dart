import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class GoogleAuthService {
  // Reemplazar con el Web Client ID de Google Cloud Console cuando esté disponible
  static const String? _webClientId = null;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  static Future<Map<String, dynamic>?> signInWithGoogle({
    String? province,
    String? referralCode,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el ID Token de Google.');
      }

      final result = await ApiService.googleLogin(
        idToken: idToken,
        province: province,
        referralCode: referralCode,
      );

      return result;
    } catch (e) {
      print('Error en GoogleAuthService.signInWithGoogle: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error al cerrar sesión en Google: $e');
    }
  }
}
