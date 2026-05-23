# Widget de Pasos y Monedas - Guía de Integración

Este proyecto incluye un widget minimalista y animado para mostrar pasos y monedas. El widget viene en dos versiones:

## 📦 Características

### 1. **StepsCoinsWidget** - Widget Principal
- ✨ Diseño minimalista y moderno
- 🎭 Animación suave al ganar monedas (escala y opacidad)
- 🎨 Soporte para tema claro/oscuro
- 📱 Versión compacta para espacios reducidos
- 🎯 Personalizable (pasos, monedas)

**Ubicación:** `lib/widgets/steps_coins_widget.dart`

### 2. **LockScreenStepsCoinsWidget** - Widget de Pantalla de Bloqueo
- 🔐 Diseño específico para lock screen
- 📊 Muestra información compacta pero clara
- ⏰ Timestamp de última actualización
- 🎨 Optimizado para visibilidad en lock screen

**Ubicación:** `lib/widgets/lock_screen_widget.dart`

---

## 🚀 Uso Básico

### En tu pantalla de inicio (ej: dashboard_screen.dart)

```dart
import 'package:walkwin_app/widgets/steps_coins_widget.dart';

// En el build() de tu widget:
StepsCoinsWidget(
  steps: 8452,
  coins: 1240,
  onCoinsChanged: () {
    // Opcional: Callback cuando aumentan monedas
    print('¡Ganaste monedas!');
  },
)
```

### Versión Compacta

```dart
StepsCoinsWidget(
  steps: 8452,
  coins: 1240,
  isCompact: true, // Para espacios reducidos
)
```

---

## 🔧 Configuración del Lock Screen Widget

### Android

1. **Agregar dependencia al `pubspec.yaml`:**
```yaml
dependencies:
  flutter_home_widget: ^0.5.0
```

2. **Crear AppWidget en Android:**
   - Navega a `android/app/src/main/java/com/example/walkwin_app/`
   - Crea la clase `StepsCoinsWidgetProvider.kt`:

```kotlin
package com.example.walkwin_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class StepsCoinsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.steps_coins_widget)
        
        // Aquí actualizarías los valores desde SharedPreferences o tu BD local
        views.setTextViewText(R.id.steps_text, "8452")
        views.setTextViewText(R.id.coins_text, "1240")
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
```

3. **Crear archivo de layout en `android/app/src/main/res/layout/steps_coins_widget.xml`:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:orientation="horizontal"
    android:padding="16dp">

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical"
        android:gravity="center">

        <TextView
            android:id="@+id/steps_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="0"
            android:textSize="28sp"
            android:textStyle="bold"
            android:textColor="#6366F1" />

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="pasos"
            android:textSize="12sp"
            android:textColor="#999999" />
    </LinearLayout>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical"
        android:gravity="center">

        <TextView
            android:id="@+id/coins_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="0"
            android:textSize="28sp"
            android:textStyle="bold"
            android:textColor="#FFD700" />

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="monedas"
            android:textSize="12sp"
            android:textColor="#999999" />
    </LinearLayout>
</LinearLayout>
```

4. **Registrar en `AndroidManifest.xml`:**

```xml
<receiver
    android:name=".StepsCoinsWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/steps_coins_widget_info" />
</receiver>
```

5. **Crear archivo `android/app/src/main/res/xml/steps_coins_widget_info.xml`:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="100dp"
    android:updatePeriodMillis="3600000"
    android:previewImage="@drawable/widget_preview"
    android:initialLayout="@layout/steps_coins_widget"
    android:widgetCategory="keyguard" />
```

### iOS

1. **Agregar dependencia:**
```yaml
dependencies:
  flutter_home_widget: ^0.5.0
```

2. **Crear WidgetKit Extension en Xcode:**
   - En Xcode: File → New → Target → Widget Extension
   - Nombre: `StepsCoinsWidget`

3. **Crear el widget en Swift:**

