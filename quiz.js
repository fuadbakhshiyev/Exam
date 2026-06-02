const QuizApp = {
    state: { course: null, category: null, currentTitle: null, questions: [], index: 0, answers: {}, correct: 0, wrong: 0, view: 'quiz', sessionStartTime: 0, isWrongMode: false, isSearchMode: false, isMockMode: false, isFlashcard: false },
    DB: { stats: 'qa_v31_s', wrong: 'qa_v31_w', correct: 'qa_v31_c', marks: 'qa_v31_m', daily: 'qa_v31_d', settings: 'qa_v31_conf' },
    MOCK_KEY: "🎲 Ümumi Sınaq",

    stats: {},
    wrongDB: {},
    correctDB: {},
    bookmarks: [],
    settings: { scale: 1 },
    timer: null,
    activeCourse: null,
    synth: window.speechSynthesis,

    init: function () {
        this.loadData();
    },

    loadData: function () {
        this.stats = JSON.parse(localStorage.getItem(this.DB.stats)) || {};
        this.wrongDB = JSON.parse(localStorage.getItem(this.DB.wrong)) || {};
        this.correctDB = JSON.parse(localStorage.getItem(this.DB.correct)) || {};
        this.bookmarks = JSON.parse(localStorage.getItem(this.DB.marks)) || [];
        this.settings = JSON.parse(localStorage.getItem(this.DB.settings)) || { scale: 1 };
        this.applyTheme();
    },

    start: function () {
        const container = document.getElementById('content-area');
        if (!container) return;

        // Custom config for beautiful course cards
        const courseStyles = {
            "Atatürk İlkeleri ve İnkılap Tarihi II": { icon: "🏛️", accent: "#ef4444", accentBorder: "rgba(239, 68, 68, 0.15)" },
            "Görsel İletişim Tasarımı": { icon: "🎨", accent: "#6366f1", accentBorder: "rgba(99, 102, 241, 0.15)" },
            "Grafik Tasarım II": { icon: "📐", accent: "#10b981", accentBorder: "rgba(16, 185, 129, 0.15)" },
            "Masaüstü Yayıncılık": { icon: "💻", accent: "#3b82f6", accentBorder: "rgba(59, 130, 246, 0.15)" },
            "Tasarımda Tipografi": { icon: "✍️", accent: "#f59e0b", accentBorder: "rgba(245, 158, 11, 0.15)" },
            "Türk Dili II": { icon: "📖", accent: "#8b5cf6", accentBorder: "rgba(139, 92, 246, 0.15)" }
        };

        const defaultStyle = { icon: "📘", accent: "#6366f1", accentBorder: "rgba(99, 102, 241, 0.15)" };

        let cardsHTML = "";
        Object.keys(CONFIG).forEach(c => {
            const style = courseStyles[c] || defaultStyle;
            let questionCount = 0;
            if (typeof quizData !== 'undefined') {
                questionCount = quizData.filter(q => q.c === c).length;
            }

            cardsHTML += `
                <div class="subject-card" style="--card-accent: ${style.accent}; --card-accent-border: ${style.accentBorder};" onclick="QuizApp.selectCat('${c.replace(/'/g, "\\'")}', 'units')">
                    <div class="subject-icon">${style.icon}</div>
                    <div class="subject-title">${c}</div>
                    <div class="subject-meta">
                        <div>Sual: <span>${questionCount}</span></div>
                        <div class="subject-action">Başla →</div>
                    </div>
                </div>
            `;
        });

        let globalTime = 0;
        let globalCorrect = 0;
        let globalWrong = 0;
        let globalTotalAns = 0;

        Object.values(this.stats).forEach(s => {
            if (s.time) globalTime += s.time;
            if (s.c) globalCorrect += s.c;
            if (s.w) globalWrong += s.w;
            if (s.t) globalTotalAns += s.t;
        });

        let globalAcc = 0;
        if (globalTotalAns > 0) globalAcc = Math.round((globalCorrect / globalTotalAns) * 100);
        let globalTotalQ = typeof quizData !== 'undefined' ? quizData.length : 0;

        const unanswered = Math.max(0, globalTotalQ - globalTotalAns);

        container.innerHTML = `
            <div class="dashboard">
                <div class="dashboard-header">
                    <h1>Xoş gəldiniz, Fuad!</h1>
                    <p>Hazırlaşmaq istədiyiniz fənni seçərək imtahan testlərinə başlayın.</p>
                </div>

                <div class="home-analytics-panel">

                    <div class="hap-donut-section">
                        <div class="hap-section-label">Ümumi Performans</div>
                        <div class="hap-donut-ring-wrap">
                            <canvas id="home-donut-canvas" width="220" height="220"></canvas>
                            <div class="hap-donut-inner">
                                <div class="hap-donut-big">${globalAcc}<span class="hap-pct-sign">%</span></div>
                                <div class="hap-donut-label">Dəqiqlik</div>
                            </div>
                        </div>
                        <div class="hap-legend">
                            <div class="hap-legend-badge" style="background:#22c55e18; border-color:#22c55e40;">
                                <span class="hap-lc-dot" style="background:#22c55e; box-shadow:0 0 6px #22c55e80;"></span>
                                <span class="hap-lc-lbl">Düzgün</span>
                                <span class="hap-lc-num" style="color:#22c55e;">${globalCorrect}</span>
                            </div>
                            <div class="hap-legend-badge" style="background:#ef444418; border-color:#ef444440;">
                                <span class="hap-lc-dot" style="background:#ef4444; box-shadow:0 0 6px #ef444460;"></span>
                                <span class="hap-lc-lbl">Səhv</span>
                                <span class="hap-lc-num" style="color:#ef4444;">${globalWrong}</span>
                            </div>
                            <div class="hap-legend-badge" style="background:#ffffff08; border-color:#ffffff15;">
                                <span class="hap-lc-dot" style="background:#ffffff30;"></span>
                                <span class="hap-lc-lbl">Qalıb</span>
                                <span class="hap-lc-num" style="color:var(--text-muted);">${unanswered}</span>
                            </div>
                        </div>
                    </div>

                    <div class="hap-courses-section">
                        <div class="hap-section-label">Fənn Üzrə İrəliləyiş</div>
                        <div class="hap-course-list" id="home-progress-list"></div>
                    </div>

                </div>

                <div class="dashboard-stats-grid" style="margin-bottom: 30px; grid-template-columns: repeat(5, 1fr);">
                    <div class="db-stat-card">
                        <div class="db-stat-lbl">Cəmi Sual</div>
                        <div class="db-stat-val">${globalTotalQ}</div>
                    </div>
                    <div class="db-stat-card">
                        <div class="db-stat-lbl">Sərf Edilən Vaxt</div>
                        <div class="db-stat-val">${this.formatTime(globalTime)}</div>
                    </div>
                    <div class="db-stat-card">
                        <div class="db-stat-lbl">Düzgün Cavab</div>
                        <div class="db-stat-val" style="color:var(--active)">${globalCorrect}</div>
                    </div>
                    <div class="db-stat-card">
                        <div class="db-stat-lbl">Səhv Cavab</div>
                        <div class="db-stat-val" style="color:var(--wrong)">${globalWrong}</div>
                    </div>
                    <div class="db-stat-card">
                        <div class="db-stat-lbl">Dəqiqlik</div>
                        <div class="db-stat-val" style="color:var(--accent)">${globalAcc}%</div>
                    </div>
                </div>

                <div class="subject-grid">
                    ${cardsHTML}
                </div>
            </div>
        `;

        this.renderHomeCharts(globalCorrect, globalWrong, unanswered);

        // Hide top nav since we are in home screen
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        // Manage sidebar active states
        const homeBtn = document.getElementById('btn-home');
        if (homeBtn) {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            homeBtn.classList.add('active');
        }
    },

    renderHomeCharts: function (correct, wrong, unanswered) {
        const courseStyles = {
            "Atatürk İlkeleri ve İnkılap Tarihi II": { accent: "#ef4444", g1: "#ef4444", g2: "#f97316" },
            "Görsel İletişim Tasarımı": { accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" },
            "Grafik Tasarım II": { accent: "#10b981", g1: "#10b981", g2: "#06b6d4" },
            "Masaüstü Yayıncılık": { accent: "#3b82f6", g1: "#3b82f6", g2: "#6366f1" },
            "Tasarımda Tipografi": { accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444" },
            "Türk Dili II": { accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899" }
        };

        // --- Animated Donut Chart ---
        const canvas = document.getElementById('home-donut-canvas');
        if (canvas) {
            const ctx = canvas.getContext('2d');
            const dpr = window.devicePixelRatio || 1;
            canvas.width = 220 * dpr; canvas.height = 220 * dpr;
            canvas.style.width = '220px'; canvas.style.height = '220px';
            ctx.scale(dpr, dpr);

            const cx = 110, cy = 110, r = 88, strokeW = 18;
            const total = correct + wrong + unanswered;

            const segments = total === 0
                ? [{ val: 1, color: '#2a2a3e', glow: false }]
                : [
                    { val: correct, color: '#22c55e', glow: true },
                    { val: wrong, color: '#ef4444', glow: false },
                    { val: unanswered, color: '#ffffff14', glow: false }
                  ].filter(s => s.val > 0);

            const totalVal = segments.reduce((a, s) => a + s.val, 0);
            const GAP = 0.04;

            // Background ring
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.strokeStyle = '#ffffff08';
            ctx.lineWidth = strokeW;
            ctx.stroke();

            // Animate draw
            let progress = 0;
            const animDuration = 1000;
            const startTime = performance.now();

            const draw = (now) => {
                progress = Math.min((now - startTime) / animDuration, 1);
                const ease = 1 - Math.pow(1 - progress, 3);
                ctx.clearRect(0, 0, 220, 220);

                // Background ring
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = '#ffffff08';
                ctx.lineWidth = strokeW;
                ctx.stroke();

                let startAngle = -Math.PI / 2;
                segments.forEach(seg => {
                    const fullSweep = (seg.val / totalVal) * (2 * Math.PI) - GAP;
                    const sweep = fullSweep * ease;
                    if (sweep <= 0) return;

                    if (seg.glow) {
                        ctx.shadowColor = seg.color;
                        ctx.shadowBlur = 18;
                    } else {
                        ctx.shadowBlur = 0;
                    }

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + sweep);
                    ctx.strokeStyle = seg.color;
                    ctx.lineWidth = strokeW;
                    ctx.lineCap = 'round';
                    ctx.stroke();
                    ctx.shadowBlur = 0;

                    startAngle += fullSweep + GAP;
                });

                if (progress < 1) requestAnimationFrame(draw);
            };
            requestAnimationFrame(draw);
        }

        // --- Course Progress Rows ---
        const list = document.getElementById('home-progress-list');
        if (!list) return;
        list.innerHTML = '';

        Object.keys(CONFIG).forEach((c, idx) => {
            const s = this.stats[c];
            const style = courseStyles[c] || { accent: '#6366f1', g1: '#6366f1', g2: '#8b5cf6' };
            let totalQ = 0;
            if (typeof quizData !== 'undefined') totalQ = quizData.filter(q => q.c === c).length;

            const answered = s ? (s.t || 0) : 0;
            const correctC = s ? (s.c || 0) : 0;
            const wrongC = s ? (s.w || 0) : 0;
            const pctProgress = totalQ > 0 ? (answered / totalQ) * 100 : 0;
            const pctCorrect = answered > 0 ? Math.round((correctC / answered) * 100) : 0;

            const row = document.createElement('div');
            row.className = 'hap-course-row';
            row.style.setProperty('--c-accent', style.accent);
            row.style.setProperty('--c-g1', style.g1);
            row.style.setProperty('--c-g2', style.g2);
            row.innerHTML = `
                <div class="hap-course-left">
                    <div class="hap-course-dot" style="background: linear-gradient(135deg, ${style.g1}, ${style.g2});"></div>
                    <div class="hap-course-info">
                        <div class="hap-course-name">${c}</div>
                        <div class="hap-course-track">
                            <div class="hap-course-bar" data-pct="${pctProgress}" style="background: linear-gradient(90deg, ${style.g1}, ${style.g2});"></div>
                        </div>
                    </div>
                </div>
                <div class="hap-course-stats">
                    <div class="hap-mini-stat" style="color:#22c55e">${correctC}</div>
                    <div class="hap-mini-stat" style="color:#ef4444">${wrongC}</div>
                    <div class="hap-mini-badge" style="background: ${style.accent}22; color: ${style.accent}">${pctCorrect}%</div>
                </div>
            `;
            list.appendChild(row);

            setTimeout(() => {
                const bar = row.querySelector('.hap-course-bar');
                if (bar) bar.style.width = Math.min(pctProgress, 100) + '%';
            }, 80 + idx * 60);
        });
    },

    selectCat: function (c, type, btn) {
        this.state = { ...this.state, view: 'dashboard', course: c, category: type, isWrongMode: false, isSearchMode: false, isMockMode: false };

        document.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active-sub'));
        if (btn) btn.classList.add('active-sub');

        this.showCourseDashboard(c);
        if (window.innerWidth <= 768) toggleSidebar();
    },

    showCourseDashboard: function (c) {
        this.stopTimer();
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        loadTemplate('course-dashboard-template');

        // Course Title
        const titleEl = document.getElementById('db-course-title');
        if (titleEl) titleEl.textContent = c;

        // Statistics
        const s = this.stats[c] || { t: 0, c: 0, w: 0, time: 0, bd: {} };
        
        // Total questions in this course
        let totalQ = 0;
        if (typeof quizData !== 'undefined') {
            totalQ = quizData.filter(q => q.c === c).length;
        }

        document.getElementById('db-total-questions').textContent = totalQ;
        document.getElementById('db-total-time').textContent = this.formatTime(s.time);
        
        const correctVal = document.getElementById('db-total-correct');
        const wrongVal = document.getElementById('db-total-wrong');
        correctVal.textContent = s.c;
        wrongVal.textContent = s.w;

        let acc = 0;
        if (s.t > 0) acc = Math.round((s.c / s.t) * 100);
        const accVal = document.getElementById('db-accuracy');
        if (accVal) accVal.textContent = acc + '%';

        const correctCard = correctVal.parentElement;
        const wrongCard = wrongVal.parentElement;
        
        correctCard.style.cursor = 'pointer';
        correctCard.title = 'Doğru cavablandırdığınız suallara baxmaq üçün klikləyin';
        correctCard.onclick = () => {
            const arr = this.correctDB[c] || [];
            if(arr.length) this.startSpecial(arr, "Doğrular", c);
            else alert("Doğru cavablandırdığınız sual hələ ki yoxdur və ya əvvəllər yaddaşda saxlanılmayıb.");
        };

        wrongCard.style.cursor = 'pointer';
        wrongCard.title = 'Səhv cavablandırdığınız suallara baxmaq üçün klikləyin';
        wrongCard.onclick = () => {
            const arr = this.wrongDB[c] || [];
            if(arr.length) this.startSpecial(arr, "Səhvlər", c);
            else alert("Əla! Səhv cavablandırdığınız sual yoxdur.");
        };

        // AI Recommendation
        const recTextEl = document.getElementById('db-recommendation-text');
        if (recTextEl) {
            let rec = "";
            const totalAnswered = s.t;
            if (totalAnswered === 0) {
                rec = "Bu fənn üzrə hələ heç bir sual cavablandırmamısınız. Öyrənməyə və özünüzü sınamağa başlamaq üçün aşağıdakı bölmələrdən birini seçib 'Başla' düyməsinə klikləyin!";
            } else {
                const percent = Math.round((s.c / s.t) * 100);
                if (percent >= 80) {
                    rec = `Mükəmməl göstərici! Bu fənn üzrə cavablarınızın ${percent}%-i doğrudur. Biliklərinizi daha da möhkəmləndirmək üçün sol menyudakı <b>Böyük Sınaq</b> rejimi ilə özünüzü sınaqdan keçirə bilərsiniz.`;
                } else if (percent >= 50) {
                    rec = `Göstəriciniz yaxşıdır (${percent}% doğru). Səhv etdiyiniz sualları yenidən nəzərdən keçirmək üçün sol menyudan <b>Səhvlərim</b> bölməsinə daxil olmanızı və zəif olduğunuz bölmələri yenidən təkrarlamanızı tövsiyə edirik.`;
                } else {
                    rec = `Bu fənn üzrə çətinlik çəkdiyiniz görünür (doğru cavab: ${percent}%). Sualları daha diqqətlə oxumağı, hər bir bölməni (Unit) ayrıca olaraq təkrar-təkrar işləməyi və çətin sualları <b>Seçilmişlər</b> (Bookmark) siyahısına əlavə edərək təkrar etməyi tövsiyə edirik.`;
                }
            }
            recTextEl.innerHTML = rec;
        }

        // Render Units List
        const listEl = document.getElementById('db-unit-list');
        if (listEl && CONFIG[c]) {
            listEl.innerHTML = "";
            CONFIG[c].units.forEach((unitName, i) => {
                const unitIdx = i + 1;
                let totalUnitQ = 0;
                if (typeof quizData !== 'undefined') {
                    totalUnitQ = quizData.filter(q => q.c === c && q.u === unitIdx).length;
                }

                const unitKey = `Unit ${unitIdx}`;
                let c_correct = 0;
                let c_wrong = 0;

                if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                    const us = s.bd['units'][unitKey];
                    c_correct = us.c;
                    c_wrong = us.w;
                }

                const item = document.createElement('div');
                item.className = 'unit-item';
                item.innerHTML = `
                    <div class="unit-item-header">
                        <div class="unit-item-title">${unitName}</div>
                        <button class="unit-btn-start" onclick="QuizApp.startUnit('${c.replace(/'/g, "\\'")}', ${i})">Başla</button>
                    </div>
                    <div class="unit-item-stats-grid">
                        <div class="unit-stat-box">
                            <span class="us-val">${totalUnitQ}</span>
                            <span class="us-lbl">CƏMİ SUAL</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--correct)">${c_correct}</span>
                            <span class="us-lbl">DOĞRU</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--wrong)">${c_wrong}</span>
                            <span class="us-lbl">YANLIŞ</span>
                        </div>
                    </div>
                `;
                listEl.appendChild(item);
            });
        }
    },

    startUnit: function (c, idx) {
        this.state = { ...this.state, view: 'quiz', course: c, category: 'units', isWrongMode: false, isSearchMode: false, isMockMode: false };
        
        loadTemplate('quiz-template');
        this.renderTopNav();
        this.loadContent(idx);
        this.startTimer(c);
    },

    renderTopNav: function () {
        const nav = document.getElementById('top-nav');
        if (!nav) return;
        nav.innerHTML = "";
        nav.style.display = 'flex';
        let items = this.getCategoryData();

        if (!items || items.length === 0) {
            nav.innerHTML = "<span style='padding:10px; color:var(--text-muted); font-size:0.9rem;'>Məlumat yoxdur</span>";
            return;
        }

        items.forEach((t, i) => {
            const p = document.createElement('button'); p.className = 'nav-pill';
            p.textContent = this.state.category === 'units' ? `Unit ${i + 1}` : t;
            p.onclick = () => QuizApp.loadContent(i);
            nav.appendChild(p);
        });
    },

    loadContent: function (idx) {
        this.state.selectionIndex = idx; this.state.index = 0; this.state.answers = {}; this.state.correct = 0; this.state.wrong = 0;
        let items = this.getCategoryData();
        this.state.currentTitle = items[idx];

        document.querySelectorAll('.nav-pill').forEach((p, i) => p.classList.toggle('active', i === idx));

        const titleUnit = document.getElementById('title-unit');
        if (titleUnit) titleUnit.textContent = this.state.currentTitle || "Seçim Yoxdur";

        const courseNameSm = document.getElementById('course-name-sm');
        if (courseNameSm) courseNameSm.textContent = this.state.course;

        if (typeof quizData !== 'undefined' && this.state.currentTitle) {
            let f = [];
            if (this.state.category === 'units') f = quizData.filter(q => q.c === this.state.course && q.u === (idx + 1));
            else if (this.state.category === 'mixed') f = quizData.filter(q => q.c === this.state.course && q.m === this.state.currentTitle);
            else f = quizData.filter(q => q.c === this.state.course && q.e === this.state.currentTitle);

            this.state.questions = shuffle([...f]);
            this.state.questions.forEach(q => { q.shuffledOpts = shuffle(q.o.map((txt, i) => ({ txt, i }))); });
        } else this.state.questions = [];

        this.renderQ();
    },

    renderQ: function () {
        if (this.synth.speaking) this.synth.cancel();
        const total = this.state.questions.length;
        const qTextEl = document.getElementById('q-text');
        if (!qTextEl) return;

        if (total === 0) { qTextEl.textContent = "Sual tapılmadı"; return; }

        const q = this.state.questions[this.state.index];
        const ans = this.state.answers[this.state.index];

        const sNav = document.getElementById('subject-nav');
        if (this.state.isMockMode) {
            sNav.style.display = 'flex'; sNav.innerHTML = "";
            [...new Set(this.state.questions.map(x => x.c))].forEach(s => {
                const b = document.createElement('button'); b.className = `nav-pill ${s === q.c ? 'active' : ''}`;
                b.textContent = s; b.onclick = () => { QuizApp.state.index = QuizApp.state.questions.findIndex(x => x.c === s); QuizApp.renderQ(); };
                sNav.appendChild(b);
            });
        } else {
            if (sNav) sNav.style.display = 'none';
        }

        if (this.state.isMockMode || this.state.isSearchMode || this.state.isWrongMode) {
            const tn = document.getElementById('top-nav');
            if (tn) tn.style.display = 'none';
        }

        const pBar = document.getElementById('progress-bar');
        pBar.innerHTML = "";
        if (total <= 40) {
            for (let i = 0; i < total; i++) {
                const s = document.createElement('div');
                s.className = 'progress-segment ' + (i === this.state.index ? 'active' : '') + (this.state.answers[i] ? (this.state.answers[i].chosen === this.state.questions[i].a ? ' correct' : ' done') : '');
                if (this.state.answers[i] && this.state.answers[i].chosen !== this.state.questions[i].a) s.classList.add('wrong');
                s.onclick = () => { QuizApp.state.index = i; QuizApp.renderQ(); }; pBar.appendChild(s);
            }
        }

        qTextEl.innerHTML = `${this.state.index + 1}. ${q.q}`;

        const btnStar = document.getElementById('btn-star');
        if (btnStar) btnStar.classList.toggle('active', this.bookmarks.some(b => b.q === q.q));

        const btnFlash = document.getElementById('btn-flash');
        if (btnFlash) btnFlash.classList.toggle('active', this.state.isFlashcard);

        const scCorrect = document.getElementById('score-correct-disp');
        if (scCorrect) scCorrect.textContent = this.state.correct;

        const scWrong = document.getElementById('score-wrong-disp');
        if (scWrong) scWrong.textContent = this.state.wrong;

        const list = document.getElementById('opt-list'); list.innerHTML = "";
        const cover = document.getElementById('flashcard-cover');

        if (this.state.isFlashcard && !ans) { cover.style.display = 'block'; list.style.display = 'none'; }
        else { cover.style.display = 'none'; list.style.display = 'block'; }

        q.shuffledOpts.forEach((o, i) => {
            const abc = ['A', 'B', 'C', 'D', 'E'][i];
            const div = document.createElement('div'); div.className = 'option';
            div.innerHTML = `<div class="option-letter">${abc}</div>${o.txt}`;
            if (ans) {
                if (o.i === q.a) div.classList.add('correct');
                else if (o.i === ans.chosen) div.classList.add('wrong');
            } else { div.onclick = () => QuizApp.checkAnswer(o.i); }
            list.appendChild(div);
        });

        const btnNext = document.getElementById('btn-next');
        if (this.state.index === total - 1) { btnNext.textContent = "Bitir"; btnNext.onclick = () => QuizApp.finishTest(); }
        else { btnNext.textContent = "Növbəti"; btnNext.onclick = () => QuizApp.nav(1); }

        const btnHint = document.getElementById('btn-hint');
        if (btnHint) btnHint.disabled = !!ans;
    },

    checkAnswer: function (i) {
        if (this.state.answers[this.state.index]) return;
        const q = this.state.questions[this.state.index];
        const isCorrect = i === q.a;
        this.state.answers[this.state.index] = { chosen: i };

        if (isCorrect) { this.state.correct++; this.saveCorrect(this.state.course, q); if (this.state.isWrongMode) this.removeWrong(this.state.course, q.q); }
        else { this.state.wrong++; this.saveWrong(this.state.course, q); this.removeCorrect(this.state.course, q.q); }

        if (this.state.isMockMode) this.recordStat(this.MOCK_KEY, "mock", `Sınaq`, isCorrect);
        else if (this.state.course && !this.state.isSearchMode && !this.state.isWrongMode) {
            let sub = this.state.currentTitle; if (this.state.category === 'units') sub = `Unit ${this.state.selectionIndex + 1}`;
            this.recordStat(this.state.course, this.state.category, sub, isCorrect);
        }
        updateDaily(true); this.renderQ();
    },

    startMock: function () {
        if (typeof quizData === 'undefined') return;
        let pool = [];
        Object.keys(CONFIG).forEach(c => {
            const qs = quizData.filter(q => q.c === c);
            if (qs.length) pool = pool.concat(shuffle(qs).slice(0, 20));
        });
        this.startSpecial(pool, this.MOCK_KEY, "Real Sınaq Rejimi");
        this.state.isMockMode = true; this.state.course = this.MOCK_KEY; this.startTimer(this.MOCK_KEY);
    },

    startHard: function () {
        let pool = []; Object.keys(this.wrongDB).forEach(k => pool = pool.concat(this.wrongDB[k]));
        if (!pool.length) return alert("Səhv yoxdur!");
        this.startSpecial(shuffle(pool).slice(0, 20), "💀 Ən Çətinlər", "Səhvlər Təkrarı");
        this.state.isWrongMode = true; this.state.course = "Hard";
    },

    handleSearch: function (e) {
        if (e.key === 'Enter') {
            const v = e.target.value.toLowerCase();
            const res = quizData.filter(q => q.q.toLowerCase().includes(v) || q.o.some(o => o.toLowerCase().includes(v)));
            if (!res.length) return alert("Tapılmadı");
            this.startSpecial(res, "Axtarış", `"${v}"`);
            this.state.isSearchMode = true;
        }
    },

    startSpecial: function (qs, t, s) {
        this.stopTimer(); this.state.view = 'quiz'; this.state.questions = [...qs];
        this.state.questions.forEach(q => { q.shuffledOpts = shuffle(q.o.map((txt, i) => ({ txt, i }))); });
        this.state.index = 0; this.state.answers = {}; this.state.correct = 0; this.state.wrong = 0; this.state.isMockMode = false; this.state.isWrongMode = false; this.state.isSearchMode = false;
        loadTemplate('quiz-template');

        document.getElementById('title-unit').textContent = t;
        document.getElementById('course-name-sm').textContent = s;

        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        this.renderQ();
    },

    showStats: function () {
        this.stopTimer();
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        loadTemplate('stats-template');

        let gt = 0, gc = 0, gw = 0, tm = 0;
        const tb = document.getElementById('stat-table-body'); tb.innerHTML = "";

        [...Object.keys(CONFIG), this.MOCK_KEY].forEach(c => {
            const s = this.stats[c]; if (s && s.t > 0) {
                gt += s.t; gc += s.c; gw += s.w; tm += s.time;
                const row = document.createElement('tr');
                row.onclick = () => this.showStatDetailsModal(c);
                row.innerHTML = `<td>${c}</td><td>${this.formatTime(s.time)}</td><td>${s.t}</td><td>${s.c}/${s.w}</td><td>${Math.round((s.c / s.t) * 100)}%</td>`;
                tb.appendChild(row);
            }
        });
        document.getElementById('st-total').textContent = gt;
        document.getElementById('st-time').textContent = this.formatTime(tm);
        document.getElementById('st-correct').textContent = gc;
        document.getElementById('st-wrong').textContent = gw;
        document.getElementById('st-accuracy').textContent = gt > 0 ? Math.round((gc / gt) * 100) + '%' : '-';
    },

    showStatDetails: function (type) {
        const modal = document.getElementById('modal-overlay');
        const title = document.getElementById('modal-title');
        const body = document.getElementById('modal-body');
        const map = { 'total': 'Sual', 'time': 'Vaxt', 'correct': 'Doğru', 'wrong': 'Yanlış', 'accuracy': 'Dəqiqlik' };
        title.textContent = map[type];
        let html = `<table class="stat-table"><thead><tr><th>Dərs</th><th>Dəyər</th></tr></thead><tbody>`;
        let data = [];
        Object.keys(this.stats).forEach(c => {
            const s = this.stats[c];
            if (s.t > 0) {
                let val = 0, disp = "";
                if (type === 'time') { val = s.time; disp = this.formatTime(s.time); }
                else if (type === 'accuracy') { val = (s.c / s.t); disp = Math.round(val * 100) + "%"; }
                else { val = s[type]; disp = val; }
                data.push({ n: c, v: val, d: disp });
            }
        });
        data.sort((a, b) => b.v - a.v);
        data.forEach(i => html += `<tr><td>${i.n}</td><td><b>${i.d}</b></td></tr>`);
        html += "</tbody></table>";
        body.innerHTML = html;
        modal.style.display = 'flex';
    },

    showStatDetailsModal: function (c) {
        const modal = document.getElementById('modal-overlay');
        document.getElementById('modal-title').textContent = c;
        const s = this.stats[c];
        let h = "";
        if (!s || !s.bd) h = "Məlumat yoxdur";
        else {
            const cats = { 'units': '📘 Dərs', 'exams': '🏛️ Keçmiş', 'mixed': '🔀 Qarışıq', 'mock': '🎲 Sınaq' };
            for (let k in cats) {
                if (s.bd[k]) {
                    h += `<h4 style="margin:15px 0 5px 0; color:var(--active)">${cats[k]}</h4><table class="stat-table">`;
                    Object.keys(s.bd[k]).sort().forEach(i => {
                        const d = s.bd[k][i];
                        h += `<tr><td>${i}</td><td>${d.c} D / ${d.w} Y</td></tr>`;
                    });
                    h += "</table>";
                }
            }
        }
        document.getElementById('modal-body').innerHTML = h;
        modal.style.display = 'flex';
    },

    finishTest: function () {
        this.stopTimer();
        const total = this.state.questions.length;
        let c = 0, w = 0; let subRes = {};
        this.state.questions.forEach((q, i) => {
            if (!subRes[q.c]) subRes[q.c] = { c: 0, w: 0 };
            if (this.state.answers[i]) {
                if (this.state.answers[i].chosen === q.a) { c++; subRes[q.c].c++; } else { w++; subRes[q.c].w++; }
            }
        });
        const net = c - (w / 4);
        const score = Math.max(0, net * 5);
        const pct = (score / (total * 5)) * 100;
        let color = pct >= 90 ? 'var(--active)' : (pct >= 50 ? 'var(--finish)' : 'var(--wrong)');
        if (pct >= 50) fireConfetti();

        const body = document.getElementById('modal-body');
        document.getElementById('modal-title').textContent = "Nəticə";

        let subHTML = `<table class="stat-table" style="margin-top:20px;"><thead><tr><th>Fənn</th><th>D</th><th>Y</th><th>Net</th></tr></thead><tbody>`;
        Object.keys(subRes).forEach(k => {
            subHTML += `<tr><td>${k}</td><td style="color:var(--active)">${subRes[k].c}</td><td style="color:var(--wrong)">${subRes[k].w}</td><td>${(subRes[k].c - subRes[k].w / 4).toFixed(2)}</td></tr>`;
        });
        subHTML += '</tbody></table>';

        body.innerHTML = `
            <div style="text-align:center; padding:10px;">
                <div style="font-size:2.5rem; font-weight:800; color:${color};">${score.toFixed(1)}</div>
                <div style="color:var(--text-muted);">${Math.round(pct)}%</div>
                <div style="display:grid; grid-template-columns:1fr 1fr 1fr; gap:5px; margin-top:15px;">
                    <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="color:var(--active); font-weight:bold;">${c}</div><div style="font-size:0.7rem">D</div></div>
                    <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="color:var(--wrong); font-weight:bold;">${w}</div><div style="font-size:0.7rem">Y</div></div>
                    <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="font-weight:bold;">${net.toFixed(2)}</div><div style="font-size:0.7rem">Net</div></div>
                </div>
                ${this.state.isMockMode ? subHTML : ''}
                <button class="btn btn-pri" style="margin-top:20px; width:100%" onclick="closeModal()">Bağla</button>
            </div>
        `;
        document.getElementById('modal-overlay').style.display = 'flex';
    },

    // Helpers
    nav: function (d) { this.state.index += d; this.renderQ(); },
    resetUnit: function () { this.state.index = 0; this.state.answers = {}; this.state.correct = 0; this.state.wrong = 0; this.renderQ(); },
    hint: function () { this.state.answers[this.state.index] = { chosen: -1, hint: true }; this.renderQ(); },
    toggleFlashcard: function () { this.state.isFlashcard = !this.state.isFlashcard; this.renderQ(); },
    revealFlashcard: function () { document.getElementById('flashcard-cover').style.display = 'none'; document.getElementById('opt-list').style.display = 'block'; },

    toggleBookmark: function () {
        const q = this.state.questions[this.state.index];
        const i = this.bookmarks.findIndex(b => b.q === q.q);
        if (i > -1) this.bookmarks.splice(i, 1); else this.bookmarks.push(q);
        localStorage.setItem(this.DB.marks, JSON.stringify(this.bookmarks));
        this.renderQ();
    },

    showBookmarks: function () { if (!this.bookmarks.length) return alert("Boşdur"); this.startSpecial(this.bookmarks, "⭐ Seçilmişlər", ""); },

    showWrong: function () {
        this.stopTimer();
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        loadTemplate('wrong-menu-template');

        const g = document.getElementById('wrong-grid');
        g.innerHTML = "";

        Object.keys(this.wrongDB).forEach(c => {
            if (this.wrongDB[c].length) {
                const d = document.createElement('div');
                d.className = 'stat-card';
                d.innerHTML = `<div class="stat-val" style="color:var(--wrong)">${this.wrongDB[c].length}</div><div class="stat-lbl">${c}</div>`;
                d.onclick = () => this.startSpecial(this.wrongDB[c], "Səhvlər", c);
                g.appendChild(d);
            }
        });
        if (!g.innerHTML) g.innerHTML = "<p style='text-align:center;color:var(--text-muted)'>Əla! Səhv yoxdur.</p>";
    },

    startTimer: function (c) {
        this.stopTimer();
        this.activeCourse = c;
        if (!this.stats[c]) this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
        this.timer = setInterval(() => { if (this.activeCourse) { this.stats[c].time++; if (this.stats[c].time % 10 === 0) this.saveStats(); } }, 1000);
    },
    stopTimer: function () { clearInterval(this.timer); this.activeCourse = null; this.saveStats(); },

    recordStat: function (c, cat, sub, isCorr) {
        if (!this.stats[c]) this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
        this.stats[c].t++; if (isCorr) this.stats[c].c++; else this.stats[c].w++;
        if (!this.stats[c].bd[cat]) this.stats[c].bd[cat] = {};
        if (!this.stats[c].bd[cat][sub]) this.stats[c].bd[cat][sub] = { t: 0, c: 0, w: 0 };
        this.stats[c].bd[cat][sub].t++;
        if (isCorr) this.stats[c].bd[cat][sub].c++; else this.stats[c].bd[cat][sub].w++;
        this.saveStats();
    },

    saveStats: function () { localStorage.setItem(this.DB.stats, JSON.stringify(this.stats)); },
    saveWrong: function (c, q) { if (!this.wrongDB[c]) this.wrongDB[c] = []; if (!this.wrongDB[c].some(x => x.q === q.q)) { this.wrongDB[c].push(q); localStorage.setItem(this.DB.wrong, JSON.stringify(this.wrongDB)); } },
    removeWrong: function (c, qt) { if (this.wrongDB[c]) { this.wrongDB[c] = this.wrongDB[c].filter(x => x.q !== qt); if (!this.wrongDB[c].length) delete this.wrongDB[c]; localStorage.setItem(this.DB.wrong, JSON.stringify(this.wrongDB)); } },
    saveCorrect: function (c, q) { if (!this.correctDB[c]) this.correctDB[c] = []; if (!this.correctDB[c].some(x => x.q === q.q)) { this.correctDB[c].push(q); localStorage.setItem(this.DB.correct, JSON.stringify(this.correctDB)); } },
    removeCorrect: function (c, qt) { if (this.correctDB[c]) { this.correctDB[c] = this.correctDB[c].filter(x => x.q !== qt); if (!this.correctDB[c].length) delete this.correctDB[c]; localStorage.setItem(this.DB.correct, JSON.stringify(this.correctDB)); } },
    resetStatistics: function () { if (confirm("Bütün məlumatlar silinəcək!")) { localStorage.clear(); location.reload(); } },
    formatTime: function (s) { return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`; },

    getCategoryData: function () {
        if (this.state.category === 'mixed') {
            if (typeof quizData === 'undefined') return [];
            return [...new Set(quizData.filter(q => q.c === this.state.course && q.m).map(q => q.m))].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
        }
        return CONFIG[this.state.course][this.state.category] || [];
    },

    speakQuestion: function () {
        if (this.synth.speaking) { this.synth.cancel(); return; }

        // Icon animation toggle
        const btn = document.getElementById('btn-speak');
        if (btn) btn.classList.add('speaking');

        const q = this.state.questions[this.state.index];
        const u = new SpeechSynthesisUtterance(`${q.q}. ${q.shuffledOpts.map(o => o.txt).join('. ')}`);

        u.onend = () => { if (btn) btn.classList.remove('speaking'); };
        u.onerror = () => { if (btn) btn.classList.remove('speaking'); };

        u.lang = 'tr-TR';
        this.synth.speak(u);
    },

    applyTheme: function () {
        document.documentElement.style.setProperty('--font-scale', this.settings.scale);
        const b = document.body;
        const saved = localStorage.getItem('theme') || 'dark';
        b.setAttribute('data-theme', saved);
    },

    toggleTheme: function () {
        const b = document.body;
        const n = b.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        b.setAttribute('data-theme', n);
        localStorage.setItem('theme', n);
        document.getElementById('theme-btn').textContent = n === 'dark' ? '☀️' : '🌙';
    },

    showSettings: function () {
        document.getElementById('modal-overlay').style.display = 'flex';
        document.getElementById('modal-title').textContent = "Tənzimləmələr";
        document.getElementById('modal-body').innerHTML = `<div class="settings-row" style="text-align:center; padding:20px;">
            <h3 style="margin-bottom:15px;">Şrift Ölçüsü</h3>
            <div style="display:flex; justify-content:center; gap:10px;">
                <button class="nav-pill" onclick="QuizApp.settings.scale=0.9;QuizApp.applyTheme();localStorage.setItem(QuizApp.DB.settings,JSON.stringify(QuizApp.settings))">Kiçik</button>
                <button class="nav-pill" onclick="QuizApp.settings.scale=1;QuizApp.applyTheme();localStorage.setItem(QuizApp.DB.settings,JSON.stringify(QuizApp.settings))">Orta</button>
                <button class="nav-pill" onclick="QuizApp.settings.scale=1.15;QuizApp.applyTheme();localStorage.setItem(QuizApp.DB.settings,JSON.stringify(QuizApp.settings))">Böyük</button>
            </div>
        </div>`;
    }
};

// Global Exposure for HTML onclick handlers - Bind Everything Correctly
window.toggleBookmark = QuizApp.toggleBookmark.bind(QuizApp);
window.speakQuestion = QuizApp.speakQuestion.bind(QuizApp);
window.toggleFlashcard = QuizApp.toggleFlashcard.bind(QuizApp);
window.revealFlashcard = QuizApp.revealFlashcard.bind(QuizApp);
window.checkAnswer = QuizApp.checkAnswer.bind(QuizApp);
window.nav = QuizApp.nav.bind(QuizApp);
window.resetUnit = QuizApp.resetUnit.bind(QuizApp);
window.hint = QuizApp.hint.bind(QuizApp);
window.closeModal = window.closeModal || ((e) => {
    // If a specific close function is needed we can check visibility
    if (document.getElementById('todo-modal').style.display === 'flex') TodoApp.closeModal();
    else document.getElementById('modal-overlay').style.display = 'none';
});

window.resetStatistics = QuizApp.resetStatistics.bind(QuizApp);
window.handleSearch = QuizApp.handleSearch.bind(QuizApp);
window.showStatDetails = QuizApp.showStatDetails.bind(QuizApp);
window.showStatDetailsModal = QuizApp.showStatDetailsModal.bind(QuizApp);
window.startMock = QuizApp.startMock.bind(QuizApp);

// Simple helpers
function updateDaily(inc = false) {
    let d = JSON.parse(localStorage.getItem(QuizApp.DB.daily)) || { d: '', c: 0 };
    if (d.d !== new Date().toDateString()) d = { d: new Date().toDateString(), c: 0 };
    if (inc) d.c++;
    localStorage.setItem(QuizApp.DB.daily, JSON.stringify(d));
    const dt = document.getElementById('daily-text');
    const db = document.getElementById('daily-bar');
    if (dt && db) {
        dt.textContent = `${d.c}/50`;
        db.style.width = Math.min((d.c / 50) * 100, 100) + '%';
    }
}

function shuffle(a) { return a.sort(() => Math.random() - 0.5); }
function loadTemplate(id) { document.getElementById('content-area').innerHTML = document.getElementById(id).innerHTML; }
