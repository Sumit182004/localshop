import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopAdminOrderPage extends StatefulWidget {
  const ShopAdminOrderPage({super.key});

  @override
  _ShopAdminOrderPageState createState() => _ShopAdminOrderPageState();
}

class _ShopAdminOrderPageState extends State<ShopAdminOrderPage> {
  String shopId = ''; // Initialize shopId

  @override
  void initState() {
    super.initState();
    _fetchShopId();
  }

  Future<void> _fetchShopId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Handle the case when the user is not logged in
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          shopId = data?['shop_id'] ?? ''; // Retrieve the shop_id field
        });
      } else {
        print('User document does not exist.');
      }
    } catch (e) {
      print('Error fetching shop ID: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      if (shopId.isEmpty) {
        print('Shop ID is not set.');
        return;
      }
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .update({
        'orderStatus': status,
      });
      print('Order status updated to $status');
      setState(() {}); // Refresh the order list
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  Future<void> updateProductQuantity(String orderId, String action) async {
    try {
      if (shopId.isEmpty) {
        print('Shop ID is not set.');
        return;
      }

      final orderDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        print('Order document does not exist.');
        return;
      }

      final orderData = orderDoc.data();
      final products = orderData?['products'] as List<dynamic>? ?? [];

      for (var product in products) {
        final productId = product['product_id'];
        final quantity = product['quantity'];
        final size = product['size']; // Assuming size is part of the order data

        print(
            'Updating product $productId (Size: $size) with quantity $quantity');

        final productRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(productId);

        // Retrieve current product data to verify correct quantity
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final productData = productDoc.data();
          final variations = productData?['variations'] as List<dynamic>? ?? [];

          // Find the variation matching the size
          for (var variation in variations) {
            if (variation['size'] == size) {
              final currentQuantity = variation['quantity'] as int? ?? 0;

              if (action == 'decrement') {
                if (currentQuantity >= quantity) {
                  await productRef.update({
                    'variations': FieldValue.arrayUnion([
                      {
                        'size': size,
                        'quantity': currentQuantity - quantity,
                      }
                    ])
                  });
                  print(
                      'Product $productId (Size: $size) quantity decremented by $quantity');
                } else {
                  print(
                      'Not enough stock for product $productId (Size: $size)');
                }
              }
              break; // Exit loop once the matching size is found
            }
          }
        } else {
          print('Product document $productId does not exist.');
        }
      }
    } catch (e) {
      print('Error updating product quantities: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Orders"),
      ),
      body: shopId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('orders')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Snapshot error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('No orders available.');
            return const Center(child: Text('No orders available.'));
          }

          final orders = snapshot.data!.docs.where((doc) {
            final status = doc['orderStatus'];
            print('Order status: $status'); // Debugging line
            return status == 'Pending' ||
                status == 'Confirmed'; // Filter orders
          }).toList();

          print('Filtered orders: ${orders.length}'); // Debugging line

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final products = data['products'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Order ID: ${order.id}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Products:'),
                      ...products.map((product) {
                        final productId = product['product_id'];
                        final size = product['size'];
                        final quantity = product['quantity'];
                        final price = product['price'];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product ID: $productId'),
                            Text('Size: $size'),
                            Text('Price: \$${price.toString()}'),
                            Text('Quantity: $quantity'),
                            SizedBox(height: 10),
                            // Add some spacing between products
                          ],
                        );
                      }).toList(),
                      Text('Status: ${data['orderStatus']}'),
                      // Add more details about the order here if needed
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data['orderStatus'] == 'Pending') ...[
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) =>
                                  AlertDialog(
                                    title: const Text('Confirm Order'),
                                    content: const Text(
                                        'Are you sure you want to confirm this order?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              await updateOrderStatus(order.id, 'Confirmed');
                              await updateProductQuantity(
                                  order.id, 'decrement');
                            }
                          },
                        ),
                      ],
                      if (data['orderStatus'] == 'Confirmed') ...[
                        IconButton(
                          icon: const Icon(
                              Icons.delivery_dining, color: Colors.blue),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) =>
                                  AlertDialog(
                                    title: const Text('Mark as Delivered'),
                                    content: const Text(
                                        'Are you sure you want to mark this order as delivered?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Deliver'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              await updateOrderStatus(order.id, 'Delivered');
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}