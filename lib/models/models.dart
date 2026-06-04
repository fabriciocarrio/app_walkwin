class User {
  final String id;
  final String name;
  final String email;
  final int peBalance;
  final int level;
  final int streakDays;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.peBalance,
    required this.level,
    required this.streakDays,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      peBalance:
          json['pe_balance'] ?? json['coins_balance'] ?? json['coins'] ?? 0,
      level: json['level'] ?? 1,
      streakDays: json['streak_days'] ?? json['streak'] ?? 0,
    );
  }
}

class Business {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int distanceM;
  final String? offer;
  final int offerCost;
  final int checkinRewardCoins;
  final int checkinRadiusMeters;
  final bool isActive;
  final bool isFeatured;
  final double? latitude;
  final double? longitude;
  final String? qrPayload;
  final bool checkedInToday;

  Business({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.distanceM,
    this.offer,
    required this.offerCost,
    this.checkinRewardCoins = 100,
    this.checkinRadiusMeters = 200,
    required this.isActive,
    this.isFeatured = false,
    this.latitude,
    this.longitude,
    this.qrPayload,
    this.checkedInToday = false,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'];
    final offerTitle = offer is Map<String, dynamic>
        ? (offer['title'] as String?)
        : json['offer'] as String?;
    final offerCost = offer is Map<String, dynamic>
        ? (offer['pe_cost'] as num?)?.toInt() ??
              (offer['coin_cost'] as num?)?.toInt() ??
              0
        : (json['pe_cost'] ??
              json['offer_pe_cost'] ??
              json['offer_cost'] ??
              json['offer_coin_cost'] ??
              0);

    return Business(
      id: json['id']?.toString() ?? '',
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      distanceM: ((json['distance_meters'] ?? json['distance_m'] ?? 0) as num)
          .toInt(),
      offer: offerTitle,
      offerCost: (offerCost as num).toInt(),
      checkinRewardCoins:
          json['checkin_reward_pe'] ?? json['checkin_reward_coins'] ?? 100,
      checkinRadiusMeters: json['checkin_radius_meters'] ?? 200,
      isActive: json['is_active'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : json['lat'] != null
          ? double.tryParse(json['lat'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : json['lng'] != null
          ? double.tryParse(json['lng'].toString())
          : null,
      qrPayload: json['qr_payload']?.toString(),
      checkedInToday: json['checked_in_today'] == true,
    );
  }
}

class Redemption {
  final String id;
  final String businessName;
  final String? businessImage;
  final String? offerTitle;
  final int peSpent;
  final String qrCodeHash;
  final String status;
  final DateTime? redeemedAt;
  final DateTime? validatedAt;

  Redemption({
    required this.id,
    required this.businessName,
    this.businessImage,
    this.offerTitle,
    required this.peSpent,
    required this.qrCodeHash,
    required this.status,
    this.redeemedAt,
    this.validatedAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      id: json['id']?.toString() ?? '',
      businessName: json['business_name'] ?? '',
      businessImage: json['business_image'],
      offerTitle: json['offer_title'],
      peSpent: json['pe_spent'] ?? json['coins_spent'] ?? 0,
      qrCodeHash: json['qr_code_hash'] ?? '',
      status: json['status'] ?? 'pending',
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.tryParse(json['redeemed_at'])
          : null,
      validatedAt: json['validated_at'] != null
          ? DateTime.tryParse(json['validated_at'])
          : null,
    );
  }
}

class UserProfileData {
  final int? age;
  final double? weightKg;
  final int? heightCm;
  final bool isComplete;

  UserProfileData({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.isComplete,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      age: json['age'] is int
          ? json['age']
          : int.tryParse('${json['age'] ?? ''}'),
      weightKg: json['weight_kg'] is num
          ? (json['weight_kg'] as num).toDouble()
          : double.tryParse('${json['weight_kg'] ?? ''}'),
      heightCm: json['height_cm'] is int
          ? json['height_cm']
          : int.tryParse('${json['height_cm'] ?? ''}'),
      isComplete: json['is_complete'] == true,
    );
  }
}

class WeeklyActivityDay {
  final String date;
  final String label;
  final int steps;
  final double distanceKm;
  final double? caloriesKcal;
  final bool completed;

  WeeklyActivityDay({
    required this.date,
    required this.label,
    required this.steps,
    required this.distanceKm,
    required this.caloriesKcal,
    required this.completed,
  });

  factory WeeklyActivityDay.fromJson(Map<String, dynamic> json) {
    return WeeklyActivityDay(
      date: json['date'] ?? '',
      label: json['label'] ?? '',
      steps: json['steps'] ?? 0,
      distanceKm: json['distance_km'] is num
          ? (json['distance_km'] as num).toDouble()
          : 0,
      caloriesKcal: json['calories_kcal'] is num
          ? (json['calories_kcal'] as num).toDouble()
          : null,
      completed: json['completed'] == true,
    );
  }
}

class WeeklyActivitySummary {
  final int exerciseGoalDays;
  final int exerciseDaysCompleted;
  final int exerciseThresholdSteps;
  final int totalSteps;
  final double totalDistanceKm;
  final double? totalCaloriesKcal;
  final bool needsProfileData;
  final String? profileHint;
  final List<WeeklyActivityDay> days;

  WeeklyActivitySummary({
    required this.exerciseGoalDays,
    required this.exerciseDaysCompleted,
    required this.exerciseThresholdSteps,
    required this.totalSteps,
    required this.totalDistanceKm,
    required this.totalCaloriesKcal,
    required this.needsProfileData,
    required this.profileHint,
    required this.days,
  });

  factory WeeklyActivitySummary.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>?) ?? {};
    final rawDays = (json['days'] as List<dynamic>? ?? []);

    return WeeklyActivitySummary(
      exerciseGoalDays: json['exercise_goal_days'] ?? 5,
      exerciseDaysCompleted: json['exercise_days_completed'] ?? 0,
      exerciseThresholdSteps: json['exercise_threshold_steps'] ?? 5000,
      totalSteps: totals['steps'] ?? 0,
      totalDistanceKm: totals['distance_km'] is num
          ? (totals['distance_km'] as num).toDouble()
          : 0,
      totalCaloriesKcal: totals['calories_kcal'] is num
          ? (totals['calories_kcal'] as num).toDouble()
          : null,
      needsProfileData: json['needs_profile_data'] == true,
      profileHint: json['profile_hint'],
      days: rawDays
          .map((d) => WeeklyActivityDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExploredTile {
  final String tileKey;
  final double lat;
  final double lng;

  ExploredTile({required this.tileKey, required this.lat, required this.lng});

  factory ExploredTile.fromJson(Map<String, dynamic> json) {
    return ExploredTile(
      tileKey: json['tile_key']?.toString() ?? '',
      lat:
          (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      lng:
          (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
    );
  }
}

class ExplorationPoi {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String type;
  final double lat;
  final double lng;
  final int distanceM;
  final int interactionRadiusMeters;
  final int rewardCoins;
  final int rewardXp;
  final String? province;
  final String? department;
  final DateTime? claimedAt;

  ExplorationPoi({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.interactionRadiusMeters,
    required this.rewardCoins,
    required this.rewardXp,
    this.province,
    this.department,
    this.claimedAt,
  });

  factory ExplorationPoi.fromJson(Map<String, dynamic> json) {
    return ExplorationPoi(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Tesoro',
      description: json['description'],
      imageUrl: json['image_url']?.toString(),
      type: json['type'] ?? json['poi_type'] ?? 'treasure',
      lat:
          (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      lng:
          (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
      distanceM:
          (json['distance_m'] as num?)?.toInt() ??
          (json['distance_meters'] as num?)?.toInt() ??
          0,
      interactionRadiusMeters:
          (json['interaction_radius_meters'] as num?)?.toInt() ?? 150,
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      province: json['province']?.toString(),
      department: json['department']?.toString(),
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse(json['claimed_at'].toString())
          : null,
    );
  }
}

class CollectibleSpawnDto {
  final String id;
  final String collectibleId;
  final String collectibleName;
  final String? collectibleImageUrl;
  final String collectibleRarity;
  final String? collectibleCategory;
  final String? collectibleSet;
  final double lat;
  final double lng;
  final int distanceM;
  final int interactionRadiusMeters;
  final int rewardCoins;
  final String? province;
  final String? department;
  final bool claimed;
  final int quantity;

  CollectibleSpawnDto({
    required this.id,
    required this.collectibleId,
    required this.collectibleName,
    this.collectibleImageUrl,
    required this.collectibleRarity,
    this.collectibleCategory,
    required this.collectibleSet,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.interactionRadiusMeters,
    this.rewardCoins = 0,
    this.province,
    this.department,
    this.claimed = false,
    this.quantity = 1,
  });

  factory CollectibleSpawnDto.fromJson(Map<String, dynamic> json) {
    final collectible = json['collectible'] is Map<String, dynamic>
        ? json['collectible'] as Map<String, dynamic>
        : <String, dynamic>{};

    return CollectibleSpawnDto(
      id:
          json['id']?.toString() ??
          json['spawn_id']?.toString() ??
          collectible['id']?.toString() ??
          '',
      collectibleId:
          json['collectible_id']?.toString() ??
          collectible['id']?.toString() ??
          '',
      collectibleName:
          json['collectible_name']?.toString() ??
          collectible['name']?.toString() ??
          'Puntos Exploria',
      collectibleImageUrl:
          json['collectible_image_url']?.toString() ??
          collectible['image_url']?.toString() ??
          json['image_url']?.toString(),
      collectibleRarity:
          json['collectible_rarity']?.toString() ??
          collectible['rarity']?.toString() ??
          'common',
      collectibleCategory:
          json['collectible_category']?.toString() ??
          collectible['category']?.toString(),
      collectibleSet:
          json['collectible_set']?.toString() ??
          collectible['set_name']?.toString(),
      lat:
          (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      lng:
          (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
      distanceM:
          (json['distance_m'] as num?)?.toInt() ??
          (json['distance_meters'] as num?)?.toInt() ??
          0,
      interactionRadiusMeters:
          (json['interaction_radius_meters'] as num?)?.toInt() ?? 120,
      rewardCoins:
          (json['reward_coins'] as num?)?.toInt() ??
          (json['coins_reward'] as num?)?.toInt() ??
          (collectible['reward_coins'] as num?)?.toInt() ??
          0,
      province:
          json['province']?.toString() ?? collectible['province']?.toString(),
      department:
          json['department']?.toString() ??
          collectible['department']?.toString(),
      claimed: json['claimed'] == true,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class CollectibleAttribute {
  final String name;
  final String value;
  final String type;
  final String? label;

  CollectibleAttribute({
    required this.name,
    required this.value,
    required this.type,
    this.label,
  });

  factory CollectibleAttribute.fromJson(Map<String, dynamic> json) {
    return CollectibleAttribute(
      name: json['name'] ?? '',
      value: json['value']?.toString() ?? '',
      type: json['type'] ?? 'string',
      label: json['label'],
    );
  }
}

class CollectibleSet {
  final String id;
  final String name;
  final String? description;
  final int rewardCoins;
  final int rewardXp;
  final String? iconKey;

  CollectibleSet({
    required this.id,
    required this.name,
    this.description,
    required this.rewardCoins,
    required this.rewardXp,
    this.iconKey,
  });

  factory CollectibleSet.fromJson(Map<String, dynamic> json) {
    return CollectibleSet(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      rewardCoins: json['completion_reward_coins'] ?? 0,
      rewardXp: json['completion_reward_xp'] ?? 0,
      iconKey: json['icon_key'],
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String? description;
  final String category;
  final String rarity;
  final String badgeType;
  final String? iconKey;
  final int rewardCoins;
  final int rewardXp;
  final Map<String, dynamic>? criteria;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.rarity,
    required this.badgeType,
    this.iconKey,
    required this.rewardCoins,
    required this.rewardXp,
    this.criteria,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'general',
      rarity: json['rarity'] ?? 'common',
      badgeType: json['badge_type'] ?? 'badge',
      iconKey: json['icon_key'],
      rewardCoins: json['reward_coins'] ?? 0,
      rewardXp: json['reward_xp'] ?? 0,
      criteria: json['criteria'] is Map<String, dynamic>
          ? json['criteria']
          : null,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
          : null,
    );
  }
}

class GeoMissionDto {
  final String id;
  final String title;
  final String? description;
  final int targetSteps;
  final int nearbyBusinessesRequired;
  final int proximityRadiusMeters;
  final int rewardCoins;
  final int rewardXp;
  final int progressSteps;
  final int progressBusinesses;
  final bool isCompleted;

  GeoMissionDto({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSteps,
    required this.nearbyBusinessesRequired,
    required this.proximityRadiusMeters,
    required this.rewardCoins,
    required this.rewardXp,
    required this.progressSteps,
    required this.progressBusinesses,
    required this.isCompleted,
  });

  factory GeoMissionDto.fromJson(Map<String, dynamic> json) {
    return GeoMissionDto(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Misión',
      description: json['description'],
      targetSteps: (json['target_steps'] as num?)?.toInt() ?? 0,
      nearbyBusinessesRequired:
          (json['nearby_businesses_required'] as num?)?.toInt() ?? 0,
      proximityRadiusMeters:
          (json['proximity_radius_meters'] as num?)?.toInt() ?? 0,
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      progressSteps: (json['progress_steps'] as num?)?.toInt() ?? 0,
      progressBusinesses: (json['progress_businesses'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] == true,
    );
  }
}
