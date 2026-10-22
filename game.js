// =============================================
// SHADOW RUNNER — Parkour Action Game Engine
// =============================================

// --- CONFIGURATION ---
const CONFIG = {
    WIDTH: 1280,
    HEIGHT: 720,
    GRAVITY: 0.62,
    PLAYER_SPEED: 5.5,
    MAX_SPEED: 13,
    SPEED_INCREASE: 0.0008,
    JUMP_FORCE: -13.5,
    DOUBLE_JUMP_FORCE: -11,
    SLIDE_DURATION: 35,
    ROLL_DURATION: 25,
    PLAYER_WIDTH: 24,
    PLAYER_HEIGHT: 58,
    PLAYER_SLIDE_HEIGHT: 28,
    PLAYER_SCREEN_X: 280,
    MIN_PLATFORM_W: 250,
    MAX_PLATFORM_W: 600,
    MIN_GAP: 60,
    MAX_GAP: 180,
    PLATFORM_Y_MIN: 340,
    PLATFORM_Y_MAX: 520,
    PURSUER_START_DIST: 280,
    PURSUER_CATCHUP: 0.015,
    PURSUER_FALLBACK: 0.04,
    OBSTACLE_CHANCE: 0.45,
    COLLECTIBLE_CHANCE: 0.3,
};

