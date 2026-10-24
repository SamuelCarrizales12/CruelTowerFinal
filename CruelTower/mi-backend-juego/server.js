// SEGMENTO 2: API del servidor
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(express.json({ limit: '1mb' }));   // los lotes de telemetría pesan más que un guardado
app.use(cors());
app.use(express.static(path.join(__dirname, 'public'))); // opcional: dashboard en http://localhost:3000

const pool = new Pool({
    user: process.env.PGUSER || 'postgres',
    host: process.env.PGHOST || 'localhost',
    database: process.env.PGDATABASE || 'game_db',
    password: process.env.PGPASSWORD || '1234',
    port: Number(process.env.PGPORT) || 5432,
});
pool.on('error', (err) => console.error('❌ Error inesperado en el pool:', err.message));

// ---------- utilidades ----------
const clampNum = (v, max) => Math.min(Math.max(Number(v) || 0, 0), max);
const clampInt = (v, max) => Math.round(clampNum(v, max));
const limitParam = (v, def, max) => Math.min(Math.max(parseInt(v, 10) || def, 1), max);

const fail = (res, msg, err) => {
    console.error('❌', msg, err.message);
    res.status(500).json({ error: msg });
};

// ---------- estado del servidor ----------
app.get('/api/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({ status: 'ok', database: 'connected' });
    } catch (err) {
        res.status(503).json({ status: 'error', database: 'disconnected' });
    }
});

// ---------- guardar partida (Godot) ----------
app.post('/api/save-progress', async (req, res) => {
    const body = req.body || {};
    const username = String(body.username || '').trim().slice(0, 50)
        || `Jugador_${Math.floor(Math.random() * 8999 + 1000)}`;

    const playTime = clampNum(body.play_time, 86400);
    const coins = clampInt(body.coins, 1000000);
    const relics = clampInt(body.collectibles_count, 1000);
    const score = clampInt(body.score, 100000000);

    console.log('📥 DATOS RECIBIDOS:', { username, playTime, coins, relics, score });

    try {
        const player = await pool.query(
            `INSERT INTO players (username) VALUES ($1)
             ON CONFLICT (username) DO UPDATE SET username = EXCLUDED.username
             RETURNING id;`,
            [username]
        );
        const playerId = player.rows[0].id;

        await pool.query(
            `INSERT INTO player_stats (player_id, play_time, coins, collectibles_count, score, updated_at)
             VALUES ($1, $2, $3, $4, $5, NOW());`,
            [playerId, playTime, coins, relics, score]
        );

        console.log(`✅ Intento guardado para ${username} (ID ${playerId})`);
        res.json({ status: 'success', message: 'Intento registrado con éxito' });
    } catch (err) {
        fail(res, 'Error al registrar intento', err);
    }
});

// ---------- historial (?limit=50&offset=0) ----------
app.get('/api/leaderboard', async (req, res) => {
    const limit = limitParam(req.query.limit, 100, 500);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
    try {
        const result = await pool.query(
            `SELECT p.username, s.score, s.coins, s.collectibles_count, s.play_time, s.updated_at
             FROM player_stats s
             JOIN players p ON p.id = s.player_id
             ORDER BY s.updated_at DESC
             LIMIT $1 OFFSET $2;`,
            [limit, offset]
        );
        res.json(result.rows);
    } catch (err) {
        fail(res, 'Error al obtener el historial', err);
    }
});

// ---------- KPIs + actividad de los últimos 14 días ----------
app.get('/api/stats', async (req, res) => {
    try {
        const kpis = await pool.query(
            `SELECT COUNT(*)::int AS total_games,
                    COUNT(DISTINCT player_id)::int AS total_players,
                    COALESCE(MAX(score), 0)::int AS best_score,
                    COALESCE(ROUND(AVG(score)), 0)::int AS avg_score,
                    COALESCE(ROUND(AVG(play_time)::numeric, 1), 0)::float AS avg_time,
                    COALESCE(SUM(coins), 0)::int AS total_coins,
                    COALESCE(SUM(collectibles_count), 0)::int AS total_relics
             FROM player_stats;`
        );
        const timeline = await pool.query(
            `SELECT to_char(date_trunc('day', updated_at), 'YYYY-MM-DD') AS day,
                    COUNT(*)::int AS games,
                    COALESCE(ROUND(AVG(score)), 0)::int AS avg_score
             FROM player_stats
             WHERE updated_at >= NOW() - INTERVAL '14 days'
             GROUP BY 1 ORDER BY 1;`
        );
        res.json({ kpis: kpis.rows[0], timeline: timeline.rows });
    } catch (err) {
        fail(res, 'Error al calcular estadísticas', err);
    }
});

// ---------- ranking: mejor puntaje por jugador (?limit=10) ----------
app.get('/api/ranking', async (req, res) => {
    const limit = limitParam(req.query.limit, 10, 100);
    try {
        const result = await pool.query(
            `SELECT p.username,
                    MAX(s.score)::int AS best_score,
                    COUNT(*)::int AS attempts,
                    SUM(s.coins)::int AS total_coins,
                    MAX(s.collectibles_count)::int AS best_relics,
                    MAX(s.updated_at) AS last_played
             FROM player_stats s
             JOIN players p ON p.id = s.player_id
             GROUP BY p.username
             ORDER BY best_score DESC, attempts ASC
             LIMIT $1;`,
            [limit]
        );
        res.json(result.rows);
    } catch (err) {
        fail(res, 'Error al obtener el ranking', err);
    }
});

