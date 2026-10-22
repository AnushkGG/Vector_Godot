// Entry point for Construct 3
runOnStartup(async runtime => {
    const gameCanvas = document.createElement('canvas');
    gameCanvas.width = 1280;
    gameCanvas.height = 720;
    gameCanvas.style.cssText = 'position:fixed;top:0;left:0;z-index:9999;background:#000;';
    document.body.appendChild(gameCanvas);
    
    function resize() {
        const wr = window.innerWidth / window.innerHeight;
        const gr = 1280 / 720;
        let w, h;
        if (wr > gr) { h = window.innerHeight; w = h * gr; }
        else { w = window.innerWidth; h = w / gr; }
        gameCanvas.style.width = w + 'px';
        gameCanvas.style.height = h + 'px';
        gameCanvas.style.left = ((window.innerWidth - w) / 2) + 'px';
        gameCanvas.style.top = ((window.innerHeight - h) / 2) + 'px';
    }
    resize();
    window.addEventListener('resize', resize);
    
    const game = new Game(gameCanvas);
    game.init();
});

const CONFIG = {
    GRAVITY: 0.62,
    PLAYER_SPEED: 5.5,
    MAX_SPEED: 13,
    JUMP_FORCE: -13.5,
    DOUBLE_JUMP_FORCE: -11.0,
    SLIDE_DURATION: 45,
    ROLL_DURATION: 30,
    STUN_DURATION: 60,
    PURSUER_SPEED_MULT: 1.05,
    PURSUER_CATCH_DIST: 50,
    GROUND_Y: 600,
    PLATFORM_SPEED: 8,
    MAX_FALL_SPEED: 15,
    SPAWN_X: 300,
    WIDTH: 1280,
    HEIGHT: 720
};

const COLORS = {
    SKY_TOP: '#2b1055',
    SKY_MID: '#75225b',
    SKY_BOT: '#d15449',
    SUN: '#ff9a44',
    BG_FAR: '#1f0d3d',
    BG_MID: '#16082b',
    FG: '#080211',
    PLAYER: '#000000',
    PURSUER: '#1a0000',
    DANGER: '#ff0000',
    COLLECTIBLE: '#00ffff',
    WINDOW_LIT: '#ffcc00',
    WINDOW_DIM: '#332200'
};

const UTILS = {
    lerp: (a, b, t) => a + (b - a) * t,
    clamp: (v, min, max) => Math.max(min, Math.min(max, v)),
    rand: (min, max) => Math.random() * (max - min) + min,
    randInt: (min, max) => Math.floor(Math.random() * (max - min + 1)) + min,
    easeOut: t => 1 - Math.pow(1 - t, 3),
    easeInOut: t => t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2
};

class SoundManager {
    constructor() {
        try {
            this.ctx = new (window.AudioContext || window.webkitAudioContext)();
            this.enabled = true;
        } catch(e) {
            this.enabled = false;
        }
    }
    
    playTone(freq, type, duration, vol=0.1) {
        if(!this.enabled) return;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
        gain.gain.setValueAtTime(vol, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + duration);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start();
        osc.stop(this.ctx.currentTime + duration);
    }
    
    noise(duration, vol=0.1) {
        if(!this.enabled) return;
        const bufferSize = this.ctx.sampleRate * duration;
        const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for(let i=0; i<bufferSize; i++) data[i] = Math.random() * 2 - 1;
        const noise = this.ctx.createBufferSource();
        noise.buffer = buffer;
        const gain = this.ctx.createGain();
        gain.gain.setValueAtTime(vol, this.ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + duration);
        
        const filter = this.ctx.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.value = 1000;
        noise.connect(filter);
        filter.connect(gain);
        gain.connect(this.ctx.destination);
        noise.start();
    }
    
    jump() { this.playTone(300, 'sine', 0.3, 0.2); setTimeout(()=>this.playTone(400, 'sine', 0.2, 0.2), 50); }
    doubleJump() { this.playTone(400, 'sine', 0.2, 0.2); setTimeout(()=>this.playTone(600, 'sine', 0.2, 0.2), 50); }
    land() { this.noise(0.2, 0.2); }
    slide() { this.noise(0.4, 0.1); }
    hit() { this.noise(0.3, 0.4); this.playTone(100, 'sawtooth', 0.3, 0.3); }
    collect() { this.playTone(800, 'sine', 0.1, 0.1); setTimeout(()=>this.playTone(1200, 'sine', 0.2, 0.1), 50); }
    death() { this.noise(0.8, 0.5); this.playTone(50, 'sawtooth', 0.8, 0.5); }
    menuSelect() { this.playTone(600, 'square', 0.1, 0.1); }
}

class Particle {
    constructor(x, y, vx, vy, life, color, size) {
        this.x = x; this.y = y; this.vx = vx; this.vy = vy;
        this.life = life; this.maxLife = life;
        this.color = color; this.size = size;
    }
    update() {
        this.x += this.vx; this.y += this.vy;
        this.life--;
        return this.life > 0;
    }
    draw(ctx, camX) {
        ctx.globalAlpha = Math.max(0, this.life / this.maxLife);
        ctx.fillStyle = this.color;
        ctx.fillRect(this.x - camX - this.size/2, this.y - this.size/2, this.size, this.size);
        ctx.globalAlpha = 1;
    }
}

