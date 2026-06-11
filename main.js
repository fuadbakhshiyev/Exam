const LifeOS = {
    currentApp: null,

    init: function () {
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

        // Home Button
        const homeBtn = document.createElement('button');
        homeBtn.className = 'menu-btn active';
        homeBtn.id = 'btn-home';
        homeBtn.innerHTML = `<span>Ana Səhifə</span>`;
        homeBtn.onclick = () => {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            homeBtn.classList.add('active');
            QuizApp.start();
            if (window.innerWidth <= 768) toggleSidebar();
        };
        container.appendChild(homeBtn);

        // PDF Exams (İmtahan) Button
        const pdfExamsBtn = document.createElement('button');
        pdfExamsBtn.className = 'menu-btn';
        pdfExamsBtn.id = 'btn-pdf-exams';
        pdfExamsBtn.innerHTML = `<span>İmtahan</span>`;
        pdfExamsBtn.onclick = () => {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            pdfExamsBtn.classList.add('active');
            QuizApp.showPdfExamsDashboard();
            if (window.innerWidth <= 768) toggleSidebar();
        };
        container.appendChild(pdfExamsBtn);

        Object.keys(CONFIG).forEach(c => {
            const btn = document.createElement('button'); btn.className = 'menu-btn course-btn';
            btn.innerHTML = `<span>${c}</span>`; btn.id = `btn-${c}`;
            btn.onclick = () => {
                document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
                document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                QuizApp.selectCat(c, 'units');
            };
            container.appendChild(btn);
        });

        container.appendChild(document.createElement('br'));

        // Group Stats and Tools under a single dropdown (above Settings)
        const toolsBtn = document.createElement('button');
        toolsBtn.className = 'menu-btn';
        toolsBtn.id = 'btn-tools';
        toolsBtn.innerHTML = `<span>Alətlər & Statistika</span> <span>▾</span>`;
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
                if (window.innerWidth <= 768) toggleSidebar();
            };
            toolsSub.appendChild(b);
        };

        addSubBtn('Statistika', () => QuizApp.showStats());
        addSubBtn('Böyük Sınaq', () => QuizApp.startMock(), 'mock-btn');
        addSubBtn('Ən Çətinlər', () => QuizApp.startHard(), 'hard-btn');
        addSubBtn('Seçilmişlər', () => QuizApp.showBookmarks(), 'star-btn');
        addSubBtn('Səhvlərim', () => QuizApp.showWrong(), 'wrong-btn');

        container.appendChild(toolsBtn);
        container.appendChild(toolsSub);

        // Add Settings button at the bottom of the list
        const addSettingsBtn = (t, f) => {
            const b = document.createElement('button'); b.className = 'menu-btn special-btn';
            b.innerHTML = `<span>${t}</span>`; b.onclick = () => { f(); if (window.innerWidth <= 768) toggleSidebar(); };
            container.appendChild(b);
        };
        addSettingsBtn('Ayarlar', () => QuizApp.showSettings());
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

        if (window.innerWidth <= 768) toggleSidebar();
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

window.onload = function () {
    LifeOS.init();
};
