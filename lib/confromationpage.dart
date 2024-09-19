import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localproject/Orderhistorypage.dart';
import 'package:localproject/hompage.dart';

class ConfirmationPage extends StatefulWidget {
  final String orderId;
  const ConfirmationPage({super.key, required this.orderId});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = _getOrderStream();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getOrderStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _orderStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('Order not found.'));
            }

            final orderData = snapshot.data!.data()!;
            final status = orderData['orderStatus'] ?? 'Pending';
            final totalPrice = orderData['totalPrice']?.toStringAsFixed(2) ?? '0.00';
            final address = orderData['deliveryAddress'] ?? '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thank you for your order!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Order ID: ${widget.orderId}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'Status: $status',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('Total Price: ₹$totalPrice'),
                Text('Delivery Address: $address'),
                const SizedBox(height: 20),
                if (status == 'Pending') ...[
                  Text(
                    'Estimated Delivery Time',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('You will be notified once the order is accepted and estimated delivery time will be updated.'),
                ],
                if (status == 'Accepted') ...[
                  Text(
                    'Your order has been accepted!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
                if (status == 'Delivered') ...[
                  Text(
                    'Your order has been delivered!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
                if (status == 'Rejected') ...[
                  Text(
                    'Your order was rejected.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Homepage(),
                      ),
                    );
                  },
                  child: const Text('Continue Shopping'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryPage(),
                      ),
                    );
                  },
                  child: const Text('View Orders'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
