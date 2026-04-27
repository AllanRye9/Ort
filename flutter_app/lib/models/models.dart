/// Lightweight data models (plain Dart) for the marketplace app.
/// These mirror the backend Pydantic response schemas.

class UserModel {
  const UserModel({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.licenseNumber,
    this.agencyName,
    required this.createdAt,
  });

  final int id;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final String? licenseNumber;
  final String? agencyName;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as int,
        role: j['role'] as String,
        firstName: j['first_name'] as String,
        lastName: j['last_name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        bio: j['bio'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        licenseNumber: j['license_number'] as String?,
        agencyName: j['agency_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class TenantModel {
  const TenantModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.tenantType,
    this.description,
    this.logoUrl,
    this.website,
    this.phone,
    this.email,
    this.address,
    this.country,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String slug;
  final String tenantType;
  final String? description;
  final String? logoUrl;
  final String? website;
  final String? phone;
  final String? email;
  final String? address;
  final String? country;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;

  factory TenantModel.fromJson(Map<String, dynamic> j) => TenantModel(
        id: j['id'] as int,
        name: j['name'] as String,
        slug: j['slug'] as String,
        tenantType: j['tenant_type'] as String,
        description: j['description'] as String?,
        logoUrl: j['logo_url'] as String?,
        website: j['website'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        country: j['country'] as String?,
        isVerified: j['is_verified'] as bool? ?? false,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PropertyModel {
  const PropertyModel({
    required this.id,
    required this.title,
    this.description,
    required this.propertyType,
    required this.address,
    this.city,
    required this.price,
    this.bedrooms,
    this.bathrooms,
    this.areaSqft,
    required this.status,
    required this.createdAt,
    this.imageUrls = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String propertyType;
  final String address;
  final String? city;
  final double price;
  final int? bedrooms;
  final int? bathrooms;
  final int? areaSqft;
  final String status;
  final DateTime createdAt;
  final List<String> imageUrls;

  factory PropertyModel.fromJson(Map<String, dynamic> j) => PropertyModel(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        propertyType: (j['property_type'] as String?) ?? 'house',  // 'house' is a valid property_types enum value
        address: j['address'] as String,
        city: j['city'] as String?,
        price: double.parse(j['price'].toString()),
        bedrooms: j['bedrooms'] as int?,
        bathrooms: j['bathrooms'] as int?,
        areaSqft: j['area_sqft'] as int?,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
        imageUrls: (j['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

class AgricultureListingModel {
  const AgricultureListingModel({
    required this.id,
    this.tenantId,
    required this.title,
    this.description,
    this.category,
    this.commodityType,
    this.quantityAvailable,
    this.unit,
    this.moq,
    required this.pricePerUnit,
    this.currency = 'USD',
    this.qualityGrade,
    this.certification,
    this.location,
    this.isPerishable = false,
    this.images,
    this.storageConditions,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int? tenantId;
  final String title;
  final String? description;
  final String? category;
  final String? commodityType;
  final double? quantityAvailable;
  final String? unit;
  final double? moq;
  final double pricePerUnit;
  final String currency;
  final String? qualityGrade;
  final String? certification;
  final String? location;
  final bool isPerishable;
  final List<String>? images;
  final String? storageConditions;
  final String status;
  final DateTime createdAt;

  factory AgricultureListingModel.fromJson(Map<String, dynamic> j) =>
      AgricultureListingModel(
        id: j['id'] as int,
        tenantId: j['tenant_id'] as int?,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String?,
        commodityType: j['commodity_type'] as String?,
        quantityAvailable: j['quantity_available'] != null
            ? double.parse(j['quantity_available'].toString())
            : null,
        unit: j['unit'] as String?,
        moq: j['moq'] != null ? double.parse(j['moq'].toString()) : null,
        pricePerUnit: double.parse(j['price_per_unit'].toString()),
        currency: j['currency'] as String? ?? 'USD',
        qualityGrade: j['quality_grade'] as String?,
        certification: j['certification'] as String?,
        location: j['location'] as String?,
        isPerishable: j['is_perishable'] as bool? ?? false,
        images: (j['images'] as List<dynamic>?)?.cast<String>(),
        storageConditions: j['storage_conditions'] as String?,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ManufacturingProductModel {
  const ManufacturingProductModel({
    required this.id,
    this.tenantId,
    required this.title,
    this.description,
    this.category,
    this.sku,
    this.quantityAvailable,
    this.moq,
    this.unit,
    required this.wholesalePrice,
    this.currency = 'USD',
    this.certifications,
    this.images,
    this.leadTimeDays,
    this.isLocallyMade = true,
    this.countryOfOrigin,
    this.location,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int? tenantId;
  final String title;
  final String? description;
  final String? category;
  final String? sku;
  final int? quantityAvailable;
  final int? moq;
  final String? unit;
  final double wholesalePrice;
  final String currency;
  final List<String>? certifications;
  final List<String>? images;
  final int? leadTimeDays;
  final bool isLocallyMade;
  final String? countryOfOrigin;
  final String? location;
  final String status;
  final DateTime createdAt;

  factory ManufacturingProductModel.fromJson(Map<String, dynamic> j) =>
      ManufacturingProductModel(
        id: j['id'] as int,
        tenantId: j['tenant_id'] as int?,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String?,
        sku: j['sku'] as String?,
        quantityAvailable: j['quantity_available'] as int?,
        moq: j['moq'] as int?,
        unit: j['unit'] as String?,
        wholesalePrice: double.parse(j['wholesale_price'].toString()),
        currency: j['currency'] as String? ?? 'USD',
        certifications:
            (j['certifications'] as List<dynamic>?)?.cast<String>(),
        images: (j['images'] as List<dynamic>?)?.cast<String>(),
        leadTimeDays: j['lead_time_days'] as int?,
        isLocallyMade: j['is_locally_made'] as bool? ?? true,
        countryOfOrigin: j['country_of_origin'] as String?,
        location: j['location'] as String?,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    this.buyerUserId,
    this.sellerTenantId,
    required this.status,
    this.totalAmount,
    this.currency = 'USD',
    required this.paymentStatus,
    this.paymentMethod,
    this.deliveryAddress,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  final int id;
  final String orderNumber;
  final int? buyerUserId;
  final int? sellerTenantId;
  final String status;
  final double? totalAmount;
  final String currency;
  final String paymentStatus;
  final String? paymentMethod;
  final String? deliveryAddress;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: j['id'] as int,
        orderNumber: j['order_number'] as String,
        buyerUserId: j['buyer_user_id'] as int?,
        sellerTenantId: j['seller_tenant_id'] as int?,
        status: (j['status'] as String?) ?? 'pending',
        totalAmount: j['total_amount'] != null
            ? double.parse(j['total_amount'].toString())
            : null,
        currency: j['currency'] as String? ?? 'USD',
        paymentStatus: (j['payment_status'] as String?) ?? 'unpaid',
        paymentMethod: j['payment_method'] as String?,
        deliveryAddress: j['delivery_address'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    this.propertyId,
    this.agricultureListingId,
    this.manufacturingProductId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int id;
  final int? propertyId;
  final int? agricultureListingId;
  final int? manufacturingProductId;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
        id: j['id'] as int,
        propertyId: j['property_id'] as int?,
        agricultureListingId: j['agriculture_listing_id'] as int?,
        manufacturingProductId: j['manufacturing_product_id'] as int?,
        quantity: double.parse(j['quantity'].toString()),
        unitPrice: double.parse(j['unit_price'].toString()),
        subtotal: double.parse(j['subtotal'].toString()),
      );
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    this.initiatorId,
    this.recipientId,
    this.subject,
    this.propertyId,
    this.orderId,
    required this.createdAt,
  });

  final int id;
  final int? initiatorId;
  final int? recipientId;
  final String? subject;
  final int? propertyId;
  final int? orderId;
  final DateTime createdAt;

  factory ConversationModel.fromJson(Map<String, dynamic> j) =>
      ConversationModel(
        id: j['id'] as int,
        initiatorId: j['initiator_id'] as int?,
        recipientId: j['recipient_id'] as int?,
        subject: j['subject'] as String?,
        propertyId: j['property_id'] as int?,
        orderId: j['order_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.body,
    this.attachmentUrl,
    required this.messageType,
    required this.isRead,
    required this.sentAt,
  });

  final int id;
  final int conversationId;
  final int? senderId;
  final String body;
  final String? attachmentUrl;
  final String messageType;
  final bool isRead;
  final DateTime sentAt;

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as int,
        conversationId: j['conversation_id'] as int,
        senderId: j['sender_id'] as int?,
        body: j['body'] as String,
        attachmentUrl: j['attachment_url'] as String?,
        messageType: (j['message_type'] as String?) ?? 'text',
        isRead: j['is_read'] as bool? ?? false,
        sentAt: DateTime.parse(j['sent_at'] as String),
      );
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.notificationType,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String title;
  final String? body;
  final String? notificationType;
  final int? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        title: j['title'] as String,
        body: j['body'] as String?,
        notificationType: j['notification_type'] as String?,
        referenceId: j['reference_id'] as int?,
        referenceType: j['reference_type'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    this.reviewerId,
    this.reviewedAgentId,
    this.reviewedTenantId,
    required this.rating,
    this.title,
    this.body,
    required this.isVerifiedPurchase,
    required this.createdAt,
  });

  final int id;
  final int? reviewerId;
  final int? reviewedAgentId;
  final int? reviewedTenantId;
  final int rating;
  final String? title;
  final String? body;
  final bool isVerifiedPurchase;
  final DateTime createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> j) => ReviewModel(
        id: j['id'] as int,
        reviewerId: j['reviewer_id'] as int?,
        reviewedAgentId: j['reviewed_agent_id'] as int?,
        reviewedTenantId: j['reviewed_tenant_id'] as int?,
        rating: j['rating'] as int,
        title: j['title'] as String?,
        body: j['body'] as String?,
        isVerifiedPurchase: j['is_verified_purchase'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class SavedItemModel {
  const SavedItemModel({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.itemId,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String itemType;
  final int itemId;
  final DateTime createdAt;

  factory SavedItemModel.fromJson(Map<String, dynamic> j) => SavedItemModel(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        itemType: j['item_type'] as String,
        itemId: j['item_id'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
