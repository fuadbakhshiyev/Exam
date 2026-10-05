const COURSE_STYLES = {
    "Grafik Üretim Teknikleri": { icon: "🖨️", accent: "#10b981", g1: "#10b981", g2: "#06b6d4" },
    "Özgün Baskı Teknikleri": { icon: "🎨", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#8b5cf6" },
    "Reklam Grafiği": { icon: "📢", accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444" },
    "Tasarım Okumaları": { icon: "📖", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899" },
    "Web Tasarımının Temelleri": { icon: "💻", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#8b5cf6" },
    "Mixed": { icon: "🔀", accent: "#ec4899", g1: "#ec4899", g2: "#f43f5e" }
};

const QuizApp = {
    state: { course: null, category: null, currentTitle: null, questions: [], index: 0, answers: {}, correct: 0, wrong: 0, view: 'quiz', sessionStartTime: 0, isWrongMode: false, isSearchMode: false, isMockMode: false, isFlashcard: false },
    DB: { stats: 'qa_v32_s', wrong: 'qa_v32_w', correct: 'qa_v32_c', marks: 'qa_v32_m', daily: 'qa_v32_h', dailyGoal: 'qa_v32_dg', settings: 'qa_v32_conf', wrongCounts: 'qa_v32_wc' },
    MOCK_KEY: "🎲 Ümumi Sınaq",

    stats: {},
    wrongDB: {},
    correctDB: {},
    bookmarks: [],
    settings: { scale: 1 },
    timer: null,
    activeCourse: null,
    platformTimer: null,
    platformSessionStart: 0,
    platformSecondsElapsedInSession: 0,
    lastActivityTime: Date.now(),
    isIdle: false,
    synth: window.speechSynthesis,

    init: function () {
        if (typeof ataaofSorularData !== 'undefined' && typeof quizData !== 'undefined') {
            const hasMixed = quizData.some(q => q.c === "Mixed");
            if (!hasMixed) {
                quizData.push(...ataaofSorularData);
            }
        }
        this.loadData();
        this.buildMixedUnits();
        this.initSurpriseTimer();
        
        this.lastActivityTime = Date.now();
        this.isIdle = false;
        const updateActivity = () => {
            this.lastActivityTime = Date.now();
            if (this.isIdle) {
                this.isIdle = false;
                this.startPlatformTimer();
                if (this.activeCourse && !this.timer && !this.state.isSurpriseActive) {
                    this.resumeTimer();
                }
            }
        };
        window.addEventListener('click', updateActivity);
        window.addEventListener('keydown', updateActivity);
        window.addEventListener('touchstart', updateActivity);
        this.startPlatformTimer();
    },

    buildMixedUnits: function () {
        if (typeof quizData === 'undefined') return;
        
        const subjects = SUBJECTS;
        
        const mixedUnits = [];
        subjects.forEach((subjName, sIdx) => {
            const uVal = sIdx + 1;
            const subjQuestions = quizData.filter(q => q.c === "Mixed" && q.u === uVal);
            const totalSubjQ = subjQuestions.length;
            const chunkSize = 20;
            const numParts = Math.ceil(totalSubjQ / chunkSize);
            
            for (let part = 1; part <= numParts; part++) {
                const start = (part - 1) * chunkSize;
                const end = Math.min(part * chunkSize, totalSubjQ);
                const unitName = `${subjName} - Hissə ${part} (${start + 1}-${end})`;
                
                mixedUnits.push({
                    name: unitName,
                    subject: subjName,
                    uVal: uVal,
                    part: part,
                    startIdx: start,
                    endIdx: end
                });
            }
        });
        
        this.mixedUnitsInfo = mixedUnits;
        if (CONFIG["Mixed"]) {
            CONFIG["Mixed"].units = mixedUnits.map(mu => mu.name);
        }
    },

    selectMixedSubSubject: function (subjName) {
        this.state.mixedSubSubject = subjName;
        this.showCourseDashboard("Mixed");
    },

    // Shared pieces of the subject-style pages (cp-*)
    cpBar: function (total, ok, bad) {
        const share = n => total > 0 ? Math.min(100, (n / total) * 100).toFixed(2) : 0;
        return `<span class="cp-bar sm"><i class="ok" style="flex:0 0 ${share(ok)}%"></i><i class="bad" style="flex:0 0 ${share(bad)}%"></i><i class="rest"></i></span>`;
    },

    cpHead: function (title, sub, back, right) {
        return `
                <div class="cp-head">
                    <div class="cp-head-l">
                        <button class="qa-icon" onclick="${back || 'QuizApp.start()'}" title="Geri qayıt" aria-label="Geri qayıt">←</button>
                        <div><h1>${title}</h1><p>${sub}</p></div>
                    </div>
                    ${right || ''}
                </div>`;
    },

    cpToggle: function () {
        const layout = this.getLayout();
        return `
                    <span class="hx-tog">
                        <button class="${layout !== 'table' ? 'active' : ''}" onclick="setDashboardLayout('grid')">Kart</button>
                        <button class="${layout === 'table' ? 'active' : ''}" onclick="setDashboardLayout('table')">Cədvəl</button>
                    </span>`;
    },

    // "Multi" entry shown first in a list (card and table row)
    cpMulti: function (target, wrQs, lastStr) {
        const hard = wrQs.filter(x => ((this.wrongCounts || {})[x.q] || 0) >= 2).length;
        const veryHard = wrQs.filter(x => ((this.wrongCounts || {})[x.q] || 0) >= 3).length;
        return {
            row: `<tr onclick="QuizApp.startMultiUnit('${target}')"><td><b>Multi (səhvlərin təkrarı)</b></td><td class="m">${hard} çətin (2+) · ${veryHard} çox çətin (3+)</td><td class="n">${wrQs.length}</td><td class="n">-</td><td class="n r">${wrQs.length}</td><td class="n">-</td><td class="m">${lastStr}</td><td class="n"><span class="cp-start">Başla</span></td></tr>`,
            card: `
                    <button class="cp-u multi" onclick="QuizApp.startMultiUnit('${target}')">
                        <div class="cp-u-top"><b>Multi (səhvlərin təkrarı)</b><span class="cp-pct">${wrQs.length} səhv</span></div>
                        <div class="cp-u-nums"><span><b>${wrQs.length}</b> səhv sual</span><span class="h"><b>${hard}</b> çətin (2+)</span><span class="r"><b>${veryHard}</b> çox çətin (3+)</span></div>
                        <div class="cp-u-foot"><span>Son sınaq: ${lastStr}</span><span class="cp-start">Başla</span></div>
                    </button>`
        };
    },

    // Cards or table, by the saved layout. rows = [{ name, total, ok, bad, done, lastStr, click, extra }]
    cpList: function (rows, firstCol, action, lead) {
        const layout = this.getLayout();
        let worst = -1;
        rows.forEach((r, i) => { if (r.bad > 0 && (worst < 0 || r.bad > rows[worst].bad)) worst = i; });
        const weakTag = '<span class="cp-weak-tag">Ən çox səhv</span>';
        if (layout === 'table') return `
                <div class="cp-tbl"><table>
                    <thead><tr><th>${firstCol}</th><th>İrəliləyiş</th><th class="n">Sual</th><th class="n">Düz</th><th class="n">Səhv</th><th class="n">Faiz</th><th>Son sınaq</th><th></th></tr></thead>
                    <tbody>
                        ${lead ? lead.row : ''}
                        ${rows.map((r, i) => `<tr class="${i === worst ? 'weak' : ''}" onclick="${r.click}"><td><b>${r.name}</b>${i === worst ? ' ' + weakTag : ''}</td><td>${this.cpBar(r.total, r.ok, r.bad)}</td><td class="n">${r.total}</td><td class="n g">${r.ok}</td><td class="n r"${r.badClick && r.bad > 0 ? ` onclick="event.stopPropagation(); ${r.badClick}" title="Səhvləri yenidən işləmək üçün klikləyin"` : ''}>${r.badClick && r.bad > 0 ? `<span class="cp-link">${r.bad}</span>` : r.bad}</td><td class="n">${r.done ? Math.round((r.ok / r.done) * 100) + '%' : '-'}</td><td class="m">${r.lastStr}</td><td class="n"><span class="cp-start">${action}</span></td></tr>`).join('')}
                    </tbody>
                </table></div>`;
        return `
                <div class="cp-cards">
                    ${lead ? lead.card : ''}
                    ${rows.map((r, i) => `
                    <button class="cp-u ${r.total ? '' : 'empty'} ${i === worst ? 'weak' : ''}" onclick="${r.click}">
                        ${i === worst ? weakTag : ''}
                        <div class="cp-u-top"><b>${r.name}</b><span class="cp-pct">${r.total ? Math.min(100, Math.round((r.done / r.total) * 100)) + '%' : 'sual yoxdur'}</span></div>
                        ${this.cpBar(r.total, r.ok, r.bad)}
                        <div class="cp-u-nums">${r.extra || ''}<span><b>${r.total}</b> sual</span><span class="g"><b>${r.ok}</b> düz</span>${r.badClick && r.bad > 0 ? `<span class="r cp-link" onclick="event.stopPropagation(); ${r.badClick}" title="Səhvləri yenidən işləmək üçün klikləyin"><b>${r.bad}</b> səhv</span>` : `<span class="r"><b>${r.bad}</b> səhv</span>`}</div>
                        <div class="cp-u-foot"><span>Son sınaq: ${r.lastStr}</span><span class="cp-start">${action}</span></div>
                    </button>`).join('')}
                </div>`;
    },

    // Stats strip: total / answered / correct / wrong / accuracy plus one free cell (o.extra = [label, value])
    cpStrip: function (o) {
        const acc = o.answered > 0 ? Math.round((o.correct / o.answered) * 100) : 0;
        const cell = (cls, label, val, click, title) => click
            ? `<button class="${cls}" onclick="${click}" title="${title}"><span class="hx-cap">${label}</span><b>${val}</b></button>`
            : `<div class="${cls}"><span class="hx-cap">${label}</span><b>${val}</b></div>`;
        return `
            <section class="cp-strip">
                <div class="cp-strip-row">
                    ${cell('', 'Cəmi sual', o.totalQ)}
                    ${cell('', 'İşlənən', o.answered)}
                    ${cell('g', 'Düz', o.correct, o.onCorrect, 'Doğru cavablandırdığınız suallara baxmaq üçün klikləyin')}
                    ${cell('r', 'Səhv', o.wrong, o.onWrong, 'Səhv cavablandırdığınız suallara baxmaq üçün klikləyin')}
                    ${cell('a', 'Dəqiqlik', acc + '%')}
                    ${cell('', o.extra[0], o.extra[1])}
                </div>
                ${this.cpBar(o.totalQ, o.correct, o.wrong)}
            </section>`;
    },

    // Mixed page: subjects first, then the 20-question parts of the chosen subject
    renderMixedPage: function () {
        const c = "Mixed";
        this.stopTimer();
        if (this.state.courseTabFor !== c) { this.state.courseTab = 'units'; this.state.courseTabFor = c; }
        this.state.view = 'dashboard';
        this.state.course = c;
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        const container = document.getElementById('content-area');
        if (!container) return;
        const sub = this.state.mixedSubSubject;
        const tab = sub ? 'units' : (this.state.courseTab || 'units');

        const s = this.stats[c] || { t: 0, c: 0, w: 0, time: 0, bd: {} };
        const unitStats = (s.bd && s.bd['units']) || {};
        const lastStr = (last, done) => this.formatLastTested(last === 0 && done > 0 ? this.getCourseLastActiveDateFromHistory(c) : last, done > 0);
        const parts = (this.mixedUnitsInfo || []).map((chunk, idx) => {
            const us = unitStats[`Unit ${idx + 1}`] || {};
            const ok = us.c || 0, bad = us.w || 0;
            return { subject: chunk.subject, name: `Hissə ${chunk.part} (${chunk.startIdx + 1}-${chunk.endIdx})`, total: chunk.endIdx - chunk.startIdx, ok, bad, done: ok + bad, last: us.last || 0, lastStr: lastStr(us.last || 0, ok + bad), click: `QuizApp.startUnit('Mixed', ${idx})` };
        });

        // Level 2: the parts of one subject
        if (sub) {
            const rows = parts.filter(p => p.subject === sub);
            const sum = k => rows.reduce((a, r) => a + r[k], 0);
            container.innerHTML = `
            <div class="cp">
                ${this.cpHead(sub, `Mixed · ${rows.length} hissə`, 'QuizApp.selectMixedSubSubject(null)')}
                ${this.cpStrip({ totalQ: sum('total'), answered: sum('done'), correct: sum('ok'), wrong: sum('bad'), extra: ['Hissə', rows.length] })}
                <div class="cp-tabs-row"><span class="cp-sec">Hissələr</span>${this.cpToggle()}</div>
                ${this.cpList(rows, 'Hissə', 'Başla')}
            </div>`;
            return;
        }

        // Level 1: subjects
        const totalQ = typeof quizData !== 'undefined' ? quizData.filter(x => x.c === c).length : 0;
        const answered = s.t || 0;
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;
        const wrQs = (this.wrongDB || {})[c] || [];
        const multi = unitStats['Multi'] || {};
        const subs = SUBJECTS.map(name => {
            const ps = parts.filter(p => p.subject === name);
            const sum = k => ps.reduce((a, p) => a + p[k], 0);
            return { name, total: sum('total'), ok: sum('ok'), bad: sum('bad'), done: sum('done'), lastStr: lastStr(ps.reduce((a, p) => Math.max(a, p.last), 0), sum('done')), click: `QuizApp.selectMixedSubSubject('${name.replace(/'/g, "\\'")}')`, extra: `<span><b>${ps.length}</b> hissə</span>` };
        });
        const content = tab === 'mixed' ? `
                <section class="cp-mix">
                    <div>
                        <h2>Qarışıq sınaq</h2>
                        <p>Bütün fənlərin Mixed suallarından qarışıq 20 suallıq sürətli sınaq. Başlamaq üçün düyməyə basın.</p>
                        <button class="btn btn-pri" onclick="startCourseMixedExam('Mixed')">Sınağa başla</button>
                    </div>
                    <div class="cp-mix-stats">
                        <div><span class="hx-cap">Sual sayı</span><b>20</b></div>
                        <div><span class="hx-cap">Mənbə</span><b>${subs.filter(r => r.total).length} fənn</b></div>
                        <div><span class="hx-cap">Hələ işlənməyib</span><b>${Math.max(0, totalQ - answered)}</b></div>
                    </div>
                </section>` : this.cpList(subs, 'Fənn', 'Aç', this.cpMulti('Mixed', wrQs, lastStr(multi.last || 0, multi.t || 0)));

        container.innerHTML = `
            <div class="cp">
                ${this.cpHead('Mixed', `${subs.length} fənn · ${parts.length} hissə`, '', `<button class="btn btn-pri cp-wrong" onclick="startCourseWrongExam('Mixed')" ${wrQs.length ? '' : 'disabled'}>Səhvlərim <i>${wrQs.length}</i></button>`)}
                ${this.cpStrip({ totalQ, answered, correct: s.c || 0, wrong: s.w || 0, onCorrect: "QuizApp.reviewCourseAnswers('Mixed', true)", onWrong: "QuizApp.reviewCourseAnswers('Mixed', false)", extra: ['Vaxt', this.formatTime(s.time || 0) + ' / ' + this.formatTime(platformTime)] })}
                <p class="cp-advice">${this.getCourseAdvice(s, totalQ)}</p>
                <div class="cp-tabs-row">
                    <span class="cp-tabs" role="group" aria-label="Bölmə">
                        <button class="${tab === 'units' ? 'active' : ''}" onclick="QuizApp.setCourseTab('units')">Fənlər <i>${subs.length}</i></button>
                        <button class="${tab === 'mixed' ? 'active' : ''}" onclick="QuizApp.setCourseTab('mixed')">Qarışıq sınaq <i>20 sual</i></button>
                    </span>
                    ${tab === 'units' ? this.cpToggle() : ''}
                </div>
                ${content}
            </div>`;
    },

    loadData: function () {
        this.stats = JSON.parse(localStorage.getItem(this.DB.stats)) || {};
        this.wrongDB = JSON.parse(localStorage.getItem(this.DB.wrong)) || {};
        this.correctDB = JSON.parse(localStorage.getItem(this.DB.correct)) || {};
        this.bookmarks = JSON.parse(localStorage.getItem(this.DB.marks)) || [];
        this.settings = JSON.parse(localStorage.getItem(this.DB.settings)) || { scale: 1 };
        this.wrongCounts = JSON.parse(localStorage.getItem(this.DB.wrongCounts)) || {};
        
        this.dailyHistory = JSON.parse(localStorage.getItem('qa_v32_h')) || {};
        this.applyTheme();
        updateDaily(false);
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

        Object.keys(this.stats).forEach(courseName => {
            if (courseName === '_platform') return;
            const s = this.stats[courseName];
            if (s.time) globalTime += s.time;
            if (s.c) globalCorrect += s.c;
            if (s.w) globalWrong += s.w;
            if (s.t) globalTotalAns += s.t;
        });

        let globalAcc = 0;
        if (globalTotalAns > 0) globalAcc = Math.round((globalCorrect / globalTotalAns) * 100);
        // Mixed repeats the subjects' own questions, so it is left out of the grand total
        let globalTotalQ = typeof quizData !== 'undefined' ? quizData.filter(q => q.c !== "Mixed").length : 0;
        if (typeof pdfExamsData !== 'undefined') {
            Object.keys(pdfExamsData).forEach(subject => {
                const exams = pdfExamsData[subject] || [];
                exams.forEach(examQs => {
                    globalTotalQ += examQs.length;
                });
            });
        }

        const unanswered = Math.max(0, globalTotalQ - globalTotalAns);

        // Calculate today's stats from dailyHistory
        const tempD = new Date();
        const todayStr = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
        const todayData = this.dailyHistory ? (this.dailyHistory[todayStr] || {}) : {};
        let todayQuestions = 0;
        let todayTime = 0;
        let todayPlatformTime = todayData.platformTime || 0;
        let todayCorrect = 0;
        let todayWrong = 0;
        Object.keys(todayData).forEach(course => {
            if (course === 'platformTime') return;
            const cData = todayData[course] || {};
            todayQuestions += (cData.correct || 0) + (cData.wrong || 0);
            todayTime += (cData.time || 0);
            todayCorrect += (cData.correct || 0);
            todayWrong += (cData.wrong || 0);
        });

        const formatTodayTime = (s) => {
            if (s <= 0) return '0s';
            const h = Math.floor(s / 3600);
            const m = Math.floor((s % 3600) / 60);
            const sec = s % 60;
            let parts = [];
            if (h > 0) parts.push(`${h}h`);
            if (m > 0 || h > 0) parts.push(`${m}m`);
            parts.push(`${sec}s`);
            return parts.join(' ');
        };

        // Exam list (one row per subject)
        let examRowsHTML = "";
        let examTotal = 0;
        if (typeof pdfExamsData !== 'undefined') {
            Object.keys(pdfExamsData).forEach(subject => {
                const numExams = pdfExamsData[subject].length;
                examTotal += numExams;
                examRowsHTML += `
                    <button class="hx-ex-row" onclick="QuizApp.showPdfExamsList('${subject.replace(/'/g, "\\'")}', 'home')">
                        <b title="${subject}">${subject}</b>
                        <span class="hx-pill">${numExams} sınaq imtahanı</span>
                        <span class="hx-chev">›</span>
                    </button>
                `;
            });
        }

        const subjectCount = typeof SUBJECTS !== 'undefined' ? SUBJECTS.length : 0;
        const pctOf = (n) => globalTotalQ > 0 ? ((n / globalTotalQ) * 100).toFixed(2) : 0;
        const todaySplit = (todayCorrect + todayWrong) > 0
            ? `<i class="ok" style="flex:${todayCorrect}"></i><i class="bad" style="flex:${todayWrong}"></i>`
            : `<i class="rest"></i>`;

        container.innerHTML = `
            <div class="hx">
                <div class="hx-head">
                    <h1>Ana səhifə</h1>
                    <p>${subjectCount} fənn · ${globalTotalQ} sual · sərf edilən vaxt <b>${this.formatTime(globalTime)}</b></p>
                </div>

                <div class="hx-grid">
                    <section class="cp-strip hx-one">
                        <div class="cp-strip-row c4">
                            <div><span class="hx-cap">Dəqiqlik</span><b>${globalAcc}%</b><small>${globalCorrect} düz · ${globalWrong} səhv</small></div>
                            <div><span class="hx-cap">Cavablanan</span><b>${globalTotalAns}</b><small>${unanswered} sual işlənməyib</small></div>
                            <div><span class="hx-cap">Bu gün</span><b>${todayQuestions} sual</b><small>${todayCorrect} düz · ${todayWrong} səhv</small></div>
                            <div><span class="hx-cap">Bu gün vaxt</span><b class="platform-time-val">${formatTodayTime(todayPlatformTime)}</b><small>testdə <span class="test-time-val">${formatTodayTime(todayTime)}</span></small></div>
                        </div>
                    </section>

                    <section class="hx-card hx-subj">
                        <div class="hx-card-head"><h2>Fənn üzrə irəliləyiş</h2><span class="hx-cap">Sərf edilən vaxt: <b>${this.formatTime(globalTime)}</b></span></div>
                        <div class="hx-tbl" id="home-progress-list"></div>
                    </section>

                    <section class="hx-card hx-chart">
                        <div class="hx-card-head">
                            <h2>Fənlərin inkişaf dinamikası</h2>
                            <div class="hx-ctrl">
                                <div id="chart-courses-filters"></div>
                                <span class="hx-tog">
                                    <button id="toggle-chart-mode-q" class="${(this.state.chartMode || 'questions') === 'questions' ? 'active' : ''}" onclick="setChartMode('questions')">Suallar</button>
                                    <button id="toggle-chart-mode-t" class="${this.state.chartMode === 'time' ? 'active' : ''}" onclick="setChartMode('time')">Sərf edilən vaxt</button>
                                </span>
                            </div>
                        </div>
                        <div class="hx-chart-body" id="home-dynamics"></div>
                    </section>

                    <section class="hx-card hx-exam">
                        <div class="hx-card-head"><h2>Mövzu sınaq imtahanları</h2><span class="hx-pill">${examTotal} PDF</span></div>
                        <div class="hx-ex">
                            ${examRowsHTML || '<div class="hx-empty">İmtahan tapılmadı</div>'}
                        </div>
                    </section>
                </div>
            </div>
        `;

        this.renderHomeCharts(globalCorrect, globalWrong, unanswered);
        this.drawDynamicsChart();
        if (typeof LifeOS !== 'undefined' && LifeOS.updateNavProgress) LifeOS.updateNavProgress();

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

    // İmtahan page: every subject's midterm exams at a glance
    showPdfExamsDashboard: function () {
        this.stopTimer();
        this.state.view = 'pdf-exams-dashboard';
        this.state.pdfExamReferrer = 'dashboard';
        const container = document.getElementById('content-area');
        if (!container) return;
        const data = (typeof pdfExamsData !== 'undefined') ? pdfExamsData : {};

        let totalQ = 0, answered = 0, correct = 0, wrong = 0, time = 0, examCount = 0;
        const rows = Object.keys(data).map(subject => {
            const exams = data[subject] || [];
            const r = { subject, exams: exams.length, done: 0, total: 0, t: 0, ok: 0, bad: 0, last: 0 };
            exams.forEach((examQs, idx) => {
                const st = this.stats[`${subject}_pdf_${idx}`] || {};
                r.total += examQs.length;
                if ((st.t || 0) > 0) r.done++;
                r.t += st.t || 0; r.ok += st.c || 0; r.bad += st.w || 0;
                const bd = st.bd && st.bd['pdf-exam'] && st.bd['pdf-exam'][`İmtahan ${idx + 1}`];
                r.last = Math.max(r.last, (bd && bd.last) || 0);
                time += st.time || 0;
            });
            totalQ += r.total; answered += r.t; correct += r.ok; wrong += r.bad; examCount += r.exams;
            return r;
        });
        const acc = answered > 0 ? Math.round((correct / answered) * 100) : 0;
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;

        let rec;
        if (answered === 0) rec = "Siz hələ heç bir vize imtahanı işləməmisiniz. Biliklərinizi yoxlamaq üçün aşağıdakı fənlərdən birini seçib ilk imtahana başlayın!";
        else if (acc >= 80) rec = `Əla göstərici! Vize imtahanlarında ümumi dəqiqliyiniz <b>${acc}%</b> təşkil edir. Hələ işləmədiyiniz digər imtahanları tamamlayaraq hazırlığınızı mükəmməlləşdirə bilərsiniz.`;
        else if (acc >= 50) rec = `İrəliləyişiniz yaxşıdır (ümumi dəqiqlik: <b>${acc}%</b>). Daha yüksək nəticə üçün səhv cavablandırdığınız sualları yenidən işləməyi tövsiyə edirik.`;
        else rec = `Vize imtahanlarında dəqiqliyiniz <b>${acc}%</b> səviyyəsindədir. Sualları tələsmədən oxumağı və zəif nəticə göstərdiyiniz imtahanları təkrar işləməyi tövsiyə edirik.`;

        container.innerHTML = `
            <div class="cp">
                <div class="cp-head">
                    <div class="cp-head-l">
                        <button class="qa-icon" onclick="QuizApp.start()" title="Ana səhifə" aria-label="Ana səhifə">←</button>
                        <div><h1>İmtahan</h1><p>${rows.length} fənn · ${examCount} vize imtahanı</p></div>
                    </div>
                </div>
                ${this.cpStrip({ totalQ, answered, correct, wrong, extra: ['Vaxt', this.formatTime(time) + ' / ' + this.formatTime(platformTime)] })}
                <p class="cp-advice">${rec}</p>
                <div class="cp-tabs-row"><span class="cp-sec">Fənlər</span>${this.cpToggle()}</div>
                ${rows.length ? this.cpList(rows.map(r => ({ name: r.subject, total: r.total, ok: r.ok, bad: r.bad, done: r.t, lastStr: this.formatLastTested(r.last, r.t > 0), click: `QuizApp.showPdfExamsList('${r.subject.replace(/'/g, "\\'")}', 'dashboard')`, extra: `<span><b>${r.done} / ${r.exams}</b> imtahan</span>` })), 'Fənn', 'Aç') : '<div class="hx-empty">İmtahan tapılmadı</div>'}
            </div>`;

        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        const pdfExamsBtn = document.getElementById('btn-pdf-exams');
        if (pdfExamsBtn) {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            pdfExamsBtn.classList.add('active');
        }
    },

    // Exam list for one subject (wrong-answer review, most frequent questions, then each exam)
    buildPdfExamsHTML: function (subjectName) {
        const exams = (typeof pdfExamsData !== 'undefined') ? (pdfExamsData[subjectName] || []) : [];
        const esc = subjectName.replace(/'/g, "\\'");
        const rows = [];

        let wrongCount = 0;
        exams.forEach((examQs, idx) => { wrongCount += (this.wrongDB[`${subjectName}_pdf_${idx}`] || []).length; });
        const lead = wrongCount > 0 ? {
            row: `<tr onclick="QuizApp.startPdfSubjectAllWrQs('${esc}')"><td><b>Multi (səhvlərin təkrarı)</b></td><td class="m">Bütün vize imtahanlarındakı səhvlər</td><td class="n">${wrongCount}</td><td class="n">-</td><td class="n r">${wrongCount}</td><td class="n">-</td><td class="m">-</td><td class="n"><span class="cp-start">Başla</span></td></tr>`,
            card: `
                    <button class="cp-u multi" onclick="QuizApp.startPdfSubjectAllWrQs('${esc}')">
                        <div class="cp-u-top"><b>Multi (səhvlərin təkrarı)</b><span class="cp-pct">${wrongCount} səhv</span></div>
                        <div class="cp-u-nums"><span>Bu fənnin bütün vize imtahanlarında etdiyiniz <b>${wrongCount}</b> səhv sual</span></div>
                        <div class="cp-u-foot"><span></span><span class="cp-start">Başla</span></div>
                    </button>`
        } : null;

        const freqQs = this.getMostFrequentQuestions(subjectName);
        if (freqQs.length > 0) {
            const bd = this.stats[subjectName] && this.stats[subjectName].bd && this.stats[subjectName].bd['pdf-exam'];
            const f = (bd && bd['Ən çox düşən suallar']) || {};
            const ok = f.c || 0, bad = f.w || 0;
            rows.push({ name: 'Ən çox düşən suallar', total: freqQs.length, ok, bad, done: ok + bad, lastStr: this.formatLastTested(f.last || 0, ok + bad > 0), click: `QuizApp.startPdfSubjectFrequentQs('${esc}')` });
        }

        exams.forEach((examQs, idx) => {
            const examTitle = `İmtahan ${idx + 1}`;
            const st = this.stats[`${subjectName}_pdf_${idx}`] || {};
            const ok = st.c || 0, bad = st.w || 0;
            const last = (st.bd && st.bd['pdf-exam'] && st.bd['pdf-exam'][examTitle] && st.bd['pdf-exam'][examTitle].last) || 0;
            rows.push({ name: examTitle, total: examQs.length, ok, bad, done: ok + bad, lastStr: this.formatLastTested(last, ok + bad > 0), click: `QuizApp.startPdfExam('${esc}', ${idx})`, badClick: `QuizApp.startPdfExamWrQs('${esc}', ${idx})` });
        });
        return rows.length ? this.cpList(rows, 'İmtahan', 'Başla', lead) : '<div class="hx-empty">İmtahan tapılmadı</div>';
    },

    showPdfExamsList: function (subjectName, referrer) {
        this.stopTimer();
        this.state.view = 'pdf-exams-list';
        this.state.pdfExamSubject = subjectName;
        if (referrer) {
            this.state.pdfExamReferrer = referrer;
        }
        
        const container = document.getElementById('content-area');
        if (!container) return;
        
        const exams = (typeof pdfExamsData !== 'undefined') ? (pdfExamsData[subjectName] || []) : [];
        let totalQ = 0, answered = 0, correct = 0, wrong = 0, time = 0;
        exams.forEach((examQs, idx) => {
            const st = this.stats[`${subjectName}_pdf_${idx}`] || {};
            totalQ += examQs.length;
            answered += st.t || 0; correct += st.c || 0; wrong += st.w || 0; time += st.time || 0;
        });
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;
        const examsHTML = this.buildPdfExamsHTML(subjectName);

        container.innerHTML = `
            <div class="cp">
                <div class="cp-head">
                    <div class="cp-head-l">
                        <button class="qa-icon" onclick="if(QuizApp.state.pdfExamReferrer === 'dashboard') { QuizApp.showPdfExamsDashboard(); } else { QuizApp.start(); }" title="Geri qayıt" aria-label="Geri qayıt">←</button>
                        <div><h1>${subjectName}</h1><p>${exams.length} vize imtahanı</p></div>
                    </div>
                </div>
                ${this.cpStrip({ totalQ, answered, correct, wrong, extra: ['Vaxt', this.formatTime(time) + ' / ' + this.formatTime(platformTime)] })}
                <div class="cp-tabs-row"><span class="cp-sec">İmtahanlar</span>${this.cpToggle()}</div>
                ${examsHTML}
            </div>
        `;
        
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        
        document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
    },
    
    startPdfExam: function (subjectName, examIdx) {
        const exams = (typeof pdfExamsData !== 'undefined') ? (pdfExamsData[subjectName] || []) : [];
        const questions = exams[examIdx] || [];
        if (!questions.length) return alert("Bu imtahanda sual tapılmadı.");
        
        const title = `İmtahan ${examIdx + 1}`;
        const examKey = `${subjectName}_pdf_${examIdx}`;
        
        questions.forEach(q => {
            q.c = examKey;
            q.u = examIdx + 1;
        });
        
        this.startSpecial(questions, title, examKey);
        
        this.state.category = 'pdf-exam';
        this.state.currentTitle = title;
        this.state.selectionIndex = examIdx;
        this.state.activePdfSubject = subjectName;
    },

    startPdfExamWrQs: function (subjectName, examIdx) {
        const examKey = `${subjectName}_pdf_${examIdx}`;
        const wrQs = this.wrongDB[examKey] || [];
        if (wrQs.length === 0) {
            return alert("Bu imtahandan səhv cavablandırdığınız sual yoxdur!");
        }
        
        const title = `İmtahan ${examIdx + 1} (Səhvlərin Təkrarı)`;
        
        wrQs.forEach(q => {
            q.c = examKey;
            q.u = examIdx + 1;
        });
        
        this.startSpecial(wrQs, title, examKey);
        
        this.state.category = 'pdf-exam';
        this.state.currentTitle = title;
        this.state.selectionIndex = examIdx;
        this.state.activePdfSubject = subjectName;
    },

    startPdfSubjectAllWrQs: function (subjectName) {
        const exams = (typeof pdfExamsData !== 'undefined') ? (pdfExamsData[subjectName] || []) : [];
        let pdfWrQs = [];
        exams.forEach((examQs, idx) => {
            const examKey = `${subjectName}_pdf_${idx}`;
            if (this.wrongDB[examKey]) {
                this.wrongDB[examKey].forEach(q => {
                    q.c = examKey;
                    q.u = idx + 1;
                });
                pdfWrQs = pdfWrQs.concat(this.wrongDB[examKey]);
            }
        });

        if (pdfWrQs.length === 0) {
            return alert("Bu fənnin PDF sınaqlarından heç bir səhv cavablandırdığınız sual yoxdur!");
        }
        
        const title = `PDF Səhvlərin Təkrarı (Multi)`;
        
        this.startSpecial(pdfWrQs, title, subjectName);
        
        this.state.category = 'pdf-exam';
        this.state.currentTitle = title;
        this.state.selectionIndex = -1;
        this.state.activePdfSubject = subjectName;
    },

    getMostFrequentQuestions: function (subjectName) {
        const exams = (typeof pdfExamsData !== 'undefined') ? (pdfExamsData[subjectName] || []) : [];
        const counts = {};
        const firstOccurrences = {};
        
        exams.forEach(examQs => {
            examQs.forEach(q => {
                const qText = q.q.trim();
                counts[qText] = (counts[qText] || 0) + 1;
                if (!firstOccurrences[qText]) {
                    firstOccurrences[qText] = q;
                }
            });
        });
        
        const dupes = [];
        Object.keys(counts).forEach(qText => {
            if (counts[qText] > 1) {
                const qObj = { ...firstOccurrences[qText] };
                qObj._frequency = counts[qText];
                dupes.push(qObj);
            }
        });
        
        dupes.sort((a, b) => b._frequency - a._frequency);
        return dupes;
    },

    startPdfSubjectFrequentQs: function (subjectName) {
        const questions = this.getMostFrequentQuestions(subjectName);
        if (questions.length === 0) {
            return alert("Bu fənnin PDF sınaqlarında təkrarlanan sual tapılmadı.");
        }
        
        const title = `Ən çox düşən suallar`;
        const examKey = subjectName;
        
        const clonedQs = questions.map(q => {
            const cloned = { ...q };
            cloned.c = examKey;
            cloned.u = -2;
            return cloned;
        });
        
        this.startSpecial(clonedQs, title, examKey);
        
        this.state.category = 'pdf-exam';
        this.state.currentTitle = title;
        this.state.selectionIndex = -2;
        this.state.activePdfSubject = subjectName;
    },

    getMixedOnlyQuestions: function (subjectName) {
        if (typeof quizData === 'undefined') return [];
        
        const subjects = SUBJECTS;
        const sIdx = subjects.indexOf(subjectName);
        if (sIdx === -1) return [];
        const uVal = sIdx + 1;
        
        const mixedQs = quizData.filter(q => q.c === "Mixed" && q.u === uVal);
        const normalQs = quizData.filter(q => q.c === subjectName);
        
        const cleanText = (txt) => {
            if (!txt) return "";
            return txt.replace(/<[^>]*>/g, "")
                      .replace(/&nbsp;/g, " ")
                      .replace(/&#39;/g, "'")
                      .replace(/&quot;/g, '"')
                      .replace(/&ldquo;/g, '"')
                      .replace(/&rdquo;/g, '"')
                      .replace(/&lsquo;/g, "'")
                      .replace(/&rsquo;/g, "'")
                      .replace(/&amp;/g, '&')
                      .replace(/\s+/g, " ")
                      .trim()
                      .toLowerCase();
        };
        
        const normalSet = new Set(normalQs.map(q => cleanText(q.q)));
        
        return mixedQs.filter(q => {
            const cleaned = cleanText(q.q);
            return !normalSet.has(cleaned);
        });
    },

    startMixedOnlyQs: function (subjectName) {
        const questions = this.getMixedOnlyQuestions(subjectName);
        if (questions.length === 0) {
            return alert("Bu fənn üçün yalnız Mixed-də olan hər hansı bir fərqli sual tapılmadı.");
        }
        
        const title = `Yalnız Mixed-də olan suallar`;
        
        this.startSpecial(questions, title, subjectName);
        
        this.state.category = 'mixed-only';
        this.state.currentTitle = title;
        this.state.selectionIndex = -3;
        this.state.activePdfSubject = subjectName;
    },

    normalizeText: function (txt) {
        if (!txt) return "";
        let decoded = "";
        try {
            const doc = new DOMParser().parseFromString(txt, 'text/html');
            decoded = doc.body.textContent || "";
        } catch (e) {
            decoded = txt.replace(/<[^>]*>/g, "")
                         .replace(/&nbsp;/g, " ")
                         .replace(/&rsquo;/g, "'")
                         .replace(/&lsquo;/g, "'")
                         .replace(/&rdquo;/g, '"')
                         .replace(/&ldquo;/g, '"')
                         .replace(/&#39;/g, "'")
                         .replace(/&quot;/g, '"')
                         .replace(/&amp;/g, '&')
                         .replace(/&ouml;/g, 'ö')
                         .replace(/&Ouml;/g, 'Ö')
                         .replace(/&uuml;/g, 'ü')
                         .replace(/&Uuml;/g, 'Ü')
                         .replace(/&ccedil;/g, 'ç')
                         .replace(/&Ccedil;/g, 'Ç')
                         .replace(/&ş/g, 'ş')
                         .replace(/&Ş/g, 'Ş')
                         .replace(/&ğ/g, 'ğ')
                         .replace(/&Ğ/g, 'Ğ');
        }
        
        // Normalize spacing around apostrophes and single quotes
        decoded = decoded.replace(/\s*’\s*/g, "'")
                         .replace(/\s*‘\s*/g, "'")
                         .replace(/\s*'\s*/g, "'")
                         .replace(/\s*`\s*/g, "'");

        const replacements = {
            'ı': 'i', 'i̇': 'i', 'İ': 'i', 'ö': 'o', 'Ö': 'o', 'ü': 'u', 'Ü': 'u',
            'ç': 'c', 'Ç': 'c', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
            'â': 'a', 'î': 'i', 'û': 'u', '’': "'", '‘': "'", '`': "'",
            "'": '',
            '.': '', ',': '', ';': '', ':': '', '?': '', '!': '', '-': ' ',
            '_': ' ', '(': '', ')': '', '[': '', ']': '', '/': ' '
        };
        decoded = decoded.toLowerCase();
        Object.keys(replacements).forEach(k => {
            decoded = decoded.split(k).join(replacements[k]);
        });
        return decoded.replace(/\s+/g, " ").trim();
    },

    getConflictingQuestions: function () {
        const allQs = [];
        
        // 1. Gather from quizData
        if (typeof quizData !== 'undefined') {
            const subjects = SUBJECTS;
            quizData.forEach(q => {
                let source = q.c;
                if (q.c === 'Mixed') {
                    const subj = subjects[q.u - 1] || 'Mixed';
                    source = `${subj} (Mixed - Hissə ${q.u})`;
                } else {
                    source = `${q.c} - Unit ${q.u}`;
                }
                const ansText = q.o[q.a] || 'Unknown';
                allQs.push({
                    source: source,
                    course: q.c === 'Mixed' ? (subjects[q.u - 1] || 'Mixed') : q.c,
                    q_raw: q.q,
                    q_norm: this.normalizeText(q.q),
                    o: q.o,
                    a: q.a,
                    ans_text: ansText,
                    ans_norm: this.normalizeText(ansText),
                    q_orig: q
                });
            });
        }
        
        // 2. Gather from pdfExamsData
        if (typeof pdfExamsData !== 'undefined') {
            Object.keys(pdfExamsData).forEach(subject => {
                const exams = pdfExamsData[subject] || [];
                exams.forEach((examQs, examIdx) => {
                    examQs.forEach(q => {
                        const ansText = q.o[q.a] || 'Unknown';
                        allQs.push({
                            source: `${subject} (PDF İmtahan ${examIdx + 1})`,
                            course: subject,
                            q_raw: q.q,
                            q_norm: this.normalizeText(q.q),
                            o: q.o,
                            a: q.a,
                            ans_text: ansText,
                            ans_norm: this.normalizeText(ansText),
                            q_orig: q
                        });
                    });
                });
            });
        }
        
        // Group by q_norm
        const grouped = {};
        allQs.forEach(q => {
            if (!grouped[q.q_norm]) grouped[q.q_norm] = [];
            grouped[q.q_norm].push(q);
        });
        
        // Filter conflicts
        const conflicts = [];
        Object.keys(grouped).forEach(qNorm => {
            const occurrences = grouped[qNorm];
            const ansVariants = {};
            occurrences.forEach(occ => {
                if (!ansVariants[occ.ans_norm]) ansVariants[occ.ans_norm] = [];
                ansVariants[occ.ans_norm].push(occ);
            });
            
            if (Object.keys(ansVariants).length > 1) {
                conflicts.push({
                    q_norm: qNorm,
                    q_raw: occurrences[0].q_raw,
                    variants: ansVariants,
                    occurrences: occurrences
                });
            }
        });
        
        return conflicts;
    },

    showConflictingQuestions: function () {
        this.stopTimer();
        this.state.view = 'conflicting-questions';
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        const container = document.getElementById('content-area');
        if (!container) return;

        const conflicts = this.getConflictingQuestions();

        let cardsHTML = "";
        conflicts.forEach((c, idx) => {
            let variantsHTML = "";
            Object.keys(c.variants).forEach(ansNorm => {
                const occurrences = c.variants[ansNorm];
                const rawAns = occurrences[0].ans_text;
                
                let badgesHTML = "";
                occurrences.forEach(occ => {
                    const style = COURSE_STYLES[occ.course] || { accent: '#8b5cf6' };
                    badgesHTML += `
                        <span class="badge-meta-course" style="background: rgba(139, 92, 246, 0.08); border: 1px solid ${style.accent}30; color: ${style.accent}; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700; margin-right: 6px; margin-top: 4px; display: inline-block;">
                            ${occ.source}
                        </span>
                    `;
                });

                variantsHTML += `
                    <div style="background: var(--bg-element); padding: 12px; border-radius: 10px; border: 1px solid var(--border); margin-top: 8px;">
                        <div style="font-weight: 700; color: var(--active); font-size: 0.95rem;">Cavab: ${rawAns}</div>
                        <div style="margin-top: 6px; display: flex; flex-wrap: wrap; gap: 4px;">
                            ${badgesHTML}
                        </div>
                    </div>
                `;
            });

            cardsHTML += `
                <div class="unit-item conflict-card" data-q="${c.q_norm}" style="background: var(--bg-card); border: 1px solid var(--border); border-radius: 18px; padding: 20px; transition: all 0.2s ease; display: flex; flex-direction: column; gap: 12px;">
                    <div style="font-size: 1.05rem; font-weight: 700; color: var(--text-main); font-family: 'Plus Jakarta Sans', sans-serif;">
                        ${c.q_raw}
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 8px;">
                        ${variantsHTML}
                    </div>
                </div>
            `;
        });

        container.innerHTML = `
            <div class="cp">
                ${this.cpHead('Ziddiyyətli suallar', `Eyni suala fərqli imtahanlarda fərqli cavab verilmiş ${conflicts.length} ziddiyyət`, '', `<button class="btn btn-pri cp-wrong" onclick="QuizApp.startConflictingQuestionsQuiz()" ${conflicts.length ? '' : 'disabled'}>Sınağa başla <i>${conflicts.length}</i></button>`)}
                <input type="text" id="conflict-search" class="cp-field" placeholder="Suallarda axtarış..." oninput="QuizApp.filterConflicts(this.value)">

                <div id="conflicts-container" class="unit-list-container" style="display: grid; grid-template-columns: 1fr; gap: 16px;">
                    ${cardsHTML || '<div style="color: var(--text-muted); font-size: 0.9rem; padding: 20px;">Heç bir ziddiyyət tapılmadı.</div>'}
                </div>
            </div>
        `;
    },

    filterConflicts: function (val) {
        const query = this.normalizeText(val);
        document.querySelectorAll('.conflict-card').forEach(card => {
            const q = card.getAttribute('data-q');
            if (q.includes(query)) {
                card.style.display = 'flex';
            } else {
                card.style.display = 'none';
            }
        });
    },

    startConflictingQuestionsQuiz: function () {
        const conflicts = this.getConflictingQuestions();
        if (conflicts.length === 0) return alert("Ziddiyyətli sual tapılmadı.");
        
        const questions = conflicts.map(c => {
            const occ = c.occurrences[0];
            return occ.q_orig;
        });

        const title = "Ziddiyyətli Suallar";
        this.startSpecial(questions, title, "Bütün Fənlər");
        
        this.state.category = 'conflicting-quiz';
        this.state.currentTitle = title;
        this.state.selectionIndex = -4;
    },

    renderHomeCharts: function (correct, wrong, unanswered) {
        const courseStyles = COURSE_STYLES;

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
        list.innerHTML = `
            <div class="hx-tr hx-th"><span>Fənn</span><span>İrəliləyiş</span><span>Düz</span><span>Səhv</span><span>Dəqiqlik</span><span>Sual</span><span></span></div>
        `;

        const addRow = (name, icon, c, w, total, onClick, isTotal) => {
            const answered = c + w;
            const acc = answered > 0 ? Math.round((c / answered) * 100) : 0;
            const share = (n) => total > 0 ? ((n / total) * 100).toFixed(2) : 0;
            const row = document.createElement('button');
            row.className = 'hx-tr' + (isTotal ? ' hx-total' : '');
            row.onclick = onClick;
            row.innerHTML = `
                <span class="hx-name"><span class="hx-em">${icon}</span><b>${name}</b></span>
                <span class="hx-bar seg"><i class="ok" style="flex:0 0 ${share(c)}%"></i><i class="bad" style="flex:0 0 ${share(w)}%"></i><i class="rest"></i></span>
                <span class="hx-td g">${c}</span>
                <span class="hx-td r">${w}</span>
                <span class="hx-acc ${answered === 0 ? '' : (acc >= 80 ? 'hi' : (acc < 60 ? 'lo' : ''))}">${acc}%</span>
                <span class="hx-td m">${total}</span>
                <span class="hx-chev">›</span>
            `;
            list.appendChild(row);
        };

        addRow('Ümumi Toplam', '📊', correct, wrong, correct + wrong + unanswered, () => this.showOverallDashboard(), true);

        Object.keys(CONFIG).forEach((c) => {
            const style = courseStyles[c] || {};
            let totalQ = 0;
            if (typeof quizData !== 'undefined') totalQ = quizData.filter(q => q.c === c).length;
            if (typeof pdfExamsData !== 'undefined' && pdfExamsData[c]) {
                pdfExamsData[c].forEach(examQs => {
                    totalQ += examQs.length;
                });
            }

            let correctC = 0;
            let wrongC = 0;
            Object.keys(this.stats).forEach(key => {
                if (key === c || key.startsWith(c + '_pdf_')) {
                    const stat = this.stats[key] || {};
                    correctC += stat.c || 0;
                    wrongC += stat.w || 0;
                }
            });

            addRow(c, style.icon || '📘', correctC, wrongC, totalQ, () => this.selectCat(c, 'units'), false);
        });
    },

    selectCat: function (c, type, btn) {
        this.state = { ...this.state, view: 'dashboard', course: c, category: type, isWrongMode: false, isSearchMode: false, isMockMode: false, mixedSubSubject: null };

        document.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active-sub'));
        if (btn) btn.classList.add('active-sub');

        this.showCourseDashboard(c);
        closeSidebar();
    },

    // Short study advice for a subject, from its answered count and accuracy
    getCourseAdvice: function (s, totalQ) {
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
        return rec;
    },

    setCourseTab: function (tab) {
        this.state.courseTab = tab;
        this.showCourseDashboard(this.state.course);
    },

    // Subject page: one stats strip, a view switcher (units / mixed quiz / midterm exams) and unit cards
    renderCoursePage: function (c) {
        this.stopTimer();
        if (this.state.courseTabFor !== c) { this.state.courseTab = 'units'; this.state.courseTabFor = c; }
        this.state.view = 'dashboard';
        this.state.course = c;
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        const container = document.getElementById('content-area');
        if (!container) return;
        const esc = c.replace(/'/g, "\\'");
        const tab = this.state.courseTab || 'units';
        const layout = this.getLayout();

        // Totals (same sources as before: the subject plus its exams)
        const s = this.stats[c] || { t: 0, c: 0, w: 0, time: 0, bd: {} };
        let totalQ = typeof quizData !== 'undefined' ? quizData.filter(q => q.c === c).length : 0;
        const exams = (typeof pdfExamsData !== 'undefined' && pdfExamsData[c]) ? pdfExamsData[c] : [];
        exams.forEach(e => { totalQ += e.length; });
        let answered = 0, correctC = 0, wrongC = 0, timeC = 0;
        Object.keys(this.stats).forEach(key => {
            if (key === c || key.startsWith(c + '_pdf_')) {
                const st = this.stats[key] || {};
                answered += st.t || 0; correctC += st.c || 0; wrongC += st.w || 0; timeC += st.time || 0;
            }
        });
        const acc = answered > 0 ? Math.round((correctC / answered) * 100) : 0;
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;
        const share = (n, total) => total > 0 ? Math.min(100, (n / total) * 100).toFixed(2) : 0;
        const bar = (total, ok, bad, cls) => `<span class="cp-bar ${cls || ''}"><i class="ok" style="flex:0 0 ${share(ok, total)}%"></i><i class="bad" style="flex:0 0 ${share(bad, total)}%"></i><i class="rest"></i></span>`;

        // Units
        const unitStats = (s.bd && s.bd['units']) || {};
        const units = CONFIG[c].units.map((name, i) => {
            const us = unitStats[`Unit ${i + 1}`] || {};
            const total = typeof quizData !== 'undefined' ? quizData.filter(q => q.c === c && q.u === (i + 1)).length : 0;
            const ok = us.c || 0, bad = us.w || 0;
            let last = us.last || 0;
            if (last === 0 && ok + bad > 0) last = this.getCourseLastActiveDateFromHistory(c);
            return { name, total, ok, bad, done: ok + bad, lastStr: this.formatLastTested(last, ok + bad > 0) };
        });
        let worst = -1;
        units.forEach((u, i) => { if (u.bad > 0 && (worst < 0 || u.bad > units[worst].bad)) worst = i; });

        // Wrong answers
        const wrQs = (this.wrongDB || {})[c] || [];
        const hard = wrQs.filter(q => ((this.wrongCounts || {})[q.q] || 0) >= 2).length;
        const veryHard = wrQs.filter(q => ((this.wrongCounts || {})[q.q] || 0) >= 3).length;
        let multiLast = (unitStats['Multi'] && unitStats['Multi'].last) || 0;
        const multiDone = unitStats['Multi'] ? (unitStats['Multi'].t || 0) : 0;
        if (multiLast === 0 && multiDone > 0) multiLast = this.getCourseLastActiveDateFromHistory(c);

        // Mixed-only questions (in the Mixed bank but not in the units)
        const mixedOnly = this.getMixedOnlyQuestions(c);
        const moStat = (s.bd && s.bd['mixed-only'] && s.bd['mixed-only']['Yalnız Mixed-də olan suallar']) || {};

        const weakTag = '<span class="cp-weak-tag">Ən çox səhv</span>';
        let content = '';
        if (tab === 'mixed') {
            content = `
                <section class="cp-mix">
                    <div>
                        <h2>Qarışıq sınaq</h2>
                        <p>Fənnin bütün bölmələrindən qarışıq 20 suallıq sürətli sınaq. Başlamaq üçün düyməyə basın.</p>
                        <button class="btn btn-pri" onclick="startCourseMixedExam('${esc}')">Sınağa başla</button>
                    </div>
                    <div class="cp-mix-stats">
                        <div><span class="hx-cap">Sual sayı</span><b>20</b></div>
                        <div><span class="hx-cap">Mənbə</span><b>${units.filter(u => u.total).length} bölmə</b></div>
                        <div><span class="hx-cap">Hələ işlənməyib</span><b>${Math.max(0, totalQ - answered)}</b></div>
                    </div>
                </section>`;
        } else if (tab === 'exams') {
            content = this.buildPdfExamsHTML(c);
        } else if (layout === 'table') {
            content = `
                <div class="cp-tbl"><table>
                    <thead><tr><th>Bölmə</th><th>İrəliləyiş</th><th class="n">Sual</th><th class="n">Düz</th><th class="n">Səhv</th><th class="n">Faiz</th><th>Son sınaq</th><th></th></tr></thead>
                    <tbody>
                        <tr onclick="QuizApp.startMultiUnit('${esc}')"><td><b>Multi (səhvlərin təkrarı)</b></td><td class="m">${hard} çətin (2+) · ${veryHard} çox çətin (3+)</td><td class="n">${wrQs.length}</td><td class="n">-</td><td class="n r">${wrQs.length}</td><td class="n">-</td><td class="m">${this.formatLastTested(multiLast, multiDone > 0)}</td><td class="n"><span class="cp-start">Başla</span></td></tr>
                        ${mixedOnly.length ? `<tr onclick="QuizApp.startMixedOnlyQs('${esc}')"><td><b>Yalnız Mixed-də olan suallar</b></td><td>${bar(mixedOnly.length, moStat.c || 0, moStat.w || 0, 'sm')}</td><td class="n">${mixedOnly.length}</td><td class="n g">${moStat.c || 0}</td><td class="n r">${moStat.w || 0}</td><td class="n">${(moStat.t || 0) > 0 ? Math.round(((moStat.c || 0) / moStat.t) * 100) + '%' : '-'}</td><td class="m">${this.formatLastTested(moStat.last || 0, (moStat.t || 0) > 0)}</td><td class="n"><span class="cp-start">Başla</span></td></tr>` : ''}
                        ${units.map((u, i) => `<tr class="${i === worst ? 'weak' : ''}" onclick="QuizApp.startUnit('${esc}', ${i})"><td><b>${u.name}</b>${i === worst ? ' ' + weakTag : ''}</td><td>${bar(u.total, u.ok, u.bad, 'sm')}</td><td class="n">${u.total}</td><td class="n g">${u.ok}</td><td class="n r">${u.bad}</td><td class="n">${u.done ? Math.round((u.ok / u.done) * 100) + '%' : '-'}</td><td class="m">${u.lastStr}</td><td class="n"><span class="cp-start">Başla</span></td></tr>`).join('')}
                    </tbody>
                </table></div>`;
        } else {
            content = `
                <div class="cp-cards">
                    <button class="cp-u multi" onclick="QuizApp.startMultiUnit('${esc}')">
                        <div class="cp-u-top"><b>Multi (səhvlərin təkrarı)</b><span class="cp-pct">${wrQs.length} səhv</span></div>
                        <div class="cp-u-nums"><span><b>${wrQs.length}</b> səhv sual</span><span class="h"><b>${hard}</b> çətin (2+)</span><span class="r"><b>${veryHard}</b> çox çətin (3+)</span></div>
                        <div class="cp-u-foot"><span>Son sınaq: ${this.formatLastTested(multiLast, multiDone > 0)}</span><span class="cp-start">Başla</span></div>
                    </button>
                    ${mixedOnly.length ? `
                    <button class="cp-u" onclick="QuizApp.startMixedOnlyQs('${esc}')">
                        <div class="cp-u-top"><b>Yalnız Mixed-də olan suallar</b><span class="cp-pct">${mixedOnly.length} sual</span></div>
                        ${bar(mixedOnly.length, moStat.c || 0, moStat.w || 0, 'sm')}
                        <div class="cp-u-nums"><span><b>${mixedOnly.length}</b> sual</span><span class="g"><b>${moStat.c || 0}</b> düz</span><span class="r"><b>${moStat.w || 0}</b> səhv</span></div>
                        <div class="cp-u-foot"><span>Son sınaq: ${this.formatLastTested(moStat.last || 0, (moStat.t || 0) > 0)}</span><span class="cp-start">Başla</span></div>
                    </button>` : ''}
                    ${units.map((u, i) => `
                    <button class="cp-u ${u.total ? '' : 'empty'} ${i === worst ? 'weak' : ''}" onclick="QuizApp.startUnit('${esc}', ${i})">
                        ${i === worst ? weakTag : ''}
                        <div class="cp-u-top"><b>${u.name}</b><span class="cp-pct">${u.total ? Math.min(100, Math.round((u.done / u.total) * 100)) + '%' : 'sual yoxdur'}</span></div>
                        ${bar(u.total, u.ok, u.bad, 'sm')}
                        <div class="cp-u-nums"><span><b>${u.total}</b> sual</span><span class="g"><b>${u.ok}</b> düz</span><span class="r"><b>${u.bad}</b> səhv</span></div>
                        <div class="cp-u-foot"><span>Son sınaq: ${u.lastStr}</span><span class="cp-start">Başla</span></div>
                    </button>`).join('')}
                </div>`;
        }

        container.innerHTML = `
            <div class="cp">
                <div class="cp-head">
                    <div class="cp-head-l">
                        <button class="qa-icon" onclick="QuizApp.start()" title="Ana səhifə" aria-label="Ana səhifə">←</button>
                        <div><h1>${c}</h1><p>${units.length} bölmə · ${exams.length} vize imtahanı</p></div>
                    </div>
                    <button class="btn btn-pri cp-wrong" onclick="startCourseWrongExam('${esc}')" ${wrQs.length ? '' : 'disabled'}>Səhvlərim <i>${wrQs.length}</i></button>
                </div>

                <section class="cp-strip">
                    <div class="cp-strip-row">
                        <div><span class="hx-cap">Cəmi sual</span><b>${totalQ}</b></div>
                        <div><span class="hx-cap">İşlənən</span><b>${answered}</b></div>
                        <button class="g" onclick="QuizApp.reviewCourseAnswers('${esc}', true)" title="Doğru cavablandırdığınız suallara baxmaq üçün klikləyin"><span class="hx-cap">Düz</span><b>${correctC}</b></button>
                        <button class="r" onclick="QuizApp.reviewCourseAnswers('${esc}', false)" title="Səhv cavablandırdığınız suallara baxmaq üçün klikləyin"><span class="hx-cap">Səhv</span><b>${wrongC}</b></button>
                        <div class="a"><span class="hx-cap">Dəqiqlik</span><b>${acc}%</b></div>
                        <div><span class="hx-cap">Vaxt</span><b>${this.formatTime(timeC)} / ${this.formatTime(platformTime)}</b></div>
                    </div>
                    ${bar(totalQ, correctC, wrongC, 'sm')}
                </section>

                <p class="cp-advice">${this.getCourseAdvice(s, totalQ)}</p>

                <div class="cp-tabs-row">
                    <span class="cp-tabs" role="group" aria-label="Bölmə">
                        <button class="${tab === 'units' ? 'active' : ''}" onclick="QuizApp.setCourseTab('units')">Bölmələr <i>${units.length}</i></button>
                        <button class="${tab === 'mixed' ? 'active' : ''}" onclick="QuizApp.setCourseTab('mixed')">Qarışıq sınaq <i>20 sual</i></button>
                        <button class="${tab === 'exams' ? 'active' : ''}" onclick="QuizApp.setCourseTab('exams')">Vize imtahanları <i>${exams.length}</i></button>
                    </span>
                    ${tab !== 'mixed' ? `
                    <span class="hx-tog">
                        <button class="${layout !== 'table' ? 'active' : ''}" onclick="setDashboardLayout('grid')">Kart</button>
                        <button class="${layout === 'table' ? 'active' : ''}" onclick="setDashboardLayout('table')">Cədvəl</button>
                    </span>` : ''}
                </div>
                ${content}
            </div>
        `;
    },

    // Review the questions answered correctly or wrongly in a subject (from the stats strip)
    reviewCourseAnswers: function (c, correct) {
        const arr = ((correct ? this.correctDB : this.wrongDB) || {})[c] || [];
        if (arr.length) this.startSpecial(arr, correct ? "Doğrular" : "Səhvlər", c);
        else alert(correct ? "Doğru cavablandırdığınız sual hələ ki yoxdur və ya əvvəllər yaddaşda saxlanılmayıb." : "Əla! Səhv cavablandırdığınız sual yoxdur.");
    },

    showCourseDashboard: function (c) {
        if (c && c.includes('_pdf_')) {
            const subjectName = this.state.activePdfSubject;
            if (subjectName) {
                this.showPdfExamsList(subjectName);
                return;
            }
        }
        if (c === 'Ümumi Toplam') return this.showOverallDashboard();
        if (c === "Mixed") return this.renderMixedPage();
        return this.renderCoursePage(c);
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
            p.textContent = (this.state.category === 'units' && this.state.course !== 'Mixed') ? `Unit ${i + 1}` : t;
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
            if (this.state.category === 'units') {
                if (this.state.course === "Mixed" && this.mixedUnitsInfo) {
                    const muInfo = this.mixedUnitsInfo[idx];
                    if (muInfo) {
                        const subjQuestions = quizData.filter(q => q.c === "Mixed" && q.u === muInfo.uVal);
                        f = subjQuestions.slice(muInfo.startIdx, muInfo.endIdx);
                    }
                } else {
                    f = quizData.filter(q => q.c === this.state.course && q.u === (idx + 1));
                }
            } else if (this.state.category === 'mixed') f = quizData.filter(q => q.c === this.state.course && q.m === this.state.currentTitle);
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
            const isMixedOrWrongOrMockOrMulti = this.state.isMockMode || this.state.isWrongMode || this.state.isSearchMode || this.state.category === 'mixed' || this.state.category === 'exams' || this.state.currentTitle === 'Multi' || this.state.course === 'Mixed';
            if (isMixedOrWrongOrMockOrMulti) {
                let displayCourse = q.c;
                let displayUnit = "";
                let accentColor = '#8b5cf6';
                
                if (q.c === "Mixed") {
                    const subjects = SUBJECTS;
                    displayCourse = subjects[q.u - 1] || "Mixed";
                    displayUnit = this.state.currentTitle || "";
                    const style = COURSE_STYLES[displayCourse] || { accent: '#ec4899' };
                    accentColor = style.accent;
                } else {
                    displayUnit = (CONFIG[q.c] && CONFIG[q.c].units[q.u - 1]) || `Unit ${q.u}`;
                    const style = COURSE_STYLES[q.c] || { accent: '#8b5cf6' };
                    accentColor = style.accent;
                }
                
                qMetaEl.innerHTML = `
                    <span class="badge-meta-course" style="background: rgba(139, 92, 246, 0.08); border: 1px solid ${accentColor}30; color: ${accentColor}; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700;">${displayCourse}</span>
                    ${displayUnit ? `<span style="color: var(--text-muted); font-size: 0.75rem;">&bull;</span>
                    <span class="badge-meta-unit" style="background: var(--bg-element); border: 1px solid var(--border); color: var(--text-main); padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 600;">${displayUnit}</span>` : ''}
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
        pBar.style.display = "";
        pBar.style.flexDirection = "";
        pBar.style.width = "";
        pBar.style.gap = "";

        if (total <= 40) {
            for (let i = 0; i < total; i++) {
                const s = document.createElement('div');
                s.className = 'progress-segment ' + (i === this.state.index ? 'active' : '') + (this.state.answers[i] ? (this.state.answers[i].chosen === this.state.questions[i].a ? ' done' : ' wrong') : '');
                s.textContent = i + 1;
                s.onclick = () => { QuizApp.state.index = i; QuizApp.renderQ(); };
                pBar.appendChild(s);
            }
        } else {
            const percent = Math.round((this.state.index / total) * 100);
            pBar.style.display = 'flex';
            pBar.style.flexDirection = 'column';
            pBar.style.width = '100%';
            pBar.style.gap = '6px';
            pBar.innerHTML = `
                <div style="display: flex; justify-content: space-between; font-size: 0.85rem; color: var(--text-muted); font-weight: 600; font-family: 'Plus Jakarta Sans', sans-serif;">
                    <span>Sual: ${this.state.index + 1} / ${total}</span>
                    <span>${percent}% Tamamlandı</span>
                </div>
                <div style="height: 6px; background: rgba(255, 255, 255, 0.08); border-radius: 10px; overflow: hidden; width: 100%;">
                    <div style="height: 100%; width: ${((this.state.index + 1) / total) * 100}%; background: var(--accent-gradient); border-radius: 10px; transition: width 0.3s ease;"></div>
                </div>
            `;
        }

        let qText = q.q;
        const qWrongCount = this.wrongCounts && this.wrongCounts[q.q] ? this.wrongCounts[q.q] : 0;
        if (qWrongCount >= 2) {
            const warningColor = qWrongCount >= 3 ? 'var(--wrong)' : 'var(--hint)';
            qText += ` <span class="badge-hard" style="background: rgba(239, 68, 68, 0.08); border: 1px solid ${warningColor}; color: ${warningColor}; font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">${qWrongCount} Səhv</span>`;
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

        const ABC = ['A', 'B', 'C', 'D', 'E'];
        let correctLine = "";
        q.shuffledOpts.forEach((o, i) => {
            const abc = ABC[i];
            const div = document.createElement('div'); div.className = 'option';
            div.innerHTML = `<div class="option-letter">${abc}</div><div class="option-text">${o.txt}</div><div class="option-mark"></div>`;
            if (o.i === q.a) correctLine = `${abc} · ${o.txt}`;
            if (ans) {
                if (o.i === q.a) { div.classList.add('correct'); div.querySelector('.option-mark').textContent = '✓'; }
                else if (o.i === ans.chosen) { div.classList.add('wrong'); div.querySelector('.option-mark').textContent = '✕'; }
                else div.classList.add('dim');
            } else { div.onclick = () => QuizApp.checkAnswer(o.i); }
            list.appendChild(div);
        });

        // Header: thin progress bar, counter, timer only in exam modes
        const answered = Object.keys(this.state.answers).length;
        const barFill = document.getElementById('qa-bar-fill');
        if (barFill) barFill.style.width = `${(answered / total) * 100}%`;
        const countEl = document.getElementById('qa-count');
        if (countEl) countEl.textContent = `${this.state.index + 1} / ${total}`;
        const timerEl = document.getElementById('quiz-timer-disp');
        const isPdfExam = typeof this.state.course === 'string' && this.state.course.includes('_pdf_');
        if (timerEl) timerEl.hidden = !(this.state.isMockMode || isPdfExam);
        const courseNameEl = document.getElementById('course-name-sm');
        if (courseNameEl) courseNameEl.textContent = courseNameEl.textContent.replace(/_pdf_\d+$/, '');
        if (!this.state.pagerOpen) pBar.style.display = 'none';

        // Footer: skip controls while unanswered, a tinted feedback bar once answered
        const foot = document.getElementById('qa-foot');
        if (foot) {
            const isLast = this.state.index === total - 1;
            const prevBtn = `<button class="btn btn-sec qa-prev" id="btn-prev" onclick="nav(-1)" ${this.state.index === 0 ? 'disabled' : ''}>Geri</button>`;
            if (!ans) {
                foot.className = 'qa-foot';
                foot.innerHTML = `${prevBtn}<button class="btn btn-sec" id="btn-next">${isLast ? 'Bitir' : 'Keç'}</button>`;
            } else {
                const isHint = !!ans.hint;
                const isRight = !isHint && ans.chosen === q.a;
                foot.className = 'qa-foot qa-fb ' + (isHint ? 'hint' : (isRight ? 'ok' : 'bad'));
                foot.innerHTML = `
                    <div class="qa-msg">
                        <b>${isHint ? 'İpucu' : (isRight ? 'Düzdür' : 'Səhv')}</b>
                        ${isRight ? '' : `<span>Düzgün cavab: ${correctLine}</span>`}
                    </div>
                    ${prevBtn}
                    <button class="btn btn-pri" id="btn-next">${isLast ? 'Nəticəyə bax' : 'Davam'}</button>`;
            }
            const btnNext = document.getElementById('btn-next');
            btnNext.onclick = isLast ? () => QuizApp.finishTest() : () => QuizApp.nav(1);
        }

        const btnHint = document.getElementById('btn-hint');
        if (btnHint) btnHint.disabled = !!ans;

        if (ans && ans.chosen !== q.a) {
            const okEl = list.querySelector('.option.correct');
            if (okEl && okEl.scrollIntoView) okEl.scrollIntoView({ block: 'nearest' });
        }
    },

    togglePager: function () {
        this.state.pagerOpen = !this.state.pagerOpen;
        this.renderQ();
    },

    confirmReset: function (btn) {
        if (btn.dataset.armed) { delete btn.dataset.armed; resetUnit(); return; }
        btn.dataset.armed = '1';
        btn.textContent = 'Əminsiniz? Bir də basın';
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
            
            if (this.state.currentTitle === 'Multi') {
                cat = 'units';
                sub = 'Multi';
            } else if (this.state.isWrongMode) {
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

        // Auto-advance only after a correct answer; a wrong answer waits for "Davam" so the correct option can be read
        if (!isCorrect) return;
        const currentIndex = this.state.index;
        setTimeout(() => {
            if (QuizApp.state.view === 'quiz' && QuizApp.state.index === currentIndex) {
                const total = QuizApp.state.questions.length;
                if (QuizApp.state.index === total - 1) {
                    QuizApp.finishTest();
                } else {
                    QuizApp.nav(1);
                }
            }
        }, 750);
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

    getLayout: function () {
        if (this._layout) return this._layout;
        let saved = null;
        try { saved = localStorage.getItem('quiz_dashboard_layout'); } catch (e) {}
        return saved === 'table' ? 'table' : 'grid';
    },

    // Kart / Cədvəl switch: remember the choice and redraw the page that is open
    setDashboardLayout: function (layout) {
        this._layout = layout;
        try { localStorage.setItem('quiz_dashboard_layout', layout); } catch (e) {}
        const v = this.state.view;
        if (v === 'pdf-exams-dashboard') this.showPdfExamsDashboard();
        else if (v === 'pdf-exams-list') this.showPdfExamsList(this.state.pdfExamSubject);
        else if (this.state.course) this.showCourseDashboard(this.state.course);
    },

    // Ümumi Toplam: all subjects together
    showOverallDashboard: function () {
        const c = 'Ümumi Toplam';
        this.stopTimer();
        if (this.state.courseTabFor !== c) { this.state.courseTab = 'units'; this.state.courseTabFor = c; }
        this.state = { ...this.state, view: 'dashboard', course: c, category: null, isWrongMode: false, isSearchMode: false, isMockMode: false };
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active-sub'));
        const container = document.getElementById('content-area');
        if (!container) return;
        const tab = this.state.courseTab || 'units';

        let time = 0, correct = 0, wrong = 0, answered = 0;
        Object.keys(this.stats).forEach(k => {
            if (k === '_platform') return;
            const st = this.stats[k];
            time += st.time || 0; correct += st.c || 0; wrong += st.w || 0; answered += st.t || 0;
        });
        const acc = answered > 0 ? Math.round((correct / answered) * 100) : 0;
        const totalQ = typeof quizData !== 'undefined' ? quizData.filter(q => q.c !== "Mixed").length : 0;
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;

        let wrQs = [];
        Object.keys(this.wrongDB).forEach(k => { wrQs = wrQs.concat(this.wrongDB[k]); });
        let multiLast = 0, multiDone = false;
        Object.keys(this.stats).forEach(k => {
            const m = this.stats[k] && this.stats[k].bd && this.stats[k].bd['units'] && this.stats[k].bd['units']['Multi'];
            if (!m) return;
            multiLast = Math.max(multiLast, m.last || 0);
            if ((m.t || 0) > 0) multiDone = true;
        });
        if (multiLast === 0 && multiDone) Object.keys(this.stats).forEach(k => { multiLast = Math.max(multiLast, this.getCourseLastActiveDateFromHistory(k)); });

        const rows = Object.keys(CONFIG).map(name => {
            const cs = this.stats[name] || {};
            return { name, total: typeof quizData !== 'undefined' ? quizData.filter(q => q.c === name).length : 0, ok: cs.c || 0, bad: cs.w || 0, done: cs.t || 0, lastStr: this.formatLastTested(this.getCourseLastTested(name), (cs.t || 0) > 0), click: `QuizApp.showCourseDashboard('${name.replace(/'/g, "\\'")}')` };
        });

        let rec;
        if (answered === 0) rec = "Hələ ki heç bir sual cavablandırmamısınız. İmtahana hazırlaşmaq üçün hər hansı bir fənni seçib sualları işləməyə başlayın!";
        else if (acc >= 80) rec = `Mükəmməl ümumi nəticə! Dəqiqliyiniz ${acc}%-dir. Bu tempi qoruyub saxlamaq üçün mütəmadi olaraq <b>Böyük sınaq</b> işləyin.`;
        else if (acc >= 50) rec = `Ümumi hazırlıq səviyyəniz yaxşıdır (${acc}% doğru). Göstəricinizi daha da yaxşılaşdırmaq üçün zəif olduğunuz fənlərə diqqət yetirin, səhv etdiyiniz sualları <b>Səhvlərim</b> ilə yenidən işləyin.`;
        else rec = `Ümumi nəticəniz zəifdir (${acc}% doğru). Hər bir fənni ayrı-ayrılıqda daha diqqətlə öyrənməyinizi və çətinlik çəkdiyiniz mövzuları təkrarlamağı tövsiyə edirik.`;

        const content = tab === 'mixed' ? `
                <section class="cp-mix">
                    <div>
                        <h2>Böyük sınaq</h2>
                        <p>Bütün fənlərdən qarışıq real sınaq imtahanı: hər fəndən 20 sual. Başlamaq üçün düyməyə basın.</p>
                        <button class="btn btn-pri" onclick="QuizApp.startMock()">Sınağa başla</button>
                    </div>
                    <div class="cp-mix-stats">
                        <div><span class="hx-cap">Hər fəndən</span><b>20 sual</b></div>
                        <div><span class="hx-cap">Mənbə</span><b>${rows.filter(r => r.total).length} fənn</b></div>
                        <div><span class="hx-cap">Hələ işlənməyib</span><b>${Math.max(0, totalQ - answered)}</b></div>
                    </div>
                </section>` : this.cpList(rows, 'Fənn', 'Aç', this.cpMulti('all', wrQs, this.formatLastTested(multiLast, multiDone)));

        container.innerHTML = `
            <div class="cp">
                ${this.cpHead(c, 'Bütün fənlər üzrə ümumi irəliləyiş', '', `<button class="btn btn-pri cp-wrong" onclick="QuizApp.startHard()" ${wrQs.length ? '' : 'disabled'}>Səhvlərim <i>${wrQs.length}</i></button>`)}
                ${this.cpStrip({ totalQ, answered, correct, wrong, onCorrect: 'QuizApp.reviewAllAnswers(true)', onWrong: 'QuizApp.reviewAllAnswers(false)', extra: ['Vaxt', this.formatTime(time) + ' / ' + this.formatTime(platformTime)] })}
                <p class="cp-advice">${rec}</p>
                <div class="cp-tabs-row">
                    <span class="cp-tabs" role="group" aria-label="Bölmə">
                        <button class="${tab === 'units' ? 'active' : ''}" onclick="QuizApp.setCourseTab('units')">Fənlər <i>${rows.length}</i></button>
                        <button class="${tab === 'mixed' ? 'active' : ''}" onclick="QuizApp.setCourseTab('mixed')">Böyük sınaq</button>
                    </span>
                    ${tab === 'units' ? this.cpToggle() : ''}
                </div>
                ${content}
            </div>`;
    },

    reviewAllAnswers: function (correct) {
        const db = (correct ? this.correctDB : this.wrongDB) || {};
        let arr = [];
        Object.keys(db).forEach(k => { arr = arr.concat(db[k]); });
        if (arr.length) this.startSpecial(arr, correct ? "Ümumi Doğrular" : "Ümumi Səhvlər", "Bütün Fənlər");
        else alert(correct ? "Doğru cavablandırdığınız sual hələ ki yoxdur." : "Əla! Səhv cavablandırdığınız sual yoxdur.");
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
        
        const isWrong = t.toLowerCase().includes('sehv') || t.toLowerCase().includes('səhv') || t.toLowerCase().includes('cetin') || t.toLowerCase().includes('çətin') || t.toLowerCase().includes('wrong') || t.toLowerCase().includes('hard') || t.toLowerCase().includes('multi');
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
        const container = document.getElementById('content-area');
        if (!container) return;

        let gt = 0, gc = 0, gw = 0, tm = 0, rowsHTML = '';
        [...Object.keys(CONFIG), this.MOCK_KEY].forEach(c => {
            const s = this.stats[c];
            if (!s || !(s.t > 0)) return;
            gt += s.t; gc += s.c; gw += s.w; tm += s.time;
            rowsHTML += `<tr onclick="QuizApp.showStatDetailsModal('${c.replace(/'/g, "\\'")}')"><td><b>${c}</b></td><td>${this.cpBar(s.t, s.c, s.w)}</td><td class="n">${s.t}</td><td class="n g">${s.c}</td><td class="n r">${s.w}</td><td class="n">${Math.round((s.c / s.t) * 100)}%</td><td class="m">${this.formatTime(s.time)}</td></tr>`;
        });
        const platformTime = this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0;
        const cell = (cls, label, val, type) => `<button class="${cls}" onclick="showStatDetails('${type}')" title="Fənlər üzrə baxmaq üçün klikləyin"><span class="hx-cap">${label}</span><b>${val}</b></button>`;

        container.innerHTML = `
            <div class="cp">
                ${this.cpHead('Statistika', 'Ümumi göstəricilər və fənlər üzrə detallar')}
                <section class="cp-strip">
                    <div class="cp-strip-row c5">
                        ${cell('', 'İşlənən', gt, 'total')}
                        ${cell('g', 'Düz', gc, 'correct')}
                        ${cell('r', 'Səhv', gw, 'wrong')}
                        ${cell('a', 'Dəqiqlik', gt > 0 ? Math.round((gc / gt) * 100) + '%' : '-', 'accuracy')}
                        ${cell('', 'Vaxt', this.formatTime(tm) + ' / ' + this.formatTime(platformTime), 'time')}
                    </div>
                    ${this.cpBar(gt, gc, gw)}
                </section>
                <div class="cp-tabs-row"><span class="cp-sec">Fənlər üzrə</span></div>
                ${rowsHTML ? `
                <div class="cp-tbl"><table>
                    <thead><tr><th>Fənn</th><th>Düz / səhv</th><th class="n">İşlənən</th><th class="n">Düz</th><th class="n">Səhv</th><th class="n">Faiz</th><th>Vaxt</th></tr></thead>
                    <tbody>${rowsHTML}</tbody>
                </table></div>` : '<div class="hx-empty">Hələ heç bir sual cavablandırılmayıb.</div>'}
                <button class="btn btn-sec px-danger" onclick="resetStatistics()">Sıfırla</button>
            </div>`;
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
                else { val = s[{ total: 't', correct: 'c', wrong: 'w' }[type]] || 0; disp = val; }
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
        const total = this.state.questions.length;
        const answeredCount = Object.keys(this.state.answers).length;
        if (answeredCount < total) {
            if (!confirm(`Sınaq yarımçıqdır (Cavablandırılıb: ${answeredCount}/${total}). Bitirməkdən əminsiniz?`)) {
                return;
            }
        }

        const timerDisp = document.getElementById('quiz-timer-disp');
        const elapsedText = timerDisp ? timerDisp.textContent : '';
        this.stopTimer();
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

        // Missed questions, shown with the chosen and the correct answer, and kept for "Səhvləri təkrarla"
        const missed = [];
        this.state.questions.forEach((q, i) => {
            const an = this.state.answers[i];
            if (an && an.chosen !== q.a) missed.push({ q, chosen: an.chosen });
        });
        this.lastMissed = missed.map(m => m.q);
        this.lastMissedCourse = this.state.course;
        const missedHTML = missed.length ? `
            <div class="res-missed">
                <div class="res-cap">Səhv cavablar</div>
                ${missed.map(m => `
                    <article>
                        <p>${m.q.q}</p>
                        <dl>
                            <dt>Sizin cavab</dt><dd class="y">${m.chosen >= 0 ? m.q.o[m.chosen] : '—'}</dd>
                            <dt>Düzgün cavab</dt><dd class="c">${m.q.o[m.q.a]}</dd>
                        </dl>
                    </article>`).join('')}
            </div>` : '';
        const actionsHTML = `
            <div class="res-actions">
                ${missed.length ? `<button class="btn btn-pri" onclick="QuizApp.reviewMissed()">Səhvləri təkrarla (${missed.length})</button>` : ''}
                <button class="btn ${missed.length ? 'btn-sec' : 'btn-pri'}" onclick="closeModal()">Bağla</button>
            </div>`;

        const body = document.getElementById('modal-body');
        document.getElementById('modal-title').textContent = "Nəticə";

        if (this.state.isMockMode) {
            body.innerHTML = `
                <div class="res">
                    <div style="font-size:1.6rem; font-weight:800; color:var(--accent);">Sınaq Nəticələri</div>
                    <div style="color:var(--text-muted);">Fənn üzrə ballar (Maks. 100):</div>
                    ${subHTML}
                    ${actionsHTML}
                    ${missedHTML}
                </div>
            `;
        } else {
            body.innerHTML = `
                <div class="res">
                    <div class="res-top">
                        <div class="res-big" style="color:${color};">${c}<small> / ${total} düz</small></div>
                        <div class="res-stats">
                            <div><b>${total ? Math.round((c / total) * 100) : 0}%</b><span>Dəqiqlik</span></div>
                            <div><b>${elapsedText || '—'}</b><span>Vaxt</span></div>
                            <div><b>${net.toFixed(2)}</b><span>Net</span></div>
                        </div>
                    </div>
                    ${actionsHTML}
                    ${missedHTML}
                </div>
            `;
        }
        document.getElementById('modal-overlay').style.display = 'flex';
    },

    reviewMissed: function () {
        if (!this.lastMissed || !this.lastMissed.length) return;
        closeModal();
        this.startSpecial(this.lastMissed, "Səhvlərin Təkrarı", this.lastMissedCourse);
    },

    // Helpers
    nav: function (d) { const nextIdx = this.state.index + d; if (nextIdx >= 0 && nextIdx < this.state.questions.length) { this.state.index = nextIdx; this.renderQ(); } },
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
        const container = document.getElementById('content-area');
        if (!container) return;

        const keys = Object.keys(this.wrongDB).filter(k => this.wrongDB[k].length);
        const total = keys.reduce((a, k) => a + this.wrongDB[k].length, 0);
        const label = k => { const m = k.match(/^(.*)_pdf_(\d+)$/); return m ? `${m[1]} · İmtahan ${+m[2] + 1}` : k; };
        container.innerHTML = `
            <div class="cp">
                ${this.cpHead('Səhvlərim', `${total} səhv sual · ${keys.length} mənbə`, '', `<button class="btn btn-pri cp-wrong" onclick="QuizApp.startHard()" ${total ? '' : 'disabled'}>Qarışıq 20 sual</button>`)}
                <div class="cp-cards">
                    ${keys.map(k => {
                        const arr = this.wrongDB[k];
                        const hard = arr.filter(x => ((this.wrongCounts || {})[x.q] || 0) >= 2).length;
                        const veryHard = arr.filter(x => ((this.wrongCounts || {})[x.q] || 0) >= 3).length;
                        return `
                    <button class="cp-u" onclick="QuizApp.startWrongFor('${k.replace(/'/g, "\\'")}')">
                        <div class="cp-u-top"><b>${label(k)}</b><span class="cp-pct">${arr.length} səhv</span></div>
                        <div class="cp-u-nums"><span><b>${arr.length}</b> səhv sual</span><span class="h"><b>${hard}</b> çətin (2+)</span><span class="r"><b>${veryHard}</b> çox çətin (3+)</span></div>
                        <div class="cp-u-foot"><span></span><span class="cp-start">Başla</span></div>
                    </button>`;
                    }).join('') || '<div class="hx-empty">Əla! Səhv yoxdur.</div>'}
                </div>
            </div>`;
    },

    startWrongFor: function (key) {
        const arr = this.wrongDB[key] || [];
        if (arr.length) this.startSpecial(arr, "Səhvlər", key);
    },

    showHomeFromSidebar: function () {
        document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
        const homeBtn = document.getElementById('btn-home');
        if (homeBtn) homeBtn.classList.add('active');
        this.start();
        closeSidebar();
    },

    performSidebarAnswerSearch: function () {
        const input = document.getElementById('sb-answer-search-input');
        if (!input) return;
        const val = input.value.trim();
        if (!val) return;
        
        this.showAnswerSearch();
        const mainSearchInput = document.getElementById('answer-search-input');
        if (mainSearchInput) {
            mainSearchInput.value = val;
            this.performAnswerSearch();
        }
        closeSidebar();
    },

    showAnswerSearch: function () {
        this.stopTimer();
        this.state.view = 'search';
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';
        loadTemplate('search-template');
        const input = document.getElementById('answer-search-input');
        if (input) input.focus();
    },

    performAnswerSearch: function () {
        const input = document.getElementById('answer-search-input');
        if (!input) return;
        const query = input.value.trim().toLowerCase();
        if (!query) return;

        if (typeof quizData === 'undefined') {
            alert("Məlumat bazası tapılmadı.");
            return;
        }

        // 1. Doğru cavaba görə filter edirik
        const results = quizData.filter(q => {
            if (!q.o || q.a === undefined || q.a === null || q.a < 0 || q.a >= q.o.length) return false;
            const correctAnswer = q.o[q.a].toLowerCase();
            return correctAnswer.includes(query);
        });

        // 2. Sual mətninə görə dublikatları təmizləyirik (təkrarlanmaması üçün)
        const uniqueResults = [];
        const seenQuestions = new Set();
        results.forEach(q => {
            const normQ = q.q.trim().toLowerCase();
            if (!seenQuestions.has(normQ)) {
                seenQuestions.add(normQ);
                uniqueResults.push(q);
            }
        });

        const infoEl = document.getElementById('search-results-info');
        const listEl = document.getElementById('search-results-list');
        if (!infoEl || !listEl) return;

        listEl.innerHTML = "";
        infoEl.style.display = 'flex';
        infoEl.style.justifyContent = 'space-between';
        infoEl.style.alignItems = 'center';
        infoEl.style.flexWrap = 'wrap';
        infoEl.style.gap = '10px';

        if (uniqueResults.length === 0) {
            infoEl.innerHTML = `<span style="color:var(--wrong)">"${input.value}" ifadəsi ilə doğru cavablarda heç bir uyğunluq tapılmadı.</span>`;
            return;
        }

        QuizApp.lastSearchResults = uniqueResults;
        QuizApp.lastSearchQuery = input.value;

        infoEl.innerHTML = `
            <span>Tapılan unikal sual sayı: <strong>${uniqueResults.length}</strong></span>
            <button class="btn btn-pri" style="padding: 6px 14px; font-size: 0.85rem; border-radius: 10px;" onclick="QuizApp.startSpecial(QuizApp.lastSearchResults, 'Axtarış Nəticələri', 'Cavab: ' + QuizApp.lastSearchQuery)">🎯 Test kimi işlə</button>
        `;

        uniqueResults.forEach((q, idx) => {
            const item = document.createElement('div');
            item.className = 'unit-item';
            item.style.cssText = "background: var(--bg-card); border: 1px solid var(--border); border-radius: 18px; padding: 20px; transition: all 0.2s ease; display: flex; flex-direction: column; gap: 14px; margin-bottom: 5px;";
            
            const meta = document.createElement('div');
            meta.style.cssText = "display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem; color: var(--text-muted); font-weight: 700; text-transform: uppercase;";
            meta.innerHTML = `<span>📚 ${q.c || 'Məlum deyil'}</span> <span>Bölmə ${q.u || '1'}</span>`;
            item.appendChild(meta);

            const questionText = document.createElement('div');
            questionText.style.cssText = "font-size: 1rem; font-weight: 600; color: var(--text-main); line-height: 1.5;";
            questionText.innerHTML = `${idx + 1}. ${q.q || '(Sual mətni yoxdur)'}`;
            item.appendChild(questionText);

            const optionsContainer = document.createElement('div');
            optionsContainer.style.cssText = "display: flex; flex-direction: column; gap: 8px; margin-top: 8px;";

            q.o.forEach((opt, optIdx) => {
                const optDiv = document.createElement('div');
                const isCorrect = optIdx === q.a;
                
                if (isCorrect) {
                    optDiv.style.cssText = "padding: 10px 14px; border-radius: 10px; font-size: 0.9rem; background: rgba(16, 185, 129, 0.08); border: 1px solid rgba(16, 185, 129, 0.3); color: #10b981; font-weight: 600; display: flex; align-items: center; gap: 8px;";
                    optDiv.innerHTML = `<span>✔️</span> <span>${opt}</span>`;
                } else {
                    optDiv.style.cssText = "padding: 10px 14px; border-radius: 10px; font-size: 0.9rem; background: rgba(255,255,255,0.01); border: 1px solid var(--border); color: var(--text-muted); display: flex; align-items: center; gap: 8px;";
                    optDiv.innerHTML = `<span style="opacity: 0.3;">⚪</span> <span>${opt}</span>`;
                }
                optionsContainer.appendChild(optDiv);
            });
            item.appendChild(optionsContainer);
            listEl.appendChild(item);
        });
    },

    quizSecondsAccumulated: 0,

    startTimer: function (c) {
        this.stopTimer();
        this.activeCourse = c;
        this.quizSecondsAccumulated = 0;
        this.resumeTimer();
    },
    
    stopTimer: function () { 
        this.pauseTimer();
        this.activeCourse = null;
        this.quizSecondsAccumulated = 0;
    },

    pauseTimer: function () {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
            
            if (this.activeCourse) {
                const now = Date.now();
                const totalElapsed = Math.floor((now - this.sessionStartTime) / 1000);
                let delta = totalElapsed - this.secondsElapsedInSession;
                const isStatTracked = this.activeCourse && (typeof CONFIG !== 'undefined' && CONFIG[this.activeCourse] !== undefined || this.activeCourse === this.MOCK_KEY || this.activeCourse.includes('_pdf_'));
                if (delta > 0) {
                    if (delta > 5) delta = 1;
                    if (isStatTracked) {
                        this.stats[this.activeCourse].time += delta;
                        this.recordDailyHistory(this.activeCourse, null, delta);
                    }
                    this.secondsElapsedInSession += delta;
                }
                this.quizSecondsAccumulated += this.secondsElapsedInSession;
            }
        }
        this.saveStats();
    },

    resumeTimer: function () {
        if (this.activeCourse && !this.timer) {
            this.sessionStartTime = Date.now();
            this.secondsElapsedInSession = 0;
            const c = this.activeCourse;
            const isStatTracked = c && (typeof CONFIG !== 'undefined' && CONFIG[c] !== undefined || c === this.MOCK_KEY || c.includes('_pdf_'));
            
            if (isStatTracked && !this.stats[c]) {
                this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
            }
            
            const timerDisp = document.getElementById('quiz-timer-disp');

            this.timer = setInterval(() => { 
                if (this.activeCourse) { 
                    const now = Date.now();
                    
                    // Idle check (180 seconds)
                    if (now - this.lastActivityTime > 180000) {
                        this.isIdle = true;
                        this.pauseTimer();
                        this.pausePlatformTimer();
                        return;
                    }
                    
                    const totalElapsed = Math.floor((now - this.sessionStartTime) / 1000);
                    let delta = totalElapsed - this.secondsElapsedInSession;
                    if (delta > 0) {
                        if (delta > 5) {
                            delta = 1;
                            this.sessionStartTime = now - (this.secondsElapsedInSession + 1) * 1000;
                        }
                        if (isStatTracked) {
                            this.stats[c].time += delta; 
                            this.recordDailyHistory(c, null, delta);
                        }
                        this.secondsElapsedInSession += delta;
                        if (isStatTracked && this.secondsElapsedInSession % 10 === 0) this.saveStats(); 
                    }
                    if (timerDisp) {
                        const displaySeconds = this.quizSecondsAccumulated + this.secondsElapsedInSession;
                        const mins = Math.floor(displaySeconds / 60);
                        const secs = displaySeconds % 60;
                        timerDisp.textContent = String(mins).padStart(2, '0') + ":" + String(secs).padStart(2, '0');
                    }
                } 
            }, 1000);
        }
    },

    startPlatformTimer: function () {
        if (this.platformTimer) return;
        this.platformSessionStart = Date.now();
        this.platformSecondsElapsedInSession = 0;
        
        this.platformTimer = setInterval(() => {
            const now = Date.now();
            
            // Idle check (180 seconds)
            if (now - this.lastActivityTime > 180000) {
                this.isIdle = true;
                this.pauseTimer();
                this.pausePlatformTimer();
                return;
            }
            
            const totalElapsed = Math.floor((now - this.platformSessionStart) / 1000);
            let delta = totalElapsed - this.platformSecondsElapsedInSession;
            if (delta > 0) {
                if (delta > 5) {
                    delta = 1;
                    this.platformSessionStart = now - (this.platformSecondsElapsedInSession + 1) * 1000;
                }
                this.recordPlatformTime(delta);
                this.platformSecondsElapsedInSession += delta;
                
                const platTimeEl = document.querySelector('.platform-time-val');
                if (platTimeEl) {
                    const tempD = new Date();
                    const today = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
                    const seconds = (this.dailyHistory && this.dailyHistory[today] && this.dailyHistory[today].platformTime) || 0;
                    const formatTodayTime = (s) => {
                        if (s <= 0) return '0s';
                        const h = Math.floor(s / 3600);
                        const m = Math.floor((s % 3600) / 60);
                        const sec = s % 60;
                        let parts = [];
                        if (h > 0) parts.push(`${h}h`);
                        if (m > 0 || h > 0) parts.push(`${m}m`);
                        parts.push(`${sec}s`);
                        return parts.join(' ');
                    };
                    platTimeEl.textContent = formatTodayTime(seconds);
                }
                
                if (this.platformSecondsElapsedInSession % 10 === 0) this.saveStats();
            }
        }, 1000);
    },

    pausePlatformTimer: function () {
        if (this.platformTimer) {
            clearInterval(this.platformTimer);
            this.platformTimer = null;
            
            const now = Date.now();
            const totalElapsed = Math.floor((now - this.platformSessionStart) / 1000);
            let delta = totalElapsed - this.platformSecondsElapsedInSession;
            if (delta > 0) {
                if (delta > 5) delta = 1;
                this.recordPlatformTime(delta);
            }
        }
        this.saveStats();
    },

    recordPlatformTime: function (delta) {
        if (!this.dailyHistory) this.dailyHistory = {};
        const tempD = new Date();
        const today = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
        if (!this.dailyHistory[today]) this.dailyHistory[today] = {};
        
        this.dailyHistory[today].platformTime = (this.dailyHistory[today].platformTime || 0) + delta;
        
        if (!this.stats["_platform"]) {
            this.stats["_platform"] = { time: 0 };
        }
        this.stats["_platform"].time += delta;
    },

    recordStat: function (c, cat, sub, isCorr) {
        if (!this.stats[c]) this.stats[c] = { t: 0, c: 0, w: 0, time: 0, bd: {} };
        if (!this.stats[c].bd) this.stats[c].bd = {};
        if (!this.stats[c].bd[cat]) this.stats[c].bd[cat] = {};
        
        if (!this.stats[c].bd[cat][sub]) {
            this.stats[c].bd[cat][sub] = { t: 0, c: 0, w: 0, last: 0 };
        }
        
        // Accumulate statistics instead of overwriting
        this.stats[c].bd[cat][sub].t++;
        if (isCorr) {
            this.stats[c].bd[cat][sub].c++;
        } else {
            this.stats[c].bd[cat][sub].w++;
        }
        this.stats[c].bd[cat][sub].last = Date.now();

        // Recalculate overall course-level correct, wrong, and total counts based on the latest states of all units/modes
        let courseCorrect = 0;
        let courseWrong = 0;
        let courseTotal = 0;

        Object.keys(this.stats[c].bd).forEach(catKey => {
            Object.keys(this.stats[c].bd[catKey]).forEach(subKey => {
                const item = this.stats[c].bd[catKey][subKey];
                courseCorrect += item.c || 0;
                courseWrong += item.w || 0;
                courseTotal += item.t || 0;
            });
        });

        this.stats[c].c = courseCorrect;
        this.stats[c].w = courseWrong;
        this.stats[c].t = courseTotal;

        this.recordDailyHistory(c, isCorr, 0);
        this.saveStats();
    },

    recordDailyHistory: function(course, isCorrect, timeIncrement = 0) {
        if (!this.dailyHistory) this.dailyHistory = {};
        const tempD = new Date();
        const today = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
        if (!this.dailyHistory[today]) this.dailyHistory[today] = {};
        
        let targetCourse = course;
        if (course && course.includes('_pdf_')) {
            targetCourse = course.split('_pdf_')[0];
        }
        
        if (!this.dailyHistory[today][targetCourse]) this.dailyHistory[today][targetCourse] = { time: 0, correct: 0, wrong: 0 };
        
        if (timeIncrement > 0) {
            this.dailyHistory[today][targetCourse].time += timeIncrement;
        } else {
            if (isCorrect) this.dailyHistory[today][targetCourse].correct++;
            else this.dailyHistory[today][targetCourse].wrong++;
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

    // Activity per day across the semester's study window (STUDY_PERIOD in config.js): stacked correct/wrong bars, or minutes spent
    drawDynamicsChart: function () {
        const host = document.getElementById('home-dynamics');
        if (!host) return;
        const mode = this.state.chartMode || 'questions';
        if (!this.state.chartSelectedCourse) this.state.chartSelectedCourse = 'all';
        const sel = this.state.chartSelectedCourse;

        const filtersContainer = document.getElementById('chart-courses-filters');
        if (filtersContainer) {
            filtersContainer.innerHTML = '';
            const select = document.createElement('select');
            select.className = 'hx-sel';
            select.setAttribute('aria-label', 'Fənn');
            [['all', 'Hamısı'], ...Object.keys(CONFIG).map(c => [c, c])].forEach(([value, label]) => {
                const opt = document.createElement('option');
                opt.value = value; opt.textContent = label;
                if (sel === value) opt.selected = true;
                select.appendChild(opt);
            });
            select.onchange = (e) => {
                this.state.chartSelectedCourse = e.target.value;
                this.drawDynamicsChart();
            };
            filtersContainer.appendChild(select);
        }

        const months = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avq', 'sen', 'okt', 'noy', 'dek'];
        const data = [];
        const parseDay = (str) => { const [yy, mm, dd] = str.split('-').map(Number); return new Date(yy, mm - 1, dd); };
        const period = typeof STUDY_PERIOD !== 'undefined' ? STUDY_PERIOD : null;
        const endDay = period ? parseDay(period.end) : new Date();
        const startDay = period ? parseDay(period.start) : new Date(Date.now() - 13 * 86400000);
        for (let d = new Date(startDay); d <= endDay; d.setDate(d.getDate() + 1)) {
            const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
            const day = (this.dailyHistory || {})[key] || {};
            let c = 0, w = 0, t = 0;
            Object.keys(day).forEach(k => {
                if (k === 'platformTime' || k === 'personalNotes') return;
                if (sel !== 'all' && k !== sel && !k.startsWith(sel + '_pdf_')) return;
                const v = day[k] || {};
                c += v.correct || 0; w += v.wrong || 0; t += v.time || 0;
            });
            data.push({ label: `${d.getDate()} ${months[d.getMonth()]}`, c, w, m: Math.round(t / 60) });
        }

        const isQ = mode === 'questions';
        const top = Math.max(4, ...data.map(d => isQ ? d.c + d.w : d.m));
        const step = top > 200 ? 50 : top > 80 ? 20 : top > 30 ? 10 : top > 12 ? 5 : top > 6 ? 2 : 1;
        const max = Math.ceil(top / step) * step;
        const W = 720, H = 230, L = 34, B = 26, T = 8, n = data.length;
        const slot = (W - L) / n, bw = Math.min(26, slot * 0.62);
        const labelEvery = n > 21 ? 7 : 2;
        const y = (v) => T + (H - B - T) * (1 - v / max);

        let grid = '';
        for (let v = 0; v <= max; v += step) {
            grid += `<line class="gl" x1="${L}" x2="${W}" y1="${y(v)}" y2="${y(v)}"></line><text x="${L - 8}" y="${y(v) + 4}" text-anchor="end">${v}</text>`;
        }
        let bars = '';
        data.forEach((d, i) => {
            const x = L + i * slot + (slot - bw) / 2;
            const total = isQ ? d.c + d.w : d.m;
            const tip = isQ ? `${d.label}: ${d.c} düz, ${d.w} səhv` : `${d.label}: ${d.m} dəq`;
            if (isQ) {
                if (d.c) bars += `<rect class="b-ok" x="${x}" y="${y(d.c)}" width="${bw}" height="${y(0) - y(d.c)}" rx="3"></rect>`;
                if (d.w) bars += `<rect class="b-bad" x="${x}" y="${y(d.c + d.w) - (d.c ? 2 : 0)}" width="${bw}" height="${y(0) - y(d.w)}" rx="3"></rect>`;
            } else if (d.m) {
                bars += `<rect class="b-t" x="${x}" y="${y(d.m)}" width="${bw}" height="${y(0) - y(d.m)}" rx="3"></rect>`;
            }
            bars += `<rect class="hit" data-tip="${tip}" data-x="${((L + i * slot + slot / 2) / W * 100).toFixed(1)}" data-y="${(y(total) / H * 100).toFixed(1)}" x="${L + i * slot}" y="${T}" width="${slot}" height="${H - B - T}"></rect>`;
            if (i % labelEvery === 0 && i < n - labelEvery / 2) bars += `<text x="${L + i * slot + slot / 2}" y="${H - 6}" text-anchor="${i === 0 ? 'start' : 'middle'}">${d.label}</text>`;
            else if (i === n - 1) bars += `<text x="${W}" y="${H - 6}" text-anchor="end">${d.label}</text>`;
        });
        const legend = isQ ? '<span class="l-ok">Düz</span><span class="l-bad">Səhv</span>' : '<span class="l-time">Dəqiqə</span>';

        host.innerHTML = `
            <div class="hx-legend">${legend}</div>
            <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Günlər üzrə fəallıq">${grid}${bars}</svg>
            <div class="hx-tip" style="display:none"></div>
        `;
        const tipEl = host.querySelector('.hx-tip');
        const svgEl = host.querySelector('svg');
        host.onmousemove = (e) => {
            const r = e.target.closest ? e.target.closest('.hit') : null;
            if (!r) { tipEl.style.display = 'none'; return; }
            const box = svgEl.getBoundingClientRect(), hb = host.getBoundingClientRect();
            tipEl.style.display = 'block';
            tipEl.textContent = r.dataset.tip;
            tipEl.style.left = (box.left - hb.left + box.width * r.dataset.x / 100) + 'px';
            tipEl.style.top = (box.top - hb.top + box.height * r.dataset.y / 100) + 'px';
        };
        host.onmouseleave = () => { tipEl.style.display = 'none'; };
    },

    saveStats: function () { 
        localStorage.setItem(this.DB.stats, JSON.stringify(this.stats)); 
        localStorage.setItem('qa_v32_h', JSON.stringify(this.dailyHistory));
    },
    saveWrong: function (c, q) { if (!this.wrongDB[c]) this.wrongDB[c] = []; if (!this.wrongDB[c].some(x => x.q === q.q)) { this.wrongDB[c].push(q); localStorage.setItem(this.DB.wrong, JSON.stringify(this.wrongDB)); } },
    removeWrong: function (c, qt) { if (this.wrongDB[c]) { this.wrongDB[c] = this.wrongDB[c].filter(x => x.q !== qt); if (!this.wrongDB[c].length) delete this.wrongDB[c]; localStorage.setItem(this.DB.wrong, JSON.stringify(this.wrongDB)); } },
    saveCorrect: function (c, q) { if (!this.correctDB[c]) this.correctDB[c] = []; if (!this.correctDB[c].some(x => x.q === q.q)) { this.correctDB[c].push(q); localStorage.setItem(this.DB.correct, JSON.stringify(this.correctDB)); } },
    removeCorrect: function (c, qt) { if (this.correctDB[c]) { this.correctDB[c] = this.correctDB[c].filter(x => x.q !== qt); if (!this.correctDB[c].length) delete this.correctDB[c]; localStorage.setItem(this.DB.correct, JSON.stringify(this.correctDB)); } },
    resetStatistics: async function () {
        if (confirm("Bütün məlumatlar silinəcək!")) {
            if (typeof firebase !== 'undefined' && firebase.auth && firebase.auth().currentUser) {
                try {
                    const uid = firebase.auth().currentUser.uid;
                    await firebase.firestore().collection('users').doc(uid).delete();
                    console.log("Cloud database document deleted");
                } catch (e) {
                    console.error("Error deleting cloud data:", e);
                }
            }
            localStorage.clear();
            location.reload();
        }
    },
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
            if (key.startsWith('qa_v32_') || key === 'theme') {
                const val = localStorage.getItem(key);
                try {
                    backup[key] = JSON.parse(val);
                } catch (e) {
                    backup[key] = val;
                }
            }
        }
        return JSON.stringify(backup, null, 2);
    },

    copyBackupToClipboard: function () {
        const txt = document.getElementById('backup-export-text');
        if (!txt) return;
        
        txt.select();
        txt.setSelectionRange(0, txt.value.length);
        
        const doSuccessAnim = () => {
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
        };

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(txt.value).then(doSuccessAnim).catch(err => {
                // Fallback to execCommand
                try {
                    const successful = document.execCommand('copy');
                    if (successful) doSuccessAnim();
                    else alert("Kopyalama alınmadı. Zəhmət olmasa, mətni əllə seçib kopyalayın.");
                } catch (e) {
                    alert("Kopyalama xətası: " + err);
                }
            });
        } else {
            // Insecure context / old browser fallback
            try {
                const successful = document.execCommand('copy');
                if (successful) {
                    doSuccessAnim();
                } else {
                    alert("Kopyalama alınmadı. Zəhmət olmasa, mətni əllə seçib kopyalayın.");
                }
            } catch (e) {
                alert("Kopyalama xətası: " + e.message);
            }
        }
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
            
            // 1. Map Firestore-style keys to localStorage keys
            const firestoreKeyMap = {
                'stats': 'qa_v32_s',
                'wrong': 'qa_v32_w',
                'correct': 'qa_v32_c',
                'bookmarks': 'qa_v32_m',
                'daily': 'qa_v32_h',
                'dailyGoal': 'qa_v32_dg',
                'settings': 'qa_v32_conf',
                'wrongCounts': 'qa_v32_wc',
                'localUpdatedAt': 'qa_v32_localUpdatedAt'
            };

            const normalizedData = {};
            for (let [key, val] of Object.entries(data)) {
                if (firestoreKeyMap[key]) {
                    normalizedData[firestoreKeyMap[key]] = val;
                } else {
                    normalizedData[key] = val;
                }
            }

            // 2. Resolve & merge daily history if both qa_v32_h and legacy qa_v32_d exist
            let dailyHistoryToImport = null;
            
            // Extract new daily history
            if (normalizedData['qa_v32_h']) {
                try {
                    dailyHistoryToImport = typeof normalizedData['qa_v32_h'] === 'string' 
                        ? JSON.parse(normalizedData['qa_v32_h']) 
                        : normalizedData['qa_v32_h'];
                } catch(e) {}
            }
            
            // Extract legacy daily history
            if (data['qa_v32_d']) {
                try {
                    const legacyDaily = typeof data['qa_v32_d'] === 'string' 
                        ? JSON.parse(data['qa_v32_d']) 
                        : data['qa_v32_d'];
                        
                    if (legacyDaily && Object.keys(legacyDaily).length > 0) {
                        if (!dailyHistoryToImport) {
                            dailyHistoryToImport = legacyDaily;
                        } else {
                            // Merge legacy history into new history
                            Object.keys(legacyDaily).forEach(date => {
                                if (date === 'c' || date === 'd') return; // Skip legacy metadata fields
                                if (!dailyHistoryToImport[date]) {
                                    dailyHistoryToImport[date] = legacyDaily[date];
                                } else {
                                    Object.keys(legacyDaily[date]).forEach(course => {
                                        if (!dailyHistoryToImport[date][course]) {
                                            dailyHistoryToImport[date][course] = legacyDaily[date][course];
                                        } else {
                                            const c1 = dailyHistoryToImport[date][course];
                                            const c2 = legacyDaily[date][course];
                                            dailyHistoryToImport[date][course] = {
                                                time: Math.max(c1.time || 0, c2.time || 0),
                                                correct: Math.max(c1.correct || 0, c2.correct || 0),
                                                wrong: Math.max(c1.wrong || 0, c2.wrong || 0)
                                            };
                                        }
                                    });
                                }
                            });
                        }
                    }
                } catch(e) {}
            }

            if (dailyHistoryToImport) {
                normalizedData['qa_v32_h'] = JSON.stringify(dailyHistoryToImport);
            }
            
            // Delete legacy qa_v32_d from data and localStorage to prevent pollution
            delete normalizedData['qa_v32_d'];
            localStorage.removeItem('qa_v32_d');

            // 3. Save all normalized keys to localStorage
            for (let [key, val] of Object.entries(normalizedData)) {
                if (key.startsWith('qa_v32_') || key === 'theme') {
                    const stringValue = typeof val === 'string' ? val : JSON.stringify(val);
                    localStorage.setItem(key, stringValue);
                    count++;
                }
            }

            if (count > 0) {
                localStorage.setItem('qa_v32_localUpdatedAt', Date.now().toString());
                this.loadData();
                if (typeof FirebaseSync !== 'undefined' && FirebaseSync.saveToCloud) {
                    FirebaseSync.saveToCloud().then(() => {
                        alert("Məlumatlar uğurla idxal edildi və buludla sinxronlaşdırıldı!");
                        location.reload();
                    }).catch(err => {
                        console.error(err);
                        alert("Məlumatlar lokal olaraq idxal edildi, lakin bulud sinxronizasiyası alınmadı. Səhifə yenilənir.");
                        location.reload();
                    });
                } else {
                    alert("Məlumatlar uğurla idxal edildi! Səhifə yenilənir.");
                    location.reload();
                }
            } else {
                alert("İdxal üçün uyğun açarlar (qa_v32_) tapılmadı.");
            }
        } catch (e) {
            alert("İdxal xətası: " + e.message);
        }
    },

    restoreFromBackupFile: async function () {
        if (!confirm("recovered_backup.json faylından məlumatları bərpa etmək istədiyinizə əminsiniz? Mövcud lokal datanız tamamilə silinəcək!")) {
            return;
        }
        try {
            const response = await fetch('./recovered_backup.json');
            if (!response.ok) {
                throw new Error("Fayl tapılmadı və ya yüklənmədi (404/500).");
            }
            const data = await response.json();
            let count = 0;
            const firestoreKeyMap = {
                'stats': 'qa_v32_s',
                'wrong': 'qa_v32_w',
                'correct': 'qa_v32_c',
                'bookmarks': 'qa_v32_m',
                'daily': 'qa_v32_h',
                'dailyGoal': 'qa_v32_dg',
                'settings': 'qa_v32_conf',
                'wrongCounts': 'qa_v32_wc',
                'localUpdatedAt': 'qa_v32_localUpdatedAt'
            };
            const normalizedData = {};
            for (let [key, val] of Object.entries(data)) {
                if (firestoreKeyMap[key]) {
                    normalizedData[firestoreKeyMap[key]] = val;
                } else {
                    normalizedData[key] = val;
                }
            }
            
            delete normalizedData['qa_v32_d'];
            localStorage.removeItem('qa_v32_d');

            for (let [key, val] of Object.entries(normalizedData)) {
                if (key.startsWith('qa_v32_') || key === 'theme') {
                    const stringValue = typeof val === 'string' ? val : JSON.stringify(val);
                    localStorage.setItem(key, stringValue);
                    count++;
                }
            }

            if (count > 0) {
                localStorage.setItem('qa_v32_localUpdatedAt', Date.now().toString());
                alert("Məlumatlar recovered_backup.json faylından uğurla bərpa edildi!");
                location.reload();
            } else {
                alert("Faylda bərpa edilə biləcək uyğun datalar tapılmadı.");
            }
        } catch (err) {
            console.error(err);
            alert("Fayldan bərpa etmək mümkün olmadı: " + err.message + "\nZəhmət olmasa recovered_backup.json faylının layihə qovluğunda mövcud olduğundan əmin olun.");
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
                        <textarea id="backup-export-text" readonly style="width:100%; height:80px; background:var(--bg-input); border:1px solid var(--border); border-radius:8px; padding:8px; font-family:monospace; font-size:0.75rem; color:var(--text-muted); resize:none; outline:none; white-space:pre-wrap; word-break:break-all;"></textarea>
                    </div>
                    
                    <!-- Import Box -->
                    <div>
                        <span style="font-size:0.75rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; display:block; margin-bottom:6px;">Ehtiyat Nüsxəni İdxal Et</span>
                        <textarea id="backup-import-text" placeholder="Bərpa etmək istədiyiniz JSON məlumatını bura yapışdırın..." style="width:100%; height:80px; background:var(--bg-input); border:1px solid var(--border); border-radius:8px; padding:8px; font-family:monospace; font-size:0.75rem; color:var(--text-main); resize:none; outline:none; margin-bottom:10px; transition:border-color 0.2s;"></textarea>
                        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">
                            <span style="font-size:0.7rem; color:var(--wrong); font-weight:500;">⚠️ Mövcud lokal datanız silinəcək!</span>
                            <button onclick="window.importBackup()" style="background:var(--accent); border:none; color:white; font-size:0.8rem; padding:8px 16px; border-radius:8px; cursor:pointer; font-weight:600; transition:opacity 0.2s;">İdxal Et</button>
                        </div>
                    </div>
 
                    <!-- Auto-Restore from recovered_backup.json -->
                    <div style="margin-top: 15px; padding-top: 15px; border-top: 1px dashed var(--border);">
                        <span style="font-size:0.75rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; display:block; margin-bottom:6px;">Lokaldan Avtomatik Bərpa</span>
                        <p style="font-size:0.75rem; color:var(--text-muted); margin-bottom:12px; line-height:1.4;">
                            Layihə qovluğunda mövcud olan <code>recovered_backup.json</code> faylından statistikaları yeniləyin.
                        </p>
                        <button onclick="window.restoreFromBackupFile()" style="background:var(--bg-element); border:1px solid var(--border); color:var(--text-main); font-size:0.8rem; padding:10px 16px; border-radius:10px; cursor:pointer; font-weight:600; transition:all 0.2s; width: 100%;">recovered_backup.json-dan bərpa et</button>
                    </div>
                </div>
            </div>
        `;
        
        const exportTxt = document.getElementById('backup-export-text');
        if (exportTxt) {
            exportTxt.value = backupData;
        }
    },

    surpriseInterval: null,
    surpriseCountdown: null,
    
    initSurpriseTimer: function() {
        if (this.surpriseInterval) clearInterval(this.surpriseInterval);
        
        // Every 3 minutes (180,000 ms), trigger a surprise question
        this.surpriseInterval = setInterval(() => {
            const overlay = document.getElementById('surprise-modal-overlay');
            if (overlay && overlay.style.display !== 'flex') {
                this.triggerSurpriseQuestion();
            }
        }, 180000);
    },
    
    triggerSurpriseQuestion: function() {
        if (typeof quizData === 'undefined' || quizData.length === 0) return;
        
        // All subjects; Mixed is skipped because it repeats the same questions
        const surprisePool = quizData.filter(q => q.c !== "Mixed");
        
        if (surprisePool.length === 0) {
            console.log("No questions found for surprise pool.");
            return;
        }

        // Pause main timer
        this.pauseTimer();
        
        // Pick a random question from the pool
        const randIndex = Math.floor(Math.random() * surprisePool.length);
        const q = surprisePool[randIndex];
        
        const overlay = document.getElementById('surprise-modal-overlay');
        const meta = document.getElementById('surprise-meta');
        const qText = document.getElementById('surprise-question-text');
        const optList = document.getElementById('surprise-options-list');
        const timerDisp = document.getElementById('surprise-timer');
        const footer = document.getElementById('surprise-footer');
        
        if (!overlay || !meta || !qText || !optList || !timerDisp || !footer) return;
        
        meta.textContent = `${q.c} • Unit ${q.u}`;
        qText.innerHTML = q.q;
        optList.innerHTML = '';
        footer.style.display = 'none';
        
        const feedbackEl = document.getElementById('surprise-feedback');
        if (feedbackEl) {
            feedbackEl.style.display = 'none';
            feedbackEl.textContent = '';
        }
        
        // Reset and start 30s countdown
        this.state.surpriseTimeLeft = 30;
        this.state.isSurpriseActive = true;
        this.state.surpriseAnswered = false;
        
        const revealAnswer = (chosenIndex) => {
            this.state.surpriseAnswered = true;
            this.state.isSurpriseActive = false;
            if (this.surpriseCountdown) {
                clearInterval(this.surpriseCountdown);
                this.surpriseCountdown = null;
            }
            
            const isCorrect = chosenIndex === q.a;
            
            // Record stats
            this.recordStat(q.c, 'surprise', 'Sürpriz Sual', isCorrect);
            if (isCorrect) {
                this.saveCorrect(q.c, q);
            } else {
                this.saveWrong(q.c, q);
                
                // Multi unit wrong count increment
                if (!this.wrongCounts) this.wrongCounts = {};
                this.wrongCounts[q.q] = (this.wrongCounts[q.q] || 0) + 1;
                localStorage.setItem(this.DB.wrongCounts, JSON.stringify(this.wrongCounts));
            }
            updateDaily(false);
            
            // Sync with Firebase automatically
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
            
            // Style the options to show correct/incorrect
            const buttons = optList.querySelectorAll('.surprise-opt-btn');
            buttons.forEach((btn, idx) => {
                btn.disabled = true;
                if (idx === q.a) {
                    btn.classList.add('correct');
                } else if (idx === chosenIndex) {
                    btn.classList.add('wrong');
                }
            });
            
            const feedbackEl = document.getElementById('surprise-feedback');
            if (feedbackEl) {
                feedbackEl.style.display = 'block';
                if (chosenIndex === null) {
                    feedbackEl.textContent = "⏱️ Vaxt bitdi! Cavablandırılmadı.";
                    feedbackEl.style.color = "var(--wrong)";
                    feedbackEl.style.background = "rgba(239, 68, 68, 0.08)";
                    feedbackEl.style.border = "1px solid rgba(239, 68, 68, 0.15)";
                } else if (isCorrect) {
                    feedbackEl.textContent = "🎉 Doğrudur! Əla.";
                    feedbackEl.style.color = "var(--active)";
                    feedbackEl.style.background = "rgba(16, 185, 129, 0.08)";
                    feedbackEl.style.border = "1px solid rgba(16, 185, 129, 0.15)";
                } else {
                    feedbackEl.textContent = "❌ Yanlışdır! Düzgün cavabı yoxlayın.";
                    feedbackEl.style.color = "var(--wrong)";
                    feedbackEl.style.background = "rgba(239, 68, 68, 0.08)";
                    feedbackEl.style.border = "1px solid rgba(239, 68, 68, 0.15)";
                }
            }
            
            // Display footer to let user close
            footer.style.display = 'flex';
        };
        
        this.revealSurpriseAnswer = revealAnswer;
        
        q.o.forEach((option, idx) => {
            const btn = document.createElement('button');
            btn.className = 'surprise-opt-btn';
            btn.innerHTML = option;
            btn.onclick = () => {
                if (!this.state.surpriseAnswered) {
                    if (btn.classList.contains('selected')) {
                        revealAnswer(idx);
                    } else {
                        const buttons = optList.querySelectorAll('.surprise-opt-btn');
                        buttons.forEach(b => b.classList.remove('selected'));
                        btn.classList.add('selected');
                    }
                }
            };
            optList.appendChild(btn);
        });
        
        overlay.style.display = 'flex';
        this.resumeSurpriseTimer();
    },
    
    resumeSurpriseTimer: function() {
        const timerDisp = document.getElementById('surprise-timer');
        if (!timerDisp) return;
        
        timerDisp.textContent = `${this.state.surpriseTimeLeft}s`;
        timerDisp.style.color = '#ef4444';
        timerDisp.style.background = 'rgba(239,68,68,0.1)';
        timerDisp.style.borderColor = 'rgba(239,68,68,0.2)';

        if (this.surpriseCountdown) clearInterval(this.surpriseCountdown);
        this.surpriseCountdown = setInterval(() => {
            this.state.surpriseTimeLeft--;
            timerDisp.textContent = `${this.state.surpriseTimeLeft}s`;
            if (this.state.surpriseTimeLeft <= 0) {
                clearInterval(this.surpriseCountdown);
                this.surpriseCountdown = null;
                if (!this.state.surpriseAnswered) {
                    this.revealSurpriseAnswer(null);
                }
            }
        }, 1000);
    },
    
    // Close button: stops the countdown first, so an unanswered question is not recorded as wrong
    dismissSurpriseModal: function() {
        if (this.surpriseCountdown) clearInterval(this.surpriseCountdown);
        this.closeSurpriseModal();
    },

    closeSurpriseModal: function() {
        const overlay = document.getElementById('surprise-modal-overlay');
        if (overlay) overlay.style.display = 'none';
        
        this.state.isSurpriseActive = false;
        
        // Resume main timer if we are in quiz view
        if (this.state.view === 'quiz' && this.activeCourse) {
            this.resumeTimer();
        }
        
        // If we are on the home screen, reload the screen to update stats
        if (this.state.view === 'home') {
            this.start();
        }
    },

    formatLastTested: function(ts, hasData = false) {
        if (!ts) return hasData ? 'Əvvəllər' : 'Heç vaxt';
        const d = new Date(ts);
        const now = new Date();
        const diffMs = now - d;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        
        if (diffMins < 1) return 'İndi';
        if (diffMins < 60) return `${diffMins} dəq əvvəl`;
        if (diffHours < 24) return `${diffHours} saat əvvəl`;
        if (diffDays === 1) return 'Dünən';
        if (diffDays < 7) return `${diffDays} gün əvvəl`;
        
        const day = String(d.getDate()).padStart(2, '0');
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const year = d.getFullYear();
        const hours = String(d.getHours()).padStart(2, '0');
        const mins = String(d.getMinutes()).padStart(2, '0');
        return `${day}.${month}.${year} ${hours}:${mins}`;
    },

    getCourseLastTested: function(c) {
        const cs = this.stats[c];
        let maxTs = 0;
        if (cs && cs.bd) {
            Object.keys(cs.bd).forEach(cat => {
                Object.keys(cs.bd[cat]).forEach(sub => {
                    const item = cs.bd[cat][sub];
                    if (item && item.last && item.last > maxTs) {
                        maxTs = item.last;
                    }
                });
            });
        }
        if (maxTs === 0) {
            maxTs = this.getCourseLastActiveDateFromHistory(c);
        }
        return maxTs;
    },

    getCourseLastActiveDateFromHistory: function(c) {
        if (!this.dailyHistory) return 0;
        let mostRecentDateStr = null;
        Object.keys(this.dailyHistory).forEach(dateStr => {
            if (this.dailyHistory[dateStr] && this.dailyHistory[dateStr][c]) {
                if (!mostRecentDateStr || dateStr > mostRecentDateStr) {
                    mostRecentDateStr = dateStr;
                }
            }
        });
        if (mostRecentDateStr) {
            return new Date(mostRecentDateStr + 'T12:00:00').getTime();
        }
        return 0;
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
window.restoreFromBackupFile = QuizApp.restoreFromBackupFile.bind(QuizApp);
window.startMultiUnit = QuizApp.startMultiUnit.bind(QuizApp);
window.closeSurpriseModal = QuizApp.closeSurpriseModal.bind(QuizApp);
window.selectMixedSubSubject = QuizApp.selectMixedSubSubject.bind(QuizApp);

// Simple helpers
function updateDaily(inc = false) {
    let d = JSON.parse(localStorage.getItem(QuizApp.DB.dailyGoal)) || { d: '', c: 0 };
    const tempD = new Date();
    const todayStr = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
    
    const todayData = QuizApp.dailyHistory ? (QuizApp.dailyHistory[todayStr] || {}) : {};
    let todayQuestions = 0;
    Object.keys(todayData).forEach(course => {
        if (course === 'platformTime') return;
        const cData = todayData[course] || {};
        todayQuestions += (cData.correct || 0) + (cData.wrong || 0);
    });

    if (d.d !== tempD.toDateString()) d = { d: tempD.toDateString(), c: 0 };
    d.c = todayQuestions;
    
    localStorage.setItem(QuizApp.DB.dailyGoal, JSON.stringify(d));
    
    // Milestones for celebration
    const milestones = [50, 100, 200, 300, 500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500, 2750, 3000];
    if (inc && milestones.includes(d.c)) {
        try {
            fireMotivationalCelebration(d.c);
        } catch (e) {
            console.error("Celebration error:", e);
        }
    }

    // Determine current level and target
    let currentLevel = "Amateur";
    let target = 50;
    
    if (d.c < 50) {
        currentLevel = "Amateur";
        target = 50;
    } else if (d.c < 100) {
        currentLevel = "Beginner";
        target = 100;
    } else if (d.c < 200) {
        currentLevel = "Novice";
        target = 200;
    } else if (d.c < 300) {
        currentLevel = "Intermediate";
        target = 300;
    } else if (d.c < 500) {
        currentLevel = "Advanced";
        target = 500;
    } else if (d.c < 750) {
        currentLevel = "Expert";
        target = 750;
    } else if (d.c < 1000) {
        currentLevel = "Master";
        target = 1000;
    } else if (d.c < 1250) {
        currentLevel = "Grandmaster";
        target = 1250;
    } else if (d.c < 1500) {
        currentLevel = "Conqueror";
        target = 1500;
    } else if (d.c < 1750) {
        currentLevel = "Champion";
        target = 1750;
    } else if (d.c < 2000) {
        currentLevel = "Legend";
        target = 2000;
    } else if (d.c < 2250) {
        currentLevel = "Immortal";
        target = 2250;
    } else if (d.c < 2500) {
        currentLevel = "Mythic";
        target = 2500;
    } else if (d.c < 2750) {
        currentLevel = "Demi-God";
        target = 2750;
    } else if (d.c < 3000) {
        currentLevel = "Godlike";
        target = 3000;
    } else {
        currentLevel = "Titan";
        target = 3000;
    }

    const dt = document.getElementById('daily-text');
    const db = document.getElementById('daily-bar');
    const dl = document.getElementById('daily-label');
    
    if (dt && db) {
        dt.textContent = `${d.c}/${target}`;
        db.style.width = Math.min((d.c / target) * 100, 100) + '%';
        if (dl) {
            dl.textContent = `HƏDƏF: ${currentLevel.toUpperCase()}`;
        }
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


const CELEBRATION_DATA = {
    50: { level: "Beginner", quote: "İlk addım ən çətinidir. Sən başladın və irəliləyirsən! 🚀" },
    100: { level: "Novice", quote: "Mükəmməllik vərdişdir. Hər gün daha da güclənirsən! 💪" },
    200: { level: "Intermediate", quote: "Dayanmaq yoxdur! Limitlər yalnız zehindədir. 🧠" },
    300: { level: "Advanced", quote: "Artıq digərlərindən bir addım öndəsən. Möhtəşəm nəticədir! ⭐" },
    500: { level: "Expert", quote: "Fokuslanma və nizam-intizam. Əsl peşəkar kimi davam edirsən! 🔥" },
    750: { level: "Master", quote: "Zirvəyə çox az qaldı. Sənin iradən sarsılmazdır! 👑" },
    1000: { level: "Grandmaster", quote: "Möhtəşəm! Sən artıq bir Grandmaster-sən. Hədəfləri fəth etməyə davam et! 🏆" },
    1250: { level: "Conqueror", quote: "Fatih! Sən çətinlikləri üstələyərək hər şeyi fəth edirsən! 🗡️" },
    1500: { level: "Champion", quote: "Çempion! Qələbə sənin qanındadır. İlham verməyə davam et! 🏅" },
    1750: { level: "Legend", quote: "Əfsanə! Adını bu günün tarixinə yazdın. İnanılmaz iradə! 🌟" },
    2000: { level: "Immortal", quote: "Ölümsüz! Sən artıq bu sistemin ən uca zirvəsindəsən. Sərhədsiz güc! 🌌" },
    2250: { level: "Mythic", quote: "Mifik! Sənin bu nailiyyətin dildən-dilə gəzəcək bir dastan yazır! 📖✨" },
    2500: { level: "Demi-God", quote: "Yarı-Tanrı! Gücün və intizamın qarşısında heç bir sual dayana bilməz! ⚡" },
    2750: { level: "Godlike", quote: "Tanrısal! Sənin iradən artıq bu aləmin fizika qanunlarını aşmışdır! 🌌☄️" },
    3000: { level: "Titan", quote: "TİTAN! Sən sistemin ən uca zirvəsini fəth etdin, mükəmməlliyin canlı sübutusan! 👑🪐🏆" }
};

function fireMotivationalCelebration(milestone) {
    const data = CELEBRATION_DATA[milestone] || { level: "Legend", quote: "Hər gün bir addım irəli! Sərhədləri aşmağa davam et! 🌟" };
    
    let overlay = document.getElementById('mot-celebration-overlay');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'mot-celebration-overlay';
        overlay.className = 'mot-celebration-overlay';
        document.body.appendChild(overlay);
    }
    
    overlay.innerHTML = `
        <canvas id="celebration-canvas" class="celebration-canvas"></canvas>
        <div class="mot-celebration-card ${milestone === 3000 ? 'mot-card-3000' : ''}">
            <div class="${milestone === 3000 ? 'mot-floating-wrap' : ''}">
                <div class="mot-badge-wrap">${milestone === 3000 ? '🌌👑🏆👑🌌' : '🏆'}</div>
                <div class="mot-level-title">${milestone === 3000 ? '🏆 LİMİTSİZ ZİRVƏ 🏆' : 'YENİ SƏVİYYƏ'}</div>
                <div class="mot-level-name">${data.level.toUpperCase()}</div>
                <div class="mot-quote">"${data.quote}"</div>
                <div class="mot-milestone-text">Bugünkü Hədəf: ${milestone} Sual Cavablandırıldı!</div>
                <button class="btn btn-primary mot-close-btn" onclick="document.getElementById('mot-celebration-overlay').classList.remove('active')">Davam Et</button>
            </div>
        </div>
    `;
    
    setTimeout(() => overlay.classList.add('active'), 50);
    
    const canvas = document.getElementById('celebration-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    
    const resizeCanvas = () => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    };
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);
    
    class Sparkle {
        constructor(x, y, color) {
            this.x = x;
            this.y = y;
            this.color = color;
            this.radius = Math.random() * 2 + 1;
            const angle = Math.random() * Math.PI * 2;
            const speed = Math.random() * 5 + 1;
            this.vx = Math.cos(angle) * speed;
            this.vy = Math.sin(angle) * speed;
            this.alpha = 1;
            this.decay = Math.random() * 0.015 + 0.01;
            this.gravity = 0.04;
        }
        update() {
            this.vy += this.gravity;
            this.x += this.vx;
            this.y += this.vy;
            this.alpha -= this.decay;
        }
        draw() {
            ctx.save();
            ctx.globalAlpha = this.alpha;
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 8;
            ctx.shadowColor = this.color;
            ctx.fill();
            ctx.restore();
        }
    }
    
    class Rocket {
        constructor() {
            this.x = Math.random() * (canvas.width - 200) + 100;
            this.y = canvas.height;
            this.targetY = Math.random() * (canvas.height * 0.5);
            const dx = (Math.random() * canvas.width * 0.4 + canvas.width * 0.3) - this.x;
            const dy = this.targetY - this.y;
            this.vx = dx / 50;
            this.vy = dy / 50;
            this.color = `hsl(${Math.random() * 360}, 100%, 60%)`;
            this.exploded = false;
        }
        update() {
            if (!this.exploded) {
                this.x += this.vx;
                this.y += this.vy;
                if (this.y <= this.targetY) {
                    this.exploded = true;
                    for (let i = 0; i < 40; i++) {
                        sparkles.push(new Sparkle(this.x, this.y, this.color));
                    }
                }
            }
        }
        draw() {
            if (!this.exploded) {
                ctx.beginPath();
                ctx.arc(this.x, this.y, 3, 0, Math.PI * 2);
                ctx.fillStyle = this.color;
                ctx.shadowBlur = 10;
                ctx.shadowColor = this.color;
                ctx.fill();
            }
        }
    }

    class Confetti {
        constructor() {
            this.x = Math.random() * canvas.width;
            this.y = Math.random() * -canvas.height;
            this.r = Math.random() * 6 + 4;
            this.d = Math.random() * canvas.height;
            const colors = ['#8b5cf6', '#8b5cf6', '#10b981', '#ef4444', '#f59e0b', '#8b5cf6'];
            this.color = colors[Math.floor(Math.random() * colors.length)];
            this.tilt = Math.random() * 10 - 5;
            this.tiltAngleIncremental = Math.random() * 0.07 + 0.02;
            this.tiltAngle = 0;
            this.vy = Math.random() * 2 + 2;
        }
        update() {
            this.tiltAngle += this.tiltAngleIncremental;
            this.y += this.vy;
            this.x += Math.sin(this.tiltAngle);
            this.tilt = Math.sin(this.tiltAngle - this.r / 2) * 15;
        }
        draw() {
            ctx.save();
            ctx.beginPath();
            ctx.lineWidth = this.r;
            ctx.strokeStyle = this.color;
            ctx.moveTo(this.x + this.tilt + this.r / 2, this.y);
            ctx.lineTo(this.x + this.tilt, this.y + this.tilt + this.r / 2);
            ctx.stroke();
            ctx.restore();
        }
    }

    class GoldenStar {
        constructor() {
            this.x = Math.random() * canvas.width;
            this.y = Math.random() * -canvas.height;
            this.size = Math.random() * 8 + 6;
            this.vy = Math.random() * 1.5 + 1;
            this.vx = Math.sin(Math.random() * Math.PI) * 0.5;
            this.rotation = Math.random() * Math.PI;
            this.rotationSpeed = Math.random() * 0.02 + 0.01;
            this.color = Math.random() > 0.3 ? '#ffd700' : '#ff8c00';
            this.alpha = 1;
        }
        update() {
            this.y += this.vy;
            this.x += this.vx;
            this.rotation += this.rotationSpeed;
            if (this.y > canvas.height - 50) {
                this.alpha -= 0.02;
            }
        }
        draw() {
            if (this.alpha <= 0) return;
            ctx.save();
            ctx.globalAlpha = this.alpha;
            ctx.translate(this.x, this.y);
            ctx.rotate(this.rotation);
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 10;
            ctx.shadowColor = this.color;
            ctx.beginPath();
            for (let i = 0; i < 5; i++) {
                ctx.lineTo(Math.cos((18 + i * 72) * Math.PI / 180) * this.size,
                           Math.sin((18 + i * 72) * Math.PI / 180) * this.size);
                ctx.lineTo(Math.cos((54 + i * 72) * Math.PI / 180) * (this.size / 2),
                           Math.sin((54 + i * 72) * Math.PI / 180) * (this.size / 2));
            }
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
    }

    class SupernovaOrb {
        constructor(x, y) {
            this.x = x;
            this.y = y;
            this.radius = 5;
            this.alpha = 1;
            this.pulsate = 0;
            this.exploded = false;
            this.glow = 10;
        }
        update() {
            if (!this.exploded) {
                this.pulsate += 0.15;
                this.radius = 5 + Math.sin(this.pulsate) * 8 + (this.pulsate * 3.5);
                this.glow = 10 + this.radius * 2;
                if (this.radius > 110) {
                    this.exploded = true;
                    // Trigger Galaxy Spiral arms!
                    const colors = ['#ffd700', '#ff8c00', '#ff0080', '#8a2be2', '#00ffff'];
                    for (let arm = 0; arm < 4; arm++) {
                        const armAngle = (arm * Math.PI) / 2;
                        for (let i = 0; i < 100; i++) {
                            const angle = armAngle + (Math.random() * 0.4 - 0.2);
                            const speed = Math.random() * 3.5 + 1;
                            const color = colors[Math.floor(Math.random() * colors.length)];
                            galaxyParticles.push(new GalaxyParticle(this.x, this.y, angle, speed, color));
                        }
                    }
                    // Trigger shockwaves
                    for (let r = 0; r < 3; r++) {
                        shockwaves.push(new Shockwave(this.x, this.y, r * 12 + 10));
                    }
                }
            }
        }
        draw() {
            if (!this.exploded) {
                ctx.save();
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
                const grad = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, this.radius);
                grad.addColorStop(0, '#ffffff');
                grad.addColorStop(0.3, '#ffd700');
                grad.addColorStop(0.8, '#ff0080');
                grad.addColorStop(1, 'rgba(15, 23, 42, 0)');
                ctx.fillStyle = grad;
                ctx.shadowBlur = this.glow;
                ctx.shadowColor = '#ffd700';
                ctx.fill();
                ctx.restore();
            }
        }
    }

    class GalaxyParticle {
        constructor(centerX, centerY, angle, speed, color) {
            this.centerX = centerX;
            this.centerY = centerY;
            this.angle = angle;
            this.radius = 0;
            this.speed = speed;
            this.color = color;
            this.size = Math.random() * 2 + 1.5;
            this.alpha = 1;
            this.rotationSpeed = Math.random() * 0.015 + 0.01;
            this.fadeSpeed = Math.random() * 0.003 + 0.001;
        }
        update() {
            this.angle += this.rotationSpeed;
            this.radius += this.speed;
            this.x = this.centerX + Math.cos(this.angle) * this.radius;
            this.y = this.centerY + Math.sin(this.angle) * this.radius;
            this.alpha -= this.fadeSpeed;
        }
        draw() {
            if (this.alpha <= 0) return;
            ctx.save();
            ctx.globalAlpha = this.alpha;
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 8;
            ctx.shadowColor = this.color;
            ctx.fill();
            ctx.restore();
        }
    }

    class Shockwave {
        constructor(x, y, startSpeed) {
            this.x = x;
            this.y = y;
            this.radius = 10;
            this.speed = startSpeed;
            this.alpha = 1;
            this.color = `hsl(${Math.random() * 360}, 100%, 70%)`;
        }
        update() {
            this.radius += this.speed;
            this.speed *= 0.95;
            this.alpha -= 0.012;
        }
        draw() {
            if (this.alpha <= 0) return;
            ctx.save();
            ctx.globalAlpha = this.alpha;
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.lineWidth = 5;
            ctx.strokeStyle = this.color;
            ctx.shadowBlur = 15;
            ctx.shadowColor = this.color;
            ctx.stroke();
            ctx.restore();
        }
    }

    class CornerRocket {
        constructor(side) {
            this.side = side;
            this.x = side === 'left' ? 0 : canvas.width;
            this.y = canvas.height;
            const targetX = canvas.width * 0.5 + (Math.random() * 200 - 100);
            const targetY = canvas.height * 0.2 + (Math.random() * 150);
            const dx = targetX - this.x;
            const dy = targetY - this.y;
            this.vx = dx / 45;
            this.vy = dy / 45;
            this.color = `hsl(${Math.random() * 360}, 100%, 65%)`;
            this.exploded = false;
            this.trail = [];
        }
        update() {
            if (!this.exploded) {
                this.trail.push({ x: this.x, y: this.y });
                if (this.trail.length > 8) this.trail.shift();
                this.x += this.vx;
                this.y += this.vy;
                if (this.y <= canvas.height * 0.35 || this.y <= 120) {
                    this.exploded = true;
                    for (let i = 0; i < 50; i++) {
                        sparkles.push(new Sparkle(this.x, this.y, this.color));
                    }
                }
            }
        }
        draw() {
            if (!this.exploded) {
                ctx.save();
                for (let i = 0; i < this.trail.length; i++) {
                    const t = this.trail[i];
                    ctx.globalAlpha = (i / this.trail.length) * 0.4;
                    ctx.beginPath();
                    ctx.arc(t.x, t.y, 2, 0, Math.PI * 2);
                    ctx.fillStyle = this.color;
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
                ctx.beginPath();
                ctx.arc(this.x, this.y, 4, 0, Math.PI * 2);
                ctx.fillStyle = '#ffffff';
                ctx.shadowBlur = 15;
                ctx.shadowColor = this.color;
                ctx.fill();
                ctx.restore();
            }
        }
    }
    
    const rockets = [];
    const cornerRockets = [];
    const sparkles = [];
    const confetti = [];
    const galaxyParticles = [];
    const shockwaves = [];
    const goldenStars = [];
    const supernovaOrbs = [];
    let animationActive = true;
    
    // Initialize particles based on milestone
    if (milestone === 3000) {
        supernovaOrbs.push(new SupernovaOrb(canvas.width / 2, canvas.height / 2));
        for (let i = 0; i < 80; i++) {
            goldenStars.push(new GoldenStar());
        }
    } else if (milestone >= 2250) {
        for (let i = 0; i < 100; i++) {
            confetti.push(new Confetti());
        }
        for (let i = 0; i < 5; i++) {
            setTimeout(() => {
                if (animationActive) rockets.push(new Rocket());
            }, i * 400);
        }
    } else {
        for (let i = 0; i < 5; i++) {
            setTimeout(() => {
                if (animationActive) rockets.push(new Rocket());
            }, i * 500);
        }
    }
    
    const animate = () => {
        if (!animationActive) return;
        ctx.fillStyle = 'rgba(15, 23, 42, 0.15)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        // Update & Draw Supernova Orbs
        for (let i = supernovaOrbs.length - 1; i >= 0; i--) {
            supernovaOrbs[i].update();
            supernovaOrbs[i].draw();
            if (supernovaOrbs[i].exploded) {
                supernovaOrbs.splice(i, 1);
            }
        }
        
        // Update & Draw Galaxy Particles
        for (let i = galaxyParticles.length - 1; i >= 0; i--) {
            galaxyParticles[i].update();
            galaxyParticles[i].draw();
            if (galaxyParticles[i].alpha <= 0) {
                galaxyParticles.splice(i, 1);
            }
        }
        
        // Update & Draw Shockwaves
        for (let i = shockwaves.length - 1; i >= 0; i--) {
            shockwaves[i].update();
            shockwaves[i].draw();
            if (shockwaves[i].alpha <= 0) {
                shockwaves.splice(i, 1);
            }
        }
        
        // Update & Draw Corner Rockets
        for (let i = cornerRockets.length - 1; i >= 0; i--) {
            cornerRockets[i].update();
            cornerRockets[i].draw();
            if (cornerRockets[i].exploded) {
                cornerRockets.splice(i, 1);
            }
        }
        
        // Update & Draw Rockets
        for (let i = rockets.length - 1; i >= 0; i--) {
            rockets[i].update();
            rockets[i].draw();
            if (rockets[i].exploded) {
                rockets.splice(i, 1);
            }
        }
        
        // Update & Draw Sparkles
        for (let i = sparkles.length - 1; i >= 0; i--) {
            sparkles[i].update();
            sparkles[i].draw();
            if (sparkles[i].alpha <= 0) {
                sparkles.splice(i, 1);
            }
        }
        
        // Update & Draw Confetti
        for (let i = confetti.length - 1; i >= 0; i--) {
            confetti[i].update();
            confetti[i].draw();
            if (confetti[i].y > canvas.height + 20) {
                confetti.splice(i, 1);
            }
        }
        
        // Update & Draw Golden Stars
        for (let i = goldenStars.length - 1; i >= 0; i--) {
            goldenStars[i].update();
            goldenStars[i].draw();
            if (goldenStars[i].y > canvas.height + 20 || goldenStars[i].alpha <= 0) {
                goldenStars.splice(i, 1);
            }
        }
        
        // Spawning extra particles during animation loop
        if (milestone === 3000) {
            if (Math.random() < 0.25 && goldenStars.length < 120) {
                goldenStars.push(new GoldenStar());
            }
            if (Math.random() < 0.04 && cornerRockets.length < 3) {
                cornerRockets.push(new CornerRocket(Math.random() > 0.5 ? 'left' : 'right'));
            }
        } else if (milestone >= 2250) {
            if (Math.random() < 0.15 && confetti.length < 120) {
                confetti.push(new Confetti());
            }
            if (Math.random() < 0.03 && rockets.length < 4) {
                rockets.push(new Rocket());
            }
        } else {
            if (Math.random() < 0.03 && rockets.length < 4) {
                rockets.push(new Rocket());
            }
        }
        
        requestAnimationFrame(animate);
    };
    animate();
    
    const duration = milestone === 3000 ? 8000 : (milestone >= 2250 ? 6000 : 4500);
    setTimeout(() => {
        animationActive = false;
        overlay.classList.remove('active');
        window.removeEventListener('resize', resizeCanvas);
    }, duration);
}

function fireConfetti() {
    const canvas = document.getElementById('confetti-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    
    const colors = ['#8b5cf6', '#8b5cf6', '#10b981', '#ef4444', '#f59e0b', '#8b5cf6'];
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
            QuizApp.pauseTimer();
        }
        QuizApp.pausePlatformTimer();
        if (QuizApp.surpriseCountdown && QuizApp.state.isSurpriseActive) {
            clearInterval(QuizApp.surpriseCountdown);
            QuizApp.surpriseCountdown = null;
        }
    } else if (document.visibilityState === 'visible') {
        QuizApp.startPlatformTimer();
        if (QuizApp.activeCourse && !QuizApp.timer && !QuizApp.state.isSurpriseActive) {
            QuizApp.resumeTimer();
        }
        if (QuizApp.state.isSurpriseActive && !QuizApp.surpriseCountdown) {
            QuizApp.resumeSurpriseTimer();
        }
    }
});

// Keyboard Shortcuts for Quiz Screen
window.addEventListener('keydown', (e) => {
    if (QuizApp.state.view !== 'quiz' || QuizApp.state.isSurpriseActive) return;

    // input, textarea və ya contenteditable elementlərdə yazarkən qısayollar işləməsin
    const activeEl = document.activeElement;
    if (activeEl && (
        activeEl.tagName === 'INPUT' || 
        activeEl.tagName === 'TEXTAREA' || 
        activeEl.isContentEditable
    )) {
        return;
    }

    const key = e.key.toLowerCase();

    // 1-5 və ya A-E / a-e variant seçimi
    const variantKeys = ['1', '2', '3', '4', '5'];
    const letterKeys = ['a', 'b', 'c', 'd', 'e'];
    
    let optIdx = -1;
    if (variantKeys.includes(key)) {
        optIdx = variantKeys.indexOf(key);
    } else if (letterKeys.includes(key)) {
        optIdx = letterKeys.indexOf(key);
    }

    if (optIdx !== -1) {
        if (!QuizApp.state.answers[QuizApp.state.index]) {
            const q = QuizApp.state.questions[QuizApp.state.index];
            if (q && q.shuffledOpts && q.shuffledOpts[optIdx]) {
                QuizApp.checkAnswer(q.shuffledOpts[optIdx].i);
            }
        }
        return;
    }

    // Növbəti: Backspace, Enter, Space, ArrowRight
    if (key === 'backspace' || key === 'enter' || e.code === 'Space' || key === 'arrowright') {
        if (key === 'backspace' || e.code === 'Space') {
            e.preventDefault();
        }
        
        const btnNext = document.getElementById('btn-next');
        if (btnNext && !btnNext.disabled) {
            btnNext.click();
        }
        return;
    }

    // Əvvəlki: ArrowLeft
    if (key === 'arrowleft') {
        if (QuizApp.state.index > 0) {
            QuizApp.nav(-1);
        }
        return;
    }
});