```swift
import WidgetKit
import SwiftUI

struct StepsCoinsWidgetEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let coins: Int
}

struct StepsCoinsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsCoinsWidgetEntry {
        StepsCoinsWidgetEntry(date: Date(), steps: 0, coins: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsCoinsWidgetEntry) -> ()) {
        let entry = StepsCoinsWidgetEntry(date: Date(), steps: 8452, coins: 1240)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsCoinsWidgetEntry>) -> ()) {
        var entries: [StepsCoinsWidgetEntry] = []
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = StepsCoinsWidgetEntry(date: entryDate, steps: 8452, coins: 1240)
            entries.append(entry)
        }
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct StepsCoinsWidgetEntryView : View {
    var entry: StepsCoinsWidgetProvider.Entry

    var body: some View {
        ZStack {
            ContainerBackground(.fill, for: .widget)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(entry.steps)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("pasos")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                VStack(alignment: .trailing) {
                    Text("\(entry.coins)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("monedas")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }
}

@main
struct StepsCoinsWidget: Widget {
    let kind: String = "StepsCoinsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: StepsCoinsWidgetProvider()
        ) { entry in
            StepsCoinsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pasos y Monedas")
        .description("Muestra tu progreso de pasos y monedas")
        .supportedFamilies([.accessoryRectangular, .systemSmall])
    }
}
```

---

## 📱 Integración en tu app

### En `main.dart`:

```dart
import 'package:walkwin_app/services/lock_screen_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar lock screen widget
  await LockScreenWidgetService.initialize();
  
  // ... resto de inicializaciones
  runApp(const WalkWinApp());
}
```

### Actualizar widget cuando cambien datos:

```dart
import 'package:walkwin_app/services/lock_screen_widget_service.dart';

// Cuando obtengas nuevos datos de pasos y monedas:
LockScreenWidgetService.updateWidget(
  steps: newSteps,
  coins: newCoins,
);
```

---

## 🎨 Personalización

### Cambiar colores

Edita los colores en `steps_coins_widget.dart`:

```dart
final accentColor = const Color(0xFF6366F1); // Cambiar azul indigo
const Color(0xFFFFD700) // Cambiar dorado
```

### Cambiar duración de animación

En `StepsCoinsWidget._setupAnimations()`:

```dart
_coinsAnimationController = AnimationController(
  duration: const Duration(milliseconds: 600), // Aumentar para más lento
  vsync: this,
);
```

### Cambiar curva de animación

```dart
CurvedAnimation(parent: _coinsAnimationController, curve: Curves.elasticOut),
// Opciones: Curves.easeInOut, Curves.bounce, Curves.decelerate, etc.
```

---

## ⚠️ Notas Importantes

- **Permisos Android:** Asegúrate de agregar los permisos necesarios en `AndroidManifest.xml`
- **iOS:** El widget en lock screen es limitado, solo actualiza en ciertos intervalos
- **Actualización en background:** Para actualizar en background, necesitas usar `WorkManager` (Android) o `Background Fetch` (iOS)
- **Datos locales:** Almacena los datos de pasos/monedas en SQLite o SharedPreferences para que el widget pueda acceder sin llamadas de red

---

## 🐛 Troubleshooting

### El widget no aparece en lock screen
- Verifica que el `widgetCategory="keyguard"` esté en `steps_coins_widget_info.xml`
- En iOS, asegúrate de que el widget esté registrado correctamente en el target

### La animación no funciona
- Verifica que estés usando `StepsCoinsWidget` (no la versión de lock screen)
- Revisa que el `TickerProvider` esté correctamente inicializado

### Datos no se actualizan
- Usa `LockScreenWidgetService.updateWidget()` cada vez que cambien los datos
- Asegúrate de que los datos estén siendo almacenados localmente

---

## 📚 Referencias

- [Flutter Widgets](https://flutter.dev/docs/development/ui/widgets)
- [Android App Widgets](https://developer.android.com/guide/topics/appwidgets)
- [iOS WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [flutter_home_widget](https://pub.dev/packages/flutter_home_widget)
