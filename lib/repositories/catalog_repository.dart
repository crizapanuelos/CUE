import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/local_store.dart';

class CatalogRepository {
  final LocalStore store;
  CatalogRepository(this.store);
  Future<List<Product>> load() async {
    final bundled =
        jsonDecode(await rootBundle.loadString('lib/data/products.json'))
            as List;
    final envelope = store.read('commerce', {}) as Map;
    final saved = envelope['products'] ?? store.read('products', bundled);
    final bundledById = {for (final item in bundled) item['id']: item};
    // Preserve edited inventory and basket IDs while upgrading the original media.
    final data = (saved as List).map((raw) {
      final item = Map<String, dynamic>.from(raw);
      if (envelope['mediaRevision'] != 2 &&
          bundledById.containsKey(item['id'])) {
        item['images'] = bundledById[item['id']]['images'];
        item['description'] = bundledById[item['id']]['description'];
      }
      // Upgrade older custom listings that selected an illustration.
      if ((item['images'] as List).any(
        (path) => path.toString().endsWith('.svg'),
      )) {
        final match = bundled.firstWhere(
          (p) => p['category'] == item['category'],
          orElse: () => bundled.first,
        );
        item['images'] = match['images'];
      }
      return item;
    }).toList();
    return data
        .map((j) => Product.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }
}
