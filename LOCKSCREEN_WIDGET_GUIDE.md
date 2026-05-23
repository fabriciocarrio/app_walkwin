# Implementar Widget Real en Pantalla de Bloqueo (Lock Screen)

## Estado Actual

Implementé una **notificación persistente** que muestra:
- 📊 Progreso de pasos (con barra de progreso)
- 💰 Monedas acumuladas
- ⏳ Pasos faltantes para alcanzar meta

✅ **Esta notificación es visible en:**
- Barra de notificaciones (siempre visible)
- Cuando el teléfono está bloqueado
- En el notification center/panel

Para agregar un **widget visual adicional** en la pantalla de bloqueo, sigue los pasos abajo:

---

## Android - AppWidget en Lock Screen

### Paso 1: Crear la UI del Widget

Crea `android/app/src/main/res/layout/steps_coins_widget_layout.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#FFFFFF"
    android:gravity="center">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center">

        <!-- Pasos -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical"
            android:gravity="center">

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="👟"
                android:textSize="24sp"
                android:gravity="center" />

            <TextView
                android:id="@+id/steps_value"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="0"
                android:textSize="24sp"
                android:textStyle="bold"
                android:textColor="#6366F1"
                android:gravity="center"
                android:layout_marginTop="4dp" />

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="pasos"
                android:textSize="12sp"
                android:textColor="#999999"
                android:gravity="center" />
        </LinearLayout>

        <!-- Divisor -->
        <View
            android:layout_width="1dp"
            android:layout_height="60dp"
            android:background="#E0E0E0"
            android:layout_marginHorizontal="16dp" />

        <!-- Monedas -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical"
            android:gravity="center">

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="🪙"
                android:textSize="24sp"
                android:gravity="center" />

            <TextView
                android:id="@+id/coins_value"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="0"
                android:textSize="24sp"
                android:textStyle="bold"
                android:textColor="#FFD700"
                android:gravity="center"
                android:layout_marginTop="4dp" />

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="monedas"
                android:textSize="12sp"
                android:textColor="#999999"
                android:gravity="center" />
        </LinearLayout>
    </LinearLayout>

    <!-- Progress Bar -->
    <ProgressBar
        android:id="@+id/progress_bar"
        android:layout_width="match_parent"
        android:layout_height="4dp"
        android:layout_marginTop="12dp"
        style="?android:attr/progressBarStyleHorizontal"
        android:progress="50"
        android:progressDrawable="@drawable/progress_bar_drawable" />

    <TextView
        android:id="@+id/progress_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="50% - Te faltan 5000 pasos"
        android:textSize="11sp"
        android:textColor="#999999"
        android:gravity="center"
        android:layout_marginTop="6dp" />
</LinearLayout>
```

### Paso 2: Crear el AppWidget Provider

Crea `android/app/src/main/java/com/walkwin/app/StepsCoinsWidgetProvider.kt`:

```kotlin
package com.walkwin.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Leer datos guardados (SharedPreferences o donde guardes los datos)
            val prefs = context.getSharedPreferences("walkwin_prefs", Context.MODE_PRIVATE)
            val steps = prefs.getInt("steps", 0)
            val coins = prefs.getInt("coins", 0)
            val dailyGoal = 10000

            val views = RemoteViews(context.packageName, R.layout.steps_coins_widget_layout)
            
            views.setTextViewText(R.id.steps_value, "$steps")
            views.setTextViewText(R.id.coins_value, "$coins")
            
            val progress = (steps.toFloat() / dailyGoal * 100).toInt()
            val stepsLeft = (dailyGoal - steps).coerceAtLeast(0)
            
            views.setProgressBar(R.id.progress_bar, 100, progress, false)
            views.setTextViewText(
                R.id.progress_text,
                "$progress% - Te faltan $stepsLeft pasos"
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

### Paso 3: Registrar en AndroidManifest.xml

Agrega dentro de `<application>`:

```xml
<receiver
    android:name=".StepsCoinsWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="com.walkwin.app.UPDATE_WIDGET" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/steps_coins_widget_info" />
</receiver>
```

### Paso 4: Crear archivo de configuración

Crea `android/app/src/main/res/xml/steps_coins_widget_info.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="200dp"
    android:minHeight="100dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/steps_coins_widget_layout"
    android:widgetCategory="keyguard|home_screen"
    android:previewImage="@mipmap/ic_launcher" />
```

**Nota:** `widgetCategory="keyguard"` hace que aparezca en la pantalla de bloqueo

### Paso 5: Actualizar el Widget desde Flutter

En tu `main.dart` o donde guardes los datos de pasos:

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> updateWidget() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('steps', _steps);
  await prefs.setInt('coins', _coins);
  
  // Enviar broadcast para actualizar widget
  await platform.invokeMethod('updateWidget', {
    'steps': _steps,
    'coins': _coins,
  });
}
```

---

## iOS - WidgetKit (Lock Screen)

### Paso 1: Crear Widget Extension

En Xcode:
1. File → New → Target
2. Selecciona "Widget Extension"
3. Nombre: `StepsCoinsWidget`

### Paso 2: Crear la estructura de datos

En el archivo `StepsCoinsWidget.swift`:

```swift
import WidgetKit
import SwiftUI

struct StepsCoinsWidgetEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let coins: Int
    let dailyGoal: Int = 10000
}

struct StepsCoinsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsCoinsWidgetEntry {
        StepsCoinsWidgetEntry(date: Date(), steps: 0, coins: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsCoinsWidgetEntry) -> ()) {
        let entry = StepsCoinsWidgetEntry(date: Date(), steps: 5000, coins: 50)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsCoinsWidgetEntry>) -> ()) {
        var entries: [StepsCoinsWidgetEntry] = []
        let currentDate = Date()
        
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            
            // Aquí leerías datos reales
            let entry = StepsCoinsWidgetEntry(date: entryDate, steps: 5000, coins: 50)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct StepsCoinsWidgetEntryView: View {
    var entry: StepsCoinsWidgetProvider.Entry

    var body: some View {
        ZStack {
            ContainerBackground(.fill, for: .widget)
            
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    // Pasos
                    VStack(spacing: 4) {
                        Text("👟").font(.system(size: 24))
                        Text("\(entry.steps)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("pasos")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                    
                    // Monedas
                    VStack(spacing: 4) {
                        Text("🪙").font(.system(size: 24))
                        Text("\(entry.coins)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        Text("monedas")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Progress Bar
                let progress = Double(entry.steps) / Double(entry.dailyGoal)
                ProgressView(value: progress)
                    .accentColor(.blue)
                
                Text("\(Int(progress * 100))% - Te faltan \(entry.dailyGoal - entry.steps) pasos")
                    .font(.caption2)
                    .foregroundColor(.gray)
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

## ¿Cuál usar?

| Opción | Ventajas | Desventajas |
|--------|----------|------------|
| **Notificación Persistente** (Ya implementada) | ✅ Fácil, funciona en ambas plataformas, sin código nativo necesario | ⚠️ No es un "widget" visual real, más pequeña |
| **AppWidget Android** | ✅ Widget visual grande, customizable | ⚠️ Solo Android, requiere código nativo |
| **WidgetKit iOS** | ✅ Widget visual en lock screen iOS, moderno | ⚠️ Solo iOS, requiere Swift |

**Recomendación:** La notificación persistente ya está implementada y funcional. Si quieres un widget visual adicional, empieza con Android.

---

## Probando

### Android
1. Abre el gestor de widgets de tu Android
2. Busca "WalkWin" o "Pasos y Monedas"
3. Arrastra a la pantalla de inicio o lock screen

### iOS
1. Ve a Lock Screen
2. Toca el botón "+"
3. Busca tu app
4. Selecciona el widget
