import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb){
 await Firebase.initializeApp(
    options:  FirebaseOptions (apiKey: "AIzaSyDur51RKyHrJQoHXoTKV64IjWJUoYhoCvo",
  authDomain: "mentimeter-0.firebaseapp.com",
  projectId: "mentimeter-0",
  storageBucket: "mentimeter-0.firebasestorage.app",
  messagingSenderId: "560318219592",
  appId: "1:560318219592:web:5aba64d589b6d6b34e5f7d",
  measurementId: "G-TW2C5RZY4G")
  

  );
  }
  else {
     await Firebase.initializeApp();
  }
 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mentimeter App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Mentimeter App'),
        ),
        body: const Center(
          child: Text('Hello Firebase!'),
        ),
      ),
    );
  }
}
