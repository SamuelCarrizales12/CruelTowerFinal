// Genera jugadores y partidas de prueba (usernames "demo_*") para ver el dashboard lleno.
// Uso:  node seed.js            (con el servidor corriendo en :3000)
//       node seed.js --clean    (borra los datos demo)
const { Pool } = require('pg');
const API = process.env.API_URL || 'http://localhost:3000';
const pool = new Pool({
    user: process.env.PGUSER || 'postgres', host: process.env.PGHOST || 'localhost',
    database: process.env.PGDATABASE || 'game_db', password: process.env.PGPASSWORD || '1234',
    port: Number(process.env.PGPORT) || 5432,
});

const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const id = () => Math.random().toString(16).slice(2, 12) + Date.now().toString(16).slice(-6);
const r2 = (n) => Math.round(n * 100) / 100;

// Posiciones tomadas de tu escena: el jugador inicia en (-3, 3) y los enemigos están cerca de (20, -12)
const START = { x: -3, z: 3 };
const ENEMY_ZONE = { x: 20.5, z: -12 };
const LEVELS = ['Nivel 1', 'Nivel 1', 'Nivel 1', 'Nivel 2'];
const NAMES = ['Ana', 'Beto', 'Caro', 'Diego', 'Eli', 'Fer', 'Gus', 'Hugo', 'Ivan', 'Jess', 'Kari', 'Luis'];

async function post(body) {
    const r = await fetch(API + '/api/telemetry/batch', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error('API respondió ' + r.status + ': ' + (await r.text()));
}

function buildRun(level, boredom) {
    // boredom 0..1: más aburrido = duración corta, se queda quieto, abandona
    const hard = level === 'Nivel 2' ? 1.5 : 1;
    const duration = Math.round(rnd(20, 420) * (1 - boredom * 0.6));
    const events = []; let seq = 0, t = 0;
    const positions = []; let p = { ...START }; let pseq = 0;
    const ev = (type, data, pos) => events.push({ seq: seq++, type, t: r2(t), x: r2(pos.x), y: 1, z: r2(pos.z), data });

    const goal = Math.random() < 0.7 - boredom * 0.4 ? ENEMY_ZONE : { x: rnd(-8, 8), z: rnd(-5, 8) };
    let hp = 100, alive = true, hasGun = false, idleFrom = null;
    for (t = 1; t <= duration && alive; t++) {
        const afk = Math.random() < boredom * 0.25;
        if (!afk) { p = { x: p.x + (goal.x - p.x) * 0.04 + rnd(-0.8, 0.8), z: p.z + (goal.z - p.z) * 0.04 + rnd(-0.8, 0.8) }; }
        if (positions.length < 480) positions.push({ seq: pseq++, t, x: r2(p.x), y: 1, z: r2(p.z) });
        if (!hasGun && t > 8) { hasGun = true; ev('weapon_pickup', {}, p); }
        if (Math.random() < 0.03) ev('collectible', { name: 'Reliquia' }, p);
        if (Math.random() < 0.015) ev('ammo_pickup', { amount: 12 }, p);
        const near = Math.hypot(p.x - ENEMY_ZONE.x, p.z - ENEMY_ZONE.z) < 9;
        if (hasGun && near && !afk) {
            if (Math.random() < 0.5) {
                ev('shot', { ammo: 10 }, p);
                if (Math.random() < 0.55) {
                    ev('hit', { enemy: 'manada_1', damage: 35 }, ENEMY_ZONE);
                    if (Math.random() < 0.4) ev('enemy_kill', { enemy: 'manada_1' }, { x: ENEMY_ZONE.x + rnd(-2, 2), z: ENEMY_ZONE.z + rnd(-2, 2) });
                }
            }
            if (Math.random() < 0.12 * hard) {
                const dmg = 3 * hard; hp -= dmg * 5;
                ev('damage_taken', { amount: Math.round(dmg * 5), hp, source: 'manada_1' }, p);
                if (hp <= 0) { ev('death', { cause: 'manada_1' }, p); alive = false; }
            }
        }
    }
    const outcome = alive ? 'quit' : 'died';
    if (outcome === 'quit') ev('quit', { reason: 'cerrar_ventana' }, p);
    return { events, positions, t: Math.min(t, duration), outcome };
}

async function main() {
    if (process.argv.includes('--clean')) {
        await pool.query(`DELETE FROM player_stats WHERE player_id IN (SELECT id FROM players WHERE username LIKE 'demo\\_%')`);
        await pool.query(`DELETE FROM players WHERE username LIKE 'demo\\_%'`);
        console.log('Datos demo eliminados'); return pool.end();
    }
    let runsTotal = 0;
    for (const name of NAMES) {
        const username = 'demo_' + name;
        const boredom = Math.random();
        const sessions = Math.ceil(rnd(1, 4));
        for (let s = 0; s < sessions; s++) {
            const sid = id();
            await post({ username, session_id: sid, game_version: '1.0.0', platform: 'Windows' });
            const base = new Date(Date.now() - rnd(0, 13) * 86400000 - rnd(0, 86400000));
            let cursor = base.getTime() + rnd(5, 40) * 1000; // tiempo en el menú
            const nRuns = Math.ceil(rnd(1, 4 - boredom * 2));
            for (let k = 0; k < nRuns; k++) {
                const level = pick(LEVELS), rid = id();
                const run = buildRun(level, boredom);
                await post({ username, session_id: sid, run_id: rid, level_name: level, slot: 1, t: run.t,
                             events: run.events, positions: run.positions, run_end: run.outcome });
                const start = new Date(cursor); cursor += run.t * 1000;
                await pool.query(`UPDATE runs SET started_at = $2, ended_at = $3, last_seen = $3 WHERE id = $1`,
                                 [rid, start, new Date(cursor)]);
                cursor += rnd(3, 10) * 1000;
                runsTotal++;
            }
            await pool.query(`UPDATE sessions SET started_at = $2, last_seen = $3, ended_at = $3, end_reason = 'quit_game' WHERE id = $1`,
                             [sid, base, new Date(cursor)]);
        }
    }
    // repartir las fechas de player_stats en los últimos 14 días para que la gráfica diaria se vea bien
    await pool.query(`UPDATE player_stats SET updated_at = NOW() - random() * INTERVAL '13 days'
                      WHERE player_id IN (SELECT id FROM players WHERE username LIKE 'demo\\_%')`);
    console.log(`Listo: ${NAMES.length} jugadores demo, ${runsTotal} runs.`);
    await pool.end();
}
main().catch((e) => { console.error(e.message); process.exit(1); });
