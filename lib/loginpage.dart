import 'package:flutter/material.dart';
import 'package:localproject/functions/authFunctions.dart';
import 'package:localproject/getlocation.dart';  // Import the GetLocation widget

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = false;
  String email = '';
  String password = '';
  String name = '';
  String phoneNumber = '';
  String address = '';
  double latitude = 0.0; // Changed to double
  double longitude = 0.0; // Changed to double
  final TextEditingController _addressController = TextEditingController();

  void _trySubmit() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();

    if (isValid) {
      _formKey.currentState!.save();

      if (isLogin) {
        // Handle login logic
        try {
          await signIn(email, password, context);
        } catch (error) {
          print(error);
        }
      } else {
        // Handle signup logic
        try {
          await signUp(email, password, name, phoneNumber, address, latitude, longitude);
          setState(() {
            isLogin = true;
          });
        } catch (error) {
          print(error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LocalShop"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isLogin)
                          TextFormField(
                            key: const ValueKey('username'),
                            decoration: const InputDecoration(hintText: "Enter Full Name"),
                            validator: (value) {
                              if (value == null || value.trim().length < 3) {
                                return "Please enter at least 3 characters.";
                              }
                              return null;
                            },
                            onSaved: (value) {
                              name = value!.trim();
                            },
                          ),
                        TextFormField(
                          key: const ValueKey('email'),
                          decoration: const InputDecoration(hintText: "Enter Email"),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return "Please enter a valid email address.";
                            }
                            return null;
                          },
                          onSaved: (value) {
                            email = value!.trim();
                          },
                        ),
                        TextFormField(
                          key: const ValueKey('password'),
                          decoration: const InputDecoration(hintText: "Enter Password"),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return "Password must be at least 6 characters long.";
                            }
                            return null;
                          },
                          onSaved: (value) {
                            password = value!.trim();
                          },
                        ),
                        if (!isLogin)
                          TextFormField(
                            key: const ValueKey('phone'),
                            decoration: const InputDecoration(hintText: "Enter Phone Number"),
                            validator: (value) {
                              if (value == null || value.trim().length < 10) {
                                return "Please enter a valid phone number.";
                              }
                              return null;
                            },
                            onSaved: (value) {
                              phoneNumber = value!.trim();
                            },
                          ),
                        if (!isLogin)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                key: const ValueKey('address'),
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  hintText: "Edit Address",
                                ),
                                onSaved: (value) {
                                  address = value!.trim();
                                },
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Open the GetLocation page and wait for the selected address and location
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const GetLocation()),
                                  );

                                  // Update the address, latitude, and longitude based on the selected location
                                  if (result != null) {
                                    setState(() {
                                      address = result['selectedAddress'];
                                      latitude = result['position'].latitude; // Directly use double
                                      longitude = result['position'].longitude; // Directly use double
                                      _addressController.text = address; // Update the TextFormField
                                    });
                                  }
                                },
                                icon: const Icon(Icons.location_on),
                                label: const Text('Select Address from Map'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _trySubmit,
                          child: Text(isLogin ? 'Login' : 'Signup'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await signInWithGoogle();
                            } catch (error) {
                              print(error);
                            }
                          },
                          child: const Text('Sign in with Google'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(isLogin ? 'Create New Account' : 'I already have an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
