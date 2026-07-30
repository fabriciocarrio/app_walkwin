class User {
  final String id;
  final String name;
  final String email;
  final int peBalance;
  final int level;
  final int streakDays;
  final String? myReferralCode;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.peBalance,
    required this.level,
    required this.streakDays,
    this.myReferralCode,
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
      myReferralCode: json['my_referral_code'],
    );
  }
}

class BusinessHour {
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  BusinessHour({
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
    required this.isClosed,
  });

  factory BusinessHour.fromJson(Map<String, dynamic> json) {
    return BusinessHour(
      dayOfWeek: json['day_of_week'] ?? 0,
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      isClosed: json['is_closed'] == true,
    );
  }

  static const dayNames = [
    'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'
  ];

  String get dayName => dayNames[dayOfWeek % 7];

  String get display {
    if (isClosed) return '$dayName: Cerrado';
    if (openTime != null && closeTime != null) {
      final open = openTime!.length >= 5 ? openTime!.substring(0, 5) : openTime!;
      final close = closeTime!.length >= 5 ? closeTime!.substring(0, 5) : closeTime!;
      return '$dayName $open-$close';
    }
    return dayName;
  }
}

class BusinessOffer {
  final String id;
  final String title;
  final String? description;
  final int peCost;
  final String limitPeriod;
  final int? limitCount;
  final int? totalStock;
  final int? remainingPeriod;
  final int? remainingStock;
  final int? usedStock;
  final bool isActive;

  BusinessOffer({
    required this.id,
    required this.title,
    this.description,
    required this.peCost,
    required this.limitPeriod,
    this.limitCount,
    this.totalStock,
    this.remainingPeriod,
    this.remainingStock,
    this.usedStock,
    this.isActive = true,
  });

  factory BusinessOffer.fromJson(Map<String, dynamic> json) {
    return BusinessOffer(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      peCost: json['pe_cost'] ?? json['coin_cost'] ?? 0,
      limitPeriod: json['limit_period'] ?? 'none',
      limitCount: json['limit_count'] != null
          ? (json['limit_count'] as num).toInt()
          : null,
      totalStock: json['total_stock'] != null
          ? (json['total_stock'] as num).toInt()
          : null,
      remainingPeriod: json['remaining_period'] != null
          ? (json['remaining_period'] as num).toInt()
          : null,
      remainingStock: json['remaining_stock'] != null
          ? (json['remaining_stock'] as num).toInt()
          : null,
      usedStock: json['used_stock'] != null
          ? (json['used_stock'] as num).toInt()
          : null,
      isActive: json['is_active'] ?? true,
    );
  }

  bool get hasStockLimit => totalStock != null && totalStock! > 0;
  int get displayRemaining => remainingStock ?? remainingPeriod ?? 0;
  bool get isSoldOut => hasStockLimit && (remainingStock != null && remainingStock! <= 0);
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
  final List<BusinessHour> businessHours;
  final List<BusinessOffer> offers;

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
    this.businessHours = const [],
    this.offers = const [],
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

    final hoursList = <BusinessHour>[];
    if (json['business_hours'] is List) {
      for (final h in json['business_hours']) {
        hoursList.add(BusinessHour.fromJson(h));
      }
    }