class ParticleSystem {
    constructor() { this.particles = []; }
    add(x, y, vx, vy, life, color, size) { this.particles.push(new Particle(x, y, vx, vy, life, color, size)); }
    update() { this.particles = this.particles.filter(p => p.update()); }
    draw(ctx, camX) { this.particles.forEach(p => p.draw(ctx, camX)); }
    
    dustBurst(x, y, count=10) {
        for(let i=0; i<count; i++) this.add(x, y, UTILS.rand(-2, 2), UTILS.rand(-2, 0), UTILS.randInt(15, 30), '#888', UTILS.rand(2, 5));
    }
    landingDust(x, y, vx) {
        for(let i=0; i<15; i++) this.add(x, y, vx + UTILS.rand(-1, 3), UTILS.rand(-3, 0), UTILS.randInt(15, 30), '#aaa', UTILS.rand(2, 6));
    }
    slideSparks(x, y) {
        for(let i=0; i<3; i++) this.add(x, y, UTILS.rand(-4, 0), UTILS.rand(-2, 0), UTILS.randInt(10, 20), '#ffaa00', UTILS.rand(1, 3));
    }
    deathBurst(x, y) {
        for(let i=0; i<50; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 8;
            this.add(x, y, Math.cos(angle)*speed, Math.sin(angle)*speed, UTILS.randInt(30, 60), '#aa0000', UTILS.rand(3, 8));
        }
    }
    collectBurst(x, y) {
        for(let i=0; i<20; i++) {
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 5;
            this.add(x, y, Math.cos(angle)*speed, Math.sin(angle)*speed, UTILS.randInt(20, 40), COLORS.COLLECTIBLE, UTILS.rand(2, 4));
        }
    }
    speedLines(x, y, width, height) {
        for(let i=0; i<2; i++) {
            this.add(x + UTILS.rand(0, width), y + UTILS.rand(0, height), -15, 0, UTILS.randInt(5, 10), '#ffffff', UTILS.rand(1, 2));
        }
    }
}

class Background {
    constructor() {
        this.stars = Array.from({length: 100}, () => ({x: Math.random(), y: Math.random()*0.6, s: Math.random()*2+1, t: Math.random()*Math.PI*2}));
        this.clouds = Array.from({length: 10}, () => ({x: Math.random()*2000, y: Math.random()*300, s: Math.random()*0.5+0.1}));
        this.farBuildings = [];
        this.midBuildings = [];
        for(let i=0; i<30; i++) {
            this.farBuildings.push({x: i*150, w: UTILS.rand(100, 250), h: UTILS.rand(200, 500)});
            this.midBuildings.push({x: i*200, w: UTILS.rand(150, 300), h: UTILS.rand(150, 400), lit: Math.random()>0.5});
        }
    }
    update(camX) {
        this.stars.forEach(s => s.t += 0.05);
        this.clouds.forEach(c => { c.x -= c.s; if(c.x < -500) c.x = 2000; });
        
        while(this.farBuildings.length && this.farBuildings[0].x - camX*0.2 < -500) this.farBuildings.shift();
        while(this.farBuildings.length < 30) {
            const last = this.farBuildings[this.farBuildings.length-1];
            this.farBuildings.push({x: last.x + last.w + UTILS.rand(10, 50), w: UTILS.rand(100, 250), h: UTILS.rand(200, 500)});
        }
        
        while(this.midBuildings.length && this.midBuildings[0].x - camX*0.5 < -500) this.midBuildings.shift();
        while(this.midBuildings.length < 30) {
            const last = this.midBuildings[this.midBuildings.length-1];
            this.midBuildings.push({x: last.x + last.w + UTILS.rand(20, 80), w: UTILS.rand(150, 300), h: UTILS.rand(150, 400), lit: Math.random()>0.5});
        }
    }
    draw(ctx, camX, w, h) {
        const grad = ctx.createLinearGradient(0, 0, 0, h);
        grad.addColorStop(0, COLORS.SKY_TOP);
        grad.addColorStop(0.5, COLORS.SKY_MID);
        grad.addColorStop(1, COLORS.SKY_BOT);
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, w, h);
        
        ctx.beginPath();
        ctx.arc(w*0.8, h*0.6, 150, 0, Math.PI*2);
        const sunGrad = ctx.createRadialGradient(w*0.8, h*0.6, 0, w*0.8, h*0.6, 150);
        sunGrad.addColorStop(0, COLORS.SUN);
        sunGrad.addColorStop(1, 'transparent');
        ctx.fillStyle = sunGrad;
        ctx.fill();
        
        ctx.fillStyle = '#fff';
        this.stars.forEach(s => {
            ctx.globalAlpha = (Math.sin(s.t)+1)/2 * 0.8;
            ctx.fillRect(s.x*w, s.y*h, s.s, s.s);
        });
        ctx.globalAlpha = 1;
        
        ctx.fillStyle = 'rgba(255,255,255,0.1)';
        this.clouds.forEach(c => {
            ctx.beginPath();
            ctx.arc(c.x, c.y, 40, 0, Math.PI*2);
            ctx.arc(c.x+30, c.y-20, 50, 0, Math.PI*2);
            ctx.arc(c.x+70, c.y, 40, 0, Math.PI*2);
            ctx.fill();
        });
        
