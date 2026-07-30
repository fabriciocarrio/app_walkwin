# Diseño del Sistema — Exploria

## 1. Descripción General

Exploria es una aplicación Flutter de gamificación de caminatas. Los usuarios ganan monedas (PE) y XP caminando, explorando lugares, coleccionando objetos digitales y completando misiones. El backend es una API REST en Laravel con comunicación en tiempo real vía WebSocket (protocolo Pusher).

## 2. Arquitectura

No se utiliza un patrón de estado formal (BLoC, Provider, Riverpod). La app se basa en:

- **StatefulWidget + setState** para el estado local de cada pantalla
- **ValueNotifier + ValueListenableBuilder** para el tema global (claro/oscuro)
- **Servicios singleton** con métodos estáticos para API, WebSocket, almacenamiento local y sensores

```
lib/
├── main.dart                              # Punto de entrada
├── config/app_config.dart                 # Constantes de entorno inyectables vía --dart-define
├── theme/app_theme.dart                   # AppColors + AppTheme (Material 3, claro/oscuro)
├── models/
│   ├── models.dart                        # Todos los DTOs (User, Business, Redemption, etc.)
│   └── local_step.dart                    # Modelo SQLite para pasos offline
├── services/
│   ├── api_service.dart                   # Cliente HTTP REST
│   ├── websocket_service.dart             # WebSocket con protocolo Pusher
│   ├── offline_sync_service.dart          # Buffer SQLite con auto-flush
│   ├── notification_service.dart          # Notificaciones locales persistentes + alertas
│   ├── health_service.dart                # Google Fit / Apple Health
│   ├── celebration_service.dart           # Sonido + vibración
│   └── lock_screen_widget_service.dart     # Method channel para widget de bloqueo
├── screens/
│   ├── login_screen.dart                  # Login con email/password
│   ├── register_screen.dart               # Registro
│   ├── home_shell.dart                    # Bottom nav + botón flotante de mapa
│   ├── dashboard_screen.dart              # Pantalla principal (~1800 líneas)
│   ├── map_screen.dart                    # Mapa interactivo con capas
│   ├── tasks_screen.dart                  # Lista de misiones (vista simple)
│   ├── missions_screen.dart               # Misiones con barras de progreso
│   ├── rewards_screen.dart                # Canje de cupones + historial
│   ├── collection_screen.dart             # Álbum de coleccionables + logros
│   ├── business_profile_screen.dart       # Perfil de comercio
│   ├── tourist_poi_profile_screen.dart    # Perfil de punto turístico
│   ├── level_progress_screen.dart         # Progresión de niveles
│   ├── settings_screen.dart               # Ajustes de usuario
│   └── qr_scanner_screen.dart             # Escáner QR
└── widgets/
    ├── index.dart                         # Barrel export
    ├── steps_coins_widget.dart            # Widget reutilizable pasos/monedas
    ├── lock_screen_widget.dart            # UI para widget de bloqueo
    └── steps_coins_widget_example.dart    # Demo
```

## 3. Flujo de Autenticación

```
main()
  └─ NotificationService.init()
  └─ OfflineSyncService.listenAndSync()
  └─ AuthWrapper
       └─ _checkAuth()
            ├─ Permission.request() (activity_recognition, location)
            ├─ ApiService.loadToken()  ← flutter_secure_storage
            └─ ¿token existe?
                 ├─ Sí → /home
                 └─ No  → /login
```

- El token JWT se guarda en `flutter_secure_storage` con clave `auth_token`.
- Permanece en memoria estática `ApiService._token`.
- Los endpoints protegidos envían `Authorization: Bearer <token>`.
- No hay refresh token — al expirar, la API responde 401 y se redirige al login.

## 4. Flujo de Conteo de Pasos