    final offersList = <BusinessOffer>[];
    if (json['offers'] is List) {
      for (final o in json['offers']) {
        offersList.add(BusinessOffer.fromJson(o));
      }
    }

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
      businessHours: hoursList,
      offers: offersList,
    );
  }

  String get hoursSummary {
    final byDay = <int, BusinessHour>{};
    for (final h in businessHours) {
      byDay[h.dayOfWeek] = h;
    }
    if (byDay.isEmpty) return '';

    final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final ranges = <String>[];
    int? rangeStart;
    String? rangeOpen, rangeClose;

    void flushRange(int end) {
      if (rangeStart == null) return;
      final startName = BusinessHour.dayNames[rangeStart!];
      final endName = BusinessHour.dayNames[end];
      final isClosed = byDay[rangeStart]?.isClosed ?? false;
      if (isClosed) {
        if (rangeStart == end) {
          ranges.add('$startName: Cerrado');
        } else {
          ranges.add('$startName-$endName: Cerrado');
        }
      } else {
        final open = (rangeOpen ?? '').length >= 5 ? rangeOpen!.substring(0, 5) : (rangeOpen ?? '');
        final close = (rangeClose ?? '').length >= 5 ? rangeClose!.substring(0, 5) : (rangeClose ?? '');
        if (rangeStart == end) {
          ranges.add('$startName $open-$close');
        } else {
          ranges.add('$startName-$endName $open-$close');
        }
      }
      rangeStart = null;
      rangeOpen = null;
      rangeClose = null;
    }

    for (final entry in sorted) {
      final h = entry.value;
      if (rangeStart == null) {
        rangeStart = h.dayOfWeek;
        rangeOpen = h.isClosed ? null : (h.openTime ?? '');
        rangeClose = h.isClosed ? null : (h.closeTime ?? '');
      } else if ((h.isClosed && byDay[rangeStart]?.isClosed == true) ||
          (!h.isClosed && !byDay[rangeStart]!.isClosed &&
              h.openTime == rangeOpen && h.closeTime == rangeClose)) {
        continue;
      } else {
        flushRange(sorted[sorted.indexOf(entry) - 1].key);
        rangeStart = h.dayOfWeek;
        rangeOpen = h.isClosed ? null : (h.openTime ?? '');
        rangeClose = h.isClosed ? null : (h.closeTime ?? '');
      }
    }
    if (rangeStart != null) {
      flushRange(sorted.last.key);
    }

    return ranges.join(' · ');
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
  final String? description;
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
  final int rarityTier;

  CollectibleSpawnDto({
    required this.id,
    required this.collectibleId,
    required this.collectibleName,
    this.collectibleImageUrl,
    required this.collectibleRarity,
    this.collectibleCategory,
    this.description,
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
    this.rarityTier = 0,
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
      description:
          json['description']?.toString(),
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
      rarityTier: (json['rarity_tier'] as num?)?.toInt() ?? 0,
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
  final String slug;
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
    required this.slug,
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
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
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

class ClanInfo {
  final int id;
  final String name;
  final String? description;
  final String? logo;
  final String department;
  final String? leaderName;
  final int memberCount;
  final int totalInfluence;
  final int seasonInfluence;

  ClanInfo({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    required this.department,
    this.leaderName,
    required this.memberCount,
    required this.totalInfluence,
    required this.seasonInfluence,
  });

  factory ClanInfo.fromJson(Map<String, dynamic> json) {
    return ClanInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      logo: json['logo'],
      department: json['department'] ?? '',
      leaderName: json['leader_name'],
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      totalInfluence: (json['total_influence'] as num?)?.toInt() ?? 0,
      seasonInfluence: (json['season_influence'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClanMemberInfo {
  final int userId;
  final String name;
  final String role;
  final int influence;
  final int seasonInfluence;
  final int rank;
  final String? joinedAt;

  ClanMemberInfo({
    required this.userId,
    required this.name,
    required this.role,
    required this.influence,
    required this.seasonInfluence,
    required this.rank,
    this.joinedAt,
  });

  factory ClanMemberInfo.fromJson(Map<String, dynamic> json) {
    return ClanMemberInfo(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      role: json['role'] ?? 'member',
      influence: (json['influence'] as num?)?.toInt() ?? 0,
      seasonInfluence: (json['season_influence'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      joinedAt: json['joined_at'],
    );
  }
}

class UserClanData {
  final int clanId;
  final String clanName;
  final String? clanLogo;
  final String clanDepartment;
  final String role;
  final int personalInfluence;
  final int personalSeasonInfluence;
  final int memberRank;
  final int totalMembers;
  final int clanTotalInfluence;
  final int clanSeasonInfluence;

  UserClanData({
    required this.clanId,
    required this.clanName,
    this.clanLogo,
    required this.clanDepartment,
    required this.role,
    required this.personalInfluence,
    required this.personalSeasonInfluence,
    required this.memberRank,
    required this.totalMembers,
    required this.clanTotalInfluence,
    required this.clanSeasonInfluence,
  });

  factory UserClanData.fromJson(Map<String, dynamic> json) {
    return UserClanData(
      clanId: (json['clan_id'] as num?)?.toInt() ?? 0,
      clanName: json['clan_name'] ?? '',
      clanLogo: json['clan_logo'],
      clanDepartment: json['clan_department'] ?? '',
      role: json['role'] ?? 'member',
      personalInfluence: (json['personal_influence'] as num?)?.toInt() ?? 0,
      personalSeasonInfluence: (json['personal_season_influence'] as num?)?.toInt() ?? 0,
      memberRank: (json['member_rank'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      clanTotalInfluence: (json['clan_total_influence'] as num?)?.toInt() ?? 0,
      clanSeasonInfluence: (json['clan_season_influence'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClanRankingEntry {
  final int rank;
  final int id;
  final String name;
  final String? logo;
  final String department;
  final int seasonInfluence;
  final int totalInfluence;
  final int memberCount;

  ClanRankingEntry({
    required this.rank,
    required this.id,
    required this.name,
    this.logo,
    required this.department,
    required this.seasonInfluence,
    required this.totalInfluence,
    required this.memberCount,
  });

  factory ClanRankingEntry.fromJson(Map<String, dynamic> json) {
    return ClanRankingEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      logo: json['logo'],
      department: json['department'] ?? '',
      seasonInfluence: (json['season_influence'] as num?)?.toInt() ?? 0,
      totalInfluence: (json['total_influence'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClanDetail {
  final int id;
  final String name;
  final String? description;
  final String? logo;
  final String department;
  final int leaderId;
  final String invitationCode;
  final int memberCount;
  final int totalInfluence;
  final int seasonInfluence;
  final int? departmentPosition;
  final int daysLeftInSeason;
  final List<ClanMemberInfo> members;

  ClanDetail({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    required this.department,
    required this.leaderId,
    required this.invitationCode,
    required this.memberCount,
    required this.totalInfluence,
    required this.seasonInfluence,
    this.departmentPosition,
    required this.daysLeftInSeason,
    required this.members,
  });

  factory ClanDetail.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List<dynamic>?)
            ?.map((m) => ClanMemberInfo.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    return ClanDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      logo: json['logo'],
      department: json['department'] ?? '',
      leaderId: (json['leader_id'] as num?)?.toInt() ?? 0,
      invitationCode: json['invitation_code'] ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      totalInfluence: (json['total_influence'] as num?)?.toInt() ?? 0,
      seasonInfluence: (json['season_influence'] as num?)?.toInt() ?? 0,
      departmentPosition: (json['department_position'] as num?)?.toInt(),
      daysLeftInSeason: (json['days_left_in_season'] as num?)?.toInt() ?? 0,
      members: membersList,
    );
  }
}

class GeoMissionDto {
  final String id;
  final String title;
  final String? description;
  final String missionType;
  final int targetCount;
  final int currentProgress;
  final int progressPercent;
  final int rewardCoins;
  final int rewardXp;
  final bool isCompleted;
  final bool isClaimed;
  final Map<String, dynamic>? criteria;
  final String? criteriaDescription;

  GeoMissionDto({
    required this.id,
    required this.title,
    required this.description,
    required this.missionType,
    required this.targetCount,
    required this.currentProgress,
    required this.progressPercent,
    required this.rewardCoins,
    required this.rewardXp,
    required this.isCompleted,
    required this.isClaimed,
    this.criteria,
    this.criteriaDescription,
  });

  factory GeoMissionDto.fromJson(Map<String, dynamic> json) {
    return GeoMissionDto(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Misión',
      description: json['description'],
      missionType: json['mission_type']?.toString() ?? 'steps',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      currentProgress: (json['current_progress'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] == true || json['completed_at'] != null,
      isClaimed: json['is_claimed'] == true || json['claimed_at'] != null,
      criteria: json['criteria'] is Map<String, dynamic>
          ? json['criteria'] as Map<String, dynamic>
          : null,
      criteriaDescription: json['criteria_description']?.toString(),
    );
  }
}