        ctx.fillStyle = COLORS.BG_FAR;
        this.farBuildings.forEach(b => {
            ctx.fillRect(b.x - camX*0.2, h - b.h, b.w, b.h);
        });
        
        this.midBuildings.forEach(b => {
            const bx = b.x - camX*0.5;
            const by = h - b.h;
            ctx.fillStyle = COLORS.BG_MID;
            ctx.fillRect(bx, by, b.w, b.h);
            
            if(b.w > 50 && b.h > 100) {
                ctx.fillStyle = b.lit ? COLORS.WINDOW_LIT : COLORS.WINDOW_DIM;
                const rows = Math.floor(b.h / 30);
                const cols = Math.floor(b.w / 30);
                for(let r=1; r<rows-1; r++) {
                    for(let c=1; c<cols-1; c++) {
                        if(Math.random() > 0.3) {
                            ctx.fillRect(bx + c*30, by + r*30, 10, 15);
                        }
                    }
                }
            }
        });
    }
}

class Platform {
    constructor(x, y, w, h) {
        this.x = x; this.y = y; this.w = w; this.h = h;
        this.details = [];
        const numDetails = Math.floor(w / 150);
        for(let i=0; i<numDetails; i++) {
            this.details.push({
                x: x + UTILS.rand(20, w-50),
                type: Math.random()>0.5 ? 'ac' : 'vent',
                w: UTILS.rand(20, 50),
                h: UTILS.rand(20, 40)
            });
        }
    }
    draw(ctx, camX) {
        const bx = this.x - camX;
        ctx.fillStyle = COLORS.FG;
        ctx.fillRect(bx, this.y, this.w, this.h);
        
        ctx.fillStyle = '#1a0f2e';
        ctx.fillRect(bx, this.y, this.w, 5);
        
        this.details.forEach(d => {
            ctx.fillStyle = COLORS.FG;
            ctx.fillRect(d.x - camX, this.y - d.h, d.w, d.h);
            if(d.type === 'ac') {
                ctx.fillStyle = '#111';
                ctx.fillRect(d.x - camX + 5, this.y - d.h + 5, d.w-10, d.h-10);
            }
        });
    }
}

class Obstacle {
    constructor(x, y, type) {
        this.x = x; this.y = y; this.type = type; // 0=HIGH, 1=LOW, 2=CRATE
        this.active = true;
        if(type === 0) { this.w = 20; this.h = 100; this.y -= this.h; }
        else if(type === 1) { this.w = 40; this.h = 20; this.y -= 120; }
        else { this.w = 40; this.h = 40; this.y -= this.h; }
    }
    draw(ctx, camX) {
        ctx.fillStyle = COLORS.FG;
        ctx.fillRect(this.x - camX, this.y, this.w, this.h);
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 2;
        ctx.strokeRect(this.x - camX, this.y, this.w, this.h);
        if(this.type === 1) {
            ctx.fillStyle = COLORS.FG;
            ctx.fillRect(this.x - camX + 5, this.y + this.h, 5, 100);
            ctx.fillRect(this.x - camX + this.w - 10, this.y + this.h, 5, 100);
        }
    }
}

class Collectible {
    constructor(x, y) {
        this.x = x; this.y = y - 40;
        this.w = 20; this.h = 20;
        this.active = true;
        this.t = Math.random() * 10;
    }
    update() { this.t += 0.1; }
    draw(ctx, camX) {
        if(!this.active) return;
        const drawY = this.y + Math.sin(this.t) * 10;
        ctx.save();
        ctx.translate(this.x - camX + this.w/2, drawY + this.h/2);
        ctx.rotate(this.t * 0.5);
        ctx.fillStyle = COLORS.COLLECTIBLE;
        ctx.shadowColor = COLORS.COLLECTIBLE;
        ctx.shadowBlur = 15;
        ctx.beginPath();
        ctx.moveTo(0, -10); ctx.lineTo(10, 0); ctx.lineTo(0, 10); ctx.lineTo(-10, 0); ctx.closePath();
        ctx.fill();
        ctx.restore();
    }
}

class Player {
    constructor(x, y) {
        this.x = x; this.y = y;
        this.vx = CONFIG.PLAYER_SPEED; this.vy = 0;
        this.w = 24; this.h = 60;
        this.state = 'RUNNING'; 
        this.jumps = 0;
        this.slideTimer = 0;
        this.rollTimer = 0;
        this.stunTimer = 0;
        this.animTimer = 0;
        this.score = 0;
        this.trail = [];
    }
    
    update(platforms, obstacles, collectibles, particles, sounds, game) {
        if(this.state === 'DEAD') {
            this.vy += CONFIG.GRAVITY;
            this.y += this.vy;
            return;
        }

        if(this.state === 'STUNNED') {
            this.stunTimer--;
            this.vx = UTILS.lerp(this.vx, CONFIG.PLAYER_SPEED * 0.5, 0.1);
            if(this.stunTimer <= 0) this.state = 'RUNNING';
        } else {
            this.vx = UTILS.lerp(this.vx, CONFIG.MAX_SPEED, 0.001);
        }

        this.vy += CONFIG.GRAVITY;
        if(this.vy > CONFIG.MAX_FALL_SPEED) this.vy = CONFIG.MAX_FALL_SPEED;

        let nextX = this.x + this.vx;
        let nextY = this.y + this.vy;
        
        let onGround = false;

        for(let p of platforms) {
            if(nextX + this.w > p.x && nextX < p.x + p.w) {
                if(this.y + this.h <= p.y && nextY + this.h >= p.y) {
                    nextY = p.y - this.h;
                    this.vy = 0;
                    onGround = true;
                }
                else if(nextY + this.h > p.y && nextY < p.y + p.h) {
                    nextX = p.x - this.w;
                    this.vx = 0;
                    this.die(particles, sounds, game);
                    return;
                }
            }
        }

        this.x = nextX;
        this.y = nextY;

        if(onGround) {
            this.jumps = 0;
            if(this.state === 'FALLING') {
                if(this.vy > 10) {
                    this.state = 'ROLLING';
                    this.rollTimer = CONFIG.ROLL_DURATION;
                    sounds.land();
                    particles.landingDust(this.x + this.w/2, this.y + this.h, this.vx);
                } else {
                    this.state = 'RUNNING';
                    sounds.land();
                    particles.landingDust(this.x + this.w/2, this.y + this.h, this.vx);
                }
            }
            if(this.state === 'SLIDING') {
                this.slideTimer--;
                particles.slideSparks(this.x + this.w, this.y + this.h);
                if(this.slideTimer <= 0) {
                    this.state = 'RUNNING';
                    this.h = 60;
                    this.y -= 30;
                }
            }
            if(this.state === 'ROLLING') {
                this.rollTimer--;
                this.vx += 0.5;
                if(this.rollTimer <= 0) {
                    this.state = 'RUNNING';
                    this.h = 60;
                    this.y -= 30;
                }
            }
        } else {
            if(this.vy > 0 && this.state !== 'STUNNED') this.state = 'FALLING';
        }

        if(this.y > CONFIG.HEIGHT) {
            this.die(particles, sounds, game);
            return;
        }

        let hitBox = {x: this.x, y: this.y, w: this.w, h: this.h};
        for(let o of obstacles) {
            if(!o.active) continue;
            if(hitBox.x < o.x + o.w && hitBox.x + hitBox.w > o.x &&
               hitBox.y < o.y + o.h && hitBox.y + hitBox.h > o.y) {
                o.active = false;
                this.state = 'STUNNED';
                this.stunTimer = CONFIG.STUN_DURATION;
                this.vx *= 0.3;
                this.vy = -3;
                sounds.hit();
                particles.dustBurst(this.x + this.w, this.y + this.h/2, 20);
                game.screenShake = 10;
            }
        }

        for(let c of collectibles) {
            if(!c.active) continue;
            if(hitBox.x < c.x + c.w && hitBox.x + hitBox.w > c.x &&
               hitBox.y < c.y + c.h && hitBox.y + hitBox.h > c.y) {
                c.active = false;
                this.score += 100;
                sounds.collect();
                particles.collectBurst(c.x + c.w/2, c.y + c.h/2);
            }
        }

        this.animTimer += 0.2 + (this.vx * 0.05);
        this.score += this.vx * 0.01;
        
        if(this.vx > CONFIG.MAX_SPEED * 0.8) {
            this.trail.push({x: this.x, y: this.y, life: 10, state: this.state, h: this.h});
            if(this.trail.length > 5) this.trail.shift();
        } else {
            this.trail.shift();
        }
        
        this.trail.forEach(t => t.life--);
        this.trail = this.trail.filter(t => t.life > 0);
    }

    jump(sounds) {
        if(this.state === 'DEAD' || this.state === 'STUNNED') return;
        if(this.jumps < 2) {
            this.vy = this.jumps === 0 ? CONFIG.JUMP_FORCE : CONFIG.DOUBLE_JUMP_FORCE;
            this.jumps++;
            this.state = 'JUMPING';
            if(this.jumps === 1) sounds.jump();
            else sounds.doubleJump();
            
            if(this.h < 60) {
                this.y -= (60 - this.h);
                this.h = 60;
            }
        }
    }

    slide(sounds) {
        if(this.state === 'DEAD' || this.state === 'STUNNED' || this.state === 'FALLING') return;
        if(this.state !== 'SLIDING' && this.state !== 'ROLLING') {
            this.state = 'SLIDING';
            this.slideTimer = CONFIG.SLIDE_DURATION;
            this.y += 30;
            this.h = 30;
            sounds.slide();
        }
    }

    die(particles, sounds, game) {
        if(this.state === 'DEAD') return;
        this.state = 'DEAD';
        this.vx = 0;
        this.vy = -5;
        sounds.death();
        particles.deathBurst(this.x + this.w/2, this.y + this.h/2);
        game.screenShake = 20;
        setTimeout(() => game.setState('GAMEOVER'), 1500);
    }

    drawStickFigure(ctx, cx, cy, state, t) {
        ctx.strokeStyle = COLORS.PLAYER;
        ctx.lineWidth = 4;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';

        const drawLimb = (x1, y1, x2, y2, x3, y3) => {
            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.lineTo(x3, y3); ctx.stroke();
        };

        let headX = cx, headY = cy - 20;
        let neckX = cx, neckY = cy - 10;
        let hipX = cx, hipY = cy + 10;
        
        let leftArmAngle = Math.sin(t) * 1.5;
        let rightArmAngle = -Math.sin(t) * 1.5;
        let leftLegAngle = -Math.sin(t) * 1.2;
        let rightLegAngle = Math.sin(t) * 1.2;
        
        let lean = 0.2;

        if(state === 'JUMPING' || state === 'FALLING') {
            leftArmAngle = -2.5; rightArmAngle = -3.0;
            leftLegAngle = -0.5; rightLegAngle = 0.2;
            if(state === 'FALLING') { leftArmAngle = -1.0; rightArmAngle = -1.5; leftLegAngle = 0.5; rightLegAngle = -0.5; }
        } else if(state === 'SLIDING') {
            headY += 20; neckY += 20; hipY += 20;
            lean = 1.5;
            leftArmAngle = -1.5; rightArmAngle = 2.0;
            leftLegAngle = 1.5; rightLegAngle = -1.5;
        } else if(state === 'ROLLING') {
            const rot = t * 2;
            ctx.translate(cx, cy);
            ctx.rotate(rot);
            cx = 0; cy = 0;
            headX = cx + 10; headY = cy; neckX = cx + 5; neckY = cy; hipX = cx - 5; hipY = cy;
            leftArmAngle = 0; rightArmAngle = 0; leftLegAngle = 0; rightLegAngle = 0;
            lean = 0;
        } else if(state === 'STUNNED') {
            headX -= 10; headY -= 5;
            lean = -0.5;
            leftArmAngle = 1.5; rightArmAngle = 1.0;
            leftLegAngle = 0.5; rightLegAngle = 0.2;
        }

        headX += Math.sin(lean) * 10;
        neckX += Math.sin(lean) * 5;

        ctx.beginPath(); ctx.arc(headX, headY, 6, 0, Math.PI*2); ctx.fillStyle = COLORS.PLAYER; ctx.fill();
        ctx.beginPath(); ctx.moveTo(neckX, neckY); ctx.lineTo(hipX, hipY); ctx.stroke();

        const armLen1 = 12, armLen2 = 12;
        const legLen1 = 15, legLen2 = 15;

        drawLimb(neckX, neckY, 
                 neckX + Math.sin(leftArmAngle)*armLen1, neckY + Math.cos(leftArmAngle)*armLen1,
                 neckX + Math.sin(leftArmAngle)*armLen1 + Math.sin(leftArmAngle+0.5)*armLen2, neckY + Math.cos(leftArmAngle)*armLen1 + Math.cos(leftArmAngle+0.5)*armLen2);
                 
        drawLimb(hipX, hipY,
                 hipX + Math.sin(leftLegAngle)*legLen1, hipY + Math.cos(leftLegAngle)*legLen1,
                 hipX + Math.sin(leftLegAngle)*legLen1 + Math.sin(leftLegAngle+0.5)*legLen2, hipY + Math.cos(leftLegAngle)*legLen1 + Math.cos(leftLegAngle+0.5)*legLen2);

        drawLimb(hipX, hipY,
                 hipX + Math.sin(rightLegAngle)*legLen1, hipY + Math.cos(rightLegAngle)*legLen1,
                 hipX + Math.sin(rightLegAngle)*legLen1 + Math.sin(rightLegAngle+0.5)*legLen2, hipY + Math.cos(rightLegAngle)*legLen1 + Math.cos(rightLegAngle+0.5)*legLen2);

        drawLimb(neckX, neckY, 
                 neckX + Math.sin(rightArmAngle)*armLen1, neckY + Math.cos(rightArmAngle)*armLen1,
                 neckX + Math.sin(rightArmAngle)*armLen1 + Math.sin(rightArmAngle+0.5)*armLen2, neckY + Math.cos(rightArmAngle)*armLen1 + Math.cos(rightArmAngle+0.5)*armLen2);

        if(state === 'ROLLING') {
            ctx.rotate(-t*2);
            ctx.translate(-cx, -cy);
        }
    }

    draw(ctx, camX) {
        this.trail.forEach((t, i) => {
            ctx.globalAlpha = t.life / 20;
            ctx.save();
            const cx = t.x - camX + this.w/2;
            const cy = t.y + t.h/2;
            this.drawStickFigure(ctx, cx, cy, t.state, this.animTimer - (this.trail.length - i)*0.5);
            ctx.restore();
        });
        ctx.globalAlpha = 1;

        if(this.state === 'DEAD') return;

        ctx.save();
        const cx = this.x - camX + this.w/2;
        const cy = this.y + this.h/2;
        this.drawStickFigure(ctx, cx, cy, this.state, this.animTimer);
        ctx.restore();
    }
}

class Pursuer extends Player {
    constructor(x, y) {
        super(x, y);
        this.w = 28; this.h = 70;
        this.targetPlayer = null;
        this.baseXOffset = -400; 
    }

    update(platforms, obstacles, collectibles, particles, sounds, game) {
        if(!this.targetPlayer) return;
        
        this.vx = this.targetPlayer.vx * CONFIG.PURSUER_SPEED_MULT;
        if(this.targetPlayer.state === 'DEAD') this.vx = 0;
        
        let targetX = this.targetPlayer.x + this.baseXOffset;
        
        if(this.targetPlayer.state === 'STUNNED') {
            this.baseXOffset += 2;
        } else {
            this.baseXOffset += 0.5;
        }
        
        if(this.baseXOffset < -600) this.baseXOffset = -600;
        
        if(this.baseXOffset >= -CONFIG.PURSUER_CATCH_DIST && this.targetPlayer.state !== 'DEAD') {
            this.targetPlayer.die(particles, sounds, game);
        }

        this.x = targetX;
        
        let targetY = this.targetPlayer.y;
        this.y = UTILS.lerp(this.y, targetY, 0.1);
        
        if(this.targetPlayer.state !== 'STUNNED' && this.targetPlayer.state !== 'DEAD') {
            this.state = this.targetPlayer.state;
        } else {
            this.state = 'RUNNING';
        }
        
        this.animTimer += 0.2 + (this.vx * 0.05);
    }

    draw(ctx, camX) {
        ctx.save();
        const cx = this.x - camX + this.w/2;
        const cy = this.y + this.h/2;
        
        ctx.shadowColor = COLORS.DANGER;
        ctx.shadowBlur = 10;
        
        // Draw pursuer with its own color without mutating globals
        const origPlayer = COLORS.PLAYER;
        COLORS.PLAYER = COLORS.PURSUER;
        this.drawStickFigure(ctx, cx, cy, this.state, this.animTimer);
        COLORS.PLAYER = origPlayer;
        
        ctx.restore();
    }
}

class LevelGenerator {
    constructor() {
        this.platforms = [];
        this.obstacles = [];
        this.collectibles = [];
        this.lastX = -100;
        
        this.addPlatform(this.lastX, CONFIG.GROUND_Y, 2000);
    }
    
    addPlatform(x, y, w) {
        this.platforms.push(new Platform(x, y, w, CONFIG.HEIGHT - y + 100));
        this.lastX = x + w;
    }

    update(camX) {
        this.platforms = this.platforms.filter(p => p.x + p.w > camX - 500);
        this.obstacles = this.obstacles.filter(o => o.x + o.w > camX - 500);
        this.collectibles = this.collectibles.filter(c => c.x + c.w > camX - 500);
        
        while(this.lastX < camX + 2500) {
            let gap = UTILS.randInt(50, 200);
            let nextY = CONFIG.GROUND_Y + UTILS.randInt(-150, 100);
            nextY = UTILS.clamp(nextY, 300, 650);
            let w = UTILS.randInt(300, 1500);
            
            this.addPlatform(this.lastX + gap, nextY, w);
            
            let obsX = this.lastX - w + 200;
            while(obsX < this.lastX - 200) {
                if(Math.random() > 0.5) {
                    let type = UTILS.randInt(0, 2);
                    this.obstacles.push(new Obstacle(obsX, nextY, type));
                    
                    if(Math.random() > 0.5) {
                        this.collectibles.push(new Collectible(obsX + 10, nextY - (type === 1 ? 50 : 150)));
                    }
                } else if(Math.random() > 0.7) {
                    this.collectibles.push(new Collectible(obsX, nextY - 50));
                }
                obsX += UTILS.randInt(300, 600);
            }
        }
        
        this.collectibles.forEach(c => c.update());
    }

    draw(ctx, camX) {
        this.platforms.forEach(p => p.draw(ctx, camX));
        this.obstacles.forEach(o => o.draw(ctx, camX));
        this.collectibles.forEach(c => c.draw(ctx, camX));
    }
}

class UI {
    constructor(game) { this.game = game; }
    
    drawMenu(ctx) {
        ctx.fillStyle = 'rgba(0,0,0,0.7)';
        ctx.fillRect(0, 0, CONFIG.WIDTH, CONFIG.HEIGHT);
        
        ctx.fillStyle = '#fff';
        ctx.textAlign = 'center';
        
        ctx.font = 'bold 80px Arial';
        ctx.shadowColor = COLORS.SUN;
        ctx.shadowBlur = 20;
        ctx.fillText('SHADOW RUNNER', CONFIG.WIDTH/2, CONFIG.HEIGHT/3);
        ctx.shadowBlur = 0;
        
        ctx.font = '24px Arial';
        ctx.fillText('Space/Up/W : Jump & Double Jump', CONFIG.WIDTH/2, CONFIG.HEIGHT/2);
        ctx.fillText('Down/S : Slide', CONFIG.WIDTH/2, CONFIG.HEIGHT/2 + 40);
        ctx.fillText('Tap Upper Half : Jump | Tap Lower Half : Slide', CONFIG.WIDTH/2, CONFIG.HEIGHT/2 + 80);
        
        ctx.globalAlpha = (Math.sin(Date.now() / 200) + 1) / 2;
        ctx.font = 'bold 32px Arial';
        ctx.fillText('PRESS SPACE OR TAP TO START', CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.8);
        ctx.globalAlpha = 1;
    }
    
    drawHUD(ctx, player, pursuer) {
        // Top bar background
        ctx.fillStyle = 'rgba(0,0,0,0.4)';
        ctx.fillRect(0, 0, CONFIG.WIDTH, 55);
        ctx.fillStyle = 'rgba(255,107,61,0.3)';
        ctx.fillRect(0, 54, CONFIG.WIDTH, 1);
        
        // Distance
        ctx.fillStyle = 'rgba(255,255,255,0.6)';
        ctx.textAlign = 'left';
        ctx.font = 'bold 14px Arial';
        ctx.fillText('DISTANCE', 20, 22);
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 22px Arial';
        ctx.fillText(`${Math.floor(player.x / 10)} m`, 20, 44);
        
        // Score
        ctx.fillStyle = 'rgba(255,217,61,0.6)';
        ctx.textAlign = 'center';
        ctx.font = 'bold 14px Arial';
        ctx.fillText('SCORE', CONFIG.WIDTH/2, 22);
        ctx.fillStyle = '#ffd93d';
        ctx.font = 'bold 22px Arial';
        ctx.fillText(`${Math.floor(player.score)}`, CONFIG.WIDTH/2, 44);
        
        // Speed bar
        ctx.fillStyle = 'rgba(255,255,255,0.6)';
        ctx.textAlign = 'right';
        ctx.font = 'bold 14px Arial';
        ctx.fillText('SPEED', CONFIG.WIDTH - 20, 22);
        ctx.fillStyle = 'rgba(255,255,255,0.15)';
        ctx.fillRect(CONFIG.WIDTH - 170, 32, 150, 8);
        const speedPct = UTILS.clamp(player.vx / CONFIG.MAX_SPEED, 0, 1);
        ctx.fillStyle = speedPct > 0.8 ? '#ff4444' : speedPct > 0.5 ? '#ff6b3d' : '#44ff44';
        ctx.fillRect(CONFIG.WIDTH - 170, 32, 150 * speedPct, 8);
        
        if(pursuer) {
            const dist = Math.abs(pursuer.baseXOffset);
            if(dist < 300) {
                const intensity = 1 - (dist / 300);
                ctx.fillStyle = `rgba(255, 0, 0, ${intensity * 0.15 * (Math.sin(Date.now()/50)+1)/2})`;
                ctx.fillRect(0, 0, CONFIG.WIDTH, CONFIG.HEIGHT);
                
                ctx.fillStyle = `rgba(255, 50, 50, ${0.5 + Math.sin(Date.now()/100) * 0.3})`;
                ctx.textAlign = 'center';
                ctx.font = 'bold 18px Arial';
                ctx.fillText('\u26A0 PURSUER CLOSING IN \u26A0', CONFIG.WIDTH/2, 80);
            }
        }
    }
    
    drawGameOver(ctx, player) {
        ctx.fillStyle = 'rgba(5, 2, 10, 0.85)';
        ctx.fillRect(0, 0, CONFIG.WIDTH, CONFIG.HEIGHT);
        
        // Title
        ctx.save();
        ctx.shadowColor = '#ff0000';
        ctx.shadowBlur = 20;
        ctx.fillStyle = '#ff4444';
        ctx.textAlign = 'center';
        ctx.font = 'bold 72px Arial';
        ctx.fillText('CAUGHT', CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.3);
        ctx.restore();
        
        ctx.fillStyle = 'rgba(255,255,255,0.5)';
        ctx.font = '20px Arial';
        ctx.fillText("You couldn't outrun the system", CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.3 + 40);
        
        // Stats
        ctx.fillStyle = 'rgba(255,255,255,0.5)';
        ctx.font = '16px Arial';
        ctx.fillText('DISTANCE', CONFIG.WIDTH/2 - 120, CONFIG.HEIGHT * 0.5);
        ctx.fillText('SCORE', CONFIG.WIDTH/2 + 120, CONFIG.HEIGHT * 0.5);
        
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 36px Arial';
        ctx.fillText(`${Math.floor(player.x / 10)} m`, CONFIG.WIDTH/2 - 120, CONFIG.HEIGHT * 0.5 + 40);
        ctx.fillStyle = '#ffd93d';
        ctx.fillText(`${Math.floor(player.score)}`, CONFIG.WIDTH/2 + 120, CONFIG.HEIGHT * 0.5 + 40);
        
        // Total
        ctx.fillStyle = 'rgba(255,159,67,0.6)';
        ctx.font = '14px Arial';
        ctx.fillText('TOTAL', CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.65);
        ctx.fillStyle = '#ff6b3d';
        ctx.font = 'bold 28px Arial';
        ctx.fillText(`${Math.floor(player.x / 10) + Math.floor(player.score)}`, CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.65 + 30);
        
        // Restart prompt
        ctx.globalAlpha = 0.4 + Math.sin(Date.now() / 300) * 0.4;
        ctx.fillStyle = '#ff6b3d';
        ctx.font = 'bold 22px Arial';
        ctx.fillText('PRESS SPACE OR TAP TO RUN AGAIN', CONFIG.WIDTH/2, CONFIG.HEIGHT * 0.85);
        ctx.globalAlpha = 1;
    }
    
    drawPause(ctx) {
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        ctx.fillRect(0, 0, CONFIG.WIDTH, CONFIG.HEIGHT);
        ctx.fillStyle = '#fff';
        ctx.textAlign = 'center';
        ctx.font = 'bold 60px Arial';
        ctx.fillText('PAUSED', CONFIG.WIDTH/2, CONFIG.HEIGHT/2);
    }
}

