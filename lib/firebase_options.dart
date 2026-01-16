import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCYJ3ctcM5MSFquTlSr-PnVWi3pr0VlvHY',
    appId: '1:912018791389:web:03b82b303e621fe2803434',
    messagingSenderId: '912018791389',
    projectId: 'yetnew-home-device',
    authDomain: 'yetnew-home-device.firebaseapp.com',
    storageBucket: 'yetnew-home-device.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfpl23XDkxt3b_ccbPetUg_NzrsA7YXoc',
    appId: '1:912018791389:android:939824288ebb4bd5803434',
    messagingSenderId: '912018791389',
    projectId: 'yetnew-home-device',
    storageBucket: 'yetnew-home-device.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWkk8ycDF6wa-bsMpzYEv4D-85QUv8vk8',
    appId: '1:912018791389:ios:7eb275e39fdc08ea803434',
    messagingSenderId: '912018791389',
    projectId: 'yetnew-home-device',
    storageBucket: 'yetnew-home-device.firebasestorage.app',
    iosClientId:
        '912018791389-js97a4fqn552ro6c64em4fps13m7j1hq.apps.googleusercontent.com',
    iosBundleId: 'com.example.yetnewApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAWkk8ycDF6wa-bsMpzYEv4D-85QUv8vk8',
    appId: '1:912018791389:ios:7eb275e39fdc08ea803434',
    messagingSenderId: '912018791389',
    projectId: 'yetnew-home-device',
    storageBucket: 'yetnew-home-device.firebasestorage.app',
    iosClientId:
        '912018791389-js97a4fqn552ro6c64em4fps13m7j1hq.apps.googleusercontent.com',
    iosBundleId: 'com.example.yetnewApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCYJ3ctcM5MSFquTlSr-PnVWi3pr0VlvHY',
    appId: '1:912018791389:web:97cdf2d65084347a803434',
    messagingSenderId: '912018791389',
    projectId: 'yetnew-home-device',
    authDomain: 'yetnew-home-device.firebaseapp.com',
    storageBucket: 'yetnew-home-device.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'ADD_LINUX_API_KEY',
    appId: 'ADD_LINUX_APP_ID',
    messagingSenderId: 'ADD_SENDER_ID',
    projectId: 'yetnew-home-device',
    storageBucket: 'yetnew-home-device.appspot.com',
  );
}