```
Pedometer.stepCountStream
  └─ delta = event.steps - _initialSteps
  └─ setState(_sessionSteps = delta)
  └─ ¿meta diaria alcanzada?
       └─ CelebrationService.celebrate() (sonido + vibración)
       └─ NotificationService.showLocal()
  └─ ¿delta >= 5 pasos desde último sync?
       └─ _syncSteps()
            ├─ OfflineSyncService.saveSteps() → SQLite
            └─ OfflineSyncService.flushPending()
                 └─ ApiService.syncSteps() → POST /api/v1/steps/sync
  └─ Timer periódico (10s) → _syncSteps()
  └─ _showProgressNotification()
       └─ NotificationService.showProgressNotification()
            └─ Notificación Android persistente (ongoing) con barra de progreso
```

### Huso Horario

La app usa Argentina UTC-3, con reinicio automático a medianoche vía `Timer` calculado contra la medianoche argentina en UTC.

## 5. Sincronización Offline

```
OfflineSyncService
  ├─ SQLite (walkwin_steps.db)
  │    └─ tabla: local_steps (id, date, total_steps, source, synced)
  ├─ saveSteps() → INSERT OR REPLACE
  ├─ flushPending()
  │    └─ Connectivity().checkConnectivity()
  │    └─ por cada registro synced=0:
  │         ├─ ApiService.syncSteps()
  │         └─ markSynced(id) si ok
  └─ listenAndSync()
       └─ Connectivity().onConnectivityChanged
            └─ si hay conexión → flushPending()
```

## 6. Comunicación en Tiempo Real

```
WebSocketService (singleton)
  ├─ initForAuthenticatedUser()
  │    ├─ ApiService.getToken()
  │    ├─ ApiService.getCurrentUser() → userId
  │    └─ WebSocketChannel.connect(wss://host/app/<appKey>)
  │
  ├─ _onRawMessage()
  │    └─ pusher:connection_established → _subscribeToRequiredChannels()
  │         ├─ user.<userId>
  │         ├─ exploration
  │         └─ missions
  │    └─ pusher:ping → pusher:pong
  │    └─ evento de negocio → _onEvent()
  │         ├─ achievement_unlocked → NotificationService.showLocal()
  │         ├─ rank_changed → NotificationService.showLocal()
  │         ├─ collectible_spawned → NotificationService.showLocal()
  │         └─ new_mission_available → NotificationService.showLocal()
  │
  └─ disconnect() (al salir del HomeShell)
```

## 7. Sistema de Temas

```
themeNotifier (ValueNotifier<ThemeMode>) — global
  └─ ExploriaApp escucha con ValueListenableBuilder
       ├─ light → AppTheme.light (Material 3)
       └─ dark  → AppTheme.dark (Material 3)

AppColors
  ├─ primary: #2B4ABF (azul royal)
  ├─ accent: #A8D558 (lima, para recompensas)
  ├─ coinGold: #F5C535
  ├─ bgLight: #EEF1F8 / bgDark: #0A0E1A
  └─ paletas completa para texto, tarjetas, divisores
```

## 8. Navegación

```
Raíz: MaterialApp con routes:
  ├─ /        → AuthWrapper (loader con check de token)
  ├─ /login   → LoginScreen
  ├─ /register→ RegisterScreen
  └─ /home    → HomeShell

HomeShell (IndexedStack)
  ├─ [0] DashboardScreen
  ├─ [1] MapScreen (botón flotante circular)
  ├─ [2] TasksScreen
  ├─ [3] CollectionScreen
  ├─ [4] RewardsScreen
  └─ [5] SettingsScreen (oculto, accesible desde header)

Pantallas hijas (Navigator.push):
  ├─ LevelProgressScreen
  ├─ MissionsScreen
  ├─ BusinessProfileScreen
  ├─ TouristPoiProfileScreen
  └─ QrScannerScreen
```

## 9. API REST