// --- UTILITIES ---
function lerp(a, b, t) { return a + (b - a) * t; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function rand(lo, hi) { return Math.random() * (hi - lo) + lo; }
function randInt(lo, hi) { return Math.floor(rand(lo, hi + 1)); }
function easeOut(t) { return 1 - Math.pow(1 - t, 3); }
function easeInOut(t) { return t < 0.5 ? 4*t*t*t : 1-Math.pow(-2*t+2,3)/2; }

// --- COLOR PALETTE ---
const COLORS = {
    sky1: '#1a0a2e',
    sky2: '#16213e',
    sky3: '#0f3460',
    sunset1: '#e94560',
    sunset2: '#ff6b3d',
    sunset3: '#ff9f43',
    sunset4: '#ffd93d',
    building1: '#0a0a1a',
    building2: '#111128',
    building3: '#0d0d20',
    window: '#2a1a4a',
    windowLit: '#ff9f43',
    player: '#111118',
    playerHighlight: '#1a1a2e',
    pursuer: '#2d0a0a',
    obstacle: '#1a1a2e',
    collectible: '#ffd93d',
    particle: '#ff6b3d',
    text: '#ffffff',
    accent: '#ff6b3d',
    accentAlt: '#ff9f43',
};

// =============================================
// SOUND MANAGER (Web Audio API)
// =============================================
class SoundManager {
    constructor() {
        this.ctx = null;
        this.enabled = true;
        this.masterGain = null;
    }

    init() {
        try {
            this.ctx = new (window.AudioContext || window.webkitAudioContext)();
            this.masterGain = this.ctx.createGain();
            this.masterGain.gain.value = 0.3;
            this.masterGain.connect(this.ctx.destination);
        } catch (e) {
            this.enabled = false;
        }
    }

    resume() {
        if (this.ctx && this.ctx.state === 'suspended') {
            this.ctx.resume();
        }
    }

    _tone(freq, duration, type = 'square', vol = 0.3) {
        if (!this.enabled || !this.ctx) return;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(freq * 0.5, this.ctx.currentTime + duration);
        gain.gain.setValueAtTime(vol, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(this.ctx.currentTime);
        osc.stop(this.ctx.currentTime + duration);
    }

    _noise(duration, vol = 0.15) {
        if (!this.enabled || !this.ctx) return;
        const bufferSize = this.ctx.sampleRate * duration;
        const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }
        const source = this.ctx.createBufferSource();
        source.buffer = buffer;
        const gain = this.ctx.createGain();
        gain.gain.setValueAtTime(vol, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
        const filter = this.ctx.createBiquadFilter();
        filter.type = 'highpass';
        filter.frequency.value = 800;
        source.connect(filter);
        filter.connect(gain);
        gain.connect(this.masterGain);
        source.start();
    }

    jump() { this._tone(400, 0.15, 'square', 0.2); this._tone(600, 0.1, 'sine', 0.1); }
    doubleJump() { this._tone(500, 0.12, 'square', 0.2); this._tone(800, 0.1, 'sine', 0.15); }
    land() { this._noise(0.08, 0.2); this._tone(120, 0.1, 'sine', 0.15); }
    slide() { this._noise(0.2, 0.15); this._tone(200, 0.15, 'sawtooth', 0.08); }
    hit() { this._noise(0.15, 0.3); this._tone(100, 0.2, 'square', 0.3); }
    collect() { this._tone(800, 0.08, 'sine', 0.2); this._tone(1200, 0.12, 'sine', 0.15); }
    death() { this._tone(300, 0.3, 'sawtooth', 0.3); this._tone(100, 0.5, 'square', 0.2); }
    menuSelect() { this._tone(600, 0.08, 'sine', 0.15); }
}

// =============================================
// PARTICLE SYSTEM
// =============================================
class Particle {
    constructor(x, y, vx, vy, size, color, life, gravity = 0.1) {
        this.x = x; this.y = y;
        this.vx = vx; this.vy = vy;
        this.size = size; this.color = color;
        this.life = life; this.maxLife = life;
        this.gravity = gravity;
        this.alpha = 1;
    }

    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.vy += this.gravity;
        this.life--;
        this.alpha = Math.max(0, this.life / this.maxLife);
        this.size *= 0.98;
        return this.life > 0;
    }

    draw(ctx, camX) {
        ctx.save();
        ctx.globalAlpha = this.alpha;
        ctx.fillStyle = this.color;
        ctx.beginPath();
        ctx.arc(this.x - camX, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

class ParticleSystem {
    constructor() { this.particles = []; }

    emit(x, y, count, opts = {}) {
        const { color = COLORS.particle, minSpeed = 1, maxSpeed = 4,
            minSize = 1, maxSize = 4, life = 30, gravity = 0.1,
            angleMin = 0, angleMax = Math.PI * 2 } = opts;
        for (let i = 0; i < count; i++) {
            const angle = rand(angleMin, angleMax);
            const speed = rand(minSpeed, maxSpeed);
            this.particles.push(new Particle(
                x + rand(-5, 5), y + rand(-3, 3),
                Math.cos(angle) * speed, Math.sin(angle) * speed,
                rand(minSize, maxSize), color, randInt(life * 0.6, life), gravity
            ));
        }
    }

    dustBurst(x, y) {
        this.emit(x, y, 8, {
            color: '#8B7355', minSpeed: 0.5, maxSpeed: 3,
            minSize: 2, maxSize: 5, life: 25, gravity: 0.05,
            angleMin: -Math.PI, angleMax: -Math.PI * 0.2
        });
    }

    landingDust(x, y) {
        this.emit(x, y, 12, {
            color: '#9B8B75', minSpeed: 1, maxSpeed: 4,
            minSize: 2, maxSize: 6, life: 20, gravity: 0.02,
            angleMin: -Math.PI, angleMax: 0
        });
    }

    slideSparks(x, y) {
        this.emit(x, y, 3, {
            color: '#ffaa44', minSpeed: 1, maxSpeed: 3,
            minSize: 1, maxSize: 3, life: 12, gravity: 0.05,
            angleMin: -Math.PI * 0.8, angleMax: -Math.PI * 0.2
        });
    }

    deathBurst(x, y) {
        this.emit(x, y, 30, {
            color: '#ff4444', minSpeed: 2, maxSpeed: 8,
            minSize: 2, maxSize: 6, life: 40, gravity: 0.1
        });
        this.emit(x, y, 20, {
            color: '#ff8844', minSpeed: 1, maxSpeed: 5,
            minSize: 3, maxSize: 8, life: 50, gravity: 0.05
        });
    }

    collectBurst(x, y) {
        this.emit(x, y, 15, {
            color: COLORS.collectible, minSpeed: 1, maxSpeed: 5,
            minSize: 2, maxSize: 5, life: 25, gravity: -0.02
        });
    }

    speedLines(x, y, h) {
        this.emit(x, y + rand(0, h), 1, {
            color: 'rgba(255,255,255,0.3)', minSpeed: 3, maxSpeed: 6,
            minSize: 1, maxSize: 2, life: 8, gravity: 0,
            angleMin: Math.PI, angleMax: Math.PI
        });
    }

    update() {
        this.particles = this.particles.filter(p => p.update());
    }

    draw(ctx, camX) {
        this.particles.forEach(p => p.draw(ctx, camX));
    }
}

// =============================================
// BACKGROUND RENDERER
// =============================================
class Background {
    constructor(w, h) {
        this.w = w;
        this.h = h;
        this.stars = [];
        this.clouds = [];
        this.farBuildings = [];
        this.midBuildings = [];
        this._generateStars();
        this._generateClouds();
        this._generateSilhouettes();
        this.time = 0;
    }

    _generateStars() {
        for (let i = 0; i < 120; i++) {
            this.stars.push({
                x: rand(0, 2000), y: rand(0, this.h * 0.5),
                size: rand(0.5, 2.5), twinkle: rand(0, Math.PI * 2),
                speed: rand(0.01, 0.04)
            });
        }
    }

    _generateClouds() {
        for (let i = 0; i < 8; i++) {
            this.clouds.push({
                x: rand(0, 2500), y: rand(40, 200),
                w: rand(120, 300), h: rand(20, 50),
                alpha: rand(0.02, 0.08)
            });
        }
    }

    _generateSilhouettes() {
        // Far layer
        let x = 0;
        while (x < 3000) {
            const w = rand(40, 120);
            const h = rand(80, 250);
            this.farBuildings.push({ x, w, h });
            x += w + rand(5, 30);
        }
        // Mid layer
        x = 0;
        while (x < 3000) {
            const w = rand(50, 150);
            const h = rand(100, 320);
            this.midBuildings.push({ x, w, h });
            x += w + rand(10, 40);
        }
    }

    draw(ctx, camX) {
        this.time += 0.005;

        // Sky gradient
        const grad = ctx.createLinearGradient(0, 0, 0, this.h);
        grad.addColorStop(0, COLORS.sky1);
        grad.addColorStop(0.35, COLORS.sky2);
        grad.addColorStop(0.6, COLORS.sky3);
        grad.addColorStop(0.78, COLORS.sunset1);
        grad.addColorStop(0.88, COLORS.sunset2);
        grad.addColorStop(0.95, COLORS.sunset3);
        grad.addColorStop(1, COLORS.sunset4);
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, this.w, this.h);

        // Sun glow
        const sunX = this.w * 0.75;
        const sunY = this.h * 0.82;
        const sunGrad = ctx.createRadialGradient(sunX, sunY, 10, sunX, sunY, 200);
        sunGrad.addColorStop(0, 'rgba(255, 217, 61, 0.6)');
        sunGrad.addColorStop(0.3, 'rgba(255, 159, 67, 0.2)');
        sunGrad.addColorStop(1, 'rgba(255, 107, 61, 0)');
        ctx.fillStyle = sunGrad;
        ctx.fillRect(0, this.h * 0.5, this.w, this.h * 0.5);

        // Stars
        this.stars.forEach(s => {
            const alpha = 0.3 + Math.sin(s.twinkle + this.time * s.speed * 50) * 0.3;
            ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
            ctx.beginPath();
            ctx.arc((s.x - camX * 0.02) % (this.w + 200), s.y, s.size, 0, Math.PI * 2);
            ctx.fill();
        });

        // Clouds
        this.clouds.forEach(c => {
            const cx = ((c.x - camX * 0.05) % (this.w + 400)) - 200;
            ctx.fillStyle = `rgba(255, 200, 150, ${c.alpha})`;
            ctx.beginPath();
            ctx.ellipse(cx, c.y, c.w / 2, c.h / 2, 0, 0, Math.PI * 2);
            ctx.fill();
        });

        // Far building silhouettes
        ctx.fillStyle = '#0a0815';
        this.farBuildings.forEach(b => {
            const bx = ((b.x - camX * 0.1) % 3000);
            ctx.fillRect(bx, this.h - b.h - 120, b.w, b.h + 120);
        });

        // Mid building silhouettes
        ctx.fillStyle = '#080612';
        this.midBuildings.forEach(b => {
            const bx = ((b.x - camX * 0.25) % 3000);
            ctx.fillRect(bx, this.h - b.h - 80, b.w, b.h + 80);
            // Few lit windows
            ctx.fillStyle = 'rgba(255, 159, 67, 0.15)';
            for (let wy = this.h - b.h - 60; wy < this.h - 100; wy += 25) {
                for (let wx = bx + 8; wx < bx + b.w - 8; wx += 18) {
                    if (Math.random() > 0.6) {
                        ctx.fillRect(wx, wy, 6, 8);
                    }
                }
            }
            ctx.fillStyle = '#080612';
        });
    }
}

// =============================================
// PLATFORM (Rooftop Building)
// =============================================
class Platform {
    constructor(x, y, w) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = CONFIG.HEIGHT - y;
        this.windows = [];
        this.details = [];
        this._generateDetails();
    }

    _generateDetails() {
        // Windows
        const windowCols = Math.floor(this.w / 30);
        const windowRows = Math.min(Math.floor(this.h / 30), 8);
        for (let r = 0; r < windowRows; r++) {
            for (let c = 0; c < windowCols; c++) {
                if (Math.random() > 0.3) {
                    this.windows.push({
                        x: 12 + c * 28,
                        y: 30 + r * 28,
                        lit: Math.random() > 0.65
                    });
                }
            }
        }
        // Roof details
        if (Math.random() > 0.5) {
            this.details.push({
                type: 'antenna',
                x: rand(20, this.w - 20),
                h: rand(15, 35)
            });
        }
        if (Math.random() > 0.6 && this.w > 150) {
            this.details.push({
                type: 'vent',
                x: rand(30, this.w - 60),
                w: rand(25, 45),
                h: rand(10, 20)
            });
        }
    }

    draw(ctx, camX) {
        const sx = this.x - camX;
        if (sx > CONFIG.WIDTH + 50 || sx + this.w < -50) return;

        // Main building body
        ctx.fillStyle = COLORS.building1;
        ctx.fillRect(sx, this.y, this.w, this.h);

        // Building edge highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.03)';
        ctx.fillRect(sx, this.y, 3, this.h);
        ctx.fillRect(sx + this.w - 3, this.y, 3, this.h);

        // Rooftop line
        ctx.fillStyle = 'rgba(255, 107, 61, 0.25)';
        ctx.fillRect(sx, this.y, this.w, 2);

        // Rooftop surface
        ctx.fillStyle = COLORS.building2;
        ctx.fillRect(sx, this.y, this.w, 8);

        // Windows
        this.windows.forEach(win => {
            ctx.fillStyle = win.lit
                ? `rgba(255, 180, 80, ${0.15 + Math.sin(Date.now() * 0.001 + win.x) * 0.05})`
                : COLORS.window;
            ctx.fillRect(sx + win.x, this.y + win.y, 12, 14);
        });

        // Roof details
        this.details.forEach(d => {
            ctx.fillStyle = '#0f0f1e';
            if (d.type === 'antenna') {
                ctx.fillRect(sx + d.x, this.y - d.h, 2, d.h);
                ctx.fillStyle = '#ff3333';
                ctx.beginPath();
                ctx.arc(sx + d.x + 1, this.y - d.h, 2, 0, Math.PI * 2);
                ctx.fill();
            } else if (d.type === 'vent') {
                ctx.fillRect(sx + d.x, this.y - d.h, d.w, d.h);
            }
        });
    }
}

// =============================================
// OBSTACLE
// =============================================
const OBS_TYPE = { BARRIER_HIGH: 0, BARRIER_LOW: 1, CRATE: 2 };

class Obstacle {
    constructor(x, y, type) {
        this.type = type;
        this.x = x;
        this.active = true;
        this.hitFlash = 0;

        switch (type) {
            case OBS_TYPE.BARRIER_HIGH:
                this.w = 15;
                this.h = 55;
                this.y = y - this.h;
                break;
            case OBS_TYPE.BARRIER_LOW:
                this.w = 50;
                this.h = 28;
                this.y = y - this.h;
                break;
            case OBS_TYPE.CRATE:
                this.w = 30;
                this.h = 30;
                this.y = y - this.h;
                break;
        }
    }

    getHitbox() {
        return { x: this.x + 3, y: this.y + 3, w: this.w - 6, h: this.h - 6 };
    }

    draw(ctx, camX) {
        if (!this.active) return;
        const sx = this.x - camX;
        if (sx > CONFIG.WIDTH + 50 || sx + this.w < -50) return;

        if (this.hitFlash > 0) {
            ctx.fillStyle = '#ff4444';
            this.hitFlash--;
        } else {
            ctx.fillStyle = COLORS.obstacle;
        }

        switch (this.type) {
            case OBS_TYPE.BARRIER_HIGH:
                // Tall thin barrier / pipe
                ctx.fillRect(sx, this.y, this.w, this.h);
                ctx.fillStyle = 'rgba(255,255,255,0.05)';
                ctx.fillRect(sx + 2, this.y, 3, this.h);
                // Warning stripe
                ctx.fillStyle = 'rgba(255, 107, 61, 0.3)';
                ctx.fillRect(sx, this.y, this.w, 4);
                ctx.fillRect(sx, this.y + this.h - 4, this.w, 4);
                break;

            case OBS_TYPE.BARRIER_LOW:
                // Low barrier to slide under (wire/beam)
                ctx.fillRect(sx, this.y, this.w, 4);
                // Support posts
                ctx.fillRect(sx, this.y, 4, this.h);
                ctx.fillRect(sx + this.w - 4, this.y, 4, this.h);
                // Warning
                ctx.fillStyle = 'rgba(255, 60, 60, 0.4)';
                ctx.fillRect(sx, this.y, this.w, 2);
                break;

            case OBS_TYPE.CRATE:
                ctx.fillRect(sx, this.y, this.w, this.h);
                ctx.strokeStyle = 'rgba(255,255,255,0.08)';
                ctx.lineWidth = 1;
                ctx.strokeRect(sx + 4, this.y + 4, this.w - 8, this.h - 8);
                // X pattern
                ctx.beginPath();
                ctx.moveTo(sx + 4, this.y + 4);
                ctx.lineTo(sx + this.w - 4, this.y + this.h - 4);
                ctx.moveTo(sx + this.w - 4, this.y + 4);
                ctx.lineTo(sx + 4, this.y + this.h - 4);
                ctx.stroke();
                break;
        }
    }
}

// =============================================
// COLLECTIBLE
// =============================================
class Collectible {
    constructor(x, y) {
        this.x = x;
        this.y = y - 40;
        this.collected = false;
        this.size = 8;
        this.bob = rand(0, Math.PI * 2);
    }

    draw(ctx, camX) {
        if (this.collected) return;
        const sx = this.x - camX;
        if (sx > CONFIG.WIDTH + 50 || sx < -50) return;
        this.bob += 0.06;
        const by = this.y + Math.sin(this.bob) * 6;

        // Glow
        ctx.save();
        ctx.globalAlpha = 0.3 + Math.sin(this.bob) * 0.1;
        const glow = ctx.createRadialGradient(sx, by, 2, sx, by, 20);
        glow.addColorStop(0, COLORS.collectible);
        glow.addColorStop(1, 'rgba(255, 217, 61, 0)');
        ctx.fillStyle = glow;
        ctx.fillRect(sx - 20, by - 20, 40, 40);
        ctx.restore();

        // Diamond shape
        ctx.fillStyle = COLORS.collectible;
        ctx.save();
        ctx.translate(sx, by);
        ctx.rotate(Math.PI / 4);
        ctx.fillRect(-this.size / 2, -this.size / 2, this.size, this.size);
        ctx.restore();

        // Inner highlight
        ctx.fillStyle = '#fff';
        ctx.save();
        ctx.translate(sx, by);
        ctx.rotate(Math.PI / 4);
        ctx.fillRect(-2, -2, 4, 4);
        ctx.restore();
    }
}

// =============================================
// PLAYER CHARACTER
// =============================================
const P_STATE = {
    RUNNING: 0, JUMPING: 1, FALLING: 2, SLIDING: 3,
    ROLLING: 4, WALL_SLIDING: 5, DEAD: 6
};

class Player {
    constructor(x, y) {
        this.x = x;
        this.y = y;
        this.vx = 0;
        this.vy = 0;
        this.speed = CONFIG.PLAYER_SPEED;
        this.state = P_STATE.RUNNING;
        this.grounded = false;
        this.canDoubleJump = true;
        this.slideTimer = 0;
        this.rollTimer = 0;
        this.runFrame = 0;
        this.stunTimer = 0;
        this.invincible = 0;
        this.distance = 0;
        this.score = 0;
        this.alive = true;
        this.trailPoints = [];
    }

    get hitbox() {
        const h = this.state === P_STATE.SLIDING ? CONFIG.PLAYER_SLIDE_HEIGHT : CONFIG.PLAYER_HEIGHT;
        const yOff = this.state === P_STATE.SLIDING ? CONFIG.PLAYER_HEIGHT - CONFIG.PLAYER_SLIDE_HEIGHT : 0;
        return {
            x: this.x - CONFIG.PLAYER_WIDTH / 2 + 4,
            y: this.y - CONFIG.PLAYER_HEIGHT + yOff + 4,
            w: CONFIG.PLAYER_WIDTH - 8,
            h: h - 8
        };
    }

    jump(sound) {
        if (this.state === P_STATE.SLIDING) {
            this.state = P_STATE.RUNNING;
            this.slideTimer = 0;
        }
        if (this.grounded) {
            this.vy = CONFIG.JUMP_FORCE;
            this.state = P_STATE.JUMPING;
            this.grounded = false;
            this.canDoubleJump = true;
            sound.jump();
        } else if (this.canDoubleJump) {
            this.vy = CONFIG.DOUBLE_JUMP_FORCE;
            this.canDoubleJump = false;
            sound.doubleJump();
        }
    }

    startSlide(sound) {
        if (this.grounded && this.state !== P_STATE.SLIDING) {
            this.state = P_STATE.SLIDING;
            this.slideTimer = CONFIG.SLIDE_DURATION;
            sound.slide();
        }
        // Fast fall if in air
        if (!this.grounded) {
            this.vy = Math.max(this.vy, 8);
        }
    }

    update(platforms, obstacles, collectibles, particles, sound) {
        if (!this.alive) return;

        // Speed gradually increases
        this.speed = Math.min(CONFIG.MAX_SPEED, this.speed + CONFIG.SPEED_INCREASE);
        this.x += this.speed;
        this.distance = this.x;

        // Stun slowdown
        if (this.stunTimer > 0) {
            this.stunTimer--;
            this.x -= this.speed * 0.4;
        }
        if (this.invincible > 0) this.invincible--;

        // Gravity
        if (!this.grounded) {
            this.vy += CONFIG.GRAVITY;
            this.y += this.vy;
        }

        // Slide timer
        if (this.state === P_STATE.SLIDING) {
            this.slideTimer--;
            if (this.slideTimer <= 0) {
                this.state = P_STATE.RUNNING;
            }
            // Slide sparks
            if (this.grounded && this.slideTimer % 3 === 0) {
                particles.slideSparks(this.x, this.y);
            }
        }

        // Roll timer
        if (this.state === P_STATE.ROLLING) {
            this.rollTimer--;
            if (this.rollTimer <= 0) {
                this.state = P_STATE.RUNNING;
            }
        }

        // Run animation
        if (this.state === P_STATE.RUNNING && this.grounded) {
            this.runFrame += this.speed * 0.15;
        }

        // Speed lines effect
        if (this.speed > 8 && Math.random() > 0.7) {
            particles.speedLines(this.x - 30, this.y - CONFIG.PLAYER_HEIGHT / 2, CONFIG.PLAYER_HEIGHT);
        }

        // Trail
        this.trailPoints.push({ x: this.x, y: this.y - CONFIG.PLAYER_HEIGHT / 2, alpha: 0.3 });
        if (this.trailPoints.length > 8) this.trailPoints.shift();
        this.trailPoints.forEach(t => t.alpha *= 0.85);

        // Platform collision
        this.grounded = false;
        for (const plat of platforms) {
            if (this.x > plat.x && this.x < plat.x + plat.w) {
                // Landing on top
                if (this.vy >= 0 && this.y >= plat.y && this.y - this.vy < plat.y + 10) {
                    this.y = plat.y;
                    if (this.vy > 5) {
                        particles.landingDust(this.x, this.y);
                        sound.land();
                        if (this.vy > 10) {
                            this.state = P_STATE.ROLLING;
                            this.rollTimer = CONFIG.ROLL_DURATION;
                        }
                    }
                    this.vy = 0;
                    this.grounded = true;
                    if (this.state === P_STATE.JUMPING || this.state === P_STATE.FALLING) {
                        this.state = P_STATE.RUNNING;
                    }
                    this.canDoubleJump = true;
                    break;
                }
            }
        }

        // Falling state
        if (!this.grounded && this.vy > 2 && this.state !== P_STATE.SLIDING) {
            this.state = P_STATE.FALLING;
        }

        // Obstacle collision
        if (this.invincible <= 0) {
            const hb = this.hitbox;
            for (const obs of obstacles) {
                if (!obs.active) continue;
                const ob = obs.getHitbox();
                if (hb.x < ob.x + ob.w && hb.x + hb.w > ob.x &&
                    hb.y < ob.y + ob.h && hb.y + hb.h > ob.y) {
                    // Hit!
                    obs.hitFlash = 10;
                    this.stunTimer = 20;
                    this.invincible = 40;
                    this.speed = Math.max(CONFIG.PLAYER_SPEED, this.speed - 2);
                    sound.hit();
                    particles.dustBurst(this.x, this.y - CONFIG.PLAYER_HEIGHT / 2);
                    obs.active = false;
                }
            }
        }

        // Collectible collision
        const hb = this.hitbox;
        for (const col of collectibles) {
            if (col.collected) continue;
            if (Math.abs(this.x - col.x) < 25 && Math.abs((this.y - CONFIG.PLAYER_HEIGHT / 2) - col.y) < 30) {
                col.collected = true;
                this.score += 100;
                sound.collect();
                particles.collectBurst(col.x, col.y);
            }
        }

        // Death by falling
        if (this.y > CONFIG.HEIGHT + 100) {
            this.die(sound, particles);
        }

        // Running dust
        if (this.grounded && this.state === P_STATE.RUNNING && this.runFrame % 8 < 1) {
            particles.emit(this.x - 5, this.y, 2, {
                color: '#7a6a5a', minSpeed: 0.3, maxSpeed: 1.5,
                minSize: 1, maxSize: 3, life: 15, gravity: -0.02,
                angleMin: -Math.PI * 0.9, angleMax: -Math.PI * 0.3
            });
        }
    }

    die(sound, particles) {
        if (!this.alive) return;
        this.alive = false;
        this.state = P_STATE.DEAD;
        sound.death();
        particles.deathBurst(this.x, this.y - CONFIG.PLAYER_HEIGHT / 2);
    }

    draw(ctx, camX) {
        const sx = CONFIG.PLAYER_SCREEN_X;
        const sy = this.y;

        // Trail
        this.trailPoints.forEach(t => {
            if (t.alpha < 0.02) return;
            ctx.fillStyle = `rgba(255, 107, 61, ${t.alpha * 0.15})`;
            ctx.beginPath();
            ctx.arc(t.x - camX, t.y, 10, 0, Math.PI * 2);
            ctx.fill();
        });

        // Invincibility flash
        if (this.invincible > 0 && Math.floor(this.invincible / 3) % 2 === 0) {
            ctx.globalAlpha = 0.5;
        }

        ctx.save();
        ctx.translate(sx, sy);

        const col = COLORS.player;

        switch (this.state) {
            case P_STATE.RUNNING:
                this._drawRunning(ctx, col);
                break;
            case P_STATE.JUMPING:
                this._drawJumping(ctx, col);
                break;
            case P_STATE.FALLING:
                this._drawFalling(ctx, col);
                break;
            case P_STATE.SLIDING:
                this._drawSliding(ctx, col);
                break;
            case P_STATE.ROLLING:
                this._drawRolling(ctx, col);
                break;
            default:
                this._drawRunning(ctx, col);
        }

        ctx.restore();
        ctx.globalAlpha = 1;
    }

    _drawRunning(ctx, col) {
        const f = this.runFrame;
        const cycle = Math.sin(f * 0.5);
        const bounce = Math.abs(Math.sin(f * 0.5)) * 3;

        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.lineWidth = 4;
        ctx.lineCap = 'round';

        // Head
        ctx.beginPath();
        ctx.arc(0, -52 + bounce, 7, 0, Math.PI * 2);
        ctx.fill();

        // Torso
        ctx.beginPath();
        ctx.moveTo(0, -45 + bounce);
        ctx.lineTo(-1, -22 + bounce * 0.5);
        ctx.stroke();

        // Arms
        const armSwing = cycle * 0.7;
        ctx.beginPath();
        ctx.moveTo(0, -40 + bounce);
        ctx.lineTo(Math.sin(armSwing) * 16, -30 + bounce + Math.cos(armSwing) * 8);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, -40 + bounce);
        ctx.lineTo(Math.sin(-armSwing) * 16, -30 + bounce + Math.cos(-armSwing) * 8);
        ctx.stroke();

        // Legs
        const legSwing = cycle * 0.8;
        ctx.beginPath();
        ctx.moveTo(-1, -22 + bounce * 0.5);
        ctx.lineTo(Math.sin(legSwing) * 14, -8 + Math.abs(Math.cos(legSwing)) * 5);
        ctx.lineTo(Math.sin(legSwing) * 18, 0);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-1, -22 + bounce * 0.5);
        ctx.lineTo(Math.sin(-legSwing) * 14, -8 + Math.abs(Math.cos(-legSwing)) * 5);
        ctx.lineTo(Math.sin(-legSwing) * 18, 0);
        ctx.stroke();
    }

    _drawJumping(ctx, col) {
        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.lineWidth = 4;
        ctx.lineCap = 'round';

        // Head
        ctx.beginPath();
        ctx.arc(2, -54, 7, 0, Math.PI * 2);
        ctx.fill();

        // Torso (leaning forward)
        ctx.beginPath();
        ctx.moveTo(2, -47);
        ctx.lineTo(-2, -24);
        ctx.stroke();

        // Arms up
        ctx.beginPath();
        ctx.moveTo(0, -42);
        ctx.lineTo(14, -50);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, -42);
        ctx.lineTo(-10, -52);
        ctx.stroke();

        // Legs tucked
        ctx.beginPath();
        ctx.moveTo(-2, -24);
        ctx.lineTo(8, -14);
        ctx.lineTo(4, -5);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-2, -24);
        ctx.lineTo(-8, -14);
        ctx.lineTo(-3, -5);
        ctx.stroke();
    }

    _drawFalling(ctx, col) {
        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.lineWidth = 4;
        ctx.lineCap = 'round';

        // Head
        ctx.beginPath();
        ctx.arc(0, -52, 7, 0, Math.PI * 2);
        ctx.fill();

        // Torso
        ctx.beginPath();
        ctx.moveTo(0, -45);
        ctx.lineTo(0, -22);
        ctx.stroke();

        // Arms spread
        ctx.beginPath();
        ctx.moveTo(0, -40);
        ctx.lineTo(18, -35);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, -40);
        ctx.lineTo(-18, -35);
        ctx.stroke();

        // Legs dangling
        ctx.beginPath();
        ctx.moveTo(0, -22);
        ctx.lineTo(8, -8);
        ctx.lineTo(6, 0);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, -22);
        ctx.lineTo(-6, -8);
        ctx.lineTo(-8, 0);
        ctx.stroke();
    }

    _drawSliding(ctx, col) {
        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.lineWidth = 4;
        ctx.lineCap = 'round';

        // Head (low)
        ctx.beginPath();
        ctx.arc(8, -22, 7, 0, Math.PI * 2);
        ctx.fill();

        // Torso (horizontal)
        ctx.beginPath();
        ctx.moveTo(8, -15);
        ctx.lineTo(-8, -10);
        ctx.stroke();

        // Front arm
        ctx.beginPath();
        ctx.moveTo(4, -14);
        ctx.lineTo(14, -8);
        ctx.stroke();

        // Back arm
        ctx.beginPath();
        ctx.moveTo(-4, -12);
        ctx.lineTo(-14, -16);
        ctx.stroke();

        // Legs extended
        ctx.beginPath();
        ctx.moveTo(-8, -10);
        ctx.lineTo(10, -4);
        ctx.lineTo(18, -2);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-8, -10);
        ctx.lineTo(4, -2);
        ctx.lineTo(12, 0);
        ctx.stroke();

        // Slide sparks visual
        ctx.fillStyle = 'rgba(255, 170, 68, 0.3)';
        ctx.fillRect(-15, -2, 30, 2);
    }

    _drawRolling(ctx, col) {
        ctx.fillStyle = col;
        const angle = this.rollTimer * 0.3;
        ctx.save();
        ctx.rotate(angle);
        ctx.beginPath();
        ctx.ellipse(0, -18, 14, 18, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

// =============================================
// PURSUER (Chaser)
// =============================================
class Pursuer {
    constructor() {
        this.distance = CONFIG.PURSUER_START_DIST;
        this.y = 0;
        this.runFrame = 0;
        this.active = true;
    }

    update(player) {
        if (!this.active || !player.alive) return;

        // Close in when player is stunned, fall back when player runs clean
        if (player.stunTimer > 0) {
            this.distance -= CONFIG.PURSUER_CATCHUP * 40;
        } else {
            this.distance = lerp(this.distance, CONFIG.PURSUER_START_DIST, CONFIG.PURSUER_FALLBACK * 0.3);
        }

        // Slowly close in over time
        this.distance -= 0.005;
        this.distance = Math.max(50, this.distance);

        this.y = player.y;
        this.runFrame += player.speed * 0.15;

        // Caught player
        if (this.distance <= 55) {
            player.die(null, null);
        }
    }

    draw(ctx, camX, playerX) {
        if (!this.active) return;
        const sx = playerX - camX - this.distance;
        const sy = this.y;

        if (sx < -80) return;

        const f = this.runFrame;
        const cycle = Math.sin(f * 0.5);
        const bounce = Math.abs(Math.sin(f * 0.5)) * 3;

        ctx.save();
        ctx.translate(sx, sy);
        ctx.fillStyle = COLORS.pursuer;
        ctx.strokeStyle = COLORS.pursuer;
        ctx.lineWidth = 5;
        ctx.lineCap = 'round';

        // Slightly bigger than player
        const scale = 1.15;
        ctx.scale(scale, scale);

        // Head
        ctx.beginPath();
        ctx.arc(0, -52 + bounce, 8, 0, Math.PI * 2);
        ctx.fill();

        // Torso
        ctx.beginPath();
        ctx.moveTo(0, -44 + bounce);
        ctx.lineTo(-1, -20 + bounce * 0.5);
        ctx.stroke();

        // Arms
        const armSwing = cycle * 0.8;
        ctx.beginPath();
        ctx.moveTo(0, -38 + bounce);
        ctx.lineTo(Math.sin(armSwing) * 18, -28 + bounce + Math.cos(armSwing) * 9);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, -38 + bounce);
        ctx.lineTo(Math.sin(-armSwing) * 18, -28 + bounce + Math.cos(-armSwing) * 9);
        ctx.stroke();

        // Legs
        const legSwing = cycle * 0.9;
        ctx.beginPath();
        ctx.moveTo(-1, -20 + bounce * 0.5);
        ctx.lineTo(Math.sin(legSwing) * 15, -7 + Math.abs(Math.cos(legSwing)) * 5);
        ctx.lineTo(Math.sin(legSwing) * 20, 0);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-1, -20 + bounce * 0.5);
        ctx.lineTo(Math.sin(-legSwing) * 15, -7 + Math.abs(Math.cos(-legSwing)) * 5);
        ctx.lineTo(Math.sin(-legSwing) * 20, 0);
        ctx.stroke();

        ctx.restore();

        // Danger indicator glow
        if (this.distance < 120) {
            const intensity = 1 - (this.distance - 55) / 65;
            ctx.save();
            ctx.globalAlpha = intensity * 0.15;
            const glow = ctx.createRadialGradient(sx, sy - 30, 5, sx, sy - 30, 60);
            glow.addColorStop(0, '#ff0000');
            glow.addColorStop(1, 'rgba(255,0,0,0)');
            ctx.fillStyle = glow;
            ctx.fillRect(sx - 60, sy - 90, 120, 120);
            ctx.restore();
        }
    }
}

