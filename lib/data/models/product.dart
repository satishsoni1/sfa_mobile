class Product {
  final int id;
  final String name;
  final String? type;

  Product({required this.id, required this.name, this.type});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['brand_id'],
      name: json['brand'],
      type: json['description'],
    );
  }
}