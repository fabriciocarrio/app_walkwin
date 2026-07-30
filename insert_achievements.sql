-- ============================================================
-- Script: insert_achievements.sql (PostgreSQL)
-- Descripcion: Inserta los 26 logros de WalkWin
-- Ejecutar: psql -U usuario -d walkwin -f insert_achievements.sql
-- ============================================================

-- Limpiar antes de insertar (opcional)
-- TRUNCATE TABLE user_achievements;
-- TRUNCATE TABLE achievements;

INSERT INTO achievements (slug, name, description, category, rarity, badge_type, icon_key, reward_coins, reward_xp, criteria, is_active, created_at, updated_at) VALUES
('primeros_pasos',      'Primeros Pasos',       'Camina 1.000 pasos en total',            'walker', 'common',    'badge', 'walk_01', 50,   100,  json_build_object('type', 'steps_walked', 'target', 1000), true, NOW(), NOW()),
('caminante',           'Caminante',            'Camina 10.000 pasos en total',           'walker', 'common',    'badge', 'walk_02', 150,  300,  json_build_object('type', 'steps_walked', 'target', 10000), true, NOW(), NOW()),
('maratonista',         'Maratonista',          'Camina 42.195 pasos en un solo dia',     'walker', 'epic',      'medal', 'walk_03', 500,  1000, json_build_object('type', 'daily_steps', 'target', 42195), true, NOW(), NOW()),
('meta_diaria_7',       'Meta Diaria x7',       'Cumple la meta diaria 7 dias seguidos',  'walker', 'rare',      'medal', 'walk_04', 300,  600,  json_build_object('type', 'consecutive_days', 'target', 7), true, NOW(), NOW()),
('doble_meta',          'Doble Meta',           'Camina 20.000 pasos en un solo dia',     'walker', 'rare',      'medal', 'walk_05', 350,  700,  json_build_object('type', 'daily_steps', 'target', 20000), true, NOW(), NOW()),
('centurion',           'Centurion',            'Camina 100.000 pasos en total',          'walker', 'epic',      'trophy','walk_06', 800,  1500, json_build_object('type', 'steps_walked', 'target', 100000), true, NOW(), NOW()),
('racha_inicial',       'Racha Inicial',        'Camina 3 dias seguidos',                 'streak', 'common',    'badge', 'streak_01', 50,   100, json_build_object('type', 'consecutive_days', 'target', 3), true, NOW(), NOW()),
('racha_semanal',       'Racha Semanal',        'Camina 7 dias seguidos',                 'streak', 'rare',      'medal', 'streak_02', 300,  600, json_build_object('type', 'consecutive_days', 'target', 7), true, NOW(), NOW()),
('racha_mensual',       'Racha Mensual',        'Camina 30 dias seguidos',                'streak', 'epic',      'trophy','streak_03', 1000, 2000, json_build_object('type', 'consecutive_days', 'target', 30), true, NOW(), NOW()),
('racha_legendaria',    'Racha Legendaria',     'Camina 100 dias seguidos',               'streak', 'legendary', 'trophy','streak_04', 5000, 10000, json_build_object('type', 'consecutive_days', 'target', 100), true, NOW(), NOW()),
('fenix',               'Fenix',                'Recupera tu racha despues de un dia sin caminar', 'streak', 'rare', 'badge', 'streak_05', 200, 400, json_build_object('type', 'streak_recovery', 'target', 1), true, NOW(), NOW()),
('primer_descubrimiento','Primer Descubrimiento','Hace check-in en tu primer comercio',   'social', 'common',    'badge', 'shop_01', 50,   100, json_build_object('type', 'checkins', 'target', 1), true, NOW(), NOW()),
('local',               'Local',                'Hace check-in en 5 comercios distintos', 'social', 'common',    'badge', 'shop_02', 100,  200, json_build_object('type', 'unique_businesses', 'target', 5), true, NOW(), NOW()),
('embajador_barrio',    'Embajador del Barrio', 'Hace check-in en 15 comercios distintos','social', 'rare',     'medal', 'shop_03', 300,  600, json_build_object('type', 'unique_businesses', 'target', 15), true, NOW(), NOW()),
('fiel',                'Fiel',                 'Hace check-in 5 veces en el mismo comercio', 'social', 'rare',  'medal', 'shop_04', 250, 500, json_build_object('type', 'same_business_checkins', 'target', 5), true, NOW(), NOW()),
('qr_master',           'QR Master',            'Escanea 10 codigos QR en comercios',    'social', 'epic',      'trophy','shop_05', 500,  1000, json_build_object('type', 'qr_scans', 'target', 10), true, NOW(), NOW()),
('cartografo',          'Cartografo',           'Descubri tu primer POI turistico',      'explorer','common',   'badge', 'explore_01', 50,   100, json_build_object('type', 'pois_discovered', 'target', 1), true, NOW(), NOW()),
('explorador_urbano',   'Explorador Urbano',    'Descubri 5 POIs turisticos',            'explorer','common',   'badge', 'explore_02', 150,  300, json_build_object('type', 'pois_discovered', 'target', 5), true, NOW(), NOW()),
('coleccionista',       'Coleccionista',        'Recolecta tu primer coleccionable',     'collector','common',  'badge', 'collect_01', 50,   100, json_build_object('type', 'collectibles_gathered', 'target', 1), true, NOW(), NOW()),
('completista',         'Completista',          'Completa un set de coleccionables',     'collector','epic',    'trophy','collect_02', 500,  1000, json_build_object('type', 'sets_completed', 'target', 1), true, NOW(), NOW()),
('exterminador_spawns', 'Exterminador de Spawns','Recolecta 50 spawns dinamicos',        'collector','epic',    'trophy','special_05', 500,  1000, json_build_object('type', 'spawns_collected', 'target', 50), true, NOW(), NOW()),
('misionero',           'Misionero',            'Completa tu primera mision',             'mission', 'common',   'badge', 'mission_01', 100,  200, json_build_object('type', 'missions_completed', 'target', 1), true, NOW(), NOW()),
('resolvedor',          'Resolvedor',           'Completa 10 misiones',                   'mission', 'rare',     'medal', 'mission_02', 300,  600, json_build_object('type', 'missions_completed', 'target', 10), true, NOW(), NOW()),
('madrugador',          'Madrugador',           'Camina 2.000 pasos antes de las 8 AM en 3 dias', 'special', 'common', 'badge', 'special_01', 100, 200, json_build_object('type', 'morning_steps', 'target', 3), true, NOW(), NOW()),
('noctambulo',          'Noctambulo',           'Camina 2.000 pasos despues de las 10 PM en 3 dias', 'special', 'common', 'badge', 'special_02', 100, 200, json_build_object('type', 'night_steps', 'target', 3), true, NOW(), NOW()),
('finde_activo',        'Finde Activo',         'Cumpli la meta diaria sabado y domingo 4 veces', 'special', 'rare', 'medal', 'special_03', 250, 500, json_build_object('type', 'weekend_goal', 'target', 4), true, NOW(), NOW()),
('semana_perfecta',     'Semana Perfecta',      'Cumpli la meta diaria los 7 dias de la semana', 'special', 'epic', 'trophy', 'special_04', 1000, 2000, json_build_object('type', 'perfect_week', 'target', 1), true, NOW(), NOW());
