import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localproject/Cartpge.dart';
import 'package:localproject/Orderhistorypage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<DocumentSnapshot> nearbyShops = []; // List to store shops fetched from Firebase
  int cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    fetchShopsBasedOnUserLocation();
    _loadCartItemCount();
  }

  Future<void> _loadCartItemCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cart = prefs.getStringList('cart') ?? [];
    setState(() {
      cartItemCount = cart.length;
    });
  }

  Future<void> fetchShopsBasedOnUserLocation() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    if (userId.isEmpty) {
      print('No user is currently logged in.');
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        double userLatitude = (userDoc.get('latitude') as num).toDouble();
        double userLongitude = (userDoc.get('longitude') as num).toDouble();

        QuerySnapshot shopsSnapshot = await FirebaseFirestore.instance.collection('shops').get();
        List<DocumentSnapshot> filteredShops = shopsSnapshot.docs.where((doc) {
          double shopLatitude = (doc.get('latitude') as num).toDouble();
          double shopLongitude = (doc.get('longitude') as num).toDouble();

          double distanceInMeters = Geolocator.distanceBetween(
              userLatitude, userLongitude, shopLatitude, shopLongitude);

          // Debugging statements
          print('User Coordinates: ($userLatitude, $userLongitude)');
          print('Shop Coordinates: ($shopLatitude, $shopLongitude)');
          print('Distance to ${doc.get('shop_name')}: $distanceInMeters meters');

          return distanceInMeters <= 2000; // 2km radius
        }).toList();

        setState(() {
          nearbyShops = filteredShops;
        });

        // Inform the user if no shops are found within the radius
        if (nearbyShops.isEmpty) {
          showNoShopsMessage();
        }
      } else {
        print('User document does not exist.');
        setState(() {
          nearbyShops = [];
        });
      }
    } catch (e) {
      print('Error fetching shops based on user location: ${e.toString()}');
    }
  }

  void showNoShopsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No shops are located within a 2km radius of your location.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void navigateToShopDetails(DocumentSnapshot shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailsPage(shop: shop),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    // Clear shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacementNamed(context, '/loginPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text("Nearby Shops"),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (cartItemCount > 0)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      child: Center(
                        child: Text(
                          '$cartItemCount',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Cartpage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${FirebaseAuth.instance.currentUser?.email ?? 'Guest'}',
                      style: const TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            ListTile(
              title: const Text('Order History'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
                );
              },
            ),
            ListTile(
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: nearbyShops.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: nearbyShops.length,
        itemBuilder: (context, index) {
          var shop = nearbyShops[index];
          String shopImageUrl = shop['image_url'] ?? ''; // Fetch image URL

          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                shopImageUrl.isNotEmpty
                    ? Image.network(
                  shopImageUrl,
                  width: 150, // Adjust width for image size
                  height: 150, // Adjust height for image size
                  fit: BoxFit.cover,
                )
                    : const Icon(Icons.store, size: 150), // Fallback icon
                const SizedBox(width: 8.0), // Space between image and text
                Expanded(
                  child: ListTile(
                    title: Text(
                      shop['shop_name'] ?? 'No name',
                      style: const TextStyle(
                        fontSize: 18, // Adjust font size as needed
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => navigateToShopDetails(shop),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Shop details page
class ShopDetailsPage extends StatelessWidget {
  final DocumentSnapshot shop;

  const ShopDetailsPage({required this.shop, super.key});

  @override
  Widget build(BuildContext context) {
    String shopId = shop.id; // Get the shop ID
    String shopImageUrl = shop['image_url'] ?? ''; // Fetch image URL

    return Scaffold(
      appBar: AppBar(
        title: Text(shop['shop_name'] ?? 'Shop Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // Navigate to the Cart Page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Cartpage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shopImageUrl.isNotEmpty
                ? Image.network(
              shopImageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            )
                : const Icon(Icons.store, size: 300), // Fallback icon
            const SizedBox(height: 16),
            Text(
              shop['shop_name'] ?? 'No name',
              style: const TextStyle(
                fontSize: 24, // Adjust the font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("Address: ${shop['location'] ?? 'No address provided'}"),
            const SizedBox(height: 8),
            Text(
                "Contact Number: ${shop['contact_info'] ?? 'No contact number provided'}"),
            const SizedBox(height: 16),
            const Text(
              "Products:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: ProductList(shopId: shopId)), // Display products
          ],
        ),
      ),
    );
  }
}

class ProductList extends StatefulWidget {
  final String shopId;

  const ProductList({required this.shopId, super.key});

  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  Map<String, String> selectedSizes = {}; // Track selected size for each product

  void _addToCart(BuildContext context, String productId, String productName, double price, String selectedSize) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cart = prefs.getStringList('cart') ?? [];
    bool productExists = false;

    List<String> updatedCart = cart.map((item) {
      List<String> parts = item.split('|');
      if (parts.length >= 6 && parts[0] == productId && parts[5] == selectedSize) {
        productExists = true;
        int currentQuantity = int.parse(parts[3]);
        int newQuantity = currentQuantity + 1;
        return '$productId|$productName|$price|$newQuantity|${widget.shopId}|$selectedSize'; // Include size
      }
      return item;
    }).toList();

    if (!productExists) {
      updatedCart.add('$productId|$productName|$price|1|${widget.shopId}|$selectedSize'); // Include size
    }

    await prefs.setStringList('cart', updatedCart);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$productName ($selectedSize) added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var products = snapshot.data!.docs;

        if (products.isEmpty) {
          return const Center(child: Text('No products available.'));
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            var product = products[index];
            var variations = product['variations'] as List<dynamic>;

            // Default to the first variation's price and size
            String selectedSize = selectedSizes[product.id] ?? variations[0]['size'];
            double selectedPrice = variations.firstWhere((v) => v['size'] == selectedSize)['price'].toDouble();

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    leading: product['image'] != null
                        ? Image.network(
                      product['image'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                        : const Icon(Icons.shopping_bag),
                    title: Text(product['name'] ?? 'No name'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price: ₹$selectedPrice',
                          style: const TextStyle(
                            fontSize: 15, // Make price font size bigger
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Size: ', // Add "Size" label in front of dropdown
                              style: TextStyle(fontSize: 16),
                            ),
                            DropdownButton<String>(
                              value: selectedSize,
                              items: variations.map<DropdownMenuItem<String>>((variation) {
                                return DropdownMenuItem<String>(
                                  value: variation['size'],
                                  child: Text('${variation['size']} '),
                                );
                              }).toList(),
                              onChanged: (newSize) {
                                setState(() {
                                  selectedSizes[product.id] = newSize!;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => _addToCart(
                        context,
                        product.id,
                        product['name'],
                        selectedPrice,
                        selectedSize,
                      ),
                    ),
                  ),
                ],
              ),
            );

          },
        );
      },
    );
  }
}
