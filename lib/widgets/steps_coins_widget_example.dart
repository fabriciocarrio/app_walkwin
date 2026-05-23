import 'package:flutter/material.dart';
import 'package:walkwin_app/widgets/steps_coins_widget.dart';
import 'package:walkwin_app/widgets/lock_screen_widget.dart';

/// Ejemplo de cómo usar los widgets de pasos y monedas en tu app
class StepsCoinsWidgetExample extends StatefulWidget {
  const StepsCoinsWidgetExample({super.key});

  @override
  State<StepsCoinsWidgetExample> createState() =>
      _StepsCoinsWidgetExampleState();
}

class _StepsCoinsWidgetExampleState extends State<StepsCoinsWidgetExample> {
  int _steps = 8452;
  int _coins = 1240;
  int _coinAnimationCounter = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ejemplo 1: Widget Principal Grande
          Text(
            'Widget Principal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          StepsCoinsWidget(
            steps: _steps,
            coins: _coins,
            onCoinsChanged: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Ganaste monedas! 🎉'),
                  duration: Duration(milliseconds: 800),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Ejemplo 2: Widget Compacto
          Text(
            'Widget Compacto (para sidebars/headers)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: StepsCoinsWidget(
              steps: _steps,
              coins: _coins,
              isCompact: true,
            ),
          ),
          const SizedBox(height: 32),

          // Ejemplo 3: Widget de Lock Screen
          Text(
            'Widget de Pantalla de Bloqueo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          LockScreenStepsCoinsWidget(
            steps: _steps,
            coins: _coins,
            lastUpdate: DateTime.now(),
          ),
          const SizedBox(height: 32),

          // Botones de prueba para animar
          Text(
            'Prueba de Animación',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _steps += 100;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('+ 100 pasos'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _coins += 50;
                    _coinAnimationCounter++;
                  });
                },
                icon: const Icon(Icons.monetization_on),
                label: const Text('+ 50 monedas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Animaciones completadas: $_coinAnimationCounter',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Ejemplo de integración en tu dashboard actual
/// Reemplaza la sección donde muestras pasos/monedas con:
/*

// En tu dashboard_screen.dart, en el build():

StepsCoinsWidget(
  steps: _steps,
  coins: _coins,
  onCoinsChanged: () {
    // Opcional: reproducir sonido, vibración, notificación
    _playCoinsSound();
  },
),

// Para usar la versión compacta en un header:

Container(
  padding: const EdgeInsets.all(16),
  child: Row(
    children: [
      const Text('Mi progreso:'),
      const SizedBox(width: 12),
      StepsCoinsWidget(
        steps: _steps,
        coins: _coins,
        isCompact: true,
      ),
    ],
  ),
),

*/
