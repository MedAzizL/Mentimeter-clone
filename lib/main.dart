import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mentimeter_app/screens/admin/home_screen.dart';
import 'package:mentimeter_app/screens/auth/login_screen.dart';
import 'package:mentimeter_app/screens/auth/reset_password_screen.dart';
import 'package:mentimeter_app/screens/auth/signup_screen.dart';
import 'package:mentimeter_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDur51RKyHrJQoHXoTKV64IjWJUoYhoCvo",
        authDomain: "mentimeter-0.firebaseapp.com",
        projectId: "mentimeter-0",
        storageBucket: "mentimeter-0.firebasestorage.app",
        messagingSenderId: "560318219592",
        appId: "1:560318219592:web:5aba64d589b6d6b34e5f7d",
        measurementId: "G-TW2C5RZY4G"
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mentimeter Clone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const AdminHomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          return const AdminHomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