// =============================================
// LEVEL GENERATOR
// =============================================
class LevelGenerator {
    constructor() {
        this.platforms = [];
        this.obstacles = [];
        this.collectibles = [];
        this.lastPlatformEnd = 0;
        this.difficulty = 0;
        this.totalGenerated = 0;
    }

    init() {
        // Starting platform (wide, safe)
        const startPlat = new Platform(0, CONFIG.PLATFORM_Y_MAX - 50, 600);
        this.platforms.push(startPlat);
        this.lastPlatformEnd = 600;
        // Generate a few more
        for (let i = 0; i < 5; i++) {
            this._generateNext();
        }
    }

    _generateNext() {
        this.difficulty = Math.min(1, this.totalGenerated * 0.008);

        const gap = rand(
            CONFIG.MIN_GAP + this.difficulty * 30,
            CONFIG.MAX_GAP + this.difficulty * 40
        );

        const yRange = CONFIG.PLATFORM_Y_MAX - CONFIG.PLATFORM_Y_MIN;
        const lastPlat = this.platforms[this.platforms.length - 1];
        let newY = clamp(
            lastPlat.y + rand(-80, 60),
            CONFIG.PLATFORM_Y_MIN,
            CONFIG.PLATFORM_Y_MAX
        );

        const newW = rand(
            CONFIG.MIN_PLATFORM_W - this.difficulty * 60,
            CONFIG.MAX_PLATFORM_W - this.difficulty * 100
        );
        const clampedW = Math.max(120, newW);

        const newX = this.lastPlatformEnd + gap;
        const plat = new Platform(newX, newY, clampedW);
        this.platforms.push(plat);
        this.lastPlatformEnd = newX + clampedW;
        this.totalGenerated++;

        // Obstacles
        if (Math.random() < CONFIG.OBSTACLE_CHANCE + this.difficulty * 0.2) {
            const obsX = newX + rand(60, clampedW - 60);
            let obsType;
            const r = Math.random();
            if (r < 0.4) obsType = OBS_TYPE.BARRIER_HIGH;
            else if (r < 0.7) obsType = OBS_TYPE.BARRIER_LOW;
            else obsType = OBS_TYPE.CRATE;
            this.obstacles.push(new Obstacle(obsX, newY, obsType));
        }

        // Second obstacle on wide platforms
        if (clampedW > 350 && Math.random() < 0.3 + this.difficulty * 0.2) {
            const obsX2 = newX + clampedW - rand(40, 100);
            this.obstacles.push(new Obstacle(obsX2, newY, randInt(0, 2)));
        }

        // Collectibles
        if (Math.random() < CONFIG.COLLECTIBLE_CHANCE) {
            const colX = newX + rand(40, clampedW - 40);
            this.collectibles.push(new Collectible(colX, newY));
        }

        // Gap collectibles (in the air between buildings)
        if (Math.random() < 0.25) {
            const midGapX = newX - gap / 2;
            this.collectibles.push(new Collectible(midGapX, newY - 30));
        }
    }

    update(cameraX) {
        // Generate more platforms ahead
        while (this.lastPlatformEnd < cameraX + CONFIG.WIDTH + 800) {
            this._generateNext();
        }

        // Clean up behind camera
        this.platforms = this.platforms.filter(p => p.x + p.w > cameraX - 200);
        this.obstacles = this.obstacles.filter(o => o.x > cameraX - 200);
        this.collectibles = this.collectibles.filter(c => c.x > cameraX - 200);
    }
}

// =============================================
// HUD & UI RENDERER
// =============================================
class UI {
    constructor(w, h) {
        this.w = w;
        this.h = h;
        this.menuAlpha = 0;
        this.gameOverAlpha = 0;
        this.shakeX = 0;
        this.shakeY = 0;
        this.shakeIntensity = 0;
        this.distanceDisplay = 0;
        this.scoreDisplay = 0;
        this.dangerFlash = 0;
    }

    shake(intensity = 5) {
        this.shakeIntensity = intensity;
    }

    updateShake() {
        if (this.shakeIntensity > 0) {
            this.shakeX = (Math.random() - 0.5) * this.shakeIntensity * 2;
            this.shakeY = (Math.random() - 0.5) * this.shakeIntensity * 2;
            this.shakeIntensity *= 0.9;
            if (this.shakeIntensity < 0.3) {
                this.shakeIntensity = 0;
                this.shakeX = 0;
                this.shakeY = 0;
            }
        }
    }

