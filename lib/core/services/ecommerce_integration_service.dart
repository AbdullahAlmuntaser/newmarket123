class EcommerceIntegrationService {
  bool _isConnected = false;
  String? _storeUrl;
  String? _apiKey;

  bool get isConnected => _isConnected;
  String? get storeUrl => _storeUrl;
  String? get apiKey => _apiKey;

  Future<bool> connect(String storeUrl, String apiKey) async {
    try {
      _storeUrl = storeUrl;
      _apiKey = apiKey;
      _isConnected = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _storeUrl = null;
    _apiKey = null;
  }

  Future<List<OnlineOrder>> fetchOrders() async {
    if (!_isConnected) return [];
    return [];
  }

  Future<bool> syncProducts() async {
    if (!_isConnected) return false;
    return false;
  }

  Future<bool> updateInventory(String productId, int quantity) async {
    if (!_isConnected) return false;
    return false;
  }

  Future<bool> pushOrderToStore(OnlineOrder order) async {
    if (!_isConnected) return false;
    return false;
  }

  Future<Map<String, dynamic>> getStoreStats() async {
    if (!_isConnected) return {};
    return {
      'totalOrders': 0,
      'pendingOrders': 0,
      'totalSales': 0.0,
      'lastSync': null,
    };
  }

  Future<bool> testConnection() async {
    if (!_isConnected) return false;
    return true;
  }
}

class OnlineOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<OnlineOrderItem> items;
  final double total;
  final String status;
  final DateTime createdAt;

  OnlineOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toLocalOrder() {
    return {
      'onlineOrderId': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((e) => e.toMap()).toList(),
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class OnlineOrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  OnlineOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}

class EcommerceSettings {
  final String? storeUrl;
  final String? apiKey;
  final bool autoSync;
  final bool autoAcceptOrders;
  final bool syncInventory;

  EcommerceSettings({
    this.storeUrl,
    this.apiKey,
    this.autoSync = false,
    this.autoAcceptOrders = false,
    this.syncInventory = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'storeUrl': storeUrl,
      'apiKey': apiKey,
      'autoSync': autoSync,
      'autoAcceptOrders': autoAcceptOrders,
      'syncInventory': syncInventory,
    };
  }

  factory EcommerceSettings.fromJson(Map<String, dynamic> json) {
    return EcommerceSettings(
      storeUrl: json['storeUrl'],
      apiKey: json['apiKey'],
      autoSync: json['autoSync'] ?? false,
      autoAcceptOrders: json['autoAcceptOrders'] ?? false,
      syncInventory: json['syncInventory'] ?? false,
    );
  }
}