import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localproject/createshopadminpage.dart';
import 'package:localproject/getlocation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController contactInfoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String shopLatitude = '';
  String shopLongitude = '';

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = image;
    });
    if (_image != null) {
      print('Image Picked: ${_image!.path}');
    } else {
      print('No image selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected.')),
      );
    }
  }

  Future<void> addShop() async {
    String shopName = shopNameController.text.trim();
    String location = _locationController.text.trim();
    String contactInfo = contactInfoController.text.trim();
    double? latitude = double.tryParse(shopLatitude);
    double? longitude = double.tryParse(shopLongitude);

    if (shopName.isNotEmpty && location.isNotEmpty && contactInfo.isNotEmpty && latitude != null && longitude != null) {
      if (_image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image.')),
        );
        return;
      }

      try {
        // Upload the image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('shop_images/${DateTime.now().millisecondsSinceEpoch}');
        final uploadTask = storageRef.putFile(File(_image!.path));
        final snapshot = await uploadTask.whenComplete(() => {});
        final imageUrl = await snapshot.ref.getDownloadURL();

        // Add shop details to Firestore
        DocumentReference shopRef = await FirebaseFirestore.instance.collection('shops').add({
          'shop_name': shopName,
          'location': location,
          'contact_info': contactInfo,
          'latitude': latitude,
          'longitude': longitude,
          'image_url': imageUrl, // Add the image URL
        });

        // Clear text fields
        shopNameController.clear();
        _locationController.clear();
        contactInfoController.clear();
        shopLatitude = '';
        shopLongitude = '';
        setState(() {
          _image = null;
        });

        // Show the newly added shop in a dialog for admin selection
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Shop Added'),
              content: const Text('The shop has been added. Do you want to assign a Shop Admin now?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateShopAdminPage(shopId: shopRef.id),
                      ),
                    );
                  },
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('Error adding shop: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding shop: $e')),
        );
      }
    } else {
      print('Please fill all fields');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image.')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Clear shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacementNamed(context, '/loginPage');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Page"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Text(
                'Admin Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shop),
              title: const Text('Add Shop'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Create Shop Admin'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateShopAdminPage(shopId: ''),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              child: Column(
                children: [
                  TextFormField(
                    controller: shopNameController,
                    decoration: const InputDecoration(labelText: 'Shop Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a shop name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: contactInfoController,
                    decoration: const InputDecoration(labelText: 'Contact Info'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter contact information';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Edit Address'),
                  ),
                  const SizedBox(height: 12),
                  _image == null
                      ? const Text('No image selected.')
                      : Image.file(File(_image!.path), height: 100, width: 100, fit: BoxFit.cover),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GetLocation()),
                      );

                      if (result != null) {
                        setState(() {
                          _locationController.text = result['selectedAddress'];
                          shopLatitude = result['position'].latitude.toString();
                          shopLongitude = result['position'].longitude.toString();
                        });
                      }
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Select Address from Map'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: addShop,
                    child: const Text('Add Shop'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
