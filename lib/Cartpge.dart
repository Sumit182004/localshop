import 'package:flutter/material.dart';
import 'package:localproject/Checkout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Cartpage extends StatefulWidget {
  const Cartpage({super.key});

  @override
  State<Cartpage> createState() => _CartpageState();
}

class _CartpageState extends State<Cartpage> {
  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedCart = prefs.getStringList('cart');
    if (savedCart != null) {
      setState(() {
        cartItems = savedCart.map((item) {
          List<String> parts = item.split('|');
          if (parts.length >= 6) {
            return {
              'productId': parts[0],
              'name': parts[1],
              'price': double.tryParse(parts[2]) ?? 0.0,
              'quantity': int.tryParse(parts[3]) ?? 0,
              'shopId': parts[4], // Ensure shopId is retrieved
              'size': parts[5], // Retrieve size
            };
          } else {
            print('Invalid cart item format: $item');
            return {
              'productId': 'unknown',
              'name': 'Unknown',
              'price': 0.0,
              'quantity': 0,
              'shopId': 'unknown', // Default shopId
              'size': 'unknown', // Default size
            };
          }
        }).toList();
      });
    }
  }



  void _updateCart(String productId, int quantity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> updatedCart = cartItems
        .map((item) {
      if (item['productId'] == productId) {
        if (quantity > 0) {
          return {
            'productId': item['productId'],
            'name': item['name'],
            'price': item['price'],
            'quantity': quantity,
            'shopId': item['shopId'], // Ensure shopId is included
            'size': item['size'], // Ensure size is included
          };
        } else {
          return null; // Remove item
        }
      }
      return item;
    })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
    await prefs.setStringList('cart', updatedCart
        .map((item) => '${item['productId']}|${item['name']}|${item['price']}|${item['quantity']}|${item['shopId']}|${item['size']}') // Include size
        .toList());
    _loadCartItems(); // Refresh cart items
  }

  void _navigateToCheckout() {
    String shopId = cartItems[0]['shopId'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Checkout(cartItems: cartItems, shopId: shopId), // Pass cartItems to Checkout
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cart"),
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text('Your cart is empty.'))
                : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                var item = cartItems[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag), // Replace with actual product image if available
                    title: Text(item['name']),
                    subtitle: Text('Price: ₹${item['price']}\nSize: ${item['size']}'), // Display size here
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (item['quantity'] > 1) {
                              _updateCart(item['productId'], item['quantity'] - 1);
                            } else {
                              _updateCart(item['productId'], 0); // Remove item
                            }
                          },
                        ),
                        Text('${item['quantity']}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _updateCart(item['productId'], item['quantity'] + 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: cartItems.isEmpty ? null : _navigateToCheckout,  // Disable button if cart is empty
              child: const Text('Go to Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