    drawMenu(ctx, time) {
        this.menuAlpha = Math.min(1, this.menuAlpha + 0.02);

        // Dark overlay
        ctx.fillStyle = 'rgba(5, 5, 16, 0.7)';
        ctx.fillRect(0, 0, this.w, this.h);

        ctx.save();
        ctx.globalAlpha = this.menuAlpha;

        // Title
        const titleY = this.h * 0.3;
        const pulse = Math.sin(time * 0.003) * 5;

        // Title glow
        ctx.save();
        ctx.shadowColor = COLORS.accent;
        ctx.shadowBlur = 30 + Math.sin(time * 0.005) * 10;
        ctx.font = '900 72px Orbitron, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillStyle = COLORS.accent;
        ctx.fillText('SHADOW', this.w / 2, titleY + pulse);
        ctx.restore();

        ctx.font = '300 48px Orbitron, sans-serif';
        ctx.fillStyle = '#ffffff';
        ctx.textAlign = 'center';
        ctx.fillText('RUNNER', this.w / 2, titleY + 55 + pulse);

        // Subtitle
        ctx.font = '400 16px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 159, 67, 0.7)';
        ctx.letterSpacing = '4px';
        ctx.fillText('A   P A R K O U R   A C T I O N   G A M E', this.w / 2, titleY + 95);

        // Controls
        const controlsY = this.h * 0.58;
        ctx.font = '600 18px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
        ctx.fillText('CONTROLS', this.w / 2, controlsY);

        ctx.font = '400 16px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
        const controls = [
            '↑  /  SPACE  /  W  —  JUMP  (double tap for double jump)',
            '↓  /  S  —  SLIDE  (or fast fall in air)',
        ];
        controls.forEach((line, i) => {
            ctx.fillText(line, this.w / 2, controlsY + 30 + i * 24);
        });

        // Start prompt
        const promptAlpha = 0.5 + Math.sin(time * 0.006) * 0.4;
        ctx.font = '700 22px Orbitron, sans-serif';
        ctx.fillStyle = `rgba(255, 107, 61, ${promptAlpha})`;
        ctx.fillText('PRESS  SPACE  OR  TAP  TO  START', this.w / 2, this.h * 0.82);

        // Mobile hint
        ctx.font = '400 13px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.25)';
        ctx.fillText('On mobile: Tap upper half to jump, lower half to slide', this.w / 2, this.h * 0.9);

        ctx.restore();
    }

