# Exploria

Una aplicación gamificada de caminatas y exploración que recompensa a los usuarios por moverse, descubrir lugares y completar misiones.

## Descripción

Exploria (antes WalkWin) transforma cada paso en una experiencia interactiva. Los usuarios ganan **Puntos Exploria (PE)** y **XP** al caminar, hacer check-in en negocios, explorar puntos turísticos, coleccionar objetos digitales y completar misiones. Los puntos se canjean por cupones y recompensas en los comercios participantes.

## Características

- **Autenticación** — Login y registro con JWT
- **Podómetro en tiempo real** — Conteo de pasos nativo con reinicio diario
- **Integración con salud** — Google Fit / Apple Health como fuente de pasos
- **Sincronización offline** — Pasos almacenados en SQLite y enviados al recuperar conexión
- **Sistema de niveles** — 30 niveles con títulos (Caminante → Maestro Explorador) e ilustraciones SVG
- **Rachas diarias** — Seguimiento de días consecutivos con notificaciones de hito
- **Actividad semanal** — Resumen de pasos, distancia y calorías por día
- **Meta diaria** — Objetivo configurable con celebración (sonido + vibración)
- **Mapa interactivo** — OpenStreetMap con CartoDB, búsqueda de lugares y filtros por capa
- **Capas en el mapa** — Negocios, puntos turísticos y apariciones de coleccionables
- **Check-in por QR** — Escaneo de código QR con validación de geolocalización
- **Rutas peatonales** — Enrutamiento OSRM con polyline en el mapa
- **Canje de cupones** — Compra de ofertas con PE y visualización de QR de canje
- **Álbum de coleccionables** — Objetos digitales categorizados por rareza y departamento
- **Logros** — Logros por departamento y generales
- **Misiones geográficas** — Misiones basadas en pasos y proximidad a negocios
- **Eventos en tiempo real** — WebSocket para notificaciones de logros, rango, coleccionables y misiones
- **Tema oscuro** — Alternancia entre claro y oscuro
- **Widget de pantalla de bloqueo** — Progreso visible sin abrir la app (Android + iOS)

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Lenguaje | Dart 3.8+ |
| Framework | Flutter (Material 3) |
| Mapas | flutter_map + OpenStreetMap + OSRM |
| Estado | setState + ValueNotifier |
| Almacén local | sqflite + flutter_secure_storage |
| Backend | Laravel REST API |
| Tiempo real | WebSocket (Pusher) |
| Notificaciones | flutter_local_notifications |
| QR | mobile_scanner + qr_flutter |
| Pasos | pedometer + health |

## Arquitectura

El proyecto no utiliza un patrón de estado formal (BLoC, Provider, etc.). La gestión de estado se basa en:

- **setState** dentro de `StatefulWidget` para estado local de pantalla
- **ValueNotifier + ValueListenableBuilder** para el tema global
- **Servicios singleton** (`ApiService`, `WebSocketService`, `OfflineSyncService`, etc.) con métodos estáticos

```
lib/
├── main.dart                  # Punto de entrada y wrapper de autenticación
├── config/
│   └── app_config.dart        # Configuración de entorno (API, WS)
├── theme/
│   └── app_theme.dart         # Colores y temas Material 3
├── models/
│   ├── models.dart            # Modelos de datos
│   └── local_step.dart        # Modelo para pasos offline
├── services/
│   ├── api_service.dart       # Llamadas REST
│   ├── health_service.dart    # Google Fit / Apple Health
│   ├── offline_sync_service.dart  # Sincronización offline
│   ├── notification_service.dart  # Notificaciones locales
│   ├── websocket_service.dart     # WebSocket en tiempo real
│   ├── celebration_service.dart   # Efectos de celebración
│   └── lock_screen_widget_service.dart  # Widget de bloqueo
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_shell.dart
│   ├── dashboard_screen.dart
│   ├── map_screen.dart
│   ├── tasks_screen.dart
│   ├── missions_screen.dart
│   ├── rewards_screen.dart
│   ├── collection_screen.dart
│   ├── business_profile_screen.dart
│   ├── tourist_poi_profile_screen.dart
│   ├── level_progress_screen.dart
│   ├── settings_screen.dart
│   └── qr_scanner_screen.dart
└── widgets/
    ├── index.dart
    ├── steps_coins_widget.dart
    ├── lock_screen_widget.dart
    └── steps_coins_widget_example.dart
```

## Requisitos

- Flutter SDK ^3.8.1
- Dart SDK ^3.8.1
- Android SDK 26+ (minSdk)
- iOS (pendiente de configuración)
- Backend Laravel en ejecución (ver repositorio companion)

## Configuración

1. Clonar el repositorio:

```bash
git clone <url-del-repositorio>
cd walkwin_app
```

2. Instalar dependencias:

```bash
flutter pub get
```

3. Configurar la URL de la API en `lib/config/app_config.dart`:

```dart
static const String apiBaseUrl = 'http://<ip>:8000/api/v1';
```

4. Ejecutar la aplicación:

```bash
flutter run
```

### Variables de entorno

La configuración del backend (API URL, WebSocket) se encuentra en `lib/config/app_config.dart`. Ajusta los valores según tu entorno de desarrollo.

## Plataformas

| Plataforma | Estado |
|---|---|
| Android | Completo |
| iOS | Pendiente de configuración |
| Web | Parcial (sin soporte de sensores) |
| Linux / macOS / Windows | Parcial (sin soporte de sensores) |

## Backend

Este frontend se conecta a una API REST en Laravel. El repositorio del backend se encuentra en el mismo workspace (`walkLaravel/`).

## Construcción

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## Licencia

Todos los derechos reservados.
