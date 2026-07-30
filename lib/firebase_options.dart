import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjUJ1X2__se88rYEl3iENQRScHMxvsJoQ',
    appId: '1:883809698181:android:d4fcf31169212b951484ec',
    messagingSenderId: '883809698181',
    projectId: 'exploria-7834a',
    storageBucket: 'exploria-7834a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '883809698181',
    projectId: 'exploria-7834a',
    storageBucket: 'exploria-7834a.firebasestorage.app',
    iosBundleId: 'com.walkwin.walkwin_app',
    iosClientId: '',
  );
}
