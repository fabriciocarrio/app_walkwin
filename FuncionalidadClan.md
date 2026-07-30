# Exploria - Sistema de Clanes e Influencia Exploria (V1)

## Objetivo

Incorporar un sistema de clanes que permita a los usuarios colaborar y competir por el liderazgo de departamentos mediante la acumulación de Influencia Exploria.

El objetivo es aumentar la retención, fomentar la actividad física y generar interacción social dentro de la aplicación.

---

# Conceptos Principales

## Puntos Exploria

Moneda principal de Exploria.

Se obtiene mediante la conversión de pasos registrados.

Conversión actual:

100 pasos = 1 Punto Exploria

Los Puntos Exploria pueden utilizarse para:

* Canjear premios.
* Obtener descuentos en comercios adheridos.
* Participar en sorteos.
* Acceder a beneficios especiales.

Los Puntos Exploria son personales y no pueden transferirse a otros usuarios.

---

## Influencia Exploria

Moneda social de Exploria.

Se utiliza exclusivamente para:

* Competencia entre clanes.
* Ranking de departamentos.
* Ranking de clanes.
* Estadísticas de participación.

La Influencia Exploria:

* No puede canjearse por premios.
* No puede comprarse.
* No puede venderse.
* No puede transferirse.

---

# Generación de Influencia

Cada vez que un usuario convierte pasos en Puntos Exploria también genera automáticamente Influencia Exploria.

Ejemplo:

# 100 pasos

1 Punto Exploria
+
1 Influencia Exploria

La generación de Influencia es automática.

El usuario no debe realizar ninguna acción adicional.

---

# Clanes

## Definición

Un clan es un grupo de usuarios que colaboran para acumular Influencia Exploria y competir contra otros clanes.

Cada usuario puede pertenecer a un único clan.

---

# Creación de Clan

Campos obligatorios:

* Nombre del clan
* Descripción
* Imagen o logo
* Provincia representada
* Departamento representado

Restricciones:

* El nombre debe ser único.
* El departamento seleccionado no podrá modificarse posteriormente.
* El usuario creador se convierte automáticamente en líder.
* Limite de 30 miembros por clan.

---

# Departamento Representado

Cada clan representa un único departamento.

Ejemplos:

* Capital
* Rawson
* Rivadavia
* Chimbas
* Pocito
* Santa Lucía

El departamento pertenece al clan, no al usuario.

Los usuarios no necesitan informar provincia, departamento o localidad en su perfil.

---

# Participación Departamental

Toda la Influencia Exploria generada por un miembro se suma automáticamente al departamento representado por su clan.

Ejemplo:

Usuario:
Fabricio

Clan:
Los Cóndores

Departamento representado:
Capital

Toda la Influencia generada por Fabricio se suma al clan Los Cóndores y al ranking del departamento Capital.

---

# Unirse a un Clan

Métodos disponibles:

* Búsqueda por nombre.
* Código de invitación.

Restricciones:

* Un usuario solo puede pertenecer a un clan.
* Si abandona un clan deberá esperar 7 días para unirse a otro.

---

# Roles

## Líder

Permisos:

* Editar información del clan.
* Cambiar imagen.
* Generar invitaciones.
* Expulsar miembros.

## Miembro

Permisos:

* Participar.
* Generar Influencia.
* Ver estadísticas.
* Invitar mediante código compartido.

---

# Influencia del Clan

Cuando un usuario obtiene Influencia:

+100 Influencia Personal

Automáticamente:

+100 Influencia para el Clan

No existe donación manual.

No existe tesoro de clan.

No existen boosters.

Todo el aporte es automático.

---

# Ranking Interno del Clan

Cada clan tendrá un ranking de aportes individuales.

Información mostrada:

* Posición
* Usuario
* Influencia acumulada

Ejemplo:

1. Fabricio - 5.200
2. Juan - 4.800
3. Ana - 4.100

Objetivo:

Reconocer a los miembros más activos.

---

# Ranking Departamental

Cada departamento posee su propio ranking.

Ejemplo:

Departamento Capital

1. Los Cóndores - 25.000
2. Guardianes Urbanos - 18.500
3. Exploradores SJ - 14.200

La posición se calcula según la Influencia acumulada durante la temporada.

---

# Rey del Departamento

El clan con mayor Influencia acumulada durante la temporada obtiene el título:

"Rey del Departamento"

Ejemplos:

* Rey de Capital
* Rey de Rawson
* Rey de Rivadavia

Beneficios:

* Insignia especial.
* Destacado visual en rankings.
* Reconocimiento dentro de la comunidad.

No existen recompensas económicas en la V1.

---

# Temporadas

Duración:

30 días

Al finalizar una temporada:

* Se determina el clan ganador de cada departamento.
* Se asigna el título Rey del Departamento.
* Se reinicia la Influencia de temporada.

Se conserva:

* Historial.
* Logros.
* Estadísticas.
* Récords.

---

# Perfil de Usuario

Nueva sección:

Clan:
Los Cóndores

Influencia Personal:
12.450

Aporte de Temporada:
2.350

Posición dentro del Clan:
#5

---

# Pantalla de Clan

Información mostrada:

* Nombre
* Logo
* Descripción
* Departamento representado
* Cantidad de miembros
* Influencia total
* Posición departamental
* Días restantes de temporada

Además:

Listado de miembros.

---

# Historial de Temporadas

Cada clan podrá visualizar:

* Temporadas disputadas
* Veces que fue Rey del Departamento
* Mejor posición histórica

---

# Reglas Anti-Abuso

* La Influencia solo se genera mediante pasos válidos.
* No se permite transferir Influencia.
* No se permite transferir Puntos Exploria.
* Un usuario solo puede pertenecer a un clan.
* Tiempo de espera de 7 días para cambiar de clan.
* El departamento de un clan no puede modificarse.

---

# Alcance de la V1

Incluido:

✅ Creación de clanes

✅ Unión a clanes

✅ Influencia Exploria

✅ Ranking interno

✅ Ranking departamental

✅ Temporadas

✅ Rey del Departamento

✅ Historial básico

No incluido:

❌ Tesoro de clan

❌ Boosters

❌ Donaciones

❌ Roles avanzados

❌ Votaciones

❌ Guerra entre clanes

❌ Eventos especiales

❌ Conquista geográfica por GPS

❌ Cartas exclusivas de clan

❌ Misiones de clan

❌ Recompensas económicas para clanes

---

# Objetivos de Validación

La V1 permitirá medir:

1. Cantidad de clanes creados.
2. Cantidad de usuarios que participan en clanes.
3. Frecuencia de consulta de rankings.
4. Impacto de los clanes en el aumento de pasos diarios.
5. Participación en temporadas.
6. Competitividad entre departamentos.

El objetivo principal es validar que la competencia social aumenta la actividad física y mejora la retención de usuarios dentro de Exploria.
