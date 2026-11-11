import '../models/order.dart';
import '../models/product.dart';

/// Upgrade only image references. Historical order values remain immutable.
ShopOrder upgradeOrderMedia(ShopOrder order, List<Product> catalog) {
  final lines = order.lines.map((line) {
    final p = line.product;
    if (!p.images.any((path) => path.endsWith('.svg'))) {
      return line.toJson();
    }
    final numeric = RegExp(r'^BH(\d{2})(\d{3})$').firstMatch(p.id);
    final category = numeric == null ? 0 : int.parse(numeric.group(1)!);
    final item = numeric == null ? 0 : int.parse(numeric.group(2)!);
    final photo = category >= 1 && category <= 14 && item >= 1 && item <= 10
        ? 'assets/photos/${p.id}.jpg'
        : catalog
                  .where((entry) => entry.category == p.category)
                  .firstOrNull
                  ?.images
                  .first ??
              'assets/photos/BH11001.jpg';
    return {
      ...line.toJson(),
      'product': {
        ...p.toJson(),
        'images': [photo],
      },
    };
  }).toList();
  return ShopOrder.fromJson({...order.toJson(), 'lines': lines});
}