class Game {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.state = 'MENU'; 
        
        this.sounds = new SoundManager();
        this.ui = new UI(this);
        this.camX = 0;
        this.screenShake = 0;
        
        this.keys = {};
        this.bindEvents();
    }
    
    init() {
        this.bg = new Background();
        this.particles = new ParticleSystem();
        this.level = new LevelGenerator();
        this.player = new Player(CONFIG.SPAWN_X, CONFIG.GROUND_Y - 100);
        this.pursuer = new Pursuer(CONFIG.SPAWN_X - 400, CONFIG.GROUND_Y - 100);
        this.pursuer.targetPlayer = this.player;
        this.camX = this.player.x - 300;
        
        if(!this.running) {
            this.running = true;
            requestAnimationFrame((t) => this.loop(t));
        }
    }
    
    bindEvents() {
        window.addEventListener('keydown', e => {
            this.keys[e.code] = true;
            this.handleInput(e.code, true);
        });
        window.addEventListener('keyup', e => {
            this.keys[e.code] = false;
        });
        
        const touchHandler = (e) => {
            e.preventDefault();
            const rect = this.canvas.getBoundingClientRect();
            const touch = e.touches[0];
            if(!touch) return;
            const y = touch.clientY - rect.top;
            if(this.state === 'MENU' || this.state === 'GAMEOVER') {
                this.handleInput('Space', true);
            } else if(this.state === 'PLAYING') {
                if(y < rect.height / 2) this.player.jump(this.sounds);
                else this.player.slide(this.sounds);
            }
        };
        this.canvas.addEventListener('touchstart', touchHandler, {passive: false});
    }
    
    handleInput(code, isDown) {
        if(!isDown) return;
        
        if(code === 'Escape') {
            if(this.state === 'PLAYING') this.setState('PAUSED');
            else if(this.state === 'PAUSED') this.setState('PLAYING');
            return;
        }
        
        if(this.state === 'MENU') {
            if(code === 'Space' || code === 'Enter') {
                this.sounds.menuSelect();
                if(this.sounds.ctx && this.sounds.ctx.state === 'suspended') this.sounds.ctx.resume();
                this.init();
                this.setState('PLAYING');
            }
        } else if(this.state === 'GAMEOVER') {
            if(code === 'Space' || code === 'Enter') {
                this.sounds.menuSelect();
                this.init();
                this.setState('PLAYING');
            }
        } else if(this.state === 'PLAYING') {
            if(code === 'Space' || code === 'ArrowUp' || code === 'KeyW') {
                this.player.jump(this.sounds);
            }
            if(code === 'ArrowDown' || code === 'KeyS') {
                this.player.slide(this.sounds);
            }
        }
    }
    
    setState(newState) {
        this.state = newState;
    }
    
    update() {
        if(this.state !== 'PLAYING') return;
        
        if(this.keys['ArrowDown'] || this.keys['KeyS']) {
            this.player.slide(this.sounds);
        }

        this.player.update(this.level.platforms, this.level.obstacles, this.level.collectibles, this.particles, this.sounds, this);
        this.pursuer.update(this.level.platforms, this.level.obstacles, this.level.collectibles, this.particles, this.sounds, this);
        
        this.bg.update(this.camX);
        this.level.update(this.camX);
        this.particles.update();
        
        if(this.player.vx > CONFIG.MAX_SPEED * 0.9 && Math.random() > 0.5) {
            this.particles.speedLines(this.camX + CONFIG.WIDTH, 0, 0, CONFIG.HEIGHT);
        }
        
        const targetCamX = this.player.x - 300;
        this.camX = UTILS.lerp(this.camX, targetCamX, 0.1);
        
        if(this.screenShake > 0) this.screenShake--;
    }
    
    draw() {
        this.ctx.clearRect(0, 0, CONFIG.WIDTH, CONFIG.HEIGHT);
        
        this.ctx.save();
        
        if(this.screenShake > 0) {
            const dx = UTILS.rand(-this.screenShake, this.screenShake);
            const dy = UTILS.rand(-this.screenShake, this.screenShake);
            this.ctx.translate(dx, dy);
        }
        
        this.bg.draw(this.ctx, this.camX, CONFIG.WIDTH, CONFIG.HEIGHT);
        this.level.draw(this.ctx, this.camX);
        this.pursuer.draw(this.ctx, this.camX);
        this.player.draw(this.ctx, this.camX);
        this.particles.draw(this.ctx, this.camX);
        
        this.ctx.restore();
        
        if(this.state === 'MENU') this.ui.drawMenu(this.ctx);
        else if(this.state === 'PLAYING') this.ui.drawHUD(this.ctx, this.player, this.pursuer);
        else if(this.state === 'GAMEOVER') {
            this.ui.drawHUD(this.ctx, this.player, null);
            this.ui.drawGameOver(this.ctx, this.player);
        }
        else if(this.state === 'PAUSED') this.ui.drawPause(this.ctx);
    }
    
    loop(timestamp) {
        this.update();
        this.draw();
        requestAnimationFrame((t) => this.loop(t));
    }
}