| Método | Endpoint | Propósito |
|--------|----------|-----------|
| POST | `/api/v1/auth/register` | Registro |
| POST | `/api/v1/auth/login` | Login |
| GET | `/api/user` | Usuario actual |
| GET | `/api/v1/user/stats` | Estadísticas (pasos, nivel, racha, PE) |
| POST | `/api/v1/steps/sync` | Sincronizar pasos |
| GET | `/api/v1/businesses/nearby` | Comercios cercanos |
| GET | `/api/v1/businesses/featured` | Comercios destacados |
| POST | `/api/v1/checkin` | Check-in en comercio |
| GET | `/api/v1/map/nearby-points` | Puntos del mapa (comercios, POIs, spawns) |
| POST | `/api/v1/map/shops/{id}/claim` | Reclamar shop en mapa |
| POST | `/api/v1/map/tourist-locations/{id}/claim` | Reclamar POI turístico |
| POST | `/api/v1/map/dynamic-spawns/{id}/claim` | Reclamar spawn dinámico |
| POST | `/api/v1/redemptions/purchase` | Comprar cupón |
| POST | `/api/v1/redemptions/validate` | Validar QR de canje |
| GET | `/api/v1/user/redemptions` | Historial de canjes |
| GET/PUT | `/api/v1/settings/profile` | Perfil (edad, peso, altura) |
| PUT | `/api/v1/settings/step-source` | Fuente de pasos |
| GET | `/api/v1/activity/weekly` | Resumen semanal |
| GET | `/api/v1/exploration/mapstate` | Estado de exploración (tiles) |
| GET | `/api/v1/exploration/nearby-pois` | POIs de exploración cercanos |
| POST | `/api/v1/exploration/claim-poi` | Reclamar POI de exploración |
| GET | `/api/v1/exploration/collectibles` | Coleccionables |
| GET | `/api/v1/exploration/inventory` | Inventario |
| GET | `/api/v1/exploration/collectibles-catalog` | Catálogo |
| POST | `/api/v1/exploration/collect-spawn` | Recolectar spawn |
| GET | `/api/v1/exploration/missions` | Misiones geográficas |
| PATCH | `/api/v1/exploration/missions/{id}/progress` | Actualizar progreso |
| GET | `/api/v1/achievements/user` | Logros del usuario |
| GET | `/api/v1/exploration/sets` | Sets de coleccionables |

## 10. Flujo de Mapas

```
MapScreen
  ├─ Geolocator.getCurrentPosition() → _currentLocation
  ├─ ApiService.getMapNearbyPoints() → negocios + POIs + spawns
  ├─ ApiService.getExplorationMapState() → tiles explorados
  ├─ ApiService.getGeoMissions() → misiones
  │
  ├─ flutter_map con CartoDB tiles (light_all)
  ├─ MarkerLayer con 3 capas filtrables:
  │    ├─ Comercios (icono store, azul)
  │    ├─ POIs turísticos (icono tip, dorado)
  │    └─ Spawns dinámicos (icono auto_awesome, púrpura)
  ├─ CircleLayer para tiles explorados (verde translúcido)
  ├─ PolylineLayer para ruta OSRM
  │    └─ GET http://router.project-osrm.org/route/v1/foot/...
  │
  └─ Bottom sheet al seleccionar marcador:
       ├─ Botón "Obtener monedas" (check-in por geolocalización)
       ├─ Botón "Cómo llegar" (ruta OSRM)
       └─ Link a perfil del comercio/POI
```

## 11. Diseño de Datos

### User
```dart
id, name, email, peBalance, level, streakDays
```

### Business
```dart
id, name, description, imageUrl, distanceM, offer, offerCost,
checkinRewardCoins, checkinRadiusMeters, isActive, isFeatured,
latitude, longitude, qrPayload, checkedInToday
```

### Redemption
```dart
id, businessName, businessImage, offerTitle, peSpent,
qrCodeHash, status(pending|validated|expired), redeemedAt, validatedAt
```

### WeeklyActivitySummary
```dart
exerciseGoalDays, exerciseDaysCompleted, totalSteps,
totalDistanceKm, totalCaloriesKcal, needsProfileData, days[]
```

