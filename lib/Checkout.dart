import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localproject/confromationpage.dart';

class Checkout extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems; // Pass cart items as a parameter
  final String shopId;
  const Checkout({super.key, required this.cartItems, required this.shopId});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  String _address = ''; // To store the fetched address
  String _paymentMethod = 'Cash on Delivery'; // Default payment method

  @override
  void initState() {
    super.initState();
    _fetchUserAddress();
  }

  Future<void> _fetchUserAddress() async {
    // Get the current user ID from Firebase Auth
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      // Fetch user address from Firebase Firestore
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        var userData = userDoc.data();
        if (userData != null) {
          setState(() {
            _address = userData['address'] ?? ''; // Set the address if it exists
          });
        }
      }
    } else {
      // Handle the case where the user is not authenticated
      print('No user is currently signed in.');
    }
  }

  Future<void> _placeOrder() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('User not logged in.');
        return;
      }

      // Group cart items by shop ID
      final shopOrders = <String, List<Map<String, dynamic>>>{};
      for (var item in widget.cartItems) {
        final shopId = item['shopId'] as String?;
        if (shopId == null) {
          print('Shop ID is missing in item: $item');
          continue; // Skip items with missing shop ID
        }
        if (!shopOrders.containsKey(shopId)) {
          shopOrders[shopId] = [];
        }
        shopOrders[shopId]!.add(item);
      }

      String? lastOrderId;

      // Place orders for each shop
      for (var shopId in shopOrders.keys) {
        // Generate a new order ID for this shop
        final orderId = FirebaseFirestore.instance.collection('orders').doc().id;
        lastOrderId = orderId; // Store the last order ID

        // Calculate total price for this shop
        final totalPrice = shopOrders[shopId]!.fold<double>(
          0.0,
              (sum, item) {
            final price = item['price'] as double?;
            final quantity = item['quantity'] as int?;
            if (price == null || quantity == null) {
              print('Price or quantity is missing in item: $item');
              return sum;
            }
            return sum + price * quantity;
          },
        );

        // Create order data
        final orderData = {
          'orderId': orderId,
          'userId': userId,
          'shopId': shopId,
          'products': shopOrders[shopId]!.map((item) {
            return {
              'productId': item['productId'],
              'name': item['name'],
              'price': item['price'],
              'quantity': item['quantity'],
              'size': item['size'],
            };
          }).toList(),
          'totalPrice': totalPrice,
          'orderDate': Timestamp.now(),
          'orderStatus': 'Pending', // Initial status
          'deliveryAddress': _address,
        };

        // Save order to Firestore under the relevant shop
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('orders')
            .doc(orderId)
            .set(orderData);

        // Save order data in the user's orders subcollection
        final userOrderData = {
          'orderId': orderId,
          'shopId': shopId,
          'totalPrice': totalPrice,
          'products': shopOrders[shopId]!.map((item) {
            return {
              'productId': item['productId'],
              'name': item['name'],
              'price': item['price'],
              'quantity': item['quantity'],
              'size': item['size'],
            };
          }).toList(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .set(userOrderData);
      }

      // Notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      if (lastOrderId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(orderId: lastOrderId!),
          ),
        );
      }
    } catch (e) {
      print('Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to place order. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Text(
              'Order Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.cartItems.length,
                itemBuilder: (context, index) {
                  var item = widget.cartItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 4.0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      title: Text(item['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity: ${item['quantity']}'),
                          Text('Size: ${item['size']}'),
                          Text('Price: ₹${item['price']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Shipping Information
            const SizedBox(height: 20),
            Text(
              'Shipping Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _address.isNotEmpty ? _address : 'Fetching address...',
              style: const TextStyle(fontSize: 16),
            ),
            // Payment Information
            const SizedBox(height: 20),
            Text(
              'Payment Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: ['Cash on Delivery', 'Credit Card', 'Online Payment']
                  .map((method) => DropdownMenuItem(
                value: method,
                child: Text(method),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value ?? 'Cash on Delivery';
                });
              },
              decoration: const InputDecoration(
                labelText: 'Payment Method',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a payment method';
                }
                return null;
              },
            ),
            // Place Order Button
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _placeOrder, // Call _placeOrder when button is pressed
              child: const Text('Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}
