import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateShopAdminPage extends StatefulWidget {
  final String shopId; // Added shopId parameter

  const CreateShopAdminPage({super.key, required this.shopId}); // Added shopId to constructor

  @override
  _CreateShopAdminPageState createState() => _CreateShopAdminPageState();
}

class _CreateShopAdminPageState extends State<CreateShopAdminPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  Future<void> createShopAdmin(
      String name, String email, String password, String phoneNumber) async {
    try {
      // Create a new user with email and password
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = credential.user;

      if (user != null) {
        // Get the highest existing shop admin role
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isGreaterThanOrEqualTo: 'shopadmin')
            .orderBy('role', descending: true)
            .limit(1)
            .get();

        String newRole = 'shopadmin1'; // Default role
        if (snapshot.docs.isNotEmpty) {
          String lastRole = snapshot.docs.first['role'];

          // Check if lastRole contains a valid number after 'shopadmin'
          String numberPart = lastRole.replaceAll('shopadmin', '');
          if (RegExp(r'^\d+$').hasMatch(numberPart)) {
            int lastNumber = int.parse(numberPart);
            newRole = 'shopadmin${lastNumber + 1}';
          }
        }

        // Store shop admin data in Firestore, including shop_id
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'phone_number': phoneNumber, // Store as a string
          'role': newRole,
          'shop_id': widget.shopId, // Use the passed shopId
        });

        print('Shop Admin Created with role: $newRole and shop_id: ${widget.shopId}');
      }
    } catch (e) {
      print('Error creating shop admin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Shop Admin"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            TextField(
              controller: phoneNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                createShopAdmin(
                  nameController.text.trim(),
                  emailController.text.trim(),
                  passwordController.text.trim(),
                  phoneNumberController.text.trim(),
                );
              },
              child: const Text('Create Shop Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
