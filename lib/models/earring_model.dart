/// Data class representing a single earring item.
class EarringModel {
  final String id;
  final String name;
  final double price;

  /// URL / asset path to the earring image (PNG or GIF).
  /// This is the primary display asset used by EarringOverlay.
  final String imageUrl;

  /// Legacy GLB model URL kept for backward-compat with API responses.
  final String modelUrl;

  final String thumbnail;
  final String category;
  final int popularity;

  const EarringModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.modelUrl = '',
    required this.thumbnail,
    required this.category,
    required this.popularity,
  });

  factory EarringModel.fromJson(Map<String, dynamic> json) {
    return EarringModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? json['modelUrl'] ?? '',
      modelUrl: json['modelUrl'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      category: json['category'] ?? '',
      popularity: json['popularity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'modelUrl': modelUrl,
        'thumbnail': thumbnail,
        'category': category,
        'popularity': popularity,
      };
}

/// Fallback local earrings — used when backend is unavailable.
/// Points to PNG assets bundled with the app.
final List<EarringModel> kFallbackEarrings = [
  const EarringModel(
    id: '1',
    name: 'Gold Jhumka',
    price: 2499,
    imageUrl: 'assets/earrings/earring1.png',
    thumbnail: 'assets/earrings/earring1.png',
    category: 'Traditional',
    popularity: 95,
  ),
  const EarringModel(
    id: '2',
    name: 'Diamond Drops',
    price: 5999,
    imageUrl: 'assets/earrings/earring2.png',
    thumbnail: 'assets/earrings/earring2.png',
    category: 'Modern',
    popularity: 88,
  ),
  const EarringModel(
    id: '3',
    name: 'Pearl Studs',
    price: 1299,
    imageUrl: 'assets/earrings/earring3.png',
    thumbnail: 'assets/earrings/earring3.png',
    category: 'Classic',
    popularity: 79,
  ),
  const EarringModel(
    id: '4',
    name: 'Ruby Danglers',
    price: 3499,
    imageUrl: 'assets/earrings/earring4.png',
    thumbnail: 'assets/earrings/earring4.png',
    category: 'Statement',
    popularity: 84,
  ),
  const EarringModel(
    id: '5',
    name: 'Silver Hoops',
    price: 899,
    imageUrl: 'assets/earrings/earring5.png',
    thumbnail: 'assets/earrings/earring5.png',
    category: 'Modern',
    popularity: 91,
  ),
];
