import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController sizeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  String? selectedUnit;
  final List<String> units = ['ml', 'grams', 'liters', 'pieces'];

  // To store multiple variations
  List<Map<String, dynamic>> variations = [];

  Future<void> _pickImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = photo;
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

  void _addVariation() {
    final size = sizeController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

    if (size.isEmpty || price <= 0.0 || quantity <= 0 || selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all fields for the variation.')),
      );
      return;
    }

    setState(() {
      variations.add({
        'size': size,
        'price': price,
        'quantity': quantity,
        'unit': selectedUnit,
      });
    });

    // Clear the controllers after adding a variation
    sizeController.clear();
    priceController.clear();
    quantityController.clear();
    selectedUnit = null;
  }

  Future<void> _uploadImageAndAddProduct(String name) async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image.')),
      );
      return;
    }

    if (variations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one size variation.')),
      );
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user logged in.')),
        );
        return;
      }

      // Fetch the shop ID from the user's profile or other appropriate source
      final String? shopId = await _getShopIdForUser(user.uid);

      if (shopId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No shop associated with this user.')),
        );
        return;
      }

      // Upload the image to Firebase Storage
      final downloadUrl = await _uploadImage();

      // Store product as a subcollection under the correct shopId
      final shopDocRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
      await shopDocRef.collection('products').add({
        'name': name,
        'variations': variations,
        'image': downloadUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error adding product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  Future<void> _updateProductByName(String name) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user logged in.')),
        );
        return;
      }

      final String? shopId = await _getShopIdForUser(user.uid);

      if (shopId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No shop associated with this user.')),
        );
        return;
      }

      final shopDocRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
      final QuerySnapshot snapshot = await shopDocRef
          .collection('products')
          .where('name', isEqualTo: name)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found.')),
        );
        return;
      }

      final docRef = snapshot.docs.first.reference;

      // Update the product's variations and other details
      await docRef.update({
        'variations': variations,
        if (_image != null) 'image': await _uploadImage(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating product: $e')),
      );
    }
  }

  Future<void> _deleteProductByName(String name) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user logged in.')),
        );
        return;
      }

      final String? shopId = await _getShopIdForUser(user.uid);

      if (shopId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No shop associated with this user.')),
        );
        return;
      }

      final shopDocRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
      final QuerySnapshot snapshot = await shopDocRef
          .collection('products')
          .where('name', isEqualTo: name)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  Future<String?> _getShopIdForUser(String uid) async {
    // Fetch the shop ID for the given user ID
    // This could be stored in the user's document in Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (userDoc.exists) {
      return userDoc.data()?['shop_id'] as String?;
    }
    return null;
  }

  Future<String> _uploadImage() async {
    if (_image == null) return '';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('product_images/${DateTime.now().millisecondsSinceEpoch}');
    final uploadTask = storageRef.putFile(File(_image!.path));
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: sizeController,
                decoration: const InputDecoration(
                    labelText: 'Size (e.g., 100ml)'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                onChanged: (value) {
                  setState(() {
                    selectedUnit = value;
                  });
                },
                items: units
                    .map((unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(unit),
                ))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addVariation,
                child: const Text('Add Variation'),
              ),
              const SizedBox(height: 16),
              _image != null
                  ? Image.file(
                File(_image!.path),
                height: 200,
              )
                  : const Text('No image selected.'),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick Image'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    _uploadImageAndAddProduct(name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a product name.')),
                    );
                  }
                },
                child: const Text('Add Product'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    _updateProductByName(name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a product name.')),
                    );
                  }
                },
                child: const Text('Update Product'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    _deleteProductByName(name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a product name.')),
                    );
                  }
                },
                child: const Text('Delete Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