// ---------- progreso de un jugador (Godot) ----------
app.get('/api/load-progress/:username', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT s.score, s.coins, s.collectibles_count, s.play_time, s.updated_at
             FROM player_stats s
             JOIN players p ON p.id = s.player_id
             WHERE p.username = $1
             ORDER BY s.updated_at DESC;`,
            [req.params.username]
        );
        const rows = result.rows;
        res.json({
            username: req.params.username,
            attempts: rows.length,
            last: rows[0] || null,
            best_score: rows.reduce((max, r) => Math.max(max, r.score || 0), 0),
            history: rows
        });
    } catch (err) {
        fail(res, 'Error al cargar progreso', err);
    }
});


// =====================================================================
//  TELEMETRÍA (Godot -> API -> PostgreSQL)
// =====================================================================
const cleanId  = (v) => /^[A-Za-z0-9_-]{6,64}$/.test(String(v || '')) ? String(v) : null;
const cleanStr = (v, max) => String(v || '').trim().slice(0, max);
const numOrNull = (v) => (Number.isFinite(Number(v)) && v !== null && v !== '' ? Number(v) : null);
const MAX_ITEMS = 500;
const PROGRESS_EVENTS = ['enemy_kill', 'collectible', 'medkit', 'ammo_pickup', 'weapon_pickup', 'hit'];

// Cierra un run: calcula sus totales desde los eventos y lo copia a player_stats (una sola vez)
async function finalizeRun(client, runId, outcome) {
    const upd = await client.query(
        `UPDATE runs r SET
            outcome = $2, ended_at = NOW(), duration_s = r.last_t,
            kills = a.kills, deaths = a.deaths, collectibles = a.collectibles,
            shots = a.shots, hits = a.hits, damage_taken = a.damage,
            idle_before_end_s = GREATEST(0, r.last_t - a.last_progress),
            score = a.kills * 100 + a.collectibles * 250
         FROM (
            SELECT COUNT(*) FILTER (WHERE event_type = 'enemy_kill')::int   AS kills,
                   COUNT(*) FILTER (WHERE event_type = 'death')::int        AS deaths,
                   COUNT(*) FILTER (WHERE event_type = 'collectible')::int  AS collectibles,
                   COUNT(*) FILTER (WHERE event_type = 'shot')::int         AS shots,
                   COUNT(*) FILTER (WHERE event_type = 'hit')::int          AS hits,
                   COALESCE(SUM((data->>'amount')::numeric) FILTER (WHERE event_type = 'damage_taken'), 0)::int AS damage,
                   COALESCE(MAX(t) FILTER (WHERE event_type = ANY($3::text[])), 0) AS last_progress
            FROM events WHERE run_id = $1
         ) a
         WHERE r.id = $1 AND r.outcome = 'in_progress'
         RETURNING r.player_id, r.duration_s, r.collectibles, r.score;`,
        [runId, outcome, PROGRESS_EVENTS]
    );
    if (upd.rowCount === 1) {
        const r = upd.rows[0];
        // coins = 0: el juego aún no tiene monedas
        await client.query(
            `INSERT INTO player_stats (player_id, play_time, coins, collectibles_count, score, updated_at)
             VALUES ($1, $2, 0, $3, $4, NOW());`,
            [r.player_id, r.duration_s, r.collectibles, r.score]
        );
    }
}

// Lotes que envía Godot cada pocos segundos (idempotente: se puede reenviar sin duplicar)
app.post('/api/telemetry/batch', async (req, res) => {
    const b = req.body || {};
    const sessionId = cleanId(b.session_id);
    if (!sessionId) return res.status(400).json({ error: 'session_id inválido' });

    const username = cleanStr(b.username, 50) || 'Jugador_anonimo';
    const runId = cleanId(b.run_id);
    const level = cleanStr(b.level_name, 60) || 'Nivel 1';
    const t = clampNum(b.t, 86400);
    const events = Array.isArray(b.events) ? b.events.slice(0, MAX_ITEMS) : [];
    const positions = Array.isArray(b.positions) ? b.positions.slice(0, MAX_ITEMS) : [];

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const player = await client.query(
            `INSERT INTO players (username) VALUES ($1)
             ON CONFLICT (username) DO UPDATE SET username = EXCLUDED.username RETURNING id;`,
            [username]
        );
        const playerId = player.rows[0].id;

        await client.query(
            `INSERT INTO sessions (id, player_id, game_version, platform) VALUES ($1, $2, $3, $4)
             ON CONFLICT (id) DO UPDATE SET last_seen = NOW(), player_id = EXCLUDED.player_id;`,
            [sessionId, playerId, cleanStr(b.game_version, 20), cleanStr(b.platform, 20)]
        );
        if (b.session_end) {
            await client.query(`UPDATE sessions SET ended_at = NOW(), end_reason = $2 WHERE id = $1;`,
                [sessionId, cleanStr(b.session_end, 30)]);
        }

        if (runId) {
            await client.query(
                `INSERT INTO runs (id, session_id, player_id, level_name, slot, last_t)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT (id) DO UPDATE SET last_t = GREATEST(runs.last_t, EXCLUDED.last_t), last_seen = NOW();`,
                [runId, sessionId, playerId, level, numOrNull(b.slot), t]
            );

            if (events.length) {
                await client.query(
                    `INSERT INTO events (run_id, player_id, level_name, seq, event_type, t, x, y, z, data)
                     SELECT $1, $2, $3, u.seq, u.type, u.t, u.x, u.y, u.z, u.data::jsonb
                     FROM unnest($4::int[], $5::text[], $6::real[], $7::real[], $8::real[], $9::real[], $10::text[])
                          AS u(seq, type, t, x, y, z, data)
                     ON CONFLICT (run_id, seq) DO NOTHING;`,
                    [runId, playerId, level,
                     events.map(e => Math.round(clampNum(e.seq, 1e9))),
                     events.map(e => cleanStr(e.type, 40) || 'unknown'),
                     events.map(e => clampNum(e.t, 86400)),
                     events.map(e => numOrNull(e.x)),
                     events.map(e => numOrNull(e.y)),
                     events.map(e => numOrNull(e.z)),
                     events.map(e => JSON.stringify(e.data && typeof e.data === 'object' ? e.data : {}))]
                );
            }

            if (positions.length) {
                await client.query(
                    `INSERT INTO position_samples (run_id, level_name, seq, t, x, y, z)
                     SELECT $1, $2, u.seq, u.t, u.x, u.y, u.z
                     FROM unnest($3::int[], $4::real[], $5::real[], $6::real[], $7::real[]) AS u(seq, t, x, y, z)
                     ON CONFLICT (run_id, seq) DO NOTHING;`,
                    [runId, level,
                     positions.map(p => Math.round(clampNum(p.seq, 1e9))),
                     positions.map(p => clampNum(p.t, 86400)),
                     positions.map(p => Number(p.x) || 0),
                     positions.map(p => Number(p.y) || 0),
                     positions.map(p => Number(p.z) || 0)]
                );
            }

            if (['died', 'quit', 'completed'].includes(b.run_end)) {
                await finalizeRun(client, runId, b.run_end);
            }
        }

        await client.query('COMMIT');
        res.json({ status: 'ok' });
    } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        fail(res, 'Error al guardar telemetría', err);
    } finally {
        client.release();
    }
});

// Si el juego se cierra de golpe (crash, kill), el run queda "in_progress":
// pasados 3 minutos sin señales se marca como abandono.
async function sweepStale() {
    const client = await pool.connect();
    try {
        const stale = await client.query(
            `SELECT id FROM runs WHERE outcome = 'in_progress' AND last_seen < NOW() - INTERVAL '3 minutes';`);
        for (const row of stale.rows) {
            await client.query('BEGIN');
            await finalizeRun(client, row.id, 'quit');
            await client.query('COMMIT');
        }
        await client.query(
            `UPDATE sessions SET ended_at = last_seen, end_reason = 'timeout'
             WHERE ended_at IS NULL AND last_seen < NOW() - INTERVAL '3 minutes';`);
    } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        console.error('❌ sweepStale:', err.message);
    } finally {
        client.release();
    }
}
setInterval(sweepStale, 60 * 1000);

// =====================================================================
//  MÉTRICAS
// =====================================================================
const levelParam = (req) => cleanStr(req.query.level, 60) || null;
const cellParam = (req, def) => Math.min(Math.max(Number(req.query.cell) || def, 0.5), 50);

// Resumen general
app.get('/api/metrics/overview', async (req, res) => {
    try {
        const runs = await pool.query(
            `SELECT COUNT(*)::int AS runs,
                    COALESCE(SUM(kills), 0)::int AS kills,
                    COALESCE(SUM(deaths), 0)::int AS deaths,
                    COALESCE(SUM(collectibles), 0)::int AS collectibles,
                    COALESCE(ROUND(AVG(duration_s)::numeric, 1), 0)::float AS avg_run_s,
                    COALESCE(ROUND(100.0 * SUM(hits) / NULLIF(SUM(shots), 0), 1), 0)::float AS accuracy
             FROM runs WHERE outcome <> 'in_progress';`);
        const sess = await pool.query(
            `SELECT COUNT(*)::int AS sessions,
                    COUNT(DISTINCT player_id)::int AS players,
                    COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (last_seen - started_at)))::numeric, 0), 0)::int AS avg_session_s
             FROM sessions;`);
        res.json({ ...runs.rows[0], ...sess.rows[0] });
    } catch (err) { fail(res, 'Error en overview', err); }
});

// Dificultad por nivel
app.get('/api/metrics/levels', async (req, res) => {
    try {
        const r = await pool.query(
            `SELECT level_name,
                    COUNT(*)::int AS runs,
                    COUNT(DISTINCT player_id)::int AS players,
                    ROUND(AVG(duration_s)::numeric, 1)::float AS avg_duration_s,
                    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'died')      / COUNT(*), 1)::float AS death_rate,
                    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'completed') / COUNT(*), 1)::float AS completion_rate,
                    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'quit')      / COUNT(*), 1)::float AS quit_rate,
                    SUM(deaths)::int AS deaths, SUM(kills)::int AS kills,
                    COALESCE(ROUND((SUM(damage_taken) / NULLIF(SUM(duration_s) / 60.0, 0))::numeric, 1), 0)::float AS damage_per_min
             FROM runs WHERE outcome <> 'in_progress'
             GROUP BY level_name;`);
        // Índice de dificultad 0-100: 60 % tasa de muerte + 40 % daño recibido por minuto (tope 60/min)
        const rows = r.rows.map(x => ({
            ...x,
            difficulty: Math.round(Math.min(100, x.death_rate * 0.6 + Math.min(x.damage_per_min / 60, 1) * 40))
        })).sort((a, b) => b.difficulty - a.difficulty);
        res.json(rows);
    } catch (err) { fail(res, 'Error en levels', err); }
});

// Zonas del mapa en celdas de ?cell=5 unidades: dónde mueren, reciben daño, se quedan
app.get('/api/metrics/zones', async (req, res) => {
    const cell = cellParam(req, 5);
    try {
        const r = await pool.query(
            `WITH ev AS (
                SELECT floor(x / $2::real)::int AS cx, floor(z / $2::real)::int AS cz, event_type, data
                FROM events WHERE x IS NOT NULL AND ($1::text IS NULL OR level_name = $1)
             ), agg AS (
                SELECT cx, cz,
                       COUNT(*) FILTER (WHERE event_type = 'death')::int AS deaths,
                       COUNT(*) FILTER (WHERE event_type = 'enemy_kill')::int AS kills,
                       COUNT(*) FILTER (WHERE event_type = 'quit')::int AS quits,
                       COALESCE(SUM((data->>'amount')::numeric) FILTER (WHERE event_type = 'damage_taken'), 0)::int AS damage
                FROM ev GROUP BY cx, cz
             ), pos AS (
                SELECT floor(x / $2::real)::int AS cx, floor(z / $2::real)::int AS cz, COUNT(*)::int AS seconds
                FROM position_samples WHERE ($1::text IS NULL OR level_name = $1) GROUP BY 1, 2
             )
             SELECT COALESCE(a.cx, p.cx) AS cx, COALESCE(a.cz, p.cz) AS cz,
                    COALESCE(a.deaths, 0) AS deaths, COALESCE(a.kills, 0) AS kills,
                    COALESCE(a.quits, 0) AS quits, COALESCE(a.damage, 0) AS damage,
                    COALESCE(p.seconds, 0) AS seconds
             FROM agg a FULL JOIN pos p ON a.cx = p.cx AND a.cz = p.cz;`,
            [levelParam(req), cell]);
        res.json({ cell, zones: r.rows });
    } catch (err) { fail(res, 'Error en zones', err); }
});

// Mapa de calor: ?type=positions|death|enemy_kill|damage_taken|quit|collectible
const HEAT_TYPES = ['positions', 'death', 'enemy_kill', 'damage_taken', 'quit', 'collectible', 'shot'];
app.get('/api/metrics/heatmap', async (req, res) => {
    const type = HEAT_TYPES.includes(req.query.type) ? req.query.type : 'positions';
    const cell = cellParam(req, 2);
    const level = levelParam(req);
    try {
        const cells = type === 'positions'
            ? await pool.query(
                `SELECT floor(x / $2::real)::int AS cx, floor(z / $2::real)::int AS cz, COUNT(*)::int AS n
                 FROM position_samples WHERE ($1::text IS NULL OR level_name = $1) GROUP BY 1, 2;`, [level, cell])
            : await pool.query(
                `SELECT floor(x / $2::real)::int AS cx, floor(z / $2::real)::int AS cz, COUNT(*)::int AS n
                 FROM events WHERE event_type = $3 AND x IS NOT NULL AND ($1::text IS NULL OR level_name = $1)
                 GROUP BY 1, 2;`, [level, cell, type]);
        const bounds = await pool.query(
            `SELECT MIN(x) AS minx, MAX(x) AS maxx, MIN(z) AS minz, MAX(z) AS maxz
             FROM position_samples WHERE ($1::text IS NULL OR level_name = $1);`, [level]);
        res.json({ type, cell, cells: cells.rows, bounds: bounds.rows[0] });
    } catch (err) { fail(res, 'Error en heatmap', err); }
});

// Últimos runs (para elegir uno y ver su recorrido)
app.get('/api/metrics/runs', async (req, res) => {
    try {
        const r = await pool.query(
            `SELECT r.id, p.username, r.level_name, r.outcome, r.duration_s, r.kills, r.deaths,
                    r.collectibles, r.damage_taken, r.score, r.started_at
             FROM runs r JOIN players p ON p.id = r.player_id
             ORDER BY r.started_at DESC LIMIT $1;`, [limitParam(req.query.limit, 30, 200)]);
        res.json(r.rows);
    } catch (err) { fail(res, 'Error en runs', err); }
});

// Recorrido completo de un run: posiciones + eventos
app.get('/api/metrics/path/:runId', async (req, res) => {
    const runId = cleanId(req.params.runId);
    if (!runId) return res.status(400).json({ error: 'run inválido' });
    try {
        const pos = await pool.query(
            `SELECT t, x, z FROM position_samples WHERE run_id = $1 ORDER BY t LIMIT 5000;`, [runId]);
        const ev = await pool.query(
            `SELECT t, x, z, event_type, data FROM events
             WHERE run_id = $1 AND x IS NOT NULL AND event_type <> 'shot' ORDER BY t LIMIT 2000;`, [runId]);
        res.json({ positions: pos.rows, events: ev.rows });
    } catch (err) { fail(res, 'Error en path', err); }
});

// Muertes: causa (manada que dio el golpe final) y evolución
app.get('/api/metrics/deaths', async (req, res) => {
    try {
        const causes = await pool.query(
            `SELECT COALESCE(data->>'cause', 'desconocido') AS cause, COUNT(*)::int AS n
             FROM events WHERE event_type = 'death' AND ($1::text IS NULL OR level_name = $1)
             GROUP BY 1 ORDER BY n DESC;`, [levelParam(req)]);
        const when = await pool.query(
            `SELECT ROUND(AVG(t)::numeric, 1)::float AS avg_time_to_death_s
             FROM events WHERE event_type = 'death' AND ($1::text IS NULL OR level_name = $1);`, [levelParam(req)]);
        res.json({ causes: causes.rows, avg_time_to_death_s: when.rows[0].avg_time_to_death_s || 0 });
    } catch (err) { fail(res, 'Error en deaths', err); }
});

// ¿Cuándo se aburren? Retención, momento del abandono, inactividad y muertes previas
app.get('/api/metrics/boredom', async (req, res) => {
    try {
        const retention = await pool.query(
            `WITH s AS (SELECT EXTRACT(EPOCH FROM (last_seen - started_at)) / 60.0 AS mins FROM sessions)
             SELECT m AS minute,
                    ROUND(100.0 * COUNT(*) FILTER (WHERE s.mins >= m) / COUNT(*), 1)::float AS pct
             FROM generate_series(0, 20) AS m CROSS JOIN s GROUP BY m ORDER BY m;`);

        const buckets = await pool.query(
            `SELECT bucket, ord, COUNT(*)::int AS n FROM (
                SELECT CASE WHEN duration_s < 30  THEN '0-30 s'
                            WHEN duration_s < 60  THEN '30-60 s'
                            WHEN duration_s < 180 THEN '1-3 min'
                            WHEN duration_s < 300 THEN '3-5 min'
                            WHEN duration_s < 600 THEN '5-10 min'
                            ELSE '10+ min' END AS bucket,
                       CASE WHEN duration_s < 30 THEN 1 WHEN duration_s < 60 THEN 2 WHEN duration_s < 180 THEN 3
                            WHEN duration_s < 300 THEN 4 WHEN duration_s < 600 THEN 5 ELSE 6 END AS ord
                FROM runs WHERE outcome = 'quit') q
             GROUP BY bucket, ord ORDER BY ord;`);

        const quits = await pool.query(
            `SELECT COUNT(*)::int AS quits,
                    COALESCE(ROUND(AVG(idle_before_end_s)::numeric, 1), 0)::float AS avg_idle_s,
                    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE idle_before_end_s > 60) / NULLIF(COUNT(*), 0), 1), 0)::float AS pct_idle_over_60,
                    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE duration_s < 60) / NULLIF(COUNT(*), 0), 1), 0)::float AS pct_quit_first_minute,
                    COALESCE(ROUND(AVG(duration_s)::numeric, 1), 0)::float AS avg_quit_at_s
             FROM runs WHERE outcome = 'quit';`);

        const afterDeaths = await pool.query(
            `SELECT deaths_before, COUNT(*)::int AS n FROM (
                SELECT (SELECT COUNT(*) FROM runs d
                        WHERE d.session_id = q.session_id AND d.outcome = 'died' AND d.started_at < q.started_at)::int AS deaths_before
                FROM runs q
                WHERE q.outcome = 'quit'
                  AND q.id = (SELECT x.id FROM runs x WHERE x.session_id = q.session_id ORDER BY x.started_at DESC LIMIT 1)
             ) t GROUP BY deaths_before ORDER BY deaths_before;`);

        const idle = await pool.query(
            `WITH d AS (
                SELECT run_id,
                       sqrt(power(x - LAG(x) OVER w, 2) + power(z - LAG(z) OVER w, 2)) AS step
                FROM position_samples WINDOW w AS (PARTITION BY run_id ORDER BY t))
             SELECT r.outcome,
                    ROUND(100.0 * COUNT(*) FILTER (WHERE d.step < 0.2) / NULLIF(COUNT(d.step), 0), 1)::float AS idle_pct
             FROM d JOIN runs r ON r.id = d.run_id GROUP BY r.outcome;`);

        const firsts = await pool.query(
            `SELECT event_type, ROUND(AVG(first_t)::numeric, 1)::float AS avg_s FROM (
                SELECT run_id, event_type, MIN(t) AS first_t FROM events
                WHERE event_type IN ('death', 'enemy_kill', 'weapon_pickup', 'collectible')
                GROUP BY run_id, event_type) f
             GROUP BY event_type;`);

        res.json({
            retention: retention.rows, quit_buckets: buckets.rows, quits: quits.rows[0],
            quit_after_deaths: afterDeaths.rows, idle_by_outcome: idle.rows, first_times: firsts.rows
        });
    } catch (err) { fail(res, 'Error en boredom', err); }
});

// Jugadores: K/D, precisión, sesiones, abandono
app.get('/api/metrics/players', async (req, res) => {
    try {
        const r = await pool.query(
            `SELECT p.username,
                    COUNT(DISTINCT r.session_id)::int AS sessions,
                    COUNT(*)::int AS runs,
                    COALESCE(SUM(r.kills), 0)::int AS kills,
                    COALESCE(SUM(r.deaths), 0)::int AS deaths,
                    COALESCE(SUM(r.collectibles), 0)::int AS collectibles,
                    COALESCE(ROUND(100.0 * SUM(r.hits) / NULLIF(SUM(r.shots), 0), 1), 0)::float AS accuracy,
                    COALESCE(ROUND(SUM(r.duration_s)::numeric, 0), 0)::int AS play_time_s,
                    COUNT(*) FILTER (WHERE r.outcome = 'quit')::int AS quits,
                    MAX(r.started_at) AS last_played
             FROM runs r JOIN players p ON p.id = r.player_id
             WHERE r.outcome <> 'in_progress'
             GROUP BY p.username ORDER BY kills DESC LIMIT $1;`, [limitParam(req.query.limit, 50, 200)]);
        res.json(r.rows);
    } catch (err) { fail(res, 'Error en players', err); }
});

const PORT = Number(process.env.PORT) || 3000;
app.listen(PORT, () => console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`));