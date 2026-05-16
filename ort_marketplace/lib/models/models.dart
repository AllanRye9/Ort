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
    this.nationality,
    this.residingCountry,
    this.userUid,
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
  final String? nationality;
  final String? residingCountry;
  final String? userUid;
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
        nationality: j['nationality'] as String?,
        residingCountry: j['residing_country'] as String?,
        userUid: j['user_uid'] as String?,
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

class AgentProfileModel {
  const AgentProfileModel({
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
    this.userUid,
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
  final String? userUid;

  String get fullName => '$firstName $lastName';

  factory AgentProfileModel.fromJson(Map<String, dynamic> j) =>
      AgentProfileModel(
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
        userUid: j['user_uid'] as String?,
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
    this.pricingType = 'negotiable',
    this.bedrooms,
    this.bathrooms,
    this.areaSqft,
    required this.status,
    required this.createdAt,
    this.imageUrls = const [],
    this.agentId,
    this.latitude,
    this.longitude,
    this.country,
    this.plotLengthM,
    this.plotWidthM,
    this.landCategory,
    this.landAreaAcres,
    // Extended fields
    this.propertyAge,
    this.furnishing,
    this.purpose,
    this.amenities,
    this.floors,
    this.buildingName,
    this.parkingSpaces,
    this.listingCode,
    this.agentProfile,
  });

  final int id;
  final String title;
  final String? description;
  final String propertyType;
  final String address;
  final String? city;
  final double price;
  final String pricingType;
  final int? bedrooms;
  final int? bathrooms;
  final int? areaSqft;
  final String status;
  final DateTime createdAt;
  final List<String> imageUrls;
  final int? agentId;
  final double? latitude;
  final double? longitude;

  /// Country name detected at listing creation time (e.g. "Uganda").
  final String? country;

  /// Plot length in metres (Uganda metric measurement).
  final double? plotLengthM;

  /// Plot width in metres (Uganda metric measurement).
  final double? plotWidthM;

  /// Land sub-category (farmland, residential, industrial, other).
  final String? landCategory;

  /// Land area in acres for land type properties.
  final double? landAreaAcres;

  // Extended listing fields
  final int? propertyAge;
  final String? furnishing;
  final String? purpose;
  final List<String>? amenities;
  final int? floors;
  final String? buildingName;
  final int? parkingSpaces;
  final String? listingCode;
  final AgentProfileModel? agentProfile;

  /// Whether this is a Uganda listing using metric L×W measurement.
  bool get isUgandaMetric => plotLengthM != null && plotWidthM != null;

  /// Computed total area in m² for Uganda listings.
  double? get totalAreaM2 =>
      isUgandaMetric ? plotLengthM! * plotWidthM! : null;

  factory PropertyModel.fromJson(Map<String, dynamic> j) => PropertyModel(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        propertyType: (j['property_type'] as String?) ?? 'house',  // 'house' is a valid property_types enum value
        address: j['address'] as String,
        city: j['city'] as String?,
        price: double.parse(j['price'].toString()),
        pricingType: (j['pricing_type'] as String?) ?? 'negotiable',
        bedrooms: j['bedrooms'] as int?,
        bathrooms: j['bathrooms'] as int?,
        areaSqft: j['area_sqft'] as int?,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
        imageUrls: (j['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
        agentId: j['agent_id'] as int?,
        latitude: j['latitude'] != null ? double.parse(j['latitude'].toString()) : null,
        longitude: j['longitude'] != null ? double.parse(j['longitude'].toString()) : null,
        country: j['country'] as String?,
        plotLengthM: j['plot_length_m'] != null ? double.parse(j['plot_length_m'].toString()) : null,
        plotWidthM: j['plot_width_m'] != null ? double.parse(j['plot_width_m'].toString()) : null,
        landCategory: j['land_category'] as String?,
        landAreaAcres: j['land_area_acres'] != null ? double.parse(j['land_area_acres'].toString()) : null,
        propertyAge: j['property_age'] as int?,
        furnishing: j['furnishing'] as String?,
        purpose: j['purpose'] as String?,
        amenities: (j['amenities'] as List<dynamic>?)?.cast<String>(),
        floors: j['floors'] as int?,
        buildingName: j['building_name'] as String?,
        parkingSpaces: j['parking_spaces'] as int?,
        listingCode: j['listing_code'] as String?,
        agentProfile: j['agent_profile'] != null
            ? AgentProfileModel.fromJson(j['agent_profile'] as Map<String, dynamic>)
            : null,
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
    this.pricingType = 'negotiable',
    this.currency = 'UGX',
    this.qualityGrade,
    this.certification,
    this.location,
    this.latitude,
    this.longitude,
    this.isPerishable = false,
    this.images,
    this.storageConditions,
    required this.status,
    required this.createdAt,
    this.listingCode,
    this.ownerProfile,
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
  final String pricingType;
  final String currency;
  final String? qualityGrade;
  final String? certification;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isPerishable;
  final List<String>? images;
  final String? storageConditions;
  final String status;
  final DateTime createdAt;
  final String? listingCode;
  final AgentProfileModel? ownerProfile;

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
        pricingType: (j['pricing_type'] as String?) ?? 'negotiable',
        currency: j['currency'] as String? ?? 'UGX',
        qualityGrade: j['quality_grade'] as String?,
        certification: j['certification'] as String?,
        location: j['location'] as String?,
        latitude: j['latitude'] != null ? double.parse(j['latitude'].toString()) : null,
        longitude: j['longitude'] != null ? double.parse(j['longitude'].toString()) : null,
        isPerishable: j['is_perishable'] as bool? ?? false,
        images: (j['images'] as List<dynamic>?)?.cast<String>(),
        storageConditions: j['storage_conditions'] as String?,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
        listingCode: j['listing_code'] as String?,
        ownerProfile: j['owner_profile'] != null
            ? AgentProfileModel.fromJson(j['owner_profile'] as Map<String, dynamic>)
            : null,
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
    this.pricingType = 'negotiable',
    this.currency = 'UGX',
    this.certifications,
    this.images,
    this.leadTimeDays,
    this.isLocallyMade = true,
    this.countryOfOrigin,
    this.location,
    this.latitude,
    this.longitude,
    required this.status,
    required this.createdAt,
    this.listingCode,
    this.ownerProfile,
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
  final String pricingType;
  final String currency;
  final List<String>? certifications;
  final List<String>? images;
  final int? leadTimeDays;
  final bool isLocallyMade;
  final String? countryOfOrigin;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String status;
  final DateTime createdAt;
  final String? listingCode;
  final AgentProfileModel? ownerProfile;

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
        pricingType: (j['pricing_type'] as String?) ?? 'negotiable',
        currency: j['currency'] as String? ?? 'UGX',
        certifications:
            (j['certifications'] as List<dynamic>?)?.cast<String>(),
        images: (j['images'] as List<dynamic>?)?.cast<String>(),
        leadTimeDays: j['lead_time_days'] as int?,
        isLocallyMade: j['is_locally_made'] as bool? ?? true,
        countryOfOrigin: j['country_of_origin'] as String?,
        location: j['location'] as String?,
        latitude: j['latitude'] != null ? double.parse(j['latitude'].toString()) : null,
        longitude: j['longitude'] != null ? double.parse(j['longitude'].toString()) : null,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
        listingCode: j['listing_code'] as String?,
        ownerProfile: j['owner_profile'] != null
            ? AgentProfileModel.fromJson(j['owner_profile'] as Map<String, dynamic>)
            : null,
      );
}

class ManufacturingServiceModel {
  const ManufacturingServiceModel({
    required this.id,
    this.tenantId,
    required this.title,
    this.description,
    this.serviceType,
    required this.price,
    this.pricingType = 'negotiable',
    this.pricingUnit,
    this.currency = 'UGX',
    this.minOrderValue,
    this.noticePeriodDays,
    this.certifications,
    this.images,
    this.location,
    this.country,
    this.latitude,
    this.longitude,
    required this.status,
    required this.createdAt,
    this.listingCode,
    this.ownerProfile,
  });

  final int id;
  final int? tenantId;
  final String title;
  final String? description;
  final String? serviceType;
  final double price;
  final String pricingType;
  final String? pricingUnit;
  final String currency;
  final double? minOrderValue;
  final int? noticePeriodDays;
  final List<String>? certifications;
  final List<String>? images;
  final String? location;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String status;
  final DateTime createdAt;
  final String? listingCode;
  final AgentProfileModel? ownerProfile;

  factory ManufacturingServiceModel.fromJson(Map<String, dynamic> j) =>
      ManufacturingServiceModel(
        id: j['id'] as int,
        tenantId: j['tenant_id'] as int?,
        title: j['title'] as String,
        description: j['description'] as String?,
        serviceType: j['service_type'] as String?,
        price: double.parse(j['price'].toString()),
        pricingType: (j['pricing_type'] as String?) ?? 'negotiable',
        pricingUnit: j['pricing_unit'] as String?,
        currency: j['currency'] as String? ?? 'UGX',
        minOrderValue: j['min_order_value'] != null
            ? double.parse(j['min_order_value'].toString())
            : null,
        noticePeriodDays: j['notice_period_days'] as int?,
        certifications:
            (j['certifications'] as List<dynamic>?)?.cast<String>(),
        images: (j['images'] as List<dynamic>?)?.cast<String>(),
        location: j['location'] as String?,
        country: j['country'] as String?,
        latitude: j['latitude'] != null
            ? double.parse(j['latitude'].toString())
            : null,
        longitude: j['longitude'] != null
            ? double.parse(j['longitude'].toString())
            : null,
        status: (j['status'] as String?) ?? 'available',
        createdAt: DateTime.parse(j['created_at'] as String),
        listingCode: j['listing_code'] as String?,
        ownerProfile: j['owner_profile'] != null
            ? AgentProfileModel.fromJson(j['owner_profile'] as Map<String, dynamic>)
            : null,
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
    this.location,
    this.propertyId,
    this.orderId,
    required this.createdAt,
  });

  final int id;
  final int? initiatorId;
  final int? recipientId;
  final String? subject;
  final String? location;
  final int? propertyId;
  final int? orderId;
  final DateTime createdAt;

  factory ConversationModel.fromJson(Map<String, dynamic> j) =>
      ConversationModel(
        id: j['id'] as int,
        initiatorId: j['initiator_id'] as int?,
        recipientId: j['recipient_id'] as int?,
        subject: j['subject'] as String?,
        location: j['location'] as String?,
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
    this.attachmentFilename,
    required this.messageType,
    required this.isRead,
    required this.sentAt,
  });

  final int id;
  final int conversationId;
  final int? senderId;
  final String body;
  final String? attachmentUrl;
  final String? attachmentFilename;
  final String messageType;
  final bool isRead;
  final DateTime sentAt;

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as int,
        conversationId: j['conversation_id'] as int,
        senderId: j['sender_id'] as int?,
        body: j['body'] as String,
        attachmentUrl: j['attachment_url'] as String?,
        attachmentFilename: j['attachment_filename'] as String?,
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

class WalletModel {
  const WalletModel({
    required this.id,
    required this.userId,
    required this.points,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final int points;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory WalletModel.fromJson(Map<String, dynamic> j) => WalletModel(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        points: j['points'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] != null
            ? DateTime.parse(j['updated_at'] as String)
            : null,
      );
}

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.transactionType,
    required this.amount,
    this.paymentMethod,
    this.reference,
    this.description,
    required this.createdAt,
  });

  final int id;
  final int walletId;
  final String transactionType;
  final int amount;
  final String? paymentMethod;
  final String? reference;
  final String? description;
  final DateTime createdAt;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> j) =>
      WalletTransactionModel(
        id: j['id'] as int,
        walletId: j['wallet_id'] as int,
        transactionType: j['transaction_type'] as String? ?? 'topup',
        amount: j['amount'] as int,
        paymentMethod: j['payment_method'] as String?,
        reference: j['reference'] as String?,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AdPromotionModel {
  const AdPromotionModel({
    required this.id,
    required this.userId,
    required this.listingType,
    required this.listingId,
    required this.durationDays,
    required this.costPoints,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String listingType;
  final int listingId;
  final int durationDays;
  final int costPoints;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;

  factory AdPromotionModel.fromJson(Map<String, dynamic> j) => AdPromotionModel(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        listingType: j['listing_type'] as String,
        listingId: j['listing_id'] as int,
        durationDays: j['duration_days'] as int,
        costPoints: j['cost_points'] as int,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        status: j['status'] as String? ?? 'active',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}


class ProductTrackingModel {
  const ProductTrackingModel({
    required this.id,
    this.orderId,
    this.listingType,
    this.listingId,
    required this.status,
    this.location,
    this.description,
    this.createdByUserId,
    required this.createdAt,
  });

  final int id;
  final int? orderId;
  final String? listingType;
  final int? listingId;
  final String status;
  final String? location;
  final String? description;
  final int? createdByUserId;
  final DateTime createdAt;

  factory ProductTrackingModel.fromJson(Map<String, dynamic> j) =>
      ProductTrackingModel(
        id: j['id'] as int,
        orderId: j['order_id'] as int?,
        listingType: j['listing_type'] as String?,
        listingId: j['listing_id'] as int?,
        status: j['status'] as String,
        location: j['location'] as String?,
        description: j['description'] as String?,
        createdByUserId: j['created_by_user_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
