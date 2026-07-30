import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class NotificationItem {
  final int? id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool read;

  NotificationItem({
    this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'body': body,
    'type': type,
    'created_at': createdAt.toIso8601String(),
    'read': read ? 1 : 0,
  };

  factory NotificationItem.fromMap(Map<String, dynamic> map) => NotificationItem(
    id: map['id'] as int?,
    title: map['title'] as String,
    body: map['body'] as String,
    type: map['type'] as String? ?? 'general',
    createdAt: DateTime.parse(map['created_at'] as String),
    read: (map['read'] as int?) == 1,
  );

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}

class NotificationStore extends ChangeNotifier {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  Database? _db;
  List<NotificationItem> _items = [];
  bool _initialized = false;

  bool get initialized => _initialized;
  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> init() async {
    if (_initialized) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'notifications.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'general',
            created_at TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    if (_db == null) return;
    final maps = await _db!.query('notifications', orderBy: 'created_at DESC');
    _items = maps.map((m) => NotificationItem.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> add(NotificationItem item) async {
    if (_db == null) return;
    final id = await _db!.insert('notifications', item.toMap());
    final stored = NotificationItem.fromMap({...item.toMap(), 'id': id});
    _items.insert(0, stored);
    notifyListeners();
  }

  Future<void> markAsRead(int id) async {
    if (_db == null) return;
    await _db!.update('notifications', {'read': 1}, where: 'id = ?', whereArgs: [id]);
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(read: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_db == null) return;
    await _db!.update('notifications', {'read': 1});
    _items = _items.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
  }

  Future<void> delete(int id) async {
    if (_db == null) return;
    await _db!.delete('notifications', where: 'id = ?', whereArgs: [id]);
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> clear() async {
    if (_db == null) return;
    await _db!.delete('notifications');
    _items.clear();
    notifyListeners();
  }
}