### ExplorationPoi
```dart
id, name, description, imageUrl, type, lat, lng, distanceM,
interactionRadiusMeters, rewardCoins, rewardXp, province, department, claimedAt
```

### CollectibleSpawnDto
```dart
id, collectibleId, collectibleName, collectibleImageUrl,
collectibleRarity, collectibleCategory, collectibleSet,
lat, lng, distanceM, interactionRadiusMeters, rewardCoins,
province, department, claimed, quantity
```

### Achievement
```dart
id, name, description, category, rarity, badgeType, iconKey,
rewardCoins, rewardXp, criteria, unlockedAt
```

### GeoMissionDto
```dart
id, title, description, targetSteps, nearbyBusinessesRequired,
proximityRadiusMeters, rewardCoins, rewardXp,
progressSteps, progressBusinesses, isCompleted
```

## 12. Sistema de Niveles

```
Niveles 1-30 con títulos:
  ├─ 1-5:   Caminante
  ├─ 6-10:  Explorador
  ├─ 11-15: Descubridor
  ├─ 16-20: Aventurero
  ├─ 21-25: Coleccionista
  └─ 26-30: Maestro Explorador

Cálculo de XP:
  └─ levelBaseXp + (level - 1) * levelGrowthXp
  └─ maxLevel = 30

SVGs por rango: assets/levels/ (novato, aventurero, explorador, elite, legendaria)
```

## 13. Monedas y Economía

- **Puntos Exploria (PE)**: moneda virtual del sistema
- Ganancia: ~1 PE cada 100 pasos (vista en `_livePe`)
- Gasto: canje de cupones en comercios
- Visualización: badge dorado en dashboard + tarjeta de recompensas

## 14. Seguridad

- Token JWT almacenado en `flutter_secure_storage` (Keychain/KeyStore)
- Device fingerprint (`ANDROID_ID` / `identifierForVendor`) en sync de pasos
- Validación de geolocalización en check-in (radio configurable por comercio)
- No hay almacenamiento de credenciales en texto plano
- El token no tiene refresh implementado

## 15. Decisiones de Diseño Clave

1. **Sin state management formal**: se eligió `setState` para simplicidad dado que el alcance actual no justifica BLoC/Riverpod. Las pantallas son independientes y no comparten estado mutable complejo.

2. **Dashboard monolítico (~1800 líneas)**: concentra lógica de pasos, animaciones, API calls, temporizadores y UI. Es la pantalla más crítica y la que más se beneficiaría de una refactorización.

3. **Dos endpoints de mapa**: `getMapNearbyPoints` y `getExplorationMapState` se llaman por separado, lo que permite actualizar la exploración sin recargar todos los negocios.

4. **Offline-first parcial**: solo los pasos se almacenan localmente. El resto de la app requiere conexión.

5. **QR como mecanismo dual**: el check-in usa `mobile_scanner` para leer QR del comercio; los canjes generan QR con `qr_flutter` para que el comercio los valide.

6. **WebSocket estilo Pusher**: la app implementa el protocolo Pusher (subscribe, ping/pong, eventos canalizados) pero sin usar la librería oficial `pusher_channels_flutter` — usa `web_socket_channel` directamente con lógica propia.

7. **Rebranding WalkWin → Exploria**: la app cambió de nombre pero conserva el package name `com.walkwin.walkwin_app` y la moneda pasó de "pepitas" a "PE" (Puntos Exploria).

## 16. Pendientes Técnicos

- Implementar refresh token
- Refactorizar `DashboardScreen` en widgets más pequeños
- Agregar manejo de errores centralizado (interceptor HTTP)
- Migrar a estado formal (Riverpod o BLoC) si el equipo crece
- Soportar iOS (pendiente de configuración de HealthKit, notificaciones)
- Pruebas unitarias y de integración (solo hay smoke test)
