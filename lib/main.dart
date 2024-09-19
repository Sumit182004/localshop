import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:localproject/adminpage.dart';
import 'package:localproject/confromationpage.dart';
import 'package:localproject/firebase_options.dart';
import 'package:localproject/hompage.dart';
import 'package:localproject/loginpage.dart';
import 'package:localproject/shopadminpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalShop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:   const CheckLoginStatus(),
      routes: {
        '/adminpage': (context) => const AdminPage(),
        '/shopAdminPage': (context) => const Shopadminpage(),
        '/homePage': (context) => const Homepage(),
        '/loginPage': (context) => const LoginPage(),

      },
    );
  }
}

class CheckLoginStatus extends StatefulWidget {
  const CheckLoginStatus({super.key});

  @override
  _CheckLoginStatusState createState() => _CheckLoginStatusState();
}

class _CheckLoginStatusState extends State<CheckLoginStatus> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    String? userRole = prefs.getString('userRole');

    if (isLoggedIn == true) {
      if (userRole == 'main_admin') {
        Navigator.pushReplacementNamed(context, '/adminpage');
      } else if (userRole != null && userRole.startsWith('shopadmin')) {
        Navigator.pushReplacementNamed(context, '/shopAdminPage');
      } else {
        Navigator.pushReplacementNamed(context, '/homePage');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/loginPage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()), // Show a loading indicator while checking
    );
  }
}