    drawHUD(ctx, player, pursuer) {
        // Distance display (smooth counter)
        const dist = Math.floor(player.distance / 10);
        this.distanceDisplay = lerp(this.distanceDisplay, dist, 0.1);
        this.scoreDisplay = lerp(this.scoreDisplay, player.score, 0.15);

        // Top bar
        ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
        ctx.fillRect(0, 0, this.w, 50);
        ctx.fillStyle = 'rgba(255, 107, 61, 0.3)';
        ctx.fillRect(0, 49, this.w, 1);

        // Distance
        ctx.font = '700 14px Orbitron, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
        ctx.textAlign = 'left';
        ctx.fillText('DISTANCE', 20, 22);
        ctx.font = '700 22px Orbitron, sans-serif';
        ctx.fillStyle = '#ffffff';
        ctx.fillText(Math.floor(this.distanceDisplay) + ' m', 20, 42);

        // Score
        ctx.font = '700 14px Orbitron, sans-serif';
        ctx.fillStyle = 'rgba(255, 217, 61, 0.6)';
        ctx.textAlign = 'center';
        ctx.fillText('SCORE', this.w / 2, 22);
        ctx.font = '700 22px Orbitron, sans-serif';
        ctx.fillStyle = COLORS.collectible;
        ctx.fillText(Math.floor(this.scoreDisplay).toString(), this.w / 2, 42);

        // Speed indicator
        const speedPct = (player.speed - CONFIG.PLAYER_SPEED) / (CONFIG.MAX_SPEED - CONFIG.PLAYER_SPEED);
        ctx.font = '700 14px Orbitron, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
        ctx.textAlign = 'right';
        ctx.fillText('SPEED', this.w - 20, 22);
        // Speed bar
        const barW = 120;
        const barH = 6;
        const barX = this.w - 20 - barW;
        const barY = 32;
        ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.fillRect(barX, barY, barW, barH);
        const speedColor = speedPct > 0.7 ? '#ff4444' : speedPct > 0.4 ? COLORS.accent : '#44ff44';
        ctx.fillStyle = speedColor;
        ctx.fillRect(barX, barY, barW * clamp(speedPct, 0, 1), barH);

        // Pursuer proximity warning
        if (pursuer.active && pursuer.distance < 150) {
            this.dangerFlash += 0.08;
            const alpha = (1 - pursuer.distance / 150) * (0.1 + Math.sin(this.dangerFlash * 5) * 0.05);
            ctx.fillStyle = `rgba(255, 0, 0, ${alpha})`;
            ctx.fillRect(0, 0, this.w, this.h);

            // Warning text
            ctx.font = '700 16px Orbitron, sans-serif';
            ctx.fillStyle = `rgba(255, 50, 50, ${0.5 + Math.sin(this.dangerFlash * 5) * 0.3})`;
            ctx.textAlign = 'center';
            ctx.fillText('⚠ PURSUER CLOSING IN ⚠', this.w / 2, 75);
        } else {
            this.dangerFlash = 0;
        }
    }

