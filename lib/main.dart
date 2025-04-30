import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mentimeter_app/screens/admin/home_screen.dart';
import 'package:mentimeter_app/screens/admin/start_session_screen.dart';
import 'package:mentimeter_app/screens/auth/login_screen.dart';
import 'package:mentimeter_app/screens/auth/reset_password_screen.dart';
import 'package:mentimeter_app/screens/auth/signup_screen.dart';
import 'package:mentimeter_app/screens/participant/join_session_screen.dart';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthWrapper());
          case '/home':
            return MaterialPageRoute(builder: (_) => const AdminHomeScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupScreen());
          case '/reset-password':
            return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());
          case '/admin/home':
            return MaterialPageRoute(builder: (_) => const AdminHomeScreen());
          case '/admin/start_session':
            return MaterialPageRoute(builder: (_) => const StartSessionScreen());
          case '/participant/join':
            return MaterialPageRoute(builder: (_) => const JoinSessionScreen());
          default:
            return MaterialPageRoute(builder: (_) => const AuthWrapper());
        }
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() => _isLoading = true);
    final isLoggedIn = _authService.currentUser != null;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoggedIn) {
      return const AdminHomeScreen();
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Mentimeter_Logo.svg/1200px-Mentimeter_Logo.svg.png',
                height: 100,
              ),
              const SizedBox(height: 40),
              const Text(
                'Welcome to Mentimeter',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign In as Admin'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign Up as Admin'),
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/participant/join'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text('Join as Participant'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
