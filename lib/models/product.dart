class Product {
  final String id, name, brand, description, sku, category;
  final int price, discountPrice, stock, reviews;
  final double rating;
  final Map<String, String> specifications;
  final List<String> images;
  final bool featured, bestSeller;
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.sku,
    required this.category,
    required this.price,
    required this.discountPrice,
    required this.stock,
    required this.reviews,
    required this.rating,
    required this.specifications,
    required this.images,
    required this.featured,
    required this.bestSeller,
  });
  int get effectivePrice => discountPrice > 0 ? discountPrice : price;
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'],
    brand: j['brand'],
    description: j['description'],
    sku: j['sku'],
    category: j['category'],
    price: j['price'],
    discountPrice: j['discountPrice'],
    stock: j['stock'],
    reviews: j['reviews'],
    rating: (j['rating'] as num).toDouble(),
    specifications: Map<String, String>.from(j['specifications']),
    images: List<String>.from(j['images']),
    featured: j['featured'],
    bestSeller: j['bestSeller'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'description': description,
    'sku': sku,
    'category': category,
    'price': price,
    'discountPrice': discountPrice,
    'stock': stock,
    'reviews': reviews,
    'rating': rating,
    'specifications': specifications,
    'images': images,
    'featured': featured,
    'bestSeller': bestSeller,
  };
  Product copyWith({int? stock}) =>
      Product.fromJson({...toJson(), 'stock': stock ?? this.stock});
}
