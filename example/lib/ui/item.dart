class Item {
  final String producto;
  final double cantidad;
  final double precio;

  Item({
    required this.producto,
    required this.cantidad,
    required this.precio,
  });

  Item copyWith({
    String? producto,
    double? cantidad,
    double? precio,
  }) =>
      Item(
        producto: producto ?? this.producto,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
      );

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        producto: json["producto"],
        cantidad: json["cantidad"],
        precio: json["precio"],
      );

  Map<String, dynamic> toJson() => {
        "producto": producto,
        "cantidad": cantidad,
        "precio": precio,
      };
}
