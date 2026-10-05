const LifeOS = {
    currentApp: null,

    init: async function () {
        this.renderSidebar();
        QuizApp.init(); // Pre-load Quiz Data

        // Default App
        this.switchApp('quiz');

        // Init Sidebar Timer
        if (window.SidebarTimer) {
            window.SidebarTimer.init();
        }
    },

    renderSidebar: function () {
        const list = document.getElementById('sidebar-list');
        list.innerHTML = "";

        // App Switcher Items
        const apps = [
            { id: 'quiz', icon: '📝', name: 'İmtahan' }
        ];

        apps.forEach(app => {
            // Container for sub-items (Course list)
            const subContainer = document.createElement('div');
            subContainer.id = `sub-container-${app.id}`;
            subContainer.className = 'app-sub-container';
            subContainer.style.display = 'block';
            list.appendChild(subContainer);
        });

        // Initialize Sub-menu
        this.renderQuizMenu();
    },

    renderQuizMenu: function () {
        const container = document.getElementById('sub-container-quiz');
        container.innerHTML = "";

        const icon = (d) => `<svg class="sbx-ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
        const group = (label) => {
            const g = document.createElement('div'); g.className = 'sbx-grp'; g.textContent = label;
            container.appendChild(g);
        };
        const activate = (btn) => {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        };
        const courseBtn = (c, inner) => {
            const btn = document.createElement('button'); btn.className = 'menu-btn course-btn';
            btn.innerHTML = inner; btn.id = `btn-${c}`;
            btn.onclick = () => { activate(btn); QuizApp.selectCat(c, 'units'); };
            container.appendChild(btn);
        };

        // Subjects, each with a small progress ring
        group('Fənlər');
        SUBJECTS.forEach((c, i) => {
            courseBtn(c, `<svg class="sbx-ring" viewBox="0 0 20 20"><circle class="b" cx="10" cy="10" r="7"></circle><circle class="f" id="nav-ring-${i}" cx="10" cy="10" r="7" stroke-dasharray="0 44"></circle></svg><span>${c}</span><span class="sbx-meta" id="nav-pct-${i}">0%</span>`);
        });

        // Exams and the mixed bank
        group('Sınaq');
        const examCount = typeof pdfExamsData !== 'undefined' ? Object.keys(pdfExamsData).reduce((n, k) => n + pdfExamsData[k].length, 0) : 0;
        const pdfExamsBtn = document.createElement('button');
        pdfExamsBtn.className = 'menu-btn';
        pdfExamsBtn.id = 'btn-pdf-exams';
        pdfExamsBtn.innerHTML = `${icon('<path d="M7 3h8l4 4v14H7z"></path><path d="M10 12h6M10 16h6"></path>')}<span>İmtahan</span><span class="sbx-meta">${examCount}</span>`;
        pdfExamsBtn.onclick = () => {
            activate(pdfExamsBtn);
            QuizApp.showPdfExamsDashboard();
            closeSidebar();
        };
        container.appendChild(pdfExamsBtn);
        if (CONFIG["Mixed"]) {
            const mixedCount = typeof ataaofSorularData !== 'undefined' ? ataaofSorularData.length : 0;
            courseBtn("Mixed", `${icon('<path d="M3 7h4l8 10h6M3 17h4l2.5-3M14.5 10L15 7h6"></path><path d="M18 4l3 3-3 3M18 14l3 3-3 3"></path>')}<span>Mixed</span><span class="sbx-meta">${mixedCount}</span>`);
        }

        group('Digər');



        // Group Stats and Tools under a single dropdown (above Settings)
        const toolsBtn = document.createElement('button');
        toolsBtn.className = 'menu-btn';
        toolsBtn.id = 'btn-tools';
        toolsBtn.innerHTML = `${icon('<path d="M4 20V10M10 20V4M16 20v-8M22 20H2"></path>')}<span>Alətlər & Statistika</span><span class="sbx-meta">▾</span>`;
        toolsBtn.onclick = () => {
            const sub = document.getElementById('sub-tools');
            sub.classList.toggle('show');
        };

        const toolsSub = document.createElement('div');
        toolsSub.className = 'sub-menu';
        toolsSub.id = 'sub-tools';

        const addSubBtn = (t, f, cls = '') => {
            const b = document.createElement('button');
            b.className = `sub-btn ${cls}`;
            b.innerHTML = t;
            b.onclick = () => {
                document.querySelectorAll('.course-btn').forEach(x => x.classList.remove('active'));
                document.querySelectorAll('.menu-btn').forEach(x => x.classList.remove('active'));
                f();
                closeSidebar();
            };
            toolsSub.appendChild(b);
        };

        addSubBtn('Statistika', () => QuizApp.showStats());
        addSubBtn('Böyük Sınaq', () => QuizApp.startMock(), 'mock-btn');
        addSubBtn('Ən Çətinlər', () => QuizApp.startHard(), 'hard-btn');
        addSubBtn('Seçilmişlər', () => QuizApp.showBookmarks(), 'star-btn');
        addSubBtn('Səhvlərim', () => QuizApp.showWrong(), 'wrong-btn');
        addSubBtn('Ziddiyyətli Suallar', () => QuizApp.showConflictingQuestions(), 'conflict-btn');

        container.appendChild(toolsBtn);
        container.appendChild(toolsSub);

        // Add Settings button at the bottom of the list
        const addSettingsBtn = (t, f) => {
            const b = document.createElement('button'); b.className = 'menu-btn special-btn';
            b.innerHTML = `${icon('<circle cx="12" cy="12" r="3"></circle><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2"></path>')}<span>${t}</span>`; b.onclick = () => { f(); closeSidebar(); };
            container.appendChild(b);
        };
        addSettingsBtn('Ayarlar', () => QuizApp.showSettings());
    },

    // Share of each subject's questions answered so far, shown as the small ring in the menu
    updateNavProgress: function () {
        if (typeof SUBJECTS === 'undefined' || typeof QuizApp === 'undefined') return;
        SUBJECTS.forEach((c, i) => {
            let total = typeof quizData !== 'undefined' ? quizData.filter(q => q.c === c).length : 0;
            if (typeof pdfExamsData !== 'undefined' && pdfExamsData[c]) pdfExamsData[c].forEach(e => { total += e.length; });
            let answered = 0;
            Object.keys(QuizApp.stats || {}).forEach(key => {
                if (key === c || key.startsWith(c + '_pdf_')) answered += (QuizApp.stats[key] || {}).t || 0;
            });
            const pct = total ? Math.min(100, Math.round((answered / total) * 100)) : 0;
            const ring = document.getElementById(`nav-ring-${i}`);
            const txt = document.getElementById(`nav-pct-${i}`);
            if (ring) ring.setAttribute('stroke-dasharray', `${(pct / 100 * 44).toFixed(1)} 44`);
            if (txt) txt.textContent = `${pct}%`;
        });
    },



    switchApp: function (appId) {
        this.currentApp = appId;

        // Hide all sub-containers, show current
        document.querySelectorAll('.app-sub-container').forEach(c => c.style.display = 'none');
        const sub = document.getElementById(`sub-container-${appId}`);
        if (sub) {
            sub.style.display = 'block';
            // Animation class?
            sub.style.animation = "slideDown 0.3s ease";
        }

        // Toggle Daily Goal Box
        const dailyBox = document.querySelector('.daily-box');
        if (dailyBox) {
            dailyBox.style.display = appId === 'quiz' ? 'block' : 'none';
        }

        // Render Main View
        const content = document.getElementById('content-area');
        content.innerHTML = ""; // Clear

        if (appId === 'quiz') {
            QuizApp.start();
        }

        closeSidebar();
    },

    toggleQuizSub: function (c) {
        // Logic moved from old app.js but adapted
        document.querySelectorAll('.sub-menu').forEach(e => {
            if (e.id !== `sub-${c}`) e.classList.remove('show');
        });
        // Note: we need to distinguish between course buttons and app buttons.
        // The course buttons are inside sub-container-quiz.

        const sub = document.getElementById(`sub-${c}`);
        if (sub) {
            const isShown = sub.classList.contains('show');
            sub.classList.toggle('show');
        }
    }
};

const SidebarTimer = {
    seconds: 0,
    timerId: null,
    status: 'stopped', // 'stopped', 'running', 'paused'
    sessionStart: 0,
    accumulatedTime: 0,

    init: function () {
        const savedStatus = localStorage.getItem('sb_timer_status') || 'stopped';
        const savedAccumulated = parseInt(localStorage.getItem('sb_timer_accumulated') || '0', 10);
        const savedSessionStart = parseInt(localStorage.getItem('sb_timer_session_start') || '0', 10);

        if (savedStatus === 'running') {
            this.status = 'running';
            this.sessionStart = savedSessionStart;
            this.accumulatedTime = savedAccumulated;
            this.seconds = Math.floor((Date.now() - this.sessionStart) / 1000) + this.accumulatedTime;
            
            const startBtn = document.getElementById('sb-timer-start');
            if (startBtn) {
                startBtn.textContent = 'Durdur';
                startBtn.classList.add('running');
            }
            this.startInterval();
        } else if (savedStatus === 'paused') {
            this.status = 'paused';
            this.accumulatedTime = savedAccumulated;
            this.seconds = this.accumulatedTime;
            
            const startBtn = document.getElementById('sb-timer-start');
            if (startBtn) {
                startBtn.textContent = 'Davam et';
                startBtn.classList.remove('running');
            }
            this.updateDisplay();
        } else {
            this.reset();
        }
    },

    toggle: function () {
        if (this.status === 'running') {
            this.pause();
        } else {
            this.start();
        }
    },

    start: function () {
        if (this.status === 'running') return;
        this.status = 'running';
        this.sessionStart = Date.now();
        
        localStorage.setItem('sb_timer_status', 'running');
        localStorage.setItem('sb_timer_session_start', this.sessionStart.toString());
        localStorage.setItem('sb_timer_accumulated', this.accumulatedTime.toString());

        const startBtn = document.getElementById('sb-timer-start');
        if (startBtn) {
            startBtn.textContent = 'Durdur';
            startBtn.classList.add('running');
        }
        this.startInterval();
    },

    startInterval: function () {
        if (this.timerId) clearInterval(this.timerId);
        this.timerId = setInterval(() => {
            const elapsed = Math.floor((Date.now() - this.sessionStart) / 1000) + this.accumulatedTime;
            this.seconds = elapsed;
            this.updateDisplay();
        }, 200);
    },

    pause: function () {
        if (this.status !== 'running') return;
        this.status = 'paused';
        if (this.timerId) {
            clearInterval(this.timerId);
            this.timerId = null;
        }
        this.accumulatedTime = this.seconds;
        
        localStorage.setItem('sb_timer_status', 'paused');
        localStorage.setItem('sb_timer_accumulated', this.accumulatedTime.toString());

        const startBtn = document.getElementById('sb-timer-start');
        if (startBtn) {
            startBtn.textContent = 'Davam et';
            startBtn.classList.remove('running');
        }
    },

    reset: function () {
        this.status = 'stopped';
        if (this.timerId) {
            clearInterval(this.timerId);
            this.timerId = null;
        }
        this.seconds = 0;
        this.accumulatedTime = 0;
        this.sessionStart = 0;

        localStorage.removeItem('sb_timer_status');
        localStorage.removeItem('sb_timer_session_start');
        localStorage.removeItem('sb_timer_accumulated');

        const startBtn = document.getElementById('sb-timer-start');
        if (startBtn) {
            startBtn.textContent = 'Başla';
            startBtn.classList.remove('running');
        }
        this.updateDisplay();
    },

    updateDisplay: function () {
        const hrs = Math.floor(this.seconds / 3600);
        const mins = Math.floor((this.seconds % 3600) / 60);
        const secs = this.seconds % 60;
        const displayStr = String(hrs).padStart(2, '0') + ':' + String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
        const el = document.getElementById('sb-timer-display');
        if (el) el.textContent = displayStr;
    }
};
window.SidebarTimer = SidebarTimer;

// Simple global helpers for sidebar toggle
function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('open');
    document.getElementById('sidebar-overlay').classList.toggle('open');
}

// After picking something from the menu on a phone, the drawer closes (it never opens by itself)
function closeSidebar() {
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('sidebar-overlay').classList.remove('open');
}

window.onload = function () {
    LifeOS.init();
};
