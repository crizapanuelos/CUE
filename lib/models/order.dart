import 'product.dart';

const orderStatuses = [
  'Pending',
  'Processing',
  'Packed',
  'Shipped',
  'Out for Delivery',
  'Delivered',
];

class OrderLine {
  final Product product;
  final int quantity;
  const OrderLine(this.product, this.quantity);
  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };
  factory OrderLine.fromJson(Map<String, dynamic> j) =>
      OrderLine(Product.fromJson(j['product']), j['quantity']);
}

class ShopOrder {
  final String id, owner, payment;
  final DateTime created;
  final List<OrderLine> lines;
  final Map<String, String> delivery;
  final int subtotal, discount, shipping, tax, total, status;
  const ShopOrder({
    required this.id,
    required this.owner,
    required this.payment,
    required this.created,
    required this.lines,
    required this.delivery,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.tax,
    required this.total,
    this.status = 0,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner': owner,
    'payment': payment,
    'created': created.toIso8601String(),
    'lines': lines.map((l) => l.toJson()).toList(),
    'delivery': delivery,
    'subtotal': subtotal,
    'discount': discount,
    'shipping': shipping,
    'tax': tax,
    'total': total,
    'status': status,
  };
  factory ShopOrder.fromJson(Map<String, dynamic> j) => ShopOrder(
    id: j['id'],
    owner: j['owner'],
    payment: j['payment'],
    created: DateTime.parse(j['created']),
    lines: (j['lines'] as List).map((l) => OrderLine.fromJson(l)).toList(),
    delivery: Map<String, String>.from(j['delivery']),
    subtotal: j['subtotal'],
    discount: j['discount'],
    shipping: j['shipping'],
    tax: j['tax'],
    total: j['total'],
    status: j['status'],
  );
  ShopOrder advance() =>
      ShopOrder.fromJson({...toJson(), 'status': status < 5 ? status + 1 : 5});
}
