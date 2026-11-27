import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cart_models.dart';

enum AddressTag { home, work, other }

class Address {
  const Address({
    required this.id,
    required this.tag,
    required this.name,
    required this.phone,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.pincode,
  });

  factory Address.fromJson(Map json) => Address(
        id: '${json['id'] ?? ''}',
        tag: AddressTag.values.firstWhere(
          (t) => t.name == '${json['tag']}'.toLowerCase(),
          orElse: () => AddressTag.other,
        ),
        name: '${json['name'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        line1: '${json['line1'] ?? ''}',
        line2: json['line2'] as String?,
        city: '${json['city'] ?? ''}',
        state: '${json['state'] ?? ''}',
        pincode: '${json['pincode'] ?? ''}',
      );

  final String id;
  final AddressTag tag;
  final String name;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;

  /// "Home" / "Work" / "Other", as the web stores it.
  String get tagLabel => '${tag.name[0].toUpperCase()}${tag.name.substring(1)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tagLabel,
        'name': name,
        'phone': phone,
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        'city': city,
        'state': state,
        'pincode': pincode,
      };
}

/// Delivery addresses. There is no address API yet, so, like the web app,
/// they live on the device (same keys as the web's localStorage).
class AddressStore {
  static const _key = 'petwork.addresses';
  static const _selectedKey = 'petwork.addresses.selected';

  Future<List<Address>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final list = jsonDecode(prefs.getString(_key) ?? '[]');
      return list is List
          ? list.whereType<Map>().map(Address.fromJson).toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Address> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(addresses.map((a) => a.toJson()).toList()));
  }

  Future<String?> selectedId() async =>
      (await SharedPreferences.getInstance()).getString(_selectedKey);

  Future<void> select(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, id);
    }
  }
}

/// Payment is cash on delivery only (UI only).
enum PaymentMode { cashOnDelivery }

class CheckoutService {
  /// TODO(backend): there is no place-order endpoint yet; the web app builds
  /// the invoice on the client. Wire this up once the backend adds one.
  /// Do not guess an endpoint.
  Future<void> placeOrder({
    required Cart cart,
    required Address address,
    PaymentMode paymentMode = PaymentMode.cashOnDelivery,
  }) {
    throw UnimplementedError(
        'Placing an order is not available yet: the backend has no endpoint for it.');
  }
}