    drawGameOver(ctx, player, time) {
        this.gameOverAlpha = Math.min(1, this.gameOverAlpha + 0.02);

        // Dark overlay
        ctx.fillStyle = `rgba(5, 2, 10, ${this.gameOverAlpha * 0.85})`;
        ctx.fillRect(0, 0, this.w, this.h);

        ctx.save();
        ctx.globalAlpha = easeOut(this.gameOverAlpha);

        const centerY = this.h * 0.35;

        // Game over text
        ctx.save();
        ctx.shadowColor = '#ff0000';
        ctx.shadowBlur = 20;
        ctx.font = '900 56px Orbitron, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillStyle = '#ff4444';
        ctx.fillText('CAUGHT', this.w / 2, centerY);
        ctx.restore();

        ctx.font = '300 20px Orbitron, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
        ctx.fillText('You couldn\'t outrun the system', this.w / 2, centerY + 40);

        // Stats
        const statsY = centerY + 90;
        const dist = Math.floor(player.distance / 10);

        ctx.font = '600 16px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
        ctx.fillText('DISTANCE', this.w / 2 - 100, statsY);
        ctx.fillText('SCORE', this.w / 2 + 100, statsY);

        ctx.font = '700 36px Orbitron, sans-serif';
        ctx.fillStyle = '#ffffff';
        ctx.fillText(dist + ' m', this.w / 2 - 100, statsY + 40);
        ctx.fillStyle = COLORS.collectible;
        ctx.fillText(player.score.toString(), this.w / 2 + 100, statsY + 40);

        // Total
        ctx.font = '600 14px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 159, 67, 0.6)';
        ctx.fillText('TOTAL SCORE', this.w / 2, statsY + 80);
        ctx.font = '700 28px Orbitron, sans-serif';
        ctx.fillStyle = COLORS.accent;
        ctx.fillText((dist + player.score).toString(), this.w / 2, statsY + 110);

        // Restart prompt
        if (this.gameOverAlpha >= 1) {
            const promptAlpha = 0.4 + Math.sin(time * 0.006) * 0.4;
            ctx.font = '700 18px Orbitron, sans-serif';
            ctx.fillStyle = `rgba(255, 107, 61, ${promptAlpha})`;
            ctx.fillText('PRESS  SPACE  OR  TAP  TO  RUN  AGAIN', this.w / 2, this.h * 0.85);
        }

        ctx.restore();
    }

    drawPause(ctx) {
        ctx.fillStyle = 'rgba(5, 5, 16, 0.7)';
        ctx.fillRect(0, 0, this.w, this.h);

        ctx.font = '900 48px Orbitron, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillStyle = '#ffffff';
        ctx.fillText('PAUSED', this.w / 2, this.h / 2 - 20);

        ctx.font = '400 18px Rajdhani, sans-serif';
        ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
        ctx.fillText('Press ESC or P to resume', this.w / 2, this.h / 2 + 20);
    }
}

// =============================================
// MAIN GAME CLASS
// =============================================
const GAME_STATE = { MENU: 0, PLAYING: 1, PAUSED: 2, GAMEOVER: 3 };

class Game {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.canvas.width = CONFIG.WIDTH;
        this.canvas.height = CONFIG.HEIGHT;
        this.state = GAME_STATE.MENU;
        this.time = 0;
        this.cameraX = 0;

        this.sound = new SoundManager();
        this.particles = new ParticleSystem();
        this.bg = new Background(CONFIG.WIDTH, CONFIG.HEIGHT);
        this.ui = new UI(CONFIG.WIDTH, CONFIG.HEIGHT);
        this.level = new LevelGenerator();
        this.player = null;
        this.pursuer = null;

