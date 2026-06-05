const COURSE_STYLES = {
    "Atatürk İlkeleri ve İnkılap Tarihi II": { icon: "🏛️", accent: "#ef4444", g1: "#ef4444", g2: "#f97316" },
    "Görsel İletişim Tasarımı": { icon: "🎨", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" },
    "Grafik Tasarım II": { icon: "📐", accent: "#10b981", g1: "#10b981", g2: "#06b6d4" },
    "Masaüstü Yayıncılık": { icon: "💻", accent: "#3b82f6", g1: "#3b82f6", g2: "#6366f1" },
    "Tasarımda Tipografi": { icon: "✍️", accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444" },
    "Türk Dili II": { icon: "📖", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899" }
};

const QuizApp = {
    state: { course: null, category: null, currentTitle: null, questions: [], index: 0, answers: {}, correct: 0, wrong: 0, view: 'quiz', sessionStartTime: 0, isWrongMode: false, isSearchMode: false, isMockMode: false, isFlashcard: false },
    DB: { stats: 'qa_v31_s', wrong: 'qa_v31_w', correct: 'qa_v31_c', marks: 'qa_v31_m', daily: 'qa_v31_d', settings: 'qa_v31_conf', wrongCounts: 'qa_v31_wc' },
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
        this.wrongCounts = JSON.parse(localStorage.getItem(this.DB.wrongCounts)) || {};
        
        if (!localStorage.getItem('qa_v31_h_real_v2')) {
            localStorage.removeItem('qa_v31_h');
            localStorage.setItem('qa_v31_h_real_v2', 'true');
        }
        this.dailyHistory = JSON.parse(localStorage.getItem('qa_v31_h')) || {};
        this.applyTheme();
    },

    start: function () {
        this.stopTimer();
        this.state.view = 'home';
        const container = document.getElementById('content-area');
        if (!container) return;

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
                            <canvas id="home-donut-canvas" width="312" height="312"></canvas>
                            <div class="hap-donut-inner">
                                <div class="hap-donut-big">${globalAcc}<span class="hap-pct-sign">%</span></div>
                                <div class="hap-donut-label">Dəqiqlik</div>
                            </div>
                        </div>
                        <div class="hap-legend">
                            <div class="hap-legend-badge" style="background:#22c55e18; border-color:#22c55e40;">
                                <span class="hap-lc-lbl">Düzgün</span>
                                <span class="hap-lc-num" style="color:#22c55e;">${globalCorrect}</span>
                            </div>
                            <div class="hap-legend-badge" style="background:#ef444418; border-color:#ef444440;">
                                <span class="hap-lc-lbl">Səhv</span>
                                <span class="hap-lc-num" style="color:#ef4444;">${globalWrong}</span>
                            </div>
                        </div>
                    </div>

                    <div class="hap-courses-section">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div class="hap-section-label" style="margin-bottom: 0;">Fənn Üzrə İrəliləyiş</div>
                            <div style="font-size: 0.85rem; color: var(--text-muted); font-weight: 500; display: flex; align-items: center; gap: 6px; background: var(--bg-main); padding: 6px 12px; border-radius: 99px; border: 1px solid var(--border);">
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
                                <span>Sərf Edilən Vaxt:</span>
                                <span style="color: var(--text-main); font-weight: 700;">${this.formatTime(globalTime)}</span>
                            </div>
                        </div>
                        <div class="hap-course-list" id="home-progress-list"></div>
                    </div>

                </div>

                <div class="hap-chart-panel">
                    <div class="hap-chart-header">
                        <div class="hap-section-label">Fənlərin İnkişaf Dinamikası</div>
                        <div class="hap-chart-toggles">
                            <button id="toggle-chart-mode-q" class="chart-toggle-btn active" onclick="setChartMode('questions')">Suallar</button>
                            <button id="toggle-chart-mode-t" class="chart-toggle-btn" onclick="setChartMode('time')">Sərf edilən vaxt</button>
                        </div>
                    </div>
                    <div class="hap-chart-body" style="position: relative;">
                        <canvas id="home-dynamics-canvas" style="width: 100%; height: 250px;"></canvas>
                        <div id="chart-tooltip" class="chart-tooltip" style="display: none;"></div>
                    </div>
                </div>

            </div>
        `;

        this.renderHomeCharts(globalCorrect, globalWrong, unanswered);
        this.drawDynamicsChart();

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
            "Atatürk İlkeleri ve İnkılap Tarihi II": { icon: "🏛️", accent: "#ef4444", g1: "#ef4444", g2: "#f97316" },
            "Görsel İletişim Tasarımı": { icon: "🎨", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" },
            "Grafik Tasarım II": { icon: "📐", accent: "#10b981", g1: "#10b981", g2: "#06b6d4" },
            "Masaüstü Yayıncılık": { icon: "💻", accent: "#3b82f6", g1: "#3b82f6", g2: "#6366f1" },
            "Tasarımda Tipografi": { icon: "✍️", accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444" },
            "Türk Dili II": { icon: "📖", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899" }
        };

        // --- Animated Donut Chart ---
        const canvas = document.getElementById('home-donut-canvas');
        if (canvas) {
            const ctx = canvas.getContext('2d');
            const dpr = window.devicePixelRatio || 1;
            canvas.width = 312 * dpr; canvas.height = 312 * dpr;
            canvas.style.width = '312px'; canvas.style.height = '312px';
            ctx.scale(dpr, dpr);

            const cx = 156, cy = 156, r = 126, strokeW = 24;
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
                ctx.clearRect(0, 0, 312, 312);

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

        const totalQ = correct + wrong + unanswered;
        const totalAns = correct + wrong;
        const acc = totalAns > 0 ? Math.round((correct / totalAns) * 100) : 0;
        const pctProgress = totalQ > 0 ? (totalAns / totalQ) * 100 : 0;

        const totalRow = document.createElement('div');
        totalRow.className = 'hap-course-row clickable';
        totalRow.onclick = () => this.showOverallDashboard();
        totalRow.innerHTML = `
            <div class="hap-course-left">
                <div class="hap-course-dot" style="background: linear-gradient(135deg, #a8a29e, #78716c);">📊</div>
                <div class="hap-course-info">
                    <div class="hap-course-name" style="font-weight: 800; color: #f5f5f5;">Ümumi Toplam</div>
                    <div class="hap-course-track">
                        <div class="hap-course-bar" style="background: linear-gradient(90deg, #a8a29e, #78716c); width: ${Math.min(pctProgress, 100)}%;"></div>
                    </div>
                </div>
            </div>
            <div class="hap-course-stats">
                <div class="hap-mini-stat" style="color:#22c55e">${correct}</div>
                <div class="hap-mini-stat" style="color:#ef4444">${wrong}</div>
                <div class="hap-mini-badge" style="background: #ffffff15; color: #ffffff">${acc}%</div>
                <div class="hap-mini-badge" style="background: rgba(255,255,255,0.05); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.1);">${totalQ}</div>
            </div>
        `;
        list.appendChild(totalRow);

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
            row.className = 'hap-course-row clickable';
            row.onclick = () => this.selectCat(c, 'units');
            row.style.setProperty('--c-accent', style.accent);
            row.style.setProperty('--c-g1', style.g1);
            row.style.setProperty('--c-g2', style.g2);
            row.innerHTML = `
                <div class="hap-course-left">
                    <div class="hap-course-dot" style="background: linear-gradient(135deg, ${style.g1}, ${style.g2});">${style.icon || '📘'}</div>
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
                    <div class="hap-mini-badge" style="background: rgba(255,255,255,0.05); color: var(--text-muted); border: 1px solid rgba(255,255,255,0.1);">${totalQ}</div>
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
        this.state.view = 'dashboard';
        this.state.course = c;
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

        // Wrong Exam Section
        const wrongExamContainer = document.getElementById('db-wrong-exam-container');
        if (wrongExamContainer) {
            const wrQs = this.wrongDB[c] || [];
            if (wrQs.length > 0) {
                wrongExamContainer.style.display = 'block';
                wrongExamContainer.innerHTML = `
                    <div class="db-wrong-exam-box">
                        <div class="db-wrong-exam-info">
                            <div class="db-wrong-exam-title">❌ SƏHVLƏRİN TƏKRARI</div>
                            <div class="db-wrong-exam-desc">Bu fəndən <span>${wrQs.length}</span> səhv cavablandırdığınız sual var. Onları düzəltmək üçün imtahana başlayın.</div>
                        </div>
                        <button class="db-wrong-exam-btn" onclick="startCourseWrongExam('${c.replace(/'/g, "\\'")}')">İmtahana Başla</button>
                    </div>
                `;
            } else {
                wrongExamContainer.style.display = 'none';
                wrongExamContainer.innerHTML = '';
            }
        }

        // Mixed Exam Section
        const mixedExamContainer = document.getElementById('db-mixed-exam-container');
        if (mixedExamContainer) {
            mixedExamContainer.innerHTML = `
                <div class="db-mixed-exam-box">
                    <div class="db-mixed-exam-info">
                        <div class="db-mixed-exam-title">🎲 QARIŞIQ SINAQ</div>
                        <div class="db-mixed-exam-desc">Fənnin bütün bölmələrindən qarışıq <span>20 suallıq</span> sürətli sınaq imtahanı işləyin.</div>
                    </div>
                    <button class="db-mixed-exam-btn" onclick="startCourseMixedExam('${c.replace(/'/g, "\\'")}')">Sınağa Başla</button>
                </div>
            `;
        }

        // AI Recommendation
        const recTextEl = document.getElementById('db-recommendation-text');
        if (recTextEl) {
            let rec = "";
            const totalAnswered = s.t;
            if (totalAnswered === 0) {
                rec = "Bu fənn üzrə hələ heç bir sual cavablandırmamısınız. Öyrənməyə və özünüzü sınamağa başlamaq üçün aşağıdakı bölmələrdən birini seçib 'Başla' düyməsinə klikləyin!";
            } else if (totalAnswered < 15) {
                const percent = Math.round((s.c / s.t) * 100);
                const progressPct = totalQ > 0 ? Math.round((totalAnswered / totalQ) * 100) : 0;
                rec = `Siz hələ ki bu fənn üzrə cəmi <b>${totalAnswered} sual</b> cavablandırmısınız (doğru cavab nisbəti: ${percent}%, fənn üzrə irəliləyiş: ${progressPct}%). AI-in daha dolğun analiz və tövsiyələr verə bilməsi üçün bölmələri işləməyə davam edin!`;
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
        const layout = localStorage.getItem('quiz_dashboard_layout') || 'grid';
        
        // Update layout toggle button active states
        const gridBtn = document.getElementById('layout-grid-btn');
        const tableBtn = document.getElementById('layout-table-btn');
        if (gridBtn && tableBtn) {
            if (layout === 'table') {
                gridBtn.classList.remove('active');
                tableBtn.classList.add('active');
            } else {
                tableBtn.classList.remove('active');
                gridBtn.classList.add('active');
            }
        }

        if (listEl && CONFIG[c]) {
            listEl.innerHTML = "";
            const wrQs = this.wrongDB[c] || [];
            const hardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 2).length;
            const veryHardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 3).length;
            
            if (layout === 'table') {
                listEl.classList.add('table-mode');
                
                // Create table element
                const table = document.createElement('table');
                table.className = 'stat-table unit-table';
                
                // Prepend Multi row to tbodyHTML
                let tbodyHTML = `
                    <tr onclick="QuizApp.startMultiUnit('${c.replace(/'/g, "\\'")}')" style="background: rgba(99, 102, 241, 0.05); border-left: 3px solid var(--accent);">
                        <td style="font-weight: 800; color: var(--accent);">
                            <span class="unit-table-num">⭐</span> Multi (Səhvlərin Təkrarı)
                            ${hardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(245, 158, 11, 0.08); border: 1px solid var(--hint); color: var(--hint); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">⚠️ ${hardQsCount} Çətin</span>` : ''}
                            ${veryHardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(239, 68, 68, 0.08); border: 1px solid var(--wrong); color: var(--wrong); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">🔥 ${veryHardQsCount} Çox Çətin</span>` : ''}
                        </td>
                        <td style="text-align: center;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--active); font-weight: 700;">-</td>
                        <td style="text-align: center; color: var(--wrong); font-weight: 700;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--accent); font-weight: 700;">-</td>
                        <td style="text-align: right;" onclick="event.stopPropagation();">
                            <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('${c.replace(/'/g, "\\'")}')">Başla</button>
                        </td>
                    </tr>
                `;
                
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
                    
                    let unitAcc = 0;
                    const totalAnswered = c_correct + c_wrong;
                    if (totalAnswered > 0) {
                        unitAcc = Math.round((c_correct / totalAnswered) * 100);
                    }
                    
                    tbodyHTML += `
                        <tr onclick="QuizApp.startUnit('${c.replace(/'/g, "\\'")}', ${i})">
                            <td style="font-weight: 700; color: var(--text-main);"><span class="unit-table-num">${unitIdx}.</span> ${unitName}</td>
                            <td style="text-align: center;">${totalUnitQ}</td>
                            <td style="text-align: center; color: var(--active); font-weight: 700;">${c_correct}</td>
                            <td style="text-align: center; color: var(--wrong); font-weight: 700;">${c_wrong}</td>
                            <td style="text-align: center; color: var(--accent); font-weight: 700;">${unitAcc}%</td>
                            <td style="text-align: right;" onclick="event.stopPropagation();">
                                <button class="unit-btn-start" onclick="QuizApp.startUnit('${c.replace(/'/g, "\\'")}', ${i})">Başla</button>
                            </td>
                        </tr>
                    `;
                });
                
                table.innerHTML = `
                    <thead>
                        <tr>
                            <th style="width: 45%;">Bölmə</th>
                            <th style="text-align: center; width: 12%;">Sual</th>
                            <th style="text-align: center; width: 10%; color: var(--active);">Düz</th>
                            <th style="text-align: center; width: 10%; color: var(--wrong);">Səhv</th>
                            <th style="text-align: center; width: 10%;">Faiz</th>
                            <th style="text-align: right; width: 13%;">İcra</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${tbodyHTML}
                    </tbody>
                `;
                listEl.appendChild(table);
            } else {
                listEl.classList.remove('table-mode');
                
                // Prepend Multi card to listEl in Grid layout
                const multiItem = document.createElement('div');
                multiItem.className = 'unit-item';
                multiItem.style.background = 'linear-gradient(135deg, rgba(99, 102, 241, 0.06) 0%, rgba(139, 92, 246, 0.06) 100%)';
                multiItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                multiItem.innerHTML = `
                    <div class="unit-item-header">
                        <div class="unit-item-title" style="color: var(--accent); font-weight: 800;">⭐ Multi (Səhvlərin Təkrarı)</div>
                        <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('${c.replace(/'/g, "\\'")}')">Başla</button>
                    </div>
                    <div class="unit-item-stats-grid">
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--text-main); font-weight: 800;">${wrQs.length}</span>
                            <span class="us-lbl">SƏHV SUAL</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--hint); font-weight: 800;">⚠️ ${hardQsCount}</span>
                            <span class="us-lbl">ÇƏTİN (2+)</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--wrong); font-weight: 800;">🔥 ${veryHardQsCount}</span>
                            <span class="us-lbl">ÇOX ÇƏTİN (3+)</span>
                        </div>
                    </div>
                `;
                listEl.appendChild(multiItem);
                
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
                                <span class="us-val" style="color: var(--active)">${c_correct}</span>
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
        }
    },

    startUnit: function (c, idx) {
        this.state = { ...this.state, view: 'quiz', course: c, category: 'units', isWrongMode: false, isSearchMode: false, isMockMode: false };
        
        loadTemplate('quiz-template');
        this.renderTopNav();
        this.loadContent(idx);
        this.startTimer(c);
    },

    startMultiUnit: function (c) {
        let arr = [];
        let courseName = c;
        if (!c || c === 'all' || c === 'Ümumi Toplam') {
            courseName = 'Ümumi Toplam';
            Object.keys(this.wrongDB).forEach(k => {
                arr = arr.concat(this.wrongDB[k]);
            });
        } else {
            arr = this.wrongDB[c] || [];
        }

        if (!arr.length) {
            alert("Multi bölməsi boşdur! Heç bir səhv cavablandırdığınız sual yoxdur. Əla!");
            return;
        }
        
        // Start the test with the wrong questions
        this.startSpecial(arr, "Multi: Səhvlərin Təkrarı", courseName);
        this.state.isWrongMode = true;
        this.state.course = courseName;
        this.state.category = 'units'; 
        this.state.currentTitle = 'Multi';
        this.startTimer(courseName);
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

        const qMetaEl = document.getElementById('q-meta');
        if (qMetaEl) {
            const isMixedOrWrongOrMockOrMulti = this.state.isMockMode || this.state.isWrongMode || this.state.isSearchMode || this.state.category === 'mixed' || this.state.category === 'exams' || this.state.currentTitle === 'Multi';
            if (isMixedOrWrongOrMockOrMulti) {
                const uName = (CONFIG[q.c] && CONFIG[q.c].units[q.u - 1]) || `Unit ${q.u}`;
                const style = COURSE_STYLES[q.c] || { accent: '#6366f1', g1: '#6366f1', g2: '#8b5cf6' };
                qMetaEl.innerHTML = `
                    <span class="badge-meta-course" style="background: rgba(99, 102, 241, 0.08); border: 1px solid ${style.accent}30; color: ${style.accent}; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700;">${q.c}</span>
                    <span style="color: var(--text-muted); font-size: 0.75rem;">&bull;</span>
                    <span class="badge-meta-unit" style="background: var(--bg-element); border: 1px solid var(--border); color: var(--text-main); padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 600;">${uName}</span>
                `;
                qMetaEl.style.display = 'flex';
            } else {
                qMetaEl.style.display = 'none';
            }
        }

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
                s.className = 'progress-segment ' + (i === this.state.index ? 'active' : '') + (this.state.answers[i] ? (this.state.answers[i].chosen === this.state.questions[i].a ? ' done' : ' wrong') : '');
                s.textContent = i + 1;
                s.onclick = () => { QuizApp.state.index = i; QuizApp.renderQ(); };
                pBar.appendChild(s);
            }
        }

        let qText = q.q;
        const qWrongCount = this.wrongCounts && this.wrongCounts[q.q] ? this.wrongCounts[q.q] : 0;
        if (qWrongCount >= 2) {
            const warningColor = qWrongCount >= 3 ? 'var(--wrong)' : 'var(--hint)';
            qText += ` <span class="badge-hard" style="background: rgba(239, 68, 68, 0.08); border: 1px solid ${warningColor}; color: ${warningColor}; font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">⚠️ ${qWrongCount} Səhv</span>`;
        }
        qTextEl.innerHTML = `${this.state.index + 1}. ${qText}`;

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

        if (isCorrect) { 
            this.state.correct++; 
            this.saveCorrect(q.c, q); 
            if (this.state.isWrongMode) this.removeWrong(q.c, q.q); 
        } else { 
            this.state.wrong++; 
            this.saveWrong(q.c, q); 
            this.removeCorrect(q.c, q.q); 
            
            // Increment persistent wrong counts for difficulty analysis
            if (!this.wrongCounts) this.wrongCounts = {};
            this.wrongCounts[q.q] = (this.wrongCounts[q.q] || 0) + 1;
            localStorage.setItem(this.DB.wrongCounts, JSON.stringify(this.wrongCounts));
            
            // Trigger Firebase sync automatically if synced
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        if (this.state.isMockMode) {
            this.recordStat(this.MOCK_KEY, "mock", `Sınaq`, isCorrect);
        } else if (this.state.course && !this.state.isSearchMode) {
            let cat = this.state.category;
            let sub = this.state.currentTitle;
            
            if (this.state.isWrongMode) {
                cat = 'wrong';
                sub = 'Səhvlərin Təkrarı';
            } else if (this.state.isMixedMode) {
                cat = 'mixed';
                sub = 'Qarışıq Sınaq';
            } else if (cat === 'units') {
                sub = `Unit ${this.state.selectionIndex + 1}`;
            }
            
            this.recordStat(this.state.course, cat, sub, isCorrect);
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
        this.startSpecial(pool, this.MOCK_KEY, "Real Sınaq Rejimi", true);
        this.state.course = this.MOCK_KEY; this.startTimer(this.MOCK_KEY);
    },

    startHard: function () {
        let pool = []; Object.keys(this.wrongDB).forEach(k => pool = pool.concat(this.wrongDB[k]));
        if (!pool.length) return alert("Səhv yoxdur!");
        this.startSpecial(shuffle(pool).slice(0, 20), "💀 Ən Çətinlər", "Səhvlər Təkrarı");
        this.state.isWrongMode = true; this.state.course = "Hard";
    },

    startCourseWrongExam: function (c) {
        const arr = this.wrongDB[c] || [];
        if (!arr.length) return alert("Səhv cavablandırdığınız sual yoxdur.");
        this.startSpecial(arr, "Səhvlərin Təkrarı: " + c, c);
        this.state.isWrongMode = true;
        this.state.course = c;
        this.startTimer(c);
    },

    startCourseMixedExam: function (c) {
        if (typeof quizData === 'undefined') return;
        const qs = quizData.filter(q => q.c === c);
        if (!qs.length) return alert("Bu fənn üzrə sual tapılmadı.");
        
        // Shuffle and take 20 questions
        const shuffled = shuffle([...qs]).slice(0, 20);
        this.startSpecial(shuffled, "Qarışıq Sınaq: " + c, c);
        this.state.isMixedMode = true;
        this.state.course = c;
        this.startTimer(c);
    },

    setDashboardLayout: function (layout) {
        localStorage.setItem('quiz_dashboard_layout', layout);
        if (this.state.course) {
            if (this.state.course === 'Ümumi Toplam') {
                this.showOverallDashboard();
            } else {
                this.showCourseDashboard(this.state.course);
            }
        }
    },

    showOverallDashboard: function () {
        this.stopTimer();
        this.state = { ...this.state, view: 'dashboard', course: 'Ümumi Toplam', category: null, isWrongMode: false, isSearchMode: false, isMockMode: false };

        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        // Clear sidebar active states
        document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active-sub'));

        loadTemplate('course-dashboard-template');

        // Title and Subtitle
        const titleEl = document.getElementById('db-course-title');
        if (titleEl) titleEl.textContent = 'Ümumi Toplam';
        
        // Find subtitle element
        const headerDiv = document.querySelector('.dashboard-full-container .dashboard-header div');
        if (headerDiv) {
            const sub = headerDiv.querySelector('span');
            if (sub) sub.textContent = 'Bütün fənlər üzrə ümumi irəliləyiş, analiz və göstəricilər';
        }

        // Aggregate statistics
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

        document.getElementById('db-total-questions').textContent = globalTotalQ;
        document.getElementById('db-total-time').textContent = this.formatTime(globalTime);
        
        const correctVal = document.getElementById('db-total-correct');
        const wrongVal = document.getElementById('db-total-wrong');
        correctVal.textContent = globalCorrect;
        wrongVal.textContent = globalWrong;

        const accVal = document.getElementById('db-accuracy');
        if (accVal) accVal.textContent = globalAcc + '%';

        // Interactive correct/wrong clicks
        const correctCard = correctVal.parentElement;
        const wrongCard = wrongVal.parentElement;
        
        correctCard.style.cursor = 'pointer';
        correctCard.title = 'Bütün fənlərdən düzgün cavablandırdığınız suallara baxmaq üçün klikləyin';
        correctCard.onclick = () => {
            let arr = [];
            Object.keys(this.correctDB).forEach(k => {
                arr = arr.concat(this.correctDB[k]);
            });
            if(arr.length) this.startSpecial(arr, "Ümumi Doğrular", "Bütün Fənlər");
            else alert("Doğru cavablandırdığınız sual hələ ki yoxdur.");
        };

        wrongCard.style.cursor = 'pointer';
        wrongCard.title = 'Bütün fənlərdən səhv cavablandırdığınız suallara baxmaq üçün klikləyin';
        wrongCard.onclick = () => {
            let arr = [];
            Object.keys(this.wrongDB).forEach(k => {
                arr = arr.concat(this.wrongDB[k]);
            });
            if(arr.length) this.startSpecial(arr, "Ümumi Səhvlər", "Bütün Fənlər");
            else alert("Əla! Səhv cavablandırdığınız sual yoxdur.");
        };

        // Səhvlərin Təkrarı Box
        const wrongExamContainer = document.getElementById('db-wrong-exam-container');
        if (wrongExamContainer) {
            let wrQs = [];
            Object.keys(this.wrongDB).forEach(k => {
                wrQs = wrQs.concat(this.wrongDB[k]);
            });
            if (wrQs.length > 0) {
                wrongExamContainer.style.display = 'block';
                wrongExamContainer.innerHTML = `
                    <div class="db-wrong-exam-box">
                        <div class="db-wrong-exam-info">
                            <div class="db-wrong-exam-title">❌ SƏHVLƏRİN TƏKRARI</div>
                            <div class="db-wrong-exam-desc">Bütün fənlərdən cəmi <span>${wrQs.length}</span> səhv cavablandırdığınız sual var. Onları düzəltmək üçün imtahana başlayın.</div>
                        </div>
                        <button class="db-wrong-exam-btn" onclick="QuizApp.startHard()">İmtahana Başla</button>
                    </div>
                `;
            } else {
                wrongExamContainer.style.display = 'none';
            }
        }

        // Qarışıq Sınaq Box (Real Sınaq Rejimi)
        const mixedExamContainer = document.getElementById('db-mixed-exam-container');
        if (mixedExamContainer) {
            mixedExamContainer.innerHTML = `
                <div class="db-mixed-exam-box">
                    <div class="db-mixed-exam-info">
                        <div class="db-mixed-exam-title">🎲 BÖYÜK SINAQ</div>
                        <div class="db-mixed-exam-desc">Bütün fənlərdən qarışıq <span>real sınaq imtahanı</span> işləyərək özünüzü yoxlayın.</div>
                    </div>
                    <button class="db-mixed-exam-btn" onclick="QuizApp.startMock()">Sınağa Başla</button>
                </div>
            `;
        }

        // AI Recommendation
        const recTextEl = document.getElementById('db-recommendation-text');
        if (recTextEl) {
            let rec = "";
            if (globalTotalAns === 0) {
                rec = "Hələ ki heç bir sual cavablandırmamısınız. İmtahana hazırlaşmaq üçün hər hansı bir fənni seçib sualları işləməyə başlayın!";
            } else {
                const percent = globalAcc;
                if (percent >= 80) {
                    rec = `Mükəmməl ümumi nəticə! Dəqiqliyiniz ${percent}%-dir. Bu tempi qoruyub saxlamaq üçün mütəmadi olaraq <b>Böyük Sınaq</b> işləyin.`;
                } else if (percent >= 50) {
                    rec = `Ümumi hazırlıq səviyyəniz yaxşıdır (${percent}% doğru). Göstəricinizi daha da yaxşılaşdırmaq üçün zəif olduğunuz fənlərə və bölmələrə diqqət yetirin, səhv etdiyiniz sualları <b>Səhvlərin Təkrarı</b> rejimində yenidən işləyin.`;
                } else {
                    rec = `Ümumi nəticəniz zəifdir (${percent}% doğru). Hər bir fənni ayrı-ayrılıqda daha diqqətlə öyrənməyinizi və çətinlik çəkdiyiniz mövzuları təkrarlamağı tövsiyə edirik.`;
                }
            }
            recTextEl.innerHTML = rec;
        }

        // Right Column Title - change to "Fənlər"
        const unitsHeaderH3 = document.querySelector('.units-header h3');
        if (unitsHeaderH3) {
            unitsHeaderH3.textContent = "Fənlər";
        }

        // Render Subjects List
        const listEl = document.getElementById('db-unit-list');
        const layout = localStorage.getItem('quiz_dashboard_layout') || 'grid';
        
        // Update layout toggle button active states
        const gridBtn = document.getElementById('layout-grid-btn');
        const tableBtn = document.getElementById('layout-table-btn');
        if (gridBtn && tableBtn) {
            if (layout === 'table') {
                gridBtn.classList.remove('active');
                tableBtn.classList.add('active');
            } else {
                tableBtn.classList.remove('active');
                gridBtn.classList.add('active');
            }
        }

        if (listEl) {
            listEl.innerHTML = "";
            let wrQs = [];
            Object.keys(this.wrongDB).forEach(k => {
                wrQs = wrQs.concat(this.wrongDB[k]);
            });
            const hardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 2).length;
            const veryHardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 3).length;
            
            if (layout === 'table') {
                listEl.classList.add('table-mode');
                
                // Create table element
                const table = document.createElement('table');
                table.className = 'stat-table unit-table';
                
                // Prepend Multi row to tbodyHTML
                let tbodyHTML = `
                    <tr onclick="QuizApp.startMultiUnit('all')" style="background: rgba(99, 102, 241, 0.05); border-left: 3px solid var(--accent);">
                        <td style="font-weight: 800; color: var(--accent);">
                            <span class="unit-table-num">⭐</span> Multi (Səhvlərin Təkrarı)
                            ${hardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(245, 158, 11, 0.08); border: 1px solid var(--hint); color: var(--hint); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">⚠️ ${hardQsCount} Çətin</span>` : ''}
                            ${veryHardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(239, 68, 68, 0.08); border: 1px solid var(--wrong); color: var(--wrong); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">🔥 ${veryHardQsCount} Çox Çətin</span>` : ''}
                        </td>
                        <td style="text-align: center;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--active); font-weight: 700;">-</td>
                        <td style="text-align: center; color: var(--wrong); font-weight: 700;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--accent); font-weight: 700;">-</td>
                        <td style="text-align: right;" onclick="event.stopPropagation();">
                            <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('all')">Başla</button>
                        </td>
                    </tr>
                `;
                Object.keys(CONFIG).forEach((c) => {
                    let totalCourseQ = 0;
                    if (typeof quizData !== 'undefined') {
                        totalCourseQ = quizData.filter(q => q.c === c).length;
                    }
                    
                    const cs = this.stats[c] || { t: 0, c: 0, w: 0 };
                    
                    let courseAcc = 0;
                    if (cs.t > 0) {
                        courseAcc = Math.round((cs.c / cs.t) * 100);
                    }
                    
                    tbodyHTML += `
                        <tr onclick="QuizApp.showCourseDashboard('${c.replace(/'/g, "\\'")}')">
                            <td style="font-weight: 700; color: var(--text-main);">${c}</td>
                            <td style="text-align: center;">${totalCourseQ}</td>
                            <td style="text-align: center; color: var(--active); font-weight: 700;">${cs.c}</td>
                            <td style="text-align: center; color: var(--wrong); font-weight: 700;">${cs.w}</td>
                            <td style="text-align: center; color: var(--accent); font-weight: 700;">${courseAcc}%</td>
                            <td style="text-align: right;" onclick="event.stopPropagation();">
                                <button class="unit-btn-start" onclick="QuizApp.showCourseDashboard('${c.replace(/'/g, "\\'")}')">Keç</button>
                            </td>
                        </tr>
                    `;
                });
                
                table.innerHTML = `
                    <thead>
                        <tr>
                            <th style="width: 45%;">Fənn</th>
                            <th style="text-align: center; width: 12%;">Sual</th>
                            <th style="text-align: center; width: 10%; color: var(--active);">Düz</th>
                            <th style="text-align: center; width: 10%; color: var(--wrong);">Səhv</th>
                            <th style="text-align: center; width: 10%;">Faiz</th>
                            <th style="text-align: right; width: 13%;">Keçid</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${tbodyHTML}
                    </tbody>
                `;
                listEl.appendChild(table);
            } else {
                listEl.classList.remove('table-mode');
                
                // Prepend Multi card to listEl in Grid layout
                const multiItem = document.createElement('div');
                multiItem.className = 'unit-item';
                multiItem.style.background = 'linear-gradient(135deg, rgba(99, 102, 241, 0.06) 0%, rgba(139, 92, 246, 0.06) 100%)';
                multiItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                multiItem.innerHTML = `
                    <div class="unit-item-header">
                        <div class="unit-item-title" style="color: var(--accent); font-weight: 800;">⭐ Multi (Səhvlərin Təkrarı)</div>
                        <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('all')">Başla</button>
                    </div>
                    <div class="unit-item-stats-grid">
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--text-main); font-weight: 800;">${wrQs.length}</span>
                            <span class="us-lbl">SƏHV SUAL</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--hint); font-weight: 800;">⚠️ ${hardQsCount}</span>
                            <span class="us-lbl">ÇƏTİN (2+)</span>
                        </div>
                        <div class="unit-stat-box">
                            <span class="us-val" style="color: var(--wrong); font-weight: 800;">🔥 ${veryHardQsCount}</span>
                            <span class="us-lbl">ÇOX ÇƏTİN (3+)</span>
                        </div>
                    </div>
                `;
                listEl.appendChild(multiItem);
                
                Object.keys(CONFIG).forEach((c) => {
                    let totalCourseQ = 0;
                    if (typeof quizData !== 'undefined') {
                        totalCourseQ = quizData.filter(q => q.c === c).length;
                    }

                    const cs = this.stats[c] || { t: 0, c: 0, w: 0 };

                    const item = document.createElement('div');
                    item.className = 'unit-item';
                    item.innerHTML = `
                        <div class="unit-item-header">
                            <div class="unit-item-title">${c}</div>
                            <button class="unit-btn-start" onclick="QuizApp.showCourseDashboard('${c.replace(/'/g, "\\'")}')">Keç</button>
                        </div>
                        <div class="unit-item-stats-grid">
                            <div class="unit-stat-box">
                                <span class="us-val">${totalCourseQ}</span>
                                <span class="us-lbl">CƏMİ SUAL</span>
                            </div>
                            <div class="unit-stat-box">
                                <span class="us-val" style="color: var(--active)">${cs.c}</span>
                                <span class="us-lbl">DOĞRU</span>
                            </div>
                            <div class="unit-stat-box">
                                <span class="us-val" style="color: var(--wrong)">${cs.w}</span>
                                <span class="us-lbl">YANLIŞ</span>
                            </div>
                        </div>
                    `;
                    listEl.appendChild(item);
                });
            }
        }
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

    startSpecial: function (qs, t, s, isMock = false) {
        this.stopTimer();
        
        const isWrong = t.toLowerCase().includes('sehv') || t.toLowerCase().includes('cetin') || t.toLowerCase().includes('wrong') || t.toLowerCase().includes('hard');
        const isMixed = t.toLowerCase().includes('qarisig') || t.toLowerCase().includes('qarışıq') || t.toLowerCase().includes('mixed');
        const isSearch = t.toLowerCase().includes('axtar') || t.toLowerCase().includes('search');

        this.state = {
            ...this.state,
            view: 'quiz',
            questions: [...qs],
            index: 0,
            answers: {},
            correct: 0,
            wrong: 0,
            isMockMode: isMock,
            isWrongMode: isWrong,
            isMixedMode: isMixed,
            isSearchMode: isSearch,
            course: s
        };

        this.state.questions.forEach(q => { q.shuffledOpts = shuffle(q.o.map((txt, i) => ({ txt, i }))); });
        
        loadTemplate('quiz-template');

        document.getElementById('title-unit').textContent = t;
        document.getElementById('course-name-sm').textContent = s;

        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        this.renderQ();
        this.startTimer(s);
    },

    showStats: function () {
        this.stopTimer();
        this.state.view = 'stats';
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
        if (!s || !s.bd || Object.keys(s.bd).length === 0) {
            h = `<div style="text-align: center; padding: 30px 10px; color: var(--text-muted); font-size: 0.95rem;">
                    <div style="font-size: 2.5rem; margin-bottom: 12px;">📊</div>
                    Bu fənn üzrə hələ heç bir sual cavablandırılmayıb.
                 </div>`;
        } else {
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
        const score = Math.max(0, (net / total) * 100);
        const pct = score;
        let color = pct >= 90 ? 'var(--active)' : (pct >= 50 ? 'var(--finish)' : 'var(--wrong)');
        
        let subHTML = `<table class="stat-table" style="margin-top:20px;"><thead><tr><th>Fənn</th><th>D</th><th>Y</th><th>Bal</th></tr></thead><tbody>`;
        let totalMockScore = 0;
        const mockSubjects = Object.keys(subRes);
        mockSubjects.forEach(k => {
            const subTotalQs = this.state.questions.filter(q => q.c === k).length;
            const subNet = subRes[k].c - (subRes[k].w / 4);
            const subScore = Math.max(0, (subNet / subTotalQs) * 100);
            totalMockScore += subScore;
            subHTML += `<tr><td>${k}</td><td style="color:var(--active)">${subRes[k].c}</td><td style="color:var(--wrong)">${subRes[k].w}</td><td style="font-weight:700; color:var(--accent);">${subScore.toFixed(1)}</td></tr>`;
        });
        subHTML += '</tbody></table>';

        const averageMockScore = mockSubjects.length > 0 ? (totalMockScore / mockSubjects.length) : 0;
        const triggerConfetti = this.state.isMockMode ? (averageMockScore >= 50) : (pct >= 50);
        if (triggerConfetti) fireConfetti();

        const body = document.getElementById('modal-body');
        document.getElementById('modal-title').textContent = "Nəticə";

        if (this.state.isMockMode) {
            body.innerHTML = `
                <div style="text-align:center; padding:10px;">
                    <div style="font-size:2.0rem; font-weight:800; color:var(--accent);">Sınaq Nəticələri</div>
                    <div style="color:var(--text-muted); margin-bottom: 15px;">Fənn üzrə ballar (Maks. 100):</div>
                    ${subHTML}
                    <button class="btn btn-pri" style="margin-top:20px; width:100%" onclick="closeModal()">Bağla</button>
                </div>
            `;
        } else {
            body.innerHTML = `
                <div style="text-align:center; padding:10px;">
                    <div style="font-size:2.5rem; font-weight:800; color:${color};">${score.toFixed(1)}</div>
                    <div style="color:var(--text-muted);">${Math.round(pct)}%</div>
                    <div style="display:grid; grid-template-columns:1fr 1fr 1fr; gap:5px; margin-top:15px;">
                        <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="color:var(--active); font-weight:bold;">${c}</div><div style="font-size:0.7rem">D</div></div>
                        <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="color:var(--wrong); font-weight:bold;">${w}</div><div style="font-size:0.7rem">Y</div></div>
                        <div style="background:var(--bg-element); padding:8px; border-radius:8px;"><div style="font-weight:bold;">${net.toFixed(2)}</div><div style="font-size:0.7rem">Net</div></div>
                    </div>
                    <button class="btn btn-pri" style="margin-top:20px; width:100%" onclick="closeModal()">Bağla</button>
                </div>
            `;
        }
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
        this.state.view = 'wrong';
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
        this.sessionStartTime = Date.now();
        this.secondsElapsedInSession = 0;
        
        const isStatTracked = c && (typeof CONFIG !== 'undefined' && CONFIG[c] !== undefined || c === this.MOCK_KEY);

        if (isStatTracked) {
            if (!this.stats[c]) this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
        }
        
        const timerDisp = document.getElementById('quiz-timer-disp');
        if (timerDisp) timerDisp.textContent = "00:00";

        this.timer = setInterval(() => { 
            if (this.activeCourse) { 
                const now = Date.now();
                const totalElapsed = Math.floor((now - this.sessionStartTime) / 1000);
                const delta = totalElapsed - this.secondsElapsedInSession;
                if (delta > 0) {
                    if (isStatTracked) {
                        this.stats[c].time += delta; 
                        this.recordDailyHistory(c, null, delta);
                    }
                    this.secondsElapsedInSession = totalElapsed;
                    if (isStatTracked && this.secondsElapsedInSession % 10 === 0) this.saveStats(); 
                }
                if (timerDisp) {
                    const mins = Math.floor(totalElapsed / 60);
                    const secs = totalElapsed % 60;
                    timerDisp.textContent = String(mins).padStart(2, '0') + ":" + String(secs).padStart(2, '0');
                }
            } 
        }, 1000);
    },
    stopTimer: function () { 
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
        }
        if (this.activeCourse) {
            const now = Date.now();
            const totalElapsed = Math.floor((now - this.sessionStartTime) / 1000);
            const delta = totalElapsed - this.secondsElapsedInSession;
            const isStatTracked = this.activeCourse && (typeof CONFIG !== 'undefined' && CONFIG[this.activeCourse] !== undefined || this.activeCourse === this.MOCK_KEY);
            if (delta > 0 && isStatTracked) {
                this.stats[this.activeCourse].time += delta;
                this.recordDailyHistory(this.activeCourse, null, delta);
            }
            this.activeCourse = null;
        }
        this.saveStats(); 
    },

    recordStat: function (c, cat, sub, isCorr) {
        if (!this.stats[c]) this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
        this.stats[c].t++; if (isCorr) this.stats[c].c++; else this.stats[c].w++;
        if (!this.stats[c].bd[cat]) this.stats[c].bd[cat] = {};
        if (!this.stats[c].bd[cat][sub]) this.stats[c].bd[cat][sub] = { t: 0, c: 0, w: 0 };
        this.stats[c].bd[cat][sub].t++;
        if (isCorr) this.stats[c].bd[cat][sub].c++; else this.stats[c].bd[cat][sub].w++;
        this.recordDailyHistory(c, isCorr, 0);
        this.saveStats();
    },

    recordDailyHistory: function(course, isCorrect, timeIncrement = 0) {
        if (!this.dailyHistory) this.dailyHistory = {};
        const tempD = new Date();
        const today = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
        if (!this.dailyHistory[today]) this.dailyHistory[today] = {};
        if (!this.dailyHistory[today][course]) this.dailyHistory[today][course] = { time: 0, correct: 0, wrong: 0 };
        
        if (timeIncrement > 0) {
            this.dailyHistory[today][course].time += timeIncrement;
        } else {
            if (isCorrect) this.dailyHistory[today][course].correct++;
            else this.dailyHistory[today][course].wrong++;
        }
    },

    setChartMode: function(mode) {
        this.state.chartMode = mode;
        const btnQ = document.getElementById('toggle-chart-mode-q');
        const btnT = document.getElementById('toggle-chart-mode-t');
        if (btnQ && btnT) {
            btnQ.classList.toggle('active', mode === 'questions');
            btnT.classList.toggle('active', mode === 'time');
        }
        this.drawDynamicsChart();
    },

    drawDynamicsChart: function(hoveredIndex = null) {
        const canvas = document.getElementById('home-dynamics-canvas');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        const mode = this.state.chartMode || 'questions';

        const last7Days = [];
        const startDate = new Date(2026, 5, 3); // June 3rd
        for (let i = 0; i < 12; i++) {
            const d = new Date(startDate);
            d.setDate(startDate.getDate() + i);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const dayNum = String(d.getDate()).padStart(2, '0');
            last7Days.push(`${y}-${m}-${dayNum}`);
        }

        const courseStyles = {
            "Atatürk İlkeleri ve İnkılap Tarihi II": { g1: "#ef4444", g2: "#f97316" },
            "Görsel İletişim Tasarımı": { g1: "#6366f1", g2: "#8b5cf6" },
            "Grafik Tasarım II": { g1: "#10b981", g2: "#06b6d4" },
            "Masaüstü Yayıncılık": { g1: "#3b82f6", g2: "#6366f1" },
            "Tasarımda Tipografi": { g1: "#f59e0b", g2: "#ef4444" },
            "Türk Dili II": { g1: "#8b5cf6", g2: "#ec4899" }
        };
        const defaultStyle = { g1: "#6366f1", g2: "#8b5cf6" };

        const chartData = last7Days.map(date => {
            const dayData = this.dailyHistory[date] || {};
            const coursesData = [];
            let totalVal = 0;
            const coursesList = ["Grafik Tasarım II", "Görsel İletişim Tasarımı", "Masaüstü Yayıncılık", "Tasarımda Tipografi", "Atatürk İlkeleri ve İnkılap Tarihi II", "Türk Dili II"];
            coursesList.forEach(c => {
                const data = dayData[c] || { time: 0, correct: 0, wrong: 0 };
                const val = mode === 'questions' ? (data.correct + data.wrong) : Math.round(data.time / 60);
                coursesData.push({ course: c, val, correct: data.correct, wrong: data.wrong, time: data.time });
                totalVal += val;
            });
            return { date, totalVal, coursesData };
        });

        // Find the maximum value to scale the Y axis
        let maxVal = 10;
        chartData.forEach(day => {
            day.coursesData.forEach(c => {
                if (c.val > maxVal) maxVal = c.val;
            });
        });
        const gridMax = Math.ceil(maxVal / 5) * 5;

        const dpr = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width * dpr;
        canvas.height = rect.height * dpr;
        ctx.scale(dpr, dpr);

        const w = rect.width;
        const h = rect.height;
        const padding = { top: 20, right: 0, bottom: 40, left: 0 };

        ctx.clearRect(0, 0, w, h);

        // Draw grid lines
        ctx.strokeStyle = "rgba(255, 255, 255, 0.05)";
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);

        const chartWidth = w - padding.left - padding.right;
        const stepWidth = chartWidth / (last7Days.length - 1);

        // 1. Horizontal grid lines
        const gridLinesCount = 4;
        for (let i = 0; i <= gridLinesCount; i++) {
            const val = Math.round((gridMax / gridLinesCount) * i);
            const y = h - padding.bottom - ((val / gridMax) * (h - padding.top - padding.bottom));
            
            ctx.beginPath();
            ctx.moveTo(padding.left, y);
            ctx.lineTo(w - padding.right, y);
            ctx.stroke();
        }

        // 2. Vertical grid lines
        chartData.forEach((day, index) => {
            const x = padding.left + index * stepWidth;
            ctx.beginPath();
            ctx.moveTo(x, padding.top);
            ctx.lineTo(x, h - padding.bottom);
            ctx.stroke();
        });

        ctx.setLineDash([]); // Reset line dash

        // 3. Draw Y-axis labels
        ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
        ctx.font = "500 0.72rem sans-serif";
        ctx.textAlign = "left";
        ctx.textBaseline = "bottom";
        for (let i = 0; i <= gridLinesCount; i++) {
            const val = Math.round((gridMax / gridLinesCount) * i);
            const y = h - padding.bottom - ((val / gridMax) * (h - padding.top - padding.bottom));
            ctx.fillText(val + (mode === 'time' ? ' d' : ''), 6, y - 4);
        }

        // Draw X-axis labels
        ctx.textBaseline = "top";
        ctx.font = "500 0.65rem sans-serif";
        chartData.forEach((day, index) => {
            const x = padding.left + index * stepWidth;
            const dObj = new Date(day.date + 'T00:00:00');
            const dayNum = String(dObj.getDate()).padStart(2, '0');
            const monthName = dObj.toLocaleDateString('en-US', { month: 'long' });
            const label = `${dayNum} ${monthName}`;
            
            ctx.fillStyle = "rgba(255, 255, 255, 0.45)";
            if (index === 0) {
                ctx.textAlign = "left";
            } else if (index === last7Days.length - 1) {
                ctx.textAlign = "right";
            } else {
                ctx.textAlign = "center";
            }
            ctx.fillText(label, x, h - padding.bottom + 14);
        });

        // Draw vertical hovered indicator line
        if (hoveredIndex !== null) {
            const x = padding.left + hoveredIndex * stepWidth;
            ctx.beginPath();
            ctx.strokeStyle = "rgba(255, 255, 255, 0.15)";
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);
            ctx.moveTo(x, padding.top);
            ctx.lineTo(x, h - padding.bottom);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Draw lines for each course
        const coursesList = ["Grafik Tasarım II", "Görsel İletişim Tasarımı", "Masaüstü Yayıncılık", "Tasarımda Tipografi", "Atatürk İlkeleri ve İnkılap Tarihi II", "Türk Dili II"];
        
        // Draw lines for each course using smooth Catmull-Rom splines
        coursesList.forEach(courseName => {
            const style = courseStyles[courseName] || defaultStyle;
            
            const points = chartData.map((day, index) => {
                const x = padding.left + index * stepWidth;
                const cData = day.coursesData.find(d => d.course === courseName);
                const val = cData ? cData.val : 0;
                const y = h - padding.bottom - ((val / gridMax) * (h - padding.top - padding.bottom));
                return { x, y };
            });

            ctx.beginPath();
            ctx.strokeStyle = style.g1;
            ctx.lineWidth = 3;
            ctx.lineCap = 'round';
            ctx.lineJoin = 'round';

            if (points.length > 0) {
                ctx.moveTo(points[0].x, points[0].y);
                for (let i = 0; i < points.length - 1; i++) {
                    const p0 = points[Math.max(i - 1, 0)];
                    const p1 = points[i];
                    const p2 = points[i + 1];
                    const p3 = points[Math.min(i + 2, points.length - 1)];
                    
                    const tension = 0.2;
                    const cp1x = p1.x + (p2.x - p0.x) * tension;
                    const cp1y = p1.y + (p2.y - p0.y) * tension;
                    const cp2x = p2.x - (p3.x - p1.x) * tension;
                    const cp2y = p2.y - (p3.y - p1.y) * tension;
                    
                    ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                }
                ctx.stroke();
            }
        });

        // Only draw dots for the hovered day to keep the chart clean and modern
        if (hoveredIndex !== null) {
            coursesList.forEach(courseName => {
                const style = courseStyles[courseName] || defaultStyle;
                const day = chartData[hoveredIndex];
                const x = padding.left + hoveredIndex * stepWidth;
                const cData = day.coursesData.find(d => d.course === courseName);
                const val = cData ? cData.val : 0;
                const y = h - padding.bottom - ((val / gridMax) * (h - padding.top - padding.bottom));
                
                ctx.beginPath();
                ctx.arc(x, y, 5.5, 0, 2 * Math.PI);
                ctx.fillStyle = style.g1;
                ctx.fill();
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 2;
                ctx.stroke();
            });
        }

        const tooltip = document.getElementById('chart-tooltip');
        if (!tooltip) return;

        if (canvas._onMouseMove) canvas.removeEventListener('mousemove', canvas._onMouseMove);

        canvas._onMouseMove = (e) => {
            const rect = canvas.getBoundingClientRect();
            const mouseX = e.clientX - rect.left;
            const mouseY = e.clientY - rect.top;

            const hoveredIdx = Math.max(0, Math.min(last7Days.length - 1, Math.round((mouseX - padding.left) / stepWidth)));

            if (hoveredIdx !== this._lastHoveredIndex) {
                this._lastHoveredIndex = hoveredIdx;
                this.drawDynamicsChart(hoveredIdx);
            }

            if (hoveredIdx !== null) {
                const dayData = chartData[hoveredIdx];
                const dObj = new Date(dayData.date + 'T00:00:00');
                const dayNum = String(dObj.getDate()).padStart(2, '0');
                const monthName = dObj.toLocaleDateString('en-US', { month: 'long' });
                const weekdayName = dObj.toLocaleDateString('en-US', { weekday: 'long' });
                const dateStr = `${dayNum} ${monthName}, ${weekdayName}`;
                
                let detailsHTML = `<div style="font-weight:700; font-size:0.8rem; margin-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.1); padding-bottom:4px;">${dateStr}</div>`;
                let hasData = false;

                dayData.coursesData.forEach(seg => {
                    if (seg.val === 0) return;
                    hasData = true;
                    const style = courseStyles[seg.course] || defaultStyle;
                    const valStr = mode === 'questions' 
                        ? `<span style="color:#22c55e;font-weight:700;">${seg.correct} D</span> / <span style="color:#ef4444;font-weight:700;">${seg.wrong} S</span>`
                        : `<span style="color:var(--text-main);font-weight:700;">${Math.round(seg.time/60)}</span> dəq`;
                    
                    detailsHTML += `
                        <div style="display:flex; align-items:center; gap:8px; font-size:0.72rem; margin-bottom:4px;">
                            <span style="width:8px; height:8px; border-radius:50%; background: ${style.g1}; flex-shrink:0;"></span>
                            <span style="flex:1; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:rgba(255,255,255,0.7);">${seg.course}</span>
                            <span>${valStr}</span>
                        </div>
                    `;
                });

                if (!hasData) {
                    detailsHTML += `<div style="font-size:0.72rem; color:var(--text-muted); text-align:center;">Fəaliyyət yoxdur</div>`;
                }

                tooltip.innerHTML = detailsHTML;
                tooltip.style.display = 'block';
                tooltip.style.left = Math.min(rect.width - 200, Math.max(10, e.clientX - rect.left + 15)) + 'px';
                tooltip.style.top = Math.min(rect.height - 120, Math.max(10, e.clientY - rect.top - 50)) + 'px';
            } else {
                tooltip.style.display = 'none';
            }
        };

        canvas.addEventListener('mousemove', canvas._onMouseMove);
        canvas.addEventListener('mouseleave', () => { 
            tooltip.style.display = 'none'; 
            if (this._lastHoveredIndex !== null) {
                this._lastHoveredIndex = null;
                this.drawDynamicsChart(null);
            }
        });
    },

    saveStats: function () { 
        localStorage.setItem(this.DB.stats, JSON.stringify(this.stats)); 
        localStorage.setItem('qa_v31_h', JSON.stringify(this.dailyHistory));
    },
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

    changeFontScale: function (scale) {
        this.settings.scale = scale;
        this.applyTheme();
        localStorage.setItem(this.DB.settings, JSON.stringify(this.settings));
        this.showSettings();
    },

    exportBackup: function () {
        const backup = {};
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key.startsWith('qa_v31_') || key === 'theme' || key === 'qa_v31_h') {
                backup[key] = localStorage.getItem(key);
            }
        }
        return JSON.stringify(backup);
    },

    copyBackupToClipboard: function () {
        const txt = document.getElementById('backup-export-text');
        if (!txt) return;
        txt.select();
        txt.setSelectionRange(0, 99999);
        navigator.clipboard.writeText(txt.value).then(() => {
            const btn = document.getElementById('btn-copy-backup');
            if (btn) {
                const oldText = btn.textContent;
                btn.textContent = "Kopyalandı! ✓";
                btn.style.background = "var(--active)";
                btn.style.color = "white";
                setTimeout(() => {
                    btn.textContent = oldText;
                    btn.style.background = "";
                    btn.style.color = "";
                }, 2000);
            }
        }).catch(err => {
            alert("Kopyalama xətası: " + err);
        });
    },

    importBackup: function () {
        const txt = document.getElementById('backup-import-text');
        if (!txt || !txt.value.trim()) {
            alert("Zəhmət olmasa, ehtiyat nüsxə JSON-unu daxil edin.");
            return;
        }
        try {
            const data = JSON.parse(txt.value.trim());
            let count = 0;
            for (const [key, val] of Object.entries(data)) {
                if (key.startsWith('qa_v31_') || key === 'theme' || key === 'qa_v31_h') {
                    const stringValue = typeof val === 'string' ? val : JSON.stringify(val);
                    localStorage.setItem(key, stringValue);
                    count++;
                }
            }
            if (count > 0) {
                alert("Məlumatlar uğurla idxal edildi! Səhifə yenilənəcək.");
                this.loadData();
                if (typeof FirebaseSync !== 'undefined' && FirebaseSync.saveToCloud) {
                    FirebaseSync.saveToCloud();
                }
                location.reload();
            } else {
                alert("İdxal üçün uyğun açarlar (qa_v31_) tapılmadı.");
            }
        } catch (e) {
            alert("İdxal xətası: Daxil edilən məlumat düzgün JSON formatında deyil. Zəhmət olmasa, kopyaladığınız mətni tam olaraq daxil etdiyinizdən əmin olun.");
        }
    },

    showSettings: function () {
        document.getElementById('modal-overlay').style.display = 'flex';
        document.getElementById('modal-title').textContent = "Tənzimləmələr";
        
        const scale = this.settings.scale || 1;
        const backupData = this.exportBackup();
        
        document.getElementById('modal-body').innerHTML = `
            <div class="settings-container" style="display:flex; flex-direction:column; gap:24px; padding:10px 0;">
                <!-- Font Scale Section -->
                <div class="settings-section" style="border-bottom:1px solid var(--border); padding-bottom:20px;">
                    <h4 style="margin-bottom:12px; font-weight:600; color:var(--text-main);">Şrift Ölçüsü</h4>
                    <div style="display:flex; gap:10px;">
                        <button class="nav-pill ${scale === 0.9 ? 'active' : ''}" onclick="window.changeFontScale(0.9)">Kiçik</button>
                        <button class="nav-pill ${scale === 1 ? 'active' : ''}" onclick="window.changeFontScale(1)">Orta</button>
                        <button class="nav-pill ${scale === 1.15 ? 'active' : ''}" onclick="window.changeFontScale(1.15)">Böyük</button>
                    </div>
                </div>
                
                <!-- Backup & Restore Section -->
                <div class="settings-section">
                    <h4 style="margin-bottom:8px; font-weight:600; color:var(--text-main);">Məlumatların Ehtiyat Nüsxəsi</h4>
                    <p style="font-size:0.8rem; color:var(--text-muted); margin-bottom:15px; line-height:1.4;">
                        Statistikalarınızı, səhvlərinizi və digər datalarınızı başqa bir cihaza/domenə keçirmək üçün istifadə edin.
                    </p>
                    
                    <!-- Export Box -->
                    <div style="margin-bottom:18px;">
                        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                            <span style="font-size:0.75rem; font-weight:700; color:var(--text-muted); text-transform:uppercase;">Ehtiyat Nüsxəni İxrac Et</span>
                            <button id="btn-copy-backup" onclick="window.copyBackupToClipboard()" style="background:var(--bg-element); border:1px solid var(--border); color:var(--text-main); font-size:0.75rem; padding:4px 10px; border-radius:6px; cursor:pointer; font-weight:600; transition:all 0.2s;">Kopyala</button>
                        </div>
                        <textarea id="backup-export-text" readonly style="width:100%; height:80px; background:var(--bg-input); border:1px solid var(--border); border-radius:8px; padding:8px; font-family:monospace; font-size:0.75rem; color:var(--text-muted); resize:none; outline:none; white-space:pre-wrap; word-break:break-all;">${backupData}</textarea>
                    </div>
                    
                    <!-- Import Box -->
                    <div>
                        <span style="font-size:0.75rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; display:block; margin-bottom:6px;">Ehtiyat Nüsxəni İdxal Et</span>
                        <textarea id="backup-import-text" placeholder="Bərpa etmək istədiyiniz JSON məlumatını bura yapışdırın..." style="width:100%; height:80px; background:var(--bg-input); border:1px solid var(--border); border-radius:8px; padding:8px; font-family:monospace; font-size:0.75rem; color:var(--text-main); resize:none; outline:none; margin-bottom:10px; transition:border-color 0.2s;"></textarea>
                        <div style="display:flex; justify-content:space-between; align-items:center;">
                            <span style="font-size:0.7rem; color:var(--wrong); font-weight:500;">⚠️ Mövcud lokal datanız silinəcək!</span>
                            <button onclick="window.importBackup()" style="background:var(--accent); border:none; color:white; font-size:0.8rem; padding:8px 16px; border-radius:8px; cursor:pointer; font-weight:600; transition:opacity 0.2s;">İdxal Et</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
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
window.closeModal = (e) => {
    const todoModal = document.getElementById('todo-modal');
    if (todoModal && todoModal.style.display === 'flex') {
        if (typeof TodoApp !== 'undefined') TodoApp.closeModal();
    } else {
        const overlay = document.getElementById('modal-overlay');
        if (overlay) overlay.style.display = 'none';
        
        // Redirection on closing modal
        if (QuizApp.state.view === 'quiz') {
            if (QuizApp.state.course === 'Ümumi Toplam' || QuizApp.state.course === QuizApp.MOCK_KEY) {
                QuizApp.showOverallDashboard();
            } else if (QuizApp.state.course && typeof CONFIG !== 'undefined' && CONFIG[QuizApp.state.course] !== undefined) {
                QuizApp.showCourseDashboard(QuizApp.state.course);
            } else {
                QuizApp.start();
            }
        }
    }
};

window.setChartMode = QuizApp.setChartMode.bind(QuizApp);
window.resetStatistics = QuizApp.resetStatistics.bind(QuizApp);
window.handleSearch = QuizApp.handleSearch.bind(QuizApp);
window.showStatDetails = QuizApp.showStatDetails.bind(QuizApp);
window.showStatDetailsModal = QuizApp.showStatDetailsModal.bind(QuizApp);
window.startMock = QuizApp.startMock.bind(QuizApp);
window.startCourseWrongExam = QuizApp.startCourseWrongExam.bind(QuizApp);
window.startCourseMixedExam = QuizApp.startCourseMixedExam.bind(QuizApp);
window.setDashboardLayout = QuizApp.setDashboardLayout.bind(QuizApp);
window.changeFontScale = QuizApp.changeFontScale.bind(QuizApp);
window.exportBackup = QuizApp.exportBackup.bind(QuizApp);
window.copyBackupToClipboard = QuizApp.copyBackupToClipboard.bind(QuizApp);
window.importBackup = QuizApp.importBackup.bind(QuizApp);
window.startMultiUnit = QuizApp.startMultiUnit.bind(QuizApp);

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

window.addEventListener('resize', () => {
    const dynamicsCanvas = document.getElementById('home-dynamics-canvas');
    if (dynamicsCanvas) {
        QuizApp.drawDynamicsChart();
    }
    const donutCanvas = document.getElementById('home-donut-canvas');
    if (donutCanvas) {
        let globalCorrect = 0;
        let globalWrong = 0;
        let globalTotalAns = 0;
        Object.values(QuizApp.stats).forEach(s => {
            if (s.c) globalCorrect += s.c;
            if (s.w) globalWrong += s.w;
            if (s.t) globalTotalAns += s.t;
        });
        let globalTotalQ = typeof quizData !== 'undefined' ? quizData.length : 0;
        const unanswered = Math.max(0, globalTotalQ - globalTotalAns);
        QuizApp.renderHomeCharts(globalCorrect, globalWrong, unanswered);
    }
});

function fireConfetti() {
    const canvas = document.getElementById('confetti-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    
    const colors = ['#6366f1', '#8b5cf6', '#10b981', '#ef4444', '#f59e0b', '#3b82f6'];
    const particles = [];
    
    for (let i = 0; i < 150; i++) {
        particles.push({
            x: Math.random() * canvas.width,
            y: Math.random() * canvas.height - canvas.height,
            r: Math.random() * 6 + 4,
            d: Math.random() * canvas.height,
            color: colors[Math.floor(Math.random() * colors.length)],
            tilt: Math.random() * 10 - 5,
            tiltAngleIncremental: Math.random() * 0.07 + 0.02,
            tiltAngle: 0
        });
    }
    
    let animId;
    const start = Date.now();
    
    function draw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        let active = false;
        
        particles.forEach(p => {
            p.tiltAngle += p.tiltAngleIncremental;
            p.y += (Math.cos(p.d) + 3 + p.r / 2) / 2;
            p.x += Math.sin(p.tiltAngle);
            p.tilt = Math.sin(p.tiltAngle - p.r / 2) * 15;
            
            if (p.y <= canvas.height) {
                active = true;
                ctx.beginPath();
                ctx.lineWidth = p.r;
                ctx.strokeStyle = p.color;
                ctx.moveTo(p.x + p.tilt + p.r / 2, p.y);
                ctx.lineTo(p.x + p.tilt, p.y + p.tilt + p.r / 2);
                ctx.stroke();
            }
        });
        
        if (active && Date.now() - start < 4000) {
            animId = requestAnimationFrame(draw);
        } else {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
    }
    
    draw();
}

document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
        if (QuizApp.timer && QuizApp.activeCourse) {
            const now = Date.now();
            const totalElapsed = Math.floor((now - QuizApp.sessionStartTime) / 1000);
            const delta = totalElapsed - QuizApp.secondsElapsedInSession;
            if (delta > 0) {
                QuizApp.stats[QuizApp.activeCourse].time += delta;
                QuizApp.recordDailyHistory(QuizApp.activeCourse, null, delta);
            }
            clearInterval(QuizApp.timer);
            QuizApp.timer = null;
            QuizApp.saveStats();
        }
    } else if (document.visibilityState === 'visible') {
        if (QuizApp.activeCourse && !QuizApp.timer) {
            QuizApp.sessionStartTime = Date.now();
            QuizApp.secondsElapsedInSession = 0;
            const c = QuizApp.activeCourse;
            QuizApp.timer = setInterval(() => { 
                if (QuizApp.activeCourse) { 
                    const now = Date.now();
                    const totalElapsed = Math.floor((now - QuizApp.sessionStartTime) / 1000);
                    const delta = totalElapsed - QuizApp.secondsElapsedInSession;
                    if (delta > 0) {
                        QuizApp.stats[c].time += delta; 
                        QuizApp.recordDailyHistory(c, null, delta);
                        QuizApp.secondsElapsedInSession = totalElapsed;
                        if (QuizApp.secondsElapsedInSession % 10 === 0) QuizApp.saveStats(); 
                    }
                } 
            }, 1000);
        }
    }
});
