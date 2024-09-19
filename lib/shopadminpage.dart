import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localproject/addproductpage.dart';
import 'package:localproject/shopadminorderpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Shopadminpage extends StatefulWidget {
  const Shopadminpage({super.key});

  @override
  _ShopadminpageState createState() => _ShopadminpageState();
}

class _ShopadminpageState extends State<Shopadminpage> {
  int pendingOrdersCount = 0;
  String? shopId;

  @override
  void initState() {
    super.initState();
    _fetchShopId();
  }

  Future<void> _fetchShopId() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            shopId = userData['shop_id'] as String?;
            if (shopId != null) {
              _fetchPendingOrdersCount();
            }
          });
        }
      } catch (e) {
        print('Error fetching shopId: $e');
      }
    }
  }

  Future<void> _fetchPendingOrdersCount() async {
    if (shopId != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('orders')
            .where('status', isEqualTo: 'Pending')
            .get();

        setState(() {
          pendingOrdersCount = snapshot.docs.length;
        });
      } catch (e) {
        print('Error fetching pending orders count: $e');
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      // Clear shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login page
      Navigator.pushReplacementNamed(context, '/loginPage');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      if (shopId != null) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(productId)
            .delete();
        print('Product deleted successfully');
        setState(() {}); // Refresh the product list
      }
    } catch (e) {
      print('Error deleting product: $e');
    }
  }

  Future<void> _navigateToOrderPage(BuildContext context) async {
    // Navigate to the ShopAdminOrderPage
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShopAdminOrderPage()),
    );

    // Reset pending orders count after navigation
    setState(() {
      pendingOrdersCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shop Admin"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Shop Admin Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Add Product'),
              leading: const Icon(Icons.add),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddProductPage()),
                );
              },
            ),
            ListTile(
              title: Row(
                children: [
                  const Text('Manage Orders'),
                  if (pendingOrdersCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          pendingOrdersCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              leading: const Icon(Icons.shopping_cart),
              onTap: () => _navigateToOrderPage(context),
            ),
            ListTile(
              title: const Text('Logout'),
              leading: const Icon(Icons.logout),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: shopId != null
                  ? FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .collection('products')
                  .get()
                  .then((snapshot) => snapshot.docs)
                  : Future.value([]), // Return an empty list when shopId is null
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No products available.'));
                }

                final products = snapshot.data!;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Image')),
                    ],
                    rows: products.expand((product) {
                      final data = product.data() as Map<String, dynamic>;
                      final variations = data['variations'] as List<dynamic>? ?? [];

                      return variations.map((variation) {
                        final price = variation['price']?.toString() ?? '';
                        final quantity = variation['quantity']?.toString() ?? '';
                        final size = variation['size'] ?? '';
                        final unit = variation['unit'] ?? '';
                        final imageUrl = data['image'] ?? '';

                        return DataRow(
                          cells: [
                            DataCell(Text(data['name'] ?? '')),
                            DataCell(Text(price)),
                            DataCell(Text(quantity)),
                            DataCell(Text(size)),
                            DataCell(Text(unit)),
                            DataCell(
                              imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, width: 50, fit: BoxFit.cover)
                                  : const Text('No image'),
                            ),
                          ],
                        );
                      }).toList();
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