        this._bindInput();
        this._resize();
        window.addEventListener('resize', () => this._resize());
    }

    _resize() {
        // Scale canvas to fill window while maintaining aspect ratio
        const ratio = CONFIG.WIDTH / CONFIG.HEIGHT;
        let w = window.innerWidth;
        let h = window.innerHeight;
        if (w / h > ratio) {
            w = h * ratio;
        } else {
            h = w / ratio;
        }
        this.canvas.style.width = w + 'px';
        this.canvas.style.height = h + 'px';
    }

    _bindInput() {
        // Keyboard
        document.addEventListener('keydown', (e) => {
            this.sound.resume();
            switch (e.code) {
                case 'Space':
                case 'ArrowUp':
                case 'KeyW':
                    e.preventDefault();
                    this._actionJump();
                    break;
                case 'ArrowDown':
                case 'KeyS':
                    e.preventDefault();
                    this._actionSlide();
                    break;
                case 'Escape':
                case 'KeyP':
                    this._actionPause();
                    break;
            }
        });

        // Touch
        this.canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            this.sound.resume();
            const touch = e.touches[0];
            const rect = this.canvas.getBoundingClientRect();
            const relY = (touch.clientY - rect.top) / rect.height;

            if (this.state === GAME_STATE.MENU) {
                this._startGame();
            } else if (this.state === GAME_STATE.GAMEOVER) {
                if (this.ui.gameOverAlpha >= 1) this._restart();
            } else if (this.state === GAME_STATE.PLAYING) {
                if (relY < 0.5) {
                    this._actionJump();
                } else {
                    this._actionSlide();
                }
            }
        }, { passive: false });

        // Mouse click (for desktop testing)
        this.canvas.addEventListener('mousedown', (e) => {
            this.sound.resume();
            if (this.state === GAME_STATE.MENU) {
                this._startGame();
            } else if (this.state === GAME_STATE.GAMEOVER) {
                if (this.ui.gameOverAlpha >= 1) this._restart();
            }
        });
    }

    _actionJump() {
        if (this.state === GAME_STATE.MENU) {
            this._startGame();
        } else if (this.state === GAME_STATE.PLAYING && this.player) {
            this.player.jump(this.sound);
        } else if (this.state === GAME_STATE.GAMEOVER && this.ui.gameOverAlpha >= 1) {
            this._restart();
        }
    }

    _actionSlide() {
        if (this.state === GAME_STATE.MENU) {
            this._startGame();
        } else if (this.state === GAME_STATE.PLAYING && this.player) {
            this.player.startSlide(this.sound);
        } else if (this.state === GAME_STATE.GAMEOVER && this.ui.gameOverAlpha >= 1) {
            this._restart();
        }
    }

    _actionPause() {
        if (this.state === GAME_STATE.PLAYING) {
            this.state = GAME_STATE.PAUSED;
        } else if (this.state === GAME_STATE.PAUSED) {
            this.state = GAME_STATE.PLAYING;
        }
    }

    _startGame() {
        this.sound.init();
        this.sound.menuSelect();
        this.level = new LevelGenerator();
        this.level.init();
        this.player = new Player(100, CONFIG.PLATFORM_Y_MAX - 50);
        this.pursuer = new Pursuer();
        this.particles = new ParticleSystem();
        this.cameraX = 0;
        this.ui.menuAlpha = 0;
        this.ui.gameOverAlpha = 0;
        this.ui.distanceDisplay = 0;
        this.ui.scoreDisplay = 0;
        this.state = GAME_STATE.PLAYING;
    }

    _restart() {
        this.sound.menuSelect();
        this._startGame();
    }

    init() {
        // Hide loading screen
        setTimeout(() => {
            const loadScreen = document.getElementById('loading-screen');
            if (loadScreen) loadScreen.classList.add('hidden');
        }, 800);

        this._loop();
    }

    _loop() {
        this.time++;
        this._update();
        this._render();
        requestAnimationFrame(() => this._loop());
    }

    _update() {
        if (this.state === GAME_STATE.PLAYING && this.player) {
            // Update player
            this.player.update(
                this.level.platforms,
                this.level.obstacles,
                this.level.collectibles,
                this.particles,
                this.sound
            );

            // Update camera
            const targetCamX = this.player.x - CONFIG.PLAYER_SCREEN_X;
            this.cameraX = lerp(this.cameraX, targetCamX, 0.1);

            // Update pursuer
            if (this.pursuer) {
                this.pursuer.update(this.player);
                // If pursuer catches player - handle death
                if (this.pursuer.distance <= 55 && this.player.alive) {
                    this.player.die(this.sound, this.particles);
                }
            }

            // Update level generation
            this.level.update(this.cameraX);

            // Screen shake on hit
            if (this.player.stunTimer === 19) {
                this.ui.shake(8);
            }

            // Check game over
            if (!this.player.alive) {
                this.state = GAME_STATE.GAMEOVER;
                this.ui.gameOverAlpha = 0;
            }

            // Update score based on distance
            this.player.score += Math.floor(this.player.speed * 0.1);
        }

        // Always update particles and shake
        this.particles.update();
        this.ui.updateShake();
    }

    _render() {
        const ctx = this.ctx;

        ctx.save();
        // Apply screen shake
        ctx.translate(this.ui.shakeX, this.ui.shakeY);

        // Background (always draws)
        this.bg.draw(ctx, this.cameraX);

        if (this.state !== GAME_STATE.MENU) {
            // Draw platforms
            this.level.platforms.forEach(p => p.draw(ctx, this.cameraX));

            // Draw collectibles
            this.level.collectibles.forEach(c => c.draw(ctx, this.cameraX));

            // Draw obstacles
            this.level.obstacles.forEach(o => o.draw(ctx, this.cameraX));

            // Draw particles (behind player)
            this.particles.draw(ctx, this.cameraX);

            // Draw pursuer
            if (this.pursuer) {
                this.pursuer.draw(ctx, this.cameraX, this.player.x);
            }

            // Draw player
            if (this.player) {
                this.player.draw(ctx, this.cameraX);
            }
        }

        ctx.restore();

        // UI overlays (not affected by shake)
        switch (this.state) {
            case GAME_STATE.MENU:
                this.ui.drawMenu(ctx, this.time);
                break;
            case GAME_STATE.PLAYING:
                if (this.player && this.pursuer) {
                    this.ui.drawHUD(ctx, this.player, this.pursuer);
                }
                break;
            case GAME_STATE.PAUSED:
                if (this.player && this.pursuer) {
                    this.ui.drawHUD(ctx, this.player, this.pursuer);
                }
                this.ui.drawPause(ctx);
                break;
            case GAME_STATE.GAMEOVER:
                if (this.player) {
                    this.ui.drawGameOver(ctx, this.player, this.time);
                }
                break;
        }
    }
}

// =============================================
// INITIALIZATION
// =============================================
window.addEventListener('load', () => {
    const canvas = document.getElementById('gameCanvas');
    if (!canvas) {
        console.error('Canvas element not found!');
        return;
    }
    const game = new Game(canvas);
    game.init();
});
