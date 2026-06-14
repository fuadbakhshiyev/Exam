const COURSE_STYLES = {
    "Atatürk İlkeleri ve İnkılap Tarihi II": { icon: "🏛️", accent: "#ef4444", g1: "#ef4444", g2: "#f97316" },
    "Görsel İletişim Tasarımı": { icon: "🎨", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" },
    "Grafik Tasarım II": { icon: "📐", accent: "#10b981", g1: "#10b981", g2: "#06b6d4" },
    "Masaüstü Yayıncılık": { icon: "💻", accent: "#3b82f6", g1: "#3b82f6", g2: "#6366f1" },
    "Tasarımda Tipografi": { icon: "✍️", accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444" },
    "Türk Dili II": { icon: "📖", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899" },
    "Mixed": { icon: "🔀", accent: "#ec4899", g1: "#ec4899", g2: "#f43f5e" }
};

const QuizApp = {
    state: { course: null, category: null, currentTitle: null, questions: [], index: 0, answers: {}, correct: 0, wrong: 0, view: 'quiz', sessionStartTime: 0, isWrongMode: false, isSearchMode: false, isMockMode: false, isFlashcard: false },
    DB: { stats: 'qa_v31_s', wrong: 'qa_v31_w', correct: 'qa_v31_c', marks: 'qa_v31_m', daily: 'qa_v31_h', dailyGoal: 'qa_v31_dg', settings: 'qa_v31_conf', wrongCounts: 'qa_v31_wc' },
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
        
        // Inject manual exam results for Tasarımda Tipografi (20 correct, 0 wrong, 4 mins)
        if (!localStorage.getItem('qa_v31_injected_tipografi_20_20_v2')) {
            const course = "Tasarımda Tipografi";
            if (!localStorage.getItem('qa_v31_injected_tipografi_20_20')) {
                for (let i = 0; i < 20; i++) {
                    this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
                }
                if (this.stats[course]) {
                    this.stats[course].time += 240;
                }
                this.recordDailyHistory(course, null, 240);
                this.saveStats();
                localStorage.setItem('qa_v31_injected_tipografi_20_20', 'true');
            }
            updateDaily(20);
            localStorage.setItem('qa_v31_injected_tipografi_20_20_v2', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject manual exam results for Tasarımda Tipografi (19 correct, 0 wrong, 3 mins)
        if (!localStorage.getItem('qa_v31_injected_tipografi_19_19')) {
            const course = "Tasarımda Tipografi";
            for (let i = 0; i < 19; i++) {
                this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            }
            if (this.stats[course]) {
                this.stats[course].time += 180;
            }
            this.recordDailyHistory(course, null, 180);
            this.saveStats();
            updateDaily(19);
            localStorage.setItem('qa_v31_injected_tipografi_19_19', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject 52 tests into yesterday's history
        if (!localStorage.getItem('qa_v31_injected_52_tests_v3')) {
            const tempD = new Date();
            const todayStr = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
            
            tempD.setDate(tempD.getDate() - 1);
            const yesterdayStr = `${tempD.getFullYear()}-${String(tempD.getMonth() + 1).padStart(2, '0')}-${String(tempD.getDate()).padStart(2, '0')}`;
            
            if (!this.dailyHistory) this.dailyHistory = {};
            
            // Clean up today's incorrect injection if it exists
            if (this.dailyHistory[todayStr] && this.dailyHistory[todayStr]["Tasarımda Tipografi"]) {
                this.dailyHistory[todayStr]["Tasarımda Tipografi"].correct = Math.max(0, this.dailyHistory[todayStr]["Tasarımda Tipografi"].correct - 52);
            }
            
            // Inject to yesterday's history
            if (!this.dailyHistory[yesterdayStr]) this.dailyHistory[yesterdayStr] = {};
            const course = "Tasarımda Tipografi";
            if (!this.dailyHistory[yesterdayStr][course]) {
                this.dailyHistory[yesterdayStr][course] = { time: 0, correct: 0, wrong: 0 };
            }
            this.dailyHistory[yesterdayStr][course].correct += 52;
            this.saveStats();
            
            updateDaily(false);
            localStorage.setItem('qa_v31_injected_52_tests_v2', 'true');
            localStorage.setItem('qa_v31_injected_52_tests_v3', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject manual exam results for Görsel İletişim Tasarımı (92 correct, 8 wrong, 1140s)
        if (!localStorage.getItem('qa_v31_injected_gorsel_iletisim')) {
            const course = "Görsel İletişim Tasarımı";
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 19 correct, 1 wrong
            for (let i = 0; i < 19; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 1; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 19 correct, 1 wrong
            for (let i = 0; i < 19; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 1; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            if (this.stats[course]) {
                this.stats[course].time += 1140;
            }
            this.recordDailyHistory(course, null, 1140);
            this.saveStats();
            
            updateDaily(false);
            localStorage.setItem('qa_v31_injected_gorsel_iletisim', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject manual exam results for Görsel İletişim Tasarımı Part 2 (74 correct, 6 wrong, 1020s)
        if (!localStorage.getItem('qa_v31_injected_gorsel_iletisim_part2')) {
            const course = "Görsel İletişim Tasarımı";
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 20 correct, 0 wrong
            for (let i = 0; i < 20; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            if (this.stats[course]) {
                this.stats[course].time += 1020;
            }
            this.recordDailyHistory(course, null, 1020);
            this.saveStats();
            
            updateDaily(false);
            localStorage.setItem('qa_v31_injected_gorsel_iletisim_part2', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject manual exam results for Grafik Tasarım II (90 correct, 10 wrong, 1221s)
        if (!localStorage.getItem('qa_v31_injected_grafik_tasarim')) {
            const course = "Grafik Tasarım II";
            
            // 17 correct, 3 wrong
            for (let i = 0; i < 17; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 3; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 18 correct, 2 wrong
            for (let i = 0; i < 18; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 2; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 19 correct, 1 wrong
            for (let i = 0; i < 19; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 1; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 19 correct, 1 wrong
            for (let i = 0; i < 19; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 1; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            // 17 correct, 3 wrong
            for (let i = 0; i < 17; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            for (let i = 0; i < 3; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', false);
            
            if (this.stats[course]) {
                this.stats[course].time += 1221;
            }
            this.recordDailyHistory(course, null, 1221);
            this.saveStats();
            
            updateDaily(false);
            localStorage.setItem('qa_v31_injected_grafik_tasarim', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }

        // Inject manual exam results for Masaüstü Yayıncılık (20 correct, 0 wrong, 213s)
        if (!localStorage.getItem('qa_v31_injected_masaustu_yayin')) {
            const course = "Masaüstü Yayıncılık";
            
            // 20 correct, 0 wrong
            for (let i = 0; i < 20; i++) this.recordStat(course, 'mixed', 'Qarışıq Sınaq', true);
            
            if (this.stats[course]) {
                this.stats[course].time += 213;
            }
            this.recordDailyHistory(course, null, 213);
            this.saveStats();
            
            updateDaily(false);
            localStorage.setItem('qa_v31_injected_masaustu_yayin', 'true');
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
        }
    },

    buildMixedUnits: function () {
        if (typeof quizData === 'undefined') return;
        
        const subjects = [
            "Atatürk İlkeleri ve İnkılap Tarihi II",
            "Grafik Tasarım II",
            "Görsel İletişim Tasarımı",
            "Masaüstü Yayıncılık",
            "Tasarımda Tipografi",
            "Türk Dili II"
        ];
        
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

    renderMixedDashboard: function (listEl, layout, s) {
        listEl.innerHTML = "";
        const c = "Mixed";
        
        // If in Level 2 (Sub-subject view)
        if (this.state.mixedSubSubject) {
            const subSubject = this.state.mixedSubSubject;
            
            // Add a Back Button at the top of the unit list
            const backHeader = document.createElement('div');
            backHeader.style.gridColumn = '1 / -1';
            backHeader.style.marginBottom = '8px';
            backHeader.innerHTML = `
                <button class="btn btn-sec" style="padding: 8px 16px; width: auto; font-size: 0.85rem;" onclick="QuizApp.state.mixedSubSubject = null; QuizApp.showCourseDashboard('Mixed')">
                    ← Fənlər Siyahısına Qayıt
                </button>
                <div style="font-size: 1.1rem; font-weight: 700; color: var(--text-main); margin-top: 12px; font-family: 'Plus Jakarta Sans', sans-serif;">
                    ${subSubject} - Bölmələr
                </div>
            `;
            listEl.appendChild(backHeader);
            
            // Filter chunks belonging to this subSubject
            const filteredChunks = this.mixedUnitsInfo.map((chunk, idx) => ({ chunk, idx }))
                .filter(item => item.chunk.subject === subSubject);
            
            if (layout === 'table') {
                listEl.classList.add('table-mode');
                const table = document.createElement('table');
                table.className = 'stat-table unit-table';
                
                let tbodyHTML = "";
                filteredChunks.forEach(({ chunk, idx }) => {
                    const unitKey = `Unit ${idx + 1}`;
                    let c_correct = 0, c_wrong = 0, unitLastTested = 0;
                    if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                        const us = s.bd['units'][unitKey];
                        c_correct = us.c;
                        c_wrong = us.w;
                        unitLastTested = us.last || 0;
                    }
                    const totalAnswered = c_correct + c_wrong;
                    const unitAcc = totalAnswered > 0 ? Math.round((c_correct / totalAnswered) * 100) : 0;
                    const totalUnitQ = chunk.endIdx - chunk.startIdx;
                    const unitLastTestedStr = this.formatLastTested(unitLastTested, totalAnswered > 0);
                    
                    tbodyHTML += `
                        <tr onclick="QuizApp.startUnit('Mixed', ${idx})">
                            <td style="font-weight: 700; color: var(--text-main);">
                                <div class="unit-table-title">Hissə ${chunk.part} (${chunk.startIdx + 1}-${chunk.endIdx})</div>
                                <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                    Son sınaq: ${unitLastTestedStr}
                                </div>
                            </td>
                            <td style="text-align: center;">${totalUnitQ}</td>
                            <td style="text-align: center; color: var(--active); font-weight: 700;">${c_correct}</td>
                            <td style="text-align: center; color: var(--wrong); font-weight: 700;">${c_wrong}</td>
                            <td style="text-align: center; color: var(--accent); font-weight: 700;">${unitAcc}%</td>
                            <td style="text-align: right;" onclick="event.stopPropagation();">
                                <button class="unit-btn-start" onclick="QuizApp.startUnit('Mixed', ${idx})">Başla</button>
                            </td>
                        </tr>
                    `;
                });
                
                table.innerHTML = `
                    <thead>
                        <tr>
                            <th style="width: 45%;">Hissə</th>
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
                
                filteredChunks.forEach(({ chunk, idx }) => {
                    const unitKey = `Unit ${idx + 1}`;
                    let c_correct = 0, c_wrong = 0, unitLastTested = 0;
                    if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                        const us = s.bd['units'][unitKey];
                        c_correct = us.c;
                        c_wrong = us.w;
                        unitLastTested = us.last || 0;
                    }
                    const totalAnswered = c_correct + c_wrong;
                    const totalUnitQ = chunk.endIdx - chunk.startIdx;
                    const unitLastTestedStr = this.formatLastTested(unitLastTested, totalAnswered > 0);
                    
                    const item = document.createElement('div');
                    item.className = 'unit-item';
                    item.innerHTML = `
                        <div class="unit-item-header">
                            <div>
                                <div class="unit-item-title">Hissə ${chunk.part} (${chunk.startIdx + 1}-${chunk.endIdx})</div>
                                <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                    ⏱️ Son sınaq: ${unitLastTestedStr}
                                </div>
                            </div>
                            <button class="unit-btn-start" onclick="QuizApp.startUnit('Mixed', ${idx})">Başla</button>
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
        } else {
            // Level 1: Subjects List
            const subjects = [
                "Atatürk İlkeleri ve İnkılap Tarihi II",
                "Grafik Tasarım II",
                "Görsel İletişim Tasarımı",
                "Masaüstü Yayıncılık",
                "Tasarımda Tipografi",
                "Türk Dili II"
            ];
            
            const wrQs = this.wrongDB[c] || [];
            const hardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 2).length;
            const veryHardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 3).length;
            
            // Render Multi row/card first
            if (layout === 'table') {
                listEl.classList.add('table-mode');
                const table = document.createElement('table');
                table.className = 'stat-table unit-table';
                
                let multiLastTested = 0;
                let hasMultiData = false;
                if (s.bd && s.bd['units'] && s.bd['units']['Multi']) {
                    multiLastTested = s.bd['units']['Multi'].last || 0;
                    hasMultiData = (s.bd['units']['Multi'].t || 0) > 0;
                }
                if (multiLastTested === 0 && hasMultiData) {
                    multiLastTested = this.getCourseLastActiveDateFromHistory(c);
                }
                const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);
                
                let tbodyHTML = `
                    <tr onclick="QuizApp.startMultiUnit('Mixed')" style="background: rgba(99, 102, 241, 0.05); border-left: 3px solid var(--accent);">
                        <td style="font-weight: 800; color: var(--accent);">
                            <div class="unit-table-title"><span class="unit-table-num">⭐</span> Multi (Səhvlərin Təkrarı)</div>
                            <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                ⏱️ Son sınaq: ${multiLastTestedStr}
                            </div>
                            ${hardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(245, 158, 11, 0.08); border: 1px solid var(--hint); color: var(--hint); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">⚠️ ${hardQsCount} Çətin</span>` : ''}
                            ${veryHardQsCount > 0 ? `<span class="badge-hard" style="background: rgba(239, 68, 68, 0.08); border: 1px solid var(--wrong); color: var(--wrong); font-size: 0.72rem; font-weight: 700; padding: 2px 8px; border-radius: 6px; margin-left: 8px; vertical-align: middle; display: inline-flex; align-items: center; gap: 4px;">🔥 ${veryHardQsCount} Çox Çətin</span>` : ''}
                        </td>
                        <td style="text-align: center;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--active); font-weight: 700;">-</td>
                        <td style="text-align: center; color: var(--wrong); font-weight: 700;">${wrQs.length}</td>
                        <td style="text-align: center; color: var(--accent); font-weight: 700;">-</td>
                        <td style="text-align: right;" onclick="event.stopPropagation();">
                            <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('Mixed')">Başla</button>
                        </td>
                    </tr>
                `;
                
                subjects.forEach((subjName, sIdx) => {
                    const uVal = sIdx + 1;
                    // Aggregate stats for this subject
                    let c_correct = 0, c_wrong = 0, subjLastTested = 0;
                    const subjChunks = this.mixedUnitsInfo.map((chunk, idx) => ({ chunk, idx }))
                        .filter(item => item.chunk.uVal === uVal);
                    
                    let totalSubjQ = 0;
                    subjChunks.forEach(({ chunk, idx }) => {
                        totalSubjQ += chunk.endIdx - chunk.startIdx;
                        const unitKey = `Unit ${idx + 1}`;
                        if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                            const us = s.bd['units'][unitKey];
                            c_correct += us.c || 0;
                            c_wrong += us.w || 0;
                            subjLastTested = Math.max(subjLastTested, us.last || 0);
                        }
                    });
                    
                    const totalAnswered = c_correct + c_wrong;
                    const subjAcc = totalAnswered > 0 ? Math.round((c_correct / totalAnswered) * 100) : 0;
                    if (subjLastTested === 0 && totalAnswered > 0) {
                        subjLastTested = this.getCourseLastActiveDateFromHistory(c);
                    }
                    const subjLastTestedStr = this.formatLastTested(subjLastTested, totalAnswered > 0);
                    
                    tbodyHTML += `
                        <tr onclick="QuizApp.selectMixedSubSubject('${subjName.replace(/'/g, "\\'")}')">
                            <td style="font-weight: 700; color: var(--text-main);">
                                <div class="unit-table-title">${subjName}</div>
                                <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                    ⏱️ Son sınaq: ${subjLastTestedStr}
                                </div>
                            </td>
                            <td style="text-align: center;">${totalSubjQ}</td>
                            <td style="text-align: center; color: var(--active); font-weight: 700;">${c_correct}</td>
                            <td style="text-align: center; color: var(--wrong); font-weight: 700;">${c_wrong}</td>
                            <td style="text-align: center; color: var(--accent); font-weight: 700;">${subjAcc}%</td>
                            <td style="text-align: right;" onclick="event.stopPropagation();">
                                <button class="unit-btn-start" onclick="QuizApp.selectMixedSubSubject('${subjName.replace(/'/g, "\\'")}')">Giriş</button>
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
                
                // Prepend Multi Card
                let multiLastTested = 0;
                let hasMultiData = false;
                if (s.bd && s.bd['units'] && s.bd['units']['Multi']) {
                    multiLastTested = s.bd['units']['Multi'].last || 0;
                    hasMultiData = (s.bd['units']['Multi'].t || 0) > 0;
                }
                if (multiLastTested === 0 && hasMultiData) {
                    multiLastTested = this.getCourseLastActiveDateFromHistory(c);
                }
                const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);
                
                const multiItem = document.createElement('div');
                multiItem.className = 'unit-item';
                multiItem.style.background = 'linear-gradient(135deg, rgba(99, 102, 241, 0.06) 0%, rgba(139, 92, 246, 0.06) 100%)';
                multiItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                multiItem.innerHTML = `
                    <div class="unit-item-header">
                        <div>
                            <div class="unit-item-title" style="color: var(--accent); font-weight: 800;">⭐ Multi (Səhvlərin Təkrarı)</div>
                            <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                ⏱️ Son sınaq: ${multiLastTestedStr}
                            </div>
                        </div>
                        <button class="unit-btn-start" style="background: var(--accent-gradient); border: none;" onclick="QuizApp.startMultiUnit('Mixed')">Başla</button>
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
                
                subjects.forEach((subjName, sIdx) => {
                    const uVal = sIdx + 1;
                    let c_correct = 0, c_wrong = 0, subjLastTested = 0;
                    const subjChunks = this.mixedUnitsInfo.map((chunk, idx) => ({ chunk, idx }))
                        .filter(item => item.chunk.uVal === uVal);
                    
                    let totalSubjQ = 0;
                    subjChunks.forEach(({ chunk, idx }) => {
                        totalSubjQ += chunk.endIdx - chunk.startIdx;
                        const unitKey = `Unit ${idx + 1}`;
                        if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                            const us = s.bd['units'][unitKey];
                            c_correct += us.c || 0;
                            c_wrong += us.w || 0;
                            subjLastTested = Math.max(subjLastTested, us.last || 0);
                        }
                    });
                    
                    const totalAnswered = c_correct + c_wrong;
                    if (subjLastTested === 0 && totalAnswered > 0) {
                        subjLastTested = this.getCourseLastActiveDateFromHistory(c);
                    }
                    const subjLastTestedStr = this.formatLastTested(subjLastTested, totalAnswered > 0);
                    
                    const style = COURSE_STYLES[subjName] || { accent: '#6366f1', g1: '#6366f1', g2: '#8b5cf6' };
                    
                    const item = document.createElement('div');
                    item.className = 'unit-item';
                    item.innerHTML = `
                        <div class="unit-item-header">
                            <div>
                                <div class="unit-item-title" style="color: var(--text-main); font-weight: 700;">${subjName}</div>
                                <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                    ⏱️ Son sınaq: ${subjLastTestedStr}
                                </div>
                            </div>
                            <button class="unit-btn-start" style="background: linear-gradient(135deg, ${style.g1}, ${style.g2}); box-shadow: 0 4px 12px ${style.accent}30;" onclick="QuizApp.selectMixedSubSubject('${subjName.replace(/'/g, "\\'")}')">Giriş</button>
                        </div>
                        <div class="unit-item-stats-grid">
                            <div class="unit-stat-box">
                                <span class="us-val">${totalSubjQ}</span>
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

    loadData: function () {
        this.stats = JSON.parse(localStorage.getItem(this.DB.stats)) || {};
        this.wrongDB = JSON.parse(localStorage.getItem(this.DB.wrong)) || {};
        this.correctDB = JSON.parse(localStorage.getItem(this.DB.correct)) || {};
        this.bookmarks = JSON.parse(localStorage.getItem(this.DB.marks)) || [];
        this.settings = JSON.parse(localStorage.getItem(this.DB.settings)) || { scale: 1 };
        this.wrongCounts = JSON.parse(localStorage.getItem(this.DB.wrongCounts)) || {};
        
        // Clean up/migrate the duplicate/incorrect Türk Dili II Unit 14 Question 8 in localStorage databases
        const oldQText = "I. Panel II.Telekonferans III.Forum IV.Sempozyum Yukarıdaki sözlü anlatım türlerinin hangisinde ya da hangilerinde yönetici olarak bir başkan bulunur?";
        const newQText = "";
        
        ["Türk Dili II", "Türk dili", "Turk dili"].forEach(subjectKey => {
            let dbChanged = false;
            if (this.wrongDB && this.wrongDB[subjectKey]) {
                this.wrongDB[subjectKey].forEach(item => {
                    if (item.u === 14 && item.q === oldQText && item.a === 2) {
                        item.q = newQText;
                        dbChanged = true;
                    }
                });
                if (dbChanged) {
                    localStorage.setItem(this.DB.wrong, JSON.stringify(this.wrongDB));
                }
            }

            let correctDbChanged = false;
            if (this.correctDB && this.correctDB[subjectKey]) {
                this.correctDB[subjectKey].forEach(item => {
                    if (item.u === 14 && item.q === oldQText && item.a === 2) {
                        item.q = newQText;
                        correctDbChanged = true;
                    }
                });
                if (correctDbChanged) {
                    localStorage.setItem(this.DB.correct, JSON.stringify(this.correctDB));
                }
            }
        });

        let bookmarksChanged = false;
        if (this.bookmarks && Array.isArray(this.bookmarks)) {
            this.bookmarks.forEach(item => {
                if ((item.c === "Türk Dili II" || item.c === "Türk dili" || item.c === "Turk dili") && item.u === 14 && item.q === oldQText && item.a === 2) {
                    item.q = newQText;
                    bookmarksChanged = true;
                }
            });
            if (bookmarksChanged) {
                localStorage.setItem(this.DB.marks, JSON.stringify(this.bookmarks));
            }
        }
        
        // Migrate legacy daily history key (qa_v31_d) to new key (qa_v31_h) if necessary
        if (localStorage.getItem('qa_v31_d')) {
            try {
                const oldHistoryStr = localStorage.getItem('qa_v31_d');
                const newHistoryStr = localStorage.getItem('qa_v31_h');
                
                let merged = {};
                if (oldHistoryStr) {
                    try { merged = JSON.parse(oldHistoryStr); } catch(e) {}
                }
                if (newHistoryStr) {
                    try {
                        const newHistory = JSON.parse(newHistoryStr);
                        Object.keys(newHistory).forEach(date => {
                            if (!merged[date]) {
                                merged[date] = newHistory[date];
                            } else {
                                Object.keys(newHistory[date]).forEach(course => {
                                    if (!merged[date][course]) {
                                        merged[date][course] = newHistory[date][course];
                                    } else {
                                        const c1 = merged[date][course];
                                        const c2 = newHistory[date][course];
                                        merged[date][course] = {
                                            time: Math.max(c1.time || 0, c2.time || 0),
                                            correct: Math.max(c1.correct || 0, c2.correct || 0),
                                            wrong: Math.max(c1.wrong || 0, c2.wrong || 0)
                                        };
                                    }
                                });
                            }
                        });
                    } catch(e) {}
                }
                
                localStorage.setItem('qa_v31_h', JSON.stringify(merged));
                localStorage.removeItem('qa_v31_d');
                console.log("Migrated and merged daily history from qa_v31_d to qa_v31_h, removed legacy key.");
            } catch (e) {
                console.error("Migration error:", e);
            }
        }
        localStorage.setItem('qa_v31_h_real_v2', 'true');
        this.dailyHistory = JSON.parse(localStorage.getItem('qa_v31_h')) || {};

                // ==========================================
        // ULTIMATE STATISTICS RECOVERY BLOCK (LEVELDB RESTORED)
        // ==========================================
        const recoveredStats = {"🎲 Ümumi Sınaq": {"t": 20, "c": 20, "w": 0, "time": 181, "bd": {"mock": {"Sınaq": {"t": 20, "c": 20, "w": 0, "last": 0}}}}, "Görsel İletişim Tasarımı": {"t": 1191, "c": 1023, "w": 168, "time": 10767, "bd": {"units": {"Unit 11": {"t": 10, "c": 10, "w": 0, "last": 0}, "Unit 12": {"t": 10, "c": 7, "w": 3, "last": 0}, "Unit 2": {"t": 20, "c": 19, "w": 2, "last": 1780736601984}, "Unit 9": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 7": {"t": 18, "c": 15, "w": 3, "last": 0}, "Unit 14": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 6": {"t": 19, "c": 16, "w": 3, "last": 0}, "Unit 8": {"t": 20, "c": 20, "w": 0, "last": 0}, "Unit 4": {"t": 21, "c": 18, "w": 5, "last": 1780738056522}, "Unit 5": {"t": 17, "c": 16, "w": 1, "last": 0}, "Unit 3": {"t": 19, "c": 19, "w": 3, "last": 1780737696148}, "Unit 10": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 1": {"t": 23, "c": 22, "w": 1, "last": 1780733356289}, "Unit 13": {"t": 10, "c": 9, "w": 1, "last": 0}}, "mixed": {"Qarışıq Sınaq": {"t": 764, "c": 638, "w": 126, "last": 1781345183765}}, "wrong": {"Səhvlərin Təkrarı": {"t": 8, "c": 8, "w": 0, "last": 0}}, "surprise": {"Sürpriz Sual": {"t": 16, "c": 12, "w": 4, "last": 1781345563136}}}}, "Tasarımda Tipografi": {"t": 1588, "c": 1375, "w": 213, "time": 19462, "bd": {"wrong": {"Səhvlərin Təkrarı": {"t": 134, "c": 106, "w": 28, "last": 1781276495719}}, "units": {"Unit 9": {"t": 34, "c": 26, "w": 8, "last": 1781271798225}, "Unit 7": {"t": 54, "c": 48, "w": 6, "last": 1781270621008}, "Unit 11": {"t": 39, "c": 37, "w": 2, "last": 1781271985807}, "Unit 12": {"t": 42, "c": 40, "w": 2, "last": 1781272194919}, "Unit 2": {"t": 42, "c": 37, "w": 5, "last": 1781269261443}, "Unit 3": {"t": 48, "c": 40, "w": 8, "last": 1781269414340}, "Unit 5": {"t": 42, "c": 41, "w": 1, "last": 1781270132231}, "Unit 1": {"t": 45, "c": 38, "w": 7, "last": 1781269166952}, "Unit 10": {"t": 42, "c": 36, "w": 6, "last": 1781271914498}, "Unit 13": {"t": 33, "c": 31, "w": 2, "last": 1781272271397}, "Unit 14": {"t": 60, "c": 51, "w": 9, "last": 1781272374525}, "Unit 6": {"t": 45, "c": 42, "w": 3, "last": 1781270331832}, "Unit 8": {"t": 42, "c": 32, "w": 10, "last": 1781271029069}, "Unit 4": {"t": 39, "c": 30, "w": 9, "last": 1781269925190}, "Multi": {"t": 2, "c": 2, "w": 0, "last": 1780820350399}}, "surprise": {"Sürpriz Sual": {"t": 8, "c": 5, "w": 3, "last": 1781283309792}}, "mixed": {"Qarışıq Sınaq": {"t": 585, "c": 503, "w": 82, "last": 1781345183765}}}}, "Masaüstü Yayıncılık": {"t": 1204, "c": 979, "w": 225, "time": 13154, "bd": {"units": {"Unit 7": {"t": 38, "c": 29, "w": 9, "last": 1780818622133}, "Unit 9": {"t": 12, "c": 9, "w": 3, "last": 1780818811617}, "Unit 2": {"t": 44, "c": 38, "w": 6, "last": 1780817239154}, "Unit 12": {"t": 30, "c": 13, "w": 17, "last": 1780819161046}, "Unit 11": {"t": 12, "c": 8, "w": 4, "last": 1780818961525}, "Unit 13": {"t": 32, "c": 24, "w": 8, "last": 1780819349637}, "Unit 1": {"t": 76, "c": 69, "w": 7, "last": 1781006282891}, "Unit 10": {"t": 29, "c": 19, "w": 10, "last": 1781005701434}, "Unit 5": {"t": 38, "c": 31, "w": 7, "last": 1780818205787}, "Unit 3": {"t": 34, "c": 27, "w": 7, "last": 1780817566380}, "Unit 4": {"t": 40, "c": 35, "w": 5, "last": 1780817780201}, "Unit 8": {"t": 20, "c": 17, "w": 3, "last": 1780818762821}, "Unit 6": {"t": 38, "c": 31, "w": 7, "last": 1780818430134}, "Unit 14": {"t": 16, "c": 13, "w": 3, "last": 1780819516633}, "Multi": {"t": 2, "c": 2, "w": 0, "last": 1780820367058}}, "mixed": {"Qarışıq Sınaq": {"t": 390, "c": 336, "w": 54, "last": 1781345183765}}, "wrong": {"Səhvlərin Təkrarı": {"t": 77, "c": 62, "w": 15, "last": 1780820244629}}, "surprise": {"Sürpriz Sual": {"t": 14, "c": 13, "w": 1, "last": 1781283526632}}}}, "Grafik Tasarım II": {"t": 1289, "c": 1158, "w": 131, "time": 14726, "bd": {"mixed": {"Qarışıq Sınaq": {"t": 451, "c": 399, "w": 52, "last": 1781345183765}}, "units": {"Unit 6": {"t": 34, "c": 32, "w": 3, "last": 1781256271096}, "Unit 4": {"t": 30, "c": 30, "w": 1, "last": 1781255848220}, "Unit 8": {"t": 26, "c": 26, "w": 3, "last": 1781257966873}, "Unit 5": {"t": 30, "c": 27, "w": 4, "last": 1781256006332}, "Unit 3": {"t": 26, "c": 25, "w": 1, "last": 1781255703577}, "Unit 10": {"t": 32, "c": 27, "w": 6, "last": 1781259010742}, "Unit 1": {"t": 30, "c": 28, "w": 4, "last": 1781280919378}, "Unit 13": {"t": 26, "c": 23, "w": 4, "last": 1781259954678}, "Unit 2": {"t": 28, "c": 27, "w": 5, "last": 1781255623489}, "Unit 11": {"t": 26, "c": 24, "w": 2, "last": 1781259462692}, "Unit 12": {"t": 28, "c": 28, "w": 3, "last": 1781259609551}, "Unit 9": {"t": 30, "c": 29, "w": 3, "last": 1781258138291}, "Unit 7": {"t": 32, "c": 32, "w": 1, "last": 1781256542802}, "Unit 14": {"t": 70, "c": 64, "w": 6, "last": 1781260228334}}, "wrong": {"Səhvlərin Təkrarı": {"t": 83, "c": 72, "w": 11, "last": 1781260392115}}, "surprise": {"Sürpriz Sual": {"t": 10, "c": 9, "w": 1, "last": 1781280198855}}}}, "Grafik Tasarım": {"t": 10, "c": 10, "w": 0, "time": 5260, "bd": {"units": {"Unit 1": {"t": 10, "c": 10, "w": 0, "last": 0}}}}, "Hard": {"t": 27, "c": 14, "w": 13, "time": 0, "bd": {"wrong": {"Səhvlərin Təkrarı": {"t": 21, "c": 10, "w": 11, "last": 1781273391699}}}}, "Atatürk İlkeleri ve İnkılap Tarihi II": {"t": 615, "c": 464, "w": 151, "time": 7886, "bd": {"units": {"Unit 1": {"t": 100, "c": 84, "w": 16, "last": 1781076752408}, "Unit 2": {"t": 63, "c": 49, "w": 14, "last": 1781089587848}, "Unit 3": {"t": 67, "c": 60, "w": 7, "last": 1781090196150}, "Unit 4": {"t": 75, "c": 61, "w": 14, "last": 1781090874942}, "Unit 5": {"t": 80, "c": 58, "w": 22, "last": 1781091685670}, "Unit 6": {"t": 60, "c": 50, "w": 10, "last": 1781096735914}, "Unit 7": {"t": 25, "c": 16, "w": 9, "last": 1781097386331}, "Unit 8": {"t": 10, "c": 7, "w": 3, "last": 1781062152478}, "Unit 9": {"t": 10, "c": 2, "w": 8, "last": 1781062325371}, "Unit 10": {"t": 10, "c": 5, "w": 5, "last": 1781062500532}, "Unit 11": {"t": 10, "c": 2, "w": 8, "last": 1781062638571}, "Unit 12": {"t": 10, "c": 1, "w": 9, "last": 1781062762425}, "Unit 13": {"t": 10, "c": 5, "w": 5, "last": 1781062888885}, "Unit 14": {"t": 10, "c": 7, "w": 3, "last": 1781063029484}}, "surprise": {"Sürpriz Sual": {"t": 19, "c": 15, "w": 4, "last": 1781344826063}}, "mixed": {"Qarışıq Sınaq": {"t": 55, "c": 42, "w": 13, "last": 1781345183765}}}}, "Türk Dili II": {"t": 867, "c": 673, "w": 194, "time": 11277, "bd": {"units": {"Unit 1": {"t": 80, "c": 72, "w": 8, "last": 1781033645786}, "Unit 2": {"t": 66, "c": 50, "w": 16, "last": 1781033492772}, "Unit 3": {"t": 60, "c": 50, "w": 10, "last": 1781033143290}, "Unit 4": {"t": 69, "c": 48, "w": 21, "last": 1781032974609}, "Unit 5": {"t": 60, "c": 48, "w": 12, "last": 1781032750196}, "Unit 6": {"t": 57, "c": 49, "w": 8, "last": 1781032581675}, "Unit 7": {"t": 57, "c": 51, "w": 6, "last": 1781032428486}, "Unit 8": {"t": 30, "c": 20, "w": 10, "last": 1781032281742}, "Unit 9": {"t": 30, "c": 22, "w": 8, "last": 1781032218305}, "Unit 10": {"t": 30, "c": 21, "w": 9, "last": 1781032110806}, "Unit 11": {"t": 30, "c": 18, "w": 12, "last": 1781032039287}, "Unit 12": {"t": 30, "c": 20, "w": 10, "last": 1781031944177}, "Unit 13": {"t": 30, "c": 18, "w": 12, "last": 1781031881399}, "Unit 14": {"t": 30, "c": 16, "w": 14, "last": 1781031752530}, "Multi": {"t": 61, "c": 50, "w": 11, "last": 1781033839179}}, "wrong": {"Səhvlərin Təkrarı": {"t": 101, "c": 86, "w": 15, "last": 1781031130890}}, "surprise": {"Sürpriz Sual": {"t": 11, "c": 6, "w": 5, "last": 1781282596223}}, "mixed": {"Qarışıq Sınaq": {"t": 34, "c": 27, "w": 7, "last": 1781345183765}}}}, "Mixed": {"t": 67, "c": 41, "w": 26, "time": 62, "bd": {"surprise": {"Sürpriz Sual": {"t": 67, "c": 41, "w": 26, "last": 1781345226274}}, "units": {"Unit 2": {"t": 3, "c": 3, "w": 0, "last": 1781169816015}}}}, "Grafik Tasarım II_pdf_4": {"t": 20, "c": 16, "w": 4, "time": 205, "bd": {"pdf-exam": {"İmtahan 5": {"t": 20, "c": 16, "w": 4, "last": 1781248237609}}}}, "Grafik Tasarım II_pdf_3": {"t": 22, "c": 22, "w": 0, "time": 277, "bd": {"pdf-exam": {"İmtahan 4": {"t": 22, "c": 22, "w": 0, "last": 1781247942210}}}}, "Masaüstü Yayıncılık_pdf_1": {"t": 20, "c": 15, "w": 5, "time": 279, "bd": {"pdf-exam": {"İmtahan 2": {"t": 20, "c": 15, "w": 5, "last": 1781278046614}}}}, "Masaüstü Yayıncılık_pdf_5": {"t": 20, "c": 16, "w": 4, "time": 336, "bd": {"pdf-exam": {"İmtahan 6": {"t": 20, "c": 16, "w": 4, "last": 1781281285313}}}}, "Grafik Tasarım II_pdf_0": {"t": 20, "c": 18, "w": 2, "time": 0, "bd": {"pdf-exam": {"İmtahan 1": {"t": 20, "c": 18, "w": 2, "last": 1781245873960}}}}, "Masaüstü Yayıncılık_pdf_4": {"t": 20, "c": 18, "w": 2, "time": 220, "bd": {"pdf-exam": {"İmtahan 5": {"t": 20, "c": 18, "w": 2, "last": 1781280652980}}}}, "Grafik Tasarım II_pdf_2": {"t": 20, "c": 16, "w": 4, "time": 132, "bd": {"pdf-exam": {"İmtahan 3": {"t": 20, "c": 16, "w": 4, "last": 1781246476598}}}}, "Grafik Tasarım II_pdf_5": {"t": 20, "c": 20, "w": 0, "time": 235, "bd": {"pdf-exam": {"İmtahan 6": {"t": 20, "c": 20, "w": 0, "last": 1781248807568}}}}, "Masaüstü Yayıncılık_pdf_6": {"t": 20, "c": 15, "w": 5, "time": 247, "bd": {"pdf-exam": {"İmtahan 7": {"t": 20, "c": 15, "w": 5, "last": 1781281588882}}}}, "Tasarımda Tipografi_pdf_3": {"t": 20, "c": 19, "w": 1, "time": 295, "bd": {"pdf-exam": {"İmtahan 4": {"t": 20, "c": 19, "w": 1, "last": 1781267136616}}}}, "Tasarımda Tipografi_pdf_0": {"t": 19, "c": 14, "w": 5, "time": 200, "bd": {"pdf-exam": {"İmtahan 1": {"t": 19, "c": 14, "w": 5, "last": 1781260642968}}}}, "Masaüstü Yayıncılık_pdf_8": {"t": 20, "c": 14, "w": 6, "time": 375, "bd": {"pdf-exam": {"İmtahan 9": {"t": 20, "c": 14, "w": 6, "last": 1781283312752}}}}, "Masaüstü Yayıncılık_pdf_0": {"t": 20, "c": 12, "w": 8, "time": 249, "bd": {"pdf-exam": {"İmtahan 1": {"t": 20, "c": 12, "w": 8, "last": 1781277108917}}}}, "Masaüstü Yayıncılık_pdf_9": {"t": 19, "c": 16, "w": 3, "time": 235, "bd": {"pdf-exam": {"İmtahan 10": {"t": 19, "c": 16, "w": 3, "last": 1781283984152}}}}, "Masaüstü Yayıncılık_pdf_12": {"t": 6, "c": 3, "w": 3, "time": 70, "bd": {"pdf-exam": {"İmtahan 13": {"t": 6, "c": 3, "w": 3, "last": 1781284603217}}}}, "Masaüstü Yayıncılık_pdf_7": {"t": 20, "c": 19, "w": 1, "time": 379, "bd": {"pdf-exam": {"İmtahan 8": {"t": 20, "c": 19, "w": 1, "last": 1781282801941}}}}, "Grafik Tasarım II_pdf_1": {"t": 20, "c": 16, "w": 4, "time": 0, "bd": {"pdf-exam": {"İmtahan 2": {"t": 20, "c": 16, "w": 4, "last": 1781246145820}}}}, "Masaüstü Yayıncılık_pdf_10": {"t": 20, "c": 14, "w": 6, "time": 217, "bd": {"pdf-exam": {"İmtahan 11": {"t": 20, "c": 14, "w": 6, "last": 1781284229851}}}}, "Masaüstü Yayıncılık_pdf_2": {"t": 20, "c": 15, "w": 5, "time": 366, "bd": {"pdf-exam": {"İmtahan 3": {"t": 20, "c": 15, "w": 5, "last": 1781279992950}}}}, "Masaüstü Yayıncılık_pdf_11": {"t": 17, "c": 15, "w": 2, "time": 192, "bd": {"pdf-exam": {"İmtahan 12": {"t": 17, "c": 15, "w": 2, "last": 1781284468415}}}}, "Görsel İletişim Tasarımı_pdf_0": {"t": 20, "c": 13, "w": 7, "time": 32, "bd": {"pdf-exam": {"İmtahan 1": {"t": 20, "c": 13, "w": 7, "last": 1781189017715}}}}, "Grafik Tasarım II_pdf_7": {"t": 20, "c": 20, "w": 0, "time": 190, "bd": {"pdf-exam": {"İmtahan 8": {"t": 20, "c": 20, "w": 0, "last": 1781252611705}}}}, "Tasarımda Tipografi_pdf_6": {"t": 20, "c": 18, "w": 2, "time": 315, "bd": {"pdf-exam": {"İmtahan 7": {"t": 20, "c": 18, "w": 2, "last": 1781268086849}}}}, "Tasarımda Tipografi_pdf_5": {"t": 20, "c": 19, "w": 1, "time": 162, "bd": {"pdf-exam": {"İmtahan 6": {"t": 20, "c": 19, "w": 1, "last": 1781267647366}}}}, "Tasarımda Tipografi_pdf_2": {"t": 20, "c": 15, "w": 5, "time": 523, "bd": {"pdf-exam": {"İmtahan 3": {"t": 20, "c": 15, "w": 5, "last": 1781261488014}}}}, "Tasarımda Tipografi_pdf_1": {"t": 20, "c": 15, "w": 5, "time": 217, "bd": {"pdf-exam": {"İmtahan 2": {"t": 20, "c": 15, "w": 5, "last": 1781260898343}}}}, "Grafik Tasarım II_pdf_6": {"t": 20, "c": 20, "w": 0, "time": 288, "bd": {"pdf-exam": {"İmtahan 7": {"t": 20, "c": 20, "w": 0, "last": 1781249199933}}}}, "Masaüstü Yayıncılık_pdf_3": {"t": 20, "c": 16, "w": 4, "time": 264, "bd": {"pdf-exam": {"İmtahan 4": {"t": 20, "c": 16, "w": 4, "last": 1781280330313}}}}, "Tasarımda Tipografi_pdf_7": {"t": 20, "c": 20, "w": 0, "time": 293, "bd": {"pdf-exam": {"İmtahan 8": {"t": 20, "c": 20, "w": 0, "last": 1781268468118}}}}, "Tasarımda Tipografi_pdf_4": {"t": 20, "c": 18, "w": 2, "time": 219, "bd": {"pdf-exam": {"İmtahan 5": {"t": 20, "c": 18, "w": 2, "last": 1781267391898}}}}, "Türk dili": {"t": 259, "c": 200, "w": 59, "time": 969, "bd": {"units": {"Unit 7": {"t": 2, "c": 1, "w": 1, "last": 0}, "Unit 8": {"t": 27, "c": 22, "w": 5, "last": 0}, "Unit 9": {"t": 50, "c": 41, "w": 9, "last": 0}, "Unit 10": {"t": 30, "c": 21, "w": 9, "last": 0}, "Unit 11": {"t": 20, "c": 14, "w": 6, "last": 0}, "Unit 12": {"t": 40, "c": 35, "w": 5, "last": 0}, "Unit 13": {"t": 20, "c": 14, "w": 6, "last": 0}, "Unit 14": {"t": 70, "c": 52, "w": 18, "last": 0}}}}, "Atatürk İlkeleri ve İnkilap Tarihi": {"t": 6, "c": 6, "w": 0, "time": 302, "bd": {"units": {"Unit 7": {"t": 2, "c": 2, "w": 0, "last": 0}}, "mixed": {"1-20": {"t": 4, "c": 4, "w": 0, "last": 0}}}}, "Tipografi": {"t": 183, "c": 153, "w": 30, "time": 108, "bd": {"units": {"Unit 8": {"t": 10, "c": 10, "w": 0, "last": 0}, "Unit 9": {"t": 20, "c": 14, "w": 6, "last": 0}, "Unit 10": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 11": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 12": {"t": 10, "c": 10, "w": 0, "last": 0}, "Unit 13": {"t": 10, "c": 10, "w": 0, "last": 0}, "Unit 14": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 7": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 6": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 1": {"t": 10, "c": 10, "w": 0, "last": 0}, "Unit 2": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 4": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 3": {"t": 10, "c": 9, "w": 1, "last": 0}, "Unit 5": {"t": 43, "c": 30, "w": 13, "last": 0}}}}, "Reklam Analizleri": {"t": 191, "c": 114, "w": 77, "time": 634, "bd": {"units": {"Unit 8": {"t": 30, "c": 21, "w": 9, "last": 0}, "Unit 9": {"t": 10, "c": 5, "w": 5, "last": 0}, "Unit 10": {"t": 10, "c": 5, "w": 5, "last": 0}, "Unit 11": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 12": {"t": 10, "c": 4, "w": 6, "last": 0}, "Unit 13": {"t": 10, "c": 7, "w": 3, "last": 0}, "Unit 14": {"t": 10, "c": 6, "w": 4, "last": 0}, "Unit 1": {"t": 11, "c": 8, "w": 3, "last": 0}, "Unit 2": {"t": 10, "c": 7, "w": 3, "last": 0}, "Unit 3": {"t": 10, "c": 7, "w": 3, "last": 0}, "Unit 4": {"t": 10, "c": 8, "w": 2, "last": 0}, "Unit 5": {"t": 10, "c": 5, "w": 5, "last": 0}, "Unit 6": {"t": 10, "c": 1, "w": 9, "last": 0}, "Unit 7": {"t": 40, "c": 22, "w": 18, "last": 0}}}}};
        const recoveredHistory = {"2026-06-03": {"Grafik Tasarım II": {"time": 547, "correct": 23, "wrong": 6}, "platformTime": 0}, "2026-06-04": {"Görsel İletişim Tasarımı": {"time": 997, "correct": 193, "wrong": 25}, "Grafik Tasarım II": {"time": 2910, "correct": 193, "wrong": 37}, "Masaüstü Yayıncılık": {"time": 3367, "correct": 198, "wrong": 73}, "Tasarımda Tipografi": {"time": 1593, "correct": 91, "wrong": 29}, "platformTime": 0}, "2026-06-05": {"Tasarımda Tipografi": {"time": 1600, "correct": 124, "wrong": 21}, "🎲 Ümumi Sınaq": {"time": 7, "correct": 0, "wrong": 0}, "Grafik Tasarım II": {"time": 200, "correct": 21, "wrong": 5}, "Görsel İletişim Tasarımı": {"time": 498, "correct": 41, "wrong": 5}, "Masaüstü Yayıncılık": {"time": 216, "correct": 21, "wrong": 3}, "platformTime": 0, "Hard": {"time": 0, "correct": 5, "wrong": 2}}, "2026-06-06": {"Görsel İletişim Tasarımı": {"time": 152, "correct": 20, "wrong": 1}, "Masaüstü Yayıncılık": {"time": 0, "correct": 1, "wrong": 2}, "Grafik Tasarım II": {"time": 2436, "correct": 186, "wrong": 18}, "Tasarımda Tipografi": {"time": 0, "correct": 2, "wrong": 2}, "Atatürk İlkeleri ve İnkılap Tarihi II": {"time": 0, "correct": 0, "wrong": 1}, "Türk Dili II": {"time": 0, "correct": 1, "wrong": 0}, "platformTime": 0}, "2026-06-07": {"Tasarımda Tipografi": {"time": 2735, "correct": 201, "wrong": 37}, "Masaüstü Yayıncılık": {"time": 2807, "correct": 215, "wrong": 39}, "platformTime": 0}, "2026-06-09": {"Türk Dili II": {"time": 10797, "correct": 639, "wrong": 182}, "Masaüstü Yayıncılık": {"time": 695, "correct": 23, "wrong": 5}, "platformTime": 0}, "2026-06-10": {"Atatürk İlkeleri ve İnkılap Tarihi II": {"time": 6986, "correct": 407, "wrong": 133}, "Tasarımda Tipografi": {"time": 0, "correct": 52, "wrong": 0}, "platformTime": 0}, "2026-06-11": {"🎲 Ümumi Sınaq": {"time": 5, "correct": 0, "wrong": 0}, "Görsel İletişim Tasarımı": {"time": 0, "correct": 3, "wrong": 2}, "Atatürk İlkeleri ve İnkılap Tarihi II": {"time": 0, "correct": 2, "wrong": 1}, "Mixed": {"time": 62, "correct": 4, "wrong": 2}, "Grafik Tasarım II": {"time": 555, "correct": 41, "wrong": 8}, "Masaüstü Yayıncılık": {"time": 0, "correct": 3, "wrong": 0}, "Tasarımda Tipografi": {"time": 420, "correct": 39, "wrong": 0}, "Türk Dili II": {"time": 0, "correct": 1, "wrong": 1}, "platformTime": 0, "Görsel İletişim Tasarımı_pdf_0": {"time": 32, "correct": 13, "wrong": 7}}, "2026-06-12": {"Tasarımda Tipografi": {"time": 5974, "correct": 454, "wrong": 45}, "platformTime": 4581, "Grafik Tasarım II": {"time": 3878, "correct": 314, "wrong": 9}, "Masaüstü Yayıncılık": {"time": 3429, "correct": 198, "wrong": 55}, "Görsel İletişim Tasarımı": {"time": 2160, "correct": 166, "wrong": 14}, "Türk Dili II": {"time": 0, "correct": 5, "wrong": 4}, "Mixed": {"time": 11, "correct": 39, "wrong": 26}, "Grafik Tasarım II_pdf_2": {"time": 132, "correct": 16, "wrong": 4}, "Grafik Tasarım II_pdf_0": {"time": 0, "correct": 18, "wrong": 2}, "Grafik Tasarım II_pdf_1": {"time": 0, "correct": 16, "wrong": 4}, "Hard": {"time": 0, "correct": 9, "wrong": 11}, "Grafik Tasarım II_pdf_4": {"time": 205, "correct": 16, "wrong": 4}, "Atatürk İlkeleri ve İnkılap Tarihi II": {"time": 0, "correct": 12, "wrong": 4}, "Grafik Tasarım II_pdf_3": {"time": 277, "correct": 22, "wrong": 0}}, "2026-06-13": {"platformTime": 26280, "Grafik Tasarım II": {"correct": 380, "wrong": 48, "time": 4200}, "Görsel İletişim Tasarımı": {"correct": 600, "wrong": 121, "time": 6960}, "Masaüstü Yayıncılık": {"correct": 320, "wrong": 48, "time": 2640}, "Tasarımda Tipografi": {"correct": 412, "wrong": 79, "time": 7140}, "Atatürk İlkeleri ve İnkılap Tarihi II": {"correct": 43, "wrong": 12, "time": 900}, "Türk Dili II": {"correct": 27, "wrong": 7, "time": 480}}};

        let historyRestored = false;
        let statsRestored = false;

        // Merge daily history
        Object.keys(recoveredHistory).forEach(date => {
            if (date === 'd' || date === 'c') return;
            if (!this.dailyHistory[date]) {
                this.dailyHistory[date] = JSON.parse(JSON.stringify(recoveredHistory[date]));
                historyRestored = true;
            } else {
                Object.keys(recoveredHistory[date]).forEach(course => {
                    if (course === 'platformTime') {
                        const curVal = this.dailyHistory[date][course] || 0;
                        const recVal = recoveredHistory[date][course] || 0;
                        if (curVal < recVal) {
                            this.dailyHistory[date][course] = recVal;
                            historyRestored = true;
                        }
                        return;
                    }
                    if (course === 'personalNotes') {
                        if (!this.dailyHistory[date][course]) {
                            this.dailyHistory[date][course] = recoveredHistory[date][course];
                            historyRestored = true;
                        }
                        return;
                    }
                    if (!this.dailyHistory[date][course]) {
                        this.dailyHistory[date][course] = JSON.parse(JSON.stringify(recoveredHistory[date][course]));
                        historyRestored = true;
                    } else {
                        const cur = this.dailyHistory[date][course];
                        const rec = recoveredHistory[date][course];
                        if ((cur.correct || 0) < (rec.correct || 0) || (cur.wrong || 0) < (rec.wrong || 0) || (cur.time || 0) < (rec.time || 0)) {
                            cur.correct = Math.max(cur.correct || 0, rec.correct || 0);
                            cur.wrong = Math.max(cur.wrong || 0, rec.wrong || 0);
                            cur.time = Math.max(cur.time || 0, rec.time || 0);
                            historyRestored = true;
                        }
                    }
                });
            }
        });

        // Merge overall stats
        Object.keys(recoveredStats).forEach(course => {
            if (!this.stats[course]) {
                this.stats[course] = JSON.parse(JSON.stringify(recoveredStats[course]));
                statsRestored = true;
            } else {
                const cur = this.stats[course];
                const rec = recoveredStats[course];
                if ((cur.c || 0) < (rec.c || 0) || (cur.w || 0) < (rec.w || 0) || (cur.time || 0) < (rec.time || 0)) {
                    cur.c = Math.max(cur.c || 0, rec.c || 0);
                    cur.w = Math.max(cur.w || 0, rec.w || 0);
                    cur.t = Math.max(cur.t || 0, cur.c + cur.w);
                    cur.time = Math.max(cur.time || 0, rec.time || 0);
                    statsRestored = true;
                }
            }
        });

        if (historyRestored) {
            localStorage.setItem('qa_v31_h', JSON.stringify(this.dailyHistory));
        }
        if (statsRestored) {
            localStorage.setItem(this.DB.stats, JSON.stringify(this.stats));
        }
        if (historyRestored || statsRestored) {
            localStorage.setItem('qa_v31_localUpdatedAt', Date.now().toString());
            if (typeof FirebaseSync !== 'undefined' && FirebaseSync.triggerAutoSave) {
                FirebaseSync.triggerAutoSave();
            }
            console.log("Ultimate Recovery: Restored missing statistics from LevelDB!");
        }
        // ==========================================
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
        let globalTotalQ = typeof quizData !== 'undefined' ? quizData.length : 0;
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

        // Generate PDF Subject Cards
        let subjectCardsHTML = "";
        if (typeof pdfExamsData !== 'undefined') {
            Object.keys(pdfExamsData).forEach(subject => {
                const style = COURSE_STYLES[subject] || { icon: "📚", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" };
                const numExams = pdfExamsData[subject].length;
                subjectCardsHTML += `
                    <div class="pdf-subject-card" onclick="QuizApp.showPdfExamsList('${subject.replace(/'/g, "\\'")}', 'home')" style="--accent-color: ${style.accent}; --accent-glow: ${style.accent}25; --icon-bg: linear-gradient(135deg, ${style.g1}20, ${style.g2}20); --icon-border: ${style.accent}30;">
                        <div class="subject-icon-wrap">
                            ${style.icon}
                        </div>
                        <div class="subject-info-wrap">
                            <div class="subject-title" title="${subject}">${subject}</div>
                            <div class="subject-desc">${numExams} Sınaq İmtahanı</div>
                        </div>
                        <div class="subject-arrow-wrap">
                            <svg viewBox="0 0 24 24"><path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/></svg>
                        </div>
                    </div>
                `;
            });
        }

        container.innerHTML = `
            <div class="dashboard">

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
                            <div class="hap-legend-badge" style="background:#3b82f618; border-color:#3b82f640;">
                                <span class="hap-lc-lbl">Sual sayı</span>
                                <span class="hap-lc-num" style="color:#3b82f6;">${globalTotalAns}</span>
                            </div>
                            <div class="hap-legend-badge" style="background:#f59e0b18; border-color:#f59e0b40;">
                                <span class="hap-lc-lbl">Vaxt</span>
                                <span class="hap-lc-num" style="color:#f59e0b;">${this.formatTime(globalTime)}</span>
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
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <div class="hap-chart-filters" id="chart-courses-filters"></div>
                            <div class="hap-chart-toggles">
                                <button id="toggle-chart-mode-q" class="chart-toggle-btn active" onclick="setChartMode('questions')">Suallar</button>
                                <button id="toggle-chart-mode-t" class="chart-toggle-btn" onclick="setChartMode('time')">Sərf edilən vaxt</button>
                            </div>
                        </div>
                    </div>

                    <div class="hap-today-summary-box">
                        <div class="hap-today-stat-item">
                            <span class="hap-today-stat-label">Bugünkü Sual</span>
                            <span class="hap-today-stat-val questions">${todayQuestions}</span>
                        </div>
                        <div class="hap-today-stat-item">
                            <span class="hap-today-stat-label">Platforma Vaxtı</span>
                            <span class="hap-today-stat-val time platform-time-val" style="color: var(--accent);">${formatTodayTime(todayPlatformTime)}</span>
                        </div>
                        <div class="hap-today-stat-item">
                            <span class="hap-today-stat-label">Test Vaxtı</span>
                            <span class="hap-today-stat-val time test-time-val" style="color: #f59e0b;">${formatTodayTime(todayTime)}</span>
                        </div>
                        <div class="hap-today-stat-item">
                            <span class="hap-today-stat-label">Bugünkü Cavablar</span>
                            <span class="hap-today-stat-val ratio">
                                <span class="correct-text" style="color: var(--active); font-weight: 700;">${todayCorrect} Düz</span> / 
                                <span class="wrong-text" style="color: var(--wrong); font-weight: 700;">${todayWrong} Səhv</span>
                            </span>
                        </div>
                    </div>

                    <div class="hap-chart-body" style="position: relative;">
                        <canvas id="home-dynamics-canvas" style="width: 100%; height: 250px;"></canvas>
                        <div id="chart-tooltip" class="chart-tooltip" style="display: none;"></div>
                    </div>
                </div>

                <!-- Mövzu Sınaq İmtahanları (PDF) Bölməsi -->
                <div class="hap-chart-panel" style="margin-top: 12px; border-color: rgba(99, 102, 241, 0.15);">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <span style="font-size: 1.3rem;">📝</span>
                        <div class="hap-section-label" style="margin: 0; background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent;">Mövzu Sınaq İmtahanları (PDF)</div>
                    </div>
                    <p style="color: var(--text-muted); font-size: 0.82rem; margin-top: -4px; margin-bottom: 8px; font-weight: 500;">
                        Yüklənmiş PDF testlərinin hər biri üzrə ayrıca tərtib olunmuş 20 suallıq sınaqlar.
                    </p>
                    <div class="home-pdf-subjects-grid">
                        ${subjectCardsHTML || '<div style="color: var(--text-muted); font-size: 0.9rem; padding: 10px;">İmtahan tapılmadı</div>'}
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

    showPdfExamsDashboard: function () {
        this.stopTimer();
        this.state.view = 'pdf-exams-dashboard';
        this.state.pdfExamReferrer = 'dashboard';
        
        let totalQ = 0;
        let totalAttempts = 0;
        let totalCorrect = 0;
        let totalWrong = 0;
        let totalTime = 0;

        // Calculate aggregates for all PDF Exams
        if (typeof pdfExamsData !== 'undefined') {
            Object.keys(pdfExamsData).forEach(subject => {
                const exams = pdfExamsData[subject] || [];
                exams.forEach((examQs, idx) => {
                    totalQ += examQs.length;
                    const examKey = `${subject}_pdf_${idx}`;
                    if (this.stats[examKey]) {
                        const s = this.stats[examKey];
                        if (s.t) totalAttempts += s.t;
                        if (s.c) totalCorrect += s.c;
                        if (s.w) totalWrong += s.w;
                        if (s.time) totalTime += s.time;
                    }
                });
            });
        }

        loadTemplate('course-dashboard-template');

        // Course Title
        const titleEl = document.getElementById('db-course-title');
        if (titleEl) titleEl.textContent = "Mövzu Sınaq İmtahanları";

        const descEl = titleEl ? titleEl.nextElementSibling : null;
        if (descEl) descEl.textContent = "Yüklənmiş PDF sınaq imtahanları üzrə ümumi statistikalar və fənlər";

        // Statistics
        document.getElementById('db-total-questions').textContent = totalQ;
        const attemptsVal = document.getElementById('db-total-attempts');
        if (attemptsVal) attemptsVal.textContent = totalAttempts;
        document.getElementById('db-total-time').textContent = this.formatTime(totalTime) + " / " + this.formatTime(this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0);
        
        const correctVal = document.getElementById('db-total-correct');
        const wrongVal = document.getElementById('db-total-wrong');
        correctVal.textContent = totalCorrect;
        wrongVal.textContent = totalWrong;

        let acc = 0;
        if (totalAttempts > 0) acc = Math.round((totalCorrect / totalAttempts) * 100);
        const accVal = document.getElementById('db-accuracy');
        if (accVal) accVal.textContent = acc + '%';

        // Hide specific elements not needed for global PDF exams dashboard
        const wrongExamContainer = document.getElementById('db-wrong-exam-container');
        if (wrongExamContainer) {
            wrongExamContainer.style.display = 'none';
            wrongExamContainer.innerHTML = '';
        }
        const mixedExamContainer = document.getElementById('db-mixed-exam-container');
        if (mixedExamContainer) {
            mixedExamContainer.style.display = 'none';
            mixedExamContainer.innerHTML = '';
        }
        const warningContainer = document.getElementById('db-warning-container');
        if (warningContainer) {
            warningContainer.style.display = 'none';
            warningContainer.innerHTML = '';
        }

        // Configure correct/wrong card click behavior
        const correctCard = correctVal.parentElement;
        const wrongCard = wrongVal.parentElement;
        if (correctCard && wrongCard) {
            correctCard.style.cursor = 'default';
            correctCard.onclick = null;
            correctCard.title = '';
            wrongCard.style.cursor = 'default';
            wrongCard.onclick = null;
            wrongCard.title = '';
        }

        // AI Recommendation text
        const recTextEl = document.getElementById('db-recommendation-text');
        if (recTextEl) {
            let rec = "";
            if (totalAttempts === 0) {
                rec = "Siz hələ heç bir PDF sınaq imtahanı işləməmisiniz. Mövzu biliklərinizi yoxlamaq üçün aşağıdakı fənlərdən birini seçib ilk sınağa başlayın!";
            } else {
                if (acc >= 80) {
                    rec = `Əla göstərici! PDF sınaqlarında ümumi dəqiqliyiniz <b>${acc}%</b> təşkil edir. Mövzuları yaxşı mənimsədiyiniz görünür. Hələ işləmədiyiniz digər PDF imtahanlarını tamamlayaraq hazırlığınızı mükəmməlləşdirə bilərsiniz.`;
                } else if (acc >= 50) {
                    rec = `İrəliləyişiniz yaxşıdır (ümumi dəqiqlik: <b>${acc}%</b>). Daha yüksək nəticə əldə etmək üçün səhv cavablandırdığınız sualları və sınaqları yenidən işləməyi və mövzuları nəzərdən keçirməyi tövsiyə edirik.`;
                } else {
                    rec = `PDF sınaqlarında dəqiqliyiniz <b>${acc}%</b> səviyyəsindədir. Mövzuları daha dərindən öyrənməyi, sualları tələsmədən oxumağı və zəif nəticə göstərdiyiniz sınaqları təkrar işləməyi tövsiyə edirik.`;
                }
            }
            recTextEl.innerHTML = rec;
        }

        // Right column setup
        const unitsHeader = document.querySelector('.units-header h3');
        if (unitsHeader) unitsHeader.textContent = "Fənlər";

        const layoutToggle = document.querySelector('.layout-toggle');
        if (layoutToggle) layoutToggle.style.display = 'none';

        const listEl = document.getElementById('db-unit-list');
        if (listEl) {
            listEl.innerHTML = "";
            listEl.className = "unit-list-container";
            listEl.style.display = 'grid';
            listEl.style.gridTemplateColumns = 'repeat(auto-fill, minmax(280px, 1fr))';
            listEl.style.gap = '16px';

            if (typeof pdfExamsData !== 'undefined') {
                Object.keys(pdfExamsData).forEach(subject => {
                    const style = COURSE_STYLES[subject] || { icon: "📚", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" };
                    const numExams = pdfExamsData[subject].length;

                    // Calculate subject completed/attempted exams and accuracy
                    let attemptedExams = 0;
                    let subjectCorrect = 0;
                    let subjectAttempts = 0;
                    for (let idx = 0; idx < numExams; idx++) {
                        const examKey = `${subject}_pdf_${idx}`;
                        if (this.stats[examKey] && this.stats[examKey].t > 0) {
                            attemptedExams++;
                            subjectCorrect += this.stats[examKey].c || 0;
                            subjectAttempts += this.stats[examKey].t || 0;
                        }
                    }
                    let subjectAcc = subjectAttempts > 0 ? Math.round((subjectCorrect / subjectAttempts) * 100) : 0;

                    const card = document.createElement('div');
                    card.className = "pdf-subject-card";
                    card.style.cssText = `--accent-color: ${style.accent}; --accent-glow: ${style.accent}25; --icon-bg: linear-gradient(135deg, ${style.g1}20, ${style.g2}20); --icon-border: ${style.accent}30; display: flex; flex-direction: column; gap: 14px; padding: 20px; align-items: stretch;`;
                    card.onclick = () => QuizApp.showPdfExamsList(subject, 'dashboard');
                    card.innerHTML = `
                        <div style="display: flex; align-items: center; gap: 14px;">
                            <div class="subject-icon-wrap">
                                ${style.icon}
                            </div>
                            <div style="flex: 1; min-width: 0;">
                                <div class="subject-title" style="min-height: auto; font-size: 1rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${subject}">${subject}</div>
                                <div style="font-size: 0.78rem; color: var(--text-muted); font-weight: 500; margin-top: 4px;">
                                    ${numExams} Sınaq İmtahanı
                                </div>
                            </div>
                            <div class="subject-arrow-wrap">
                                <svg viewBox="0 0 24 24"><path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"/></svg>
                            </div>
                        </div>
                        
                        <div style="background: rgba(255,255,255,0.01); border: 1px solid var(--border); border-radius: 12px; padding: 10px 14px; display: flex; justify-content: space-between; align-items: center; font-size: 0.8rem;">
                            <div style="display: flex; flex-direction: column; gap: 2px;">
                                <span style="color: var(--text-muted); font-size: 0.68rem; font-weight: 600; text-transform: uppercase;">İşlənilib</span>
                                <span style="color: var(--text-main); font-weight: 700;">${attemptedExams} / ${numExams}</span>
                            </div>
                            <div style="display: flex; flex-direction: column; gap: 2px; align-items: flex-end;">
                                <span style="color: var(--text-muted); font-size: 0.68rem; font-weight: 600; text-transform: uppercase;">Dəqiqlik</span>
                                <span style="color: ${attemptedExams > 0 ? 'var(--accent)' : 'var(--text-muted)'}; font-weight: 700;">${attemptedExams > 0 ? subjectAcc + '%' : '-'}</span>
                            </div>
                        </div>
                    `;
                    listEl.appendChild(card);
                });
            }
        }

        // Hide top nav since we are in a dashboard screen
        const tn = document.getElementById('top-nav');
        if (tn) tn.style.display = 'none';

        // Manage sidebar active states
        const pdfExamsBtn = document.getElementById('btn-pdf-exams');
        if (pdfExamsBtn) {
            document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
            pdfExamsBtn.classList.add('active');
        }
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
        const style = COURSE_STYLES[subjectName] || { icon: "📚", accent: "#6366f1", g1: "#6366f1", g2: "#8b5cf6" };
        
        let examsHTML = "";
        
        // Prepend Multi (All wrongs for this PDF subject)
        let pdfWrQs = [];
        exams.forEach((examQs, idx) => {
            const examKey = `${subjectName}_pdf_${idx}`;
            if (this.wrongDB[examKey]) {
                pdfWrQs = pdfWrQs.concat(this.wrongDB[examKey]);
            }
        });
        
        if (pdfWrQs.length > 0) {
            examsHTML += `
                <div class="unit-item" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.06) 0%, rgba(249, 115, 22, 0.06) 100%); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 18px; padding: 20px; transition: all 0.2s ease; display: flex; flex-direction: column; gap: 14px; grid-column: 1 / -1;">
                    <div class="unit-item-header" style="display: flex; justify-content: space-between; align-items: center; gap: 10px;">
                        <div>
                            <div class="unit-item-title" style="font-size: 1.15rem; font-weight: 800; color: var(--wrong); font-family: 'Plus Jakarta Sans', sans-serif;">
                                ❌ SƏHVLƏRİN TƏKRARI (MULTİ)
                            </div>
                            <div class="unit-item-last-tested" style="font-size: 0.8rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                Bu fənnin bütün PDF sınaqlarında etdiyiniz <strong>${pdfWrQs.length}</strong> səhv sualı yenidən işləyin.
                            </div>
                        </div>
                        <button class="unit-btn-start" style="background: linear-gradient(135deg, #ef4444, #f97316); box-shadow: 0 4px 12px rgba(239, 68, 68, 0.2); border: none;" onclick="QuizApp.startPdfSubjectAllWrQs('${subjectName.replace(/'/g, "\\'")}')">Başla</button>
                    </div>
                </div>
            `;
        }

        // Add "Ən çox düşən suallar" section
        const freqQs = this.getMostFrequentQuestions(subjectName);
        if (freqQs.length > 0) {
            let f_correct = 0, f_wrong = 0, f_lastTested = 0;
            if (this.stats[subjectName] && this.stats[subjectName].bd && this.stats[subjectName].bd['pdf-exam'] && this.stats[subjectName].bd['pdf-exam']['Ən çox düşən suallar']) {
                const item = this.stats[subjectName].bd['pdf-exam']['Ən çox düşən suallar'];
                f_correct = item.c || 0;
                f_wrong = item.w || 0;
                f_lastTested = item.last || 0;
            }
            const f_totalAnswered = f_correct + f_wrong;
            const f_lastTestedStr = this.formatLastTested(f_lastTested, f_totalAnswered > 0);

            examsHTML += `
                <div class="unit-item" style="background: linear-gradient(135deg, rgba(249, 115, 22, 0.06) 0%, rgba(239, 68, 68, 0.06) 100%); border: 1px solid rgba(249, 115, 22, 0.3); border-radius: 18px; padding: 20px; transition: all 0.2s ease; display: flex; flex-direction: column; gap: 14px; grid-column: 1 / -1;">
                    <div class="unit-item-header" style="display: flex; justify-content: space-between; align-items: center; gap: 10px;">
                        <div>
                            <div class="unit-item-title" style="font-size: 1.15rem; font-weight: 800; color: #f97316; font-family: 'Plus Jakarta Sans', sans-serif; display: flex; align-items: center; gap: 8px;">
                                🔥 ƏN ÇOX DÜŞƏN SUALLAR
                            </div>
                            <div class="unit-item-last-tested" style="font-size: 0.8rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                Bu fənnin imtahanlarında təkrarlanan <strong>${freqQs.length}</strong> ən populyar sualı işləyin. Son sınaq: ${f_lastTestedStr}
                            </div>
                        </div>
                        <button class="unit-btn-start" style="background: linear-gradient(135deg, #f97316, #ef4444); box-shadow: 0 4px 12px rgba(249, 115, 22, 0.2); border: none;" onclick="QuizApp.startPdfSubjectFrequentQs('${subjectName.replace(/'/g, "\\'")}')">Başla</button>
                    </div>
                    
                    <div class="unit-item-stats-grid" style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; background: rgba(255,255,255,0.02); padding: 12px; border-radius: 12px; border: 1px solid var(--border);">
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--text-main);">${freqQs.length}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Cəm Sual</span>
                        </div>
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--active);">${f_correct}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Düzgün</span>
                        </div>
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--wrong);">${f_wrong}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Səhv</span>
                        </div>
                    </div>
                </div>
            `;
        }

        exams.forEach((examQs, idx) => {
            const examTitle = `İmtahan ${idx + 1}`;
            const examKey = `${subjectName}_pdf_${idx}`;
            let c_correct = 0, c_wrong = 0, lastTested = 0;
            if (this.stats[examKey]) {
                c_correct = this.stats[examKey].c || 0;
                c_wrong = this.stats[examKey].w || 0;
                if (this.stats[examKey].bd && this.stats[examKey].bd['pdf-exam'] && this.stats[examKey].bd['pdf-exam'][examTitle]) {
                    lastTested = this.stats[examKey].bd['pdf-exam'][examTitle].last || 0;
                }
            }
            const totalAnswered = c_correct + c_wrong;
            const lastTestedStr = this.formatLastTested(lastTested, totalAnswered > 0);
            
            examsHTML += `
                <div class="unit-item" style="background: var(--bg-card); border: 1px solid var(--border); border-radius: 18px; padding: 20px; transition: all 0.2s ease; display: flex; flex-direction: column; gap: 14px;">
                    <div class="unit-item-header" style="display: flex; justify-content: space-between; align-items: flex-start; gap: 10px;">
                        <div>
                            <div class="unit-item-title" style="font-size: 1.05rem; font-weight: 700; color: var(--text-main); font-family: 'Plus Jakarta Sans', sans-serif;">
                                ${examTitle}
                            </div>
                            <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                ⏱️ Son sınaq: ${lastTestedStr}
                            </div>
                        </div>
                        <button class="unit-btn-start" style="background: linear-gradient(135deg, ${style.g1}, ${style.g2}); box-shadow: 0 4px 12px ${style.accent}30;" onclick="QuizApp.startPdfExam('${subjectName.replace(/'/g, "\\'")}', ${idx})">Başla</button>
                    </div>
                    
                    <div class="unit-item-stats-grid" style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; background: rgba(255,255,255,0.02); padding: 12px; border-radius: 12px; border: 1px solid var(--border);">
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--text-main);">${examQs.length}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Cəm Sual</span>
                        </div>
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--active);">${c_correct}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Düzgün</span>
                        </div>
                        <div class="unit-stat-box" style="display: flex; flex-direction: column; align-items: center; justify-content: center; ${c_wrong > 0 ? 'cursor: pointer; background: rgba(239, 68, 68, 0.05); transition: background 0.2s;' : ''}" ${c_wrong > 0 ? `onclick="QuizApp.startPdfExamWrQs('${subjectName.replace(/'/g, "\\'")}', ${idx})" title="Səhvləri yenidən işləmək üçün klikləyin"` : ''}>
                            <span class="us-val" style="font-size: 1rem; font-weight: 800; color: var(--wrong);">${c_wrong}</span>
                            <span class="us-lbl" style="font-size: 0.62rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-top: 3px; letter-spacing: 0.5px;">Səhv</span>
                        </div>
                    </div>
                </div>
            `;
        });
        
        container.innerHTML = `
            <div class="dashboard" style="max-width: 1000px; width: 100%; margin: 0 auto; padding: 10px 0;">
                <div style="margin-bottom: 20px; display: flex; flex-direction: column; gap: 12px;">
                    <button class="btn btn-sec" style="padding: 8px 16px; width: auto; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 6px; align-self: flex-start;" onclick="if(QuizApp.state.pdfExamReferrer === 'dashboard') { QuizApp.showPdfExamsDashboard(); } else { QuizApp.start(); }">
                        ← Geri Qayıt
                    </button>
                    <div style="display: flex; align-items: center; gap: 12px; margin-top: 8px;">
                        <div style="width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; background: linear-gradient(135deg, ${style.g1}20, ${style.g2}20); border: 1px solid ${style.accent}30; color: ${style.accent};">
                            ${style.icon}
                        </div>
                        <div>
                            <h2 style="font-size: 1.4rem; font-weight: 800; color: var(--text-main); font-family: 'Plus Jakarta Sans', sans-serif; margin: 0;">${subjectName}</h2>
                            <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 3px; font-weight: 500;">PDF Sınaq İmtahanları</p>
                        </div>
                    </div>
                </div>
                
                <div class="unit-list-container" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px;">
                    ${examsHTML || '<div style="color: var(--text-muted); font-size: 0.9rem; padding: 20px;">İmtahan tapılmadı</div>'}
                </div>
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
        
        const subjects = [
            "Atatürk İlkeleri ve İnkılap Tarihi II",
            "Grafik Tasarım II",
            "Görsel İletişim Tasarımı",
            "Masaüstü Yayıncılık",
            "Tasarımda Tipografi",
            "Türk Dili II"
        ];
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
            const subjects = [
                "Atatürk İlkeleri ve İnkılap Tarihi II",
                "Grafik Tasarım II",
                "Görsel İletişim Tasarımı",
                "Masaüstü Yayıncılık",
                "Tasarımda Tipografi",
                "Türk Dili II"
            ];
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
                    const style = COURSE_STYLES[occ.course] || { accent: '#6366f1' };
                    badgesHTML += `
                        <span class="badge-meta-course" style="background: rgba(99, 102, 241, 0.08); border: 1px solid ${style.accent}30; color: ${style.accent}; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700; margin-right: 6px; margin-top: 4px; display: inline-block;">
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
            <div class="dashboard" style="max-width: 1000px; width: 100%; margin: 0 auto; padding: 10px 0;">
                <div style="margin-bottom: 25px; display: flex; justify-content: space-between; align-items: center; gap: 15px; flex-wrap: wrap;">
                    <div>
                        <h2 style="font-size: 1.6rem; font-weight: 800; color: var(--text-main); font-family: 'Plus Jakarta Sans', sans-serif; margin: 0;">⚠️ Ziddiyyətli Suallar</h2>
                        <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 5px; font-weight: 500;">Bazada eyni suala fərqli imtahanlarda fərqli cavab verilmiş ${conflicts.length} ziddiyyət mövcuddur.</p>
                    </div>
                    <div style="display: flex; gap: 10px;">
                        <button class="btn btn-pri" style="background: linear-gradient(135deg, #f59e0b 0%, #ef4444 100%); box-shadow: 0 4px 12px rgba(245, 158, 11, 0.2); border: none;" onclick="QuizApp.startConflictingQuestionsQuiz()">
                            ⚡ Sınağa Başla (${conflicts.length} Sual)
                        </button>
                    </div>
                </div>

                <div style="margin-bottom: 20px;">
                    <input type="text" id="conflict-search" placeholder="Suallarda axtarış..." oninput="QuizApp.filterConflicts(this.value)" style="width: 100%; padding: 12px 16px; border-radius: 12px; border: 1px solid var(--border); background: var(--bg-card); color: var(--text-main); font-size: 0.95rem; font-family: 'Plus Jakarta Sans', sans-serif; outline: none; transition: border-color 0.2s;" onfocus="this.style.borderColor='var(--accent)'" onblur="this.style.borderColor='var(--border)'">
                </div>
                
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
            const style = courseStyles[c] || { accent: '#6366f1', g1: '#6366f1', g2: '#8b5cf6' };
            let totalQ = 0;
            if (typeof quizData !== 'undefined') totalQ = quizData.filter(q => q.c === c).length;
            if (typeof pdfExamsData !== 'undefined' && pdfExamsData[c]) {
                pdfExamsData[c].forEach(examQs => {
                    totalQ += examQs.length;
                });
            }

            let answered = 0;
            let correctC = 0;
            let wrongC = 0;

            Object.keys(this.stats).forEach(key => {
                if (key === c || key.startsWith(c + '_pdf_')) {
                    const stat = this.stats[key] || {};
                    answered += stat.t || 0;
                    correctC += stat.c || 0;
                    wrongC += stat.w || 0;
                }
            });

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
        this.state = { ...this.state, view: 'dashboard', course: c, category: type, isWrongMode: false, isSearchMode: false, isMockMode: false, mixedSubSubject: null };

        document.querySelectorAll('.sub-btn').forEach(b => b.classList.remove('active-sub'));
        if (btn) btn.classList.add('active-sub');

        this.showCourseDashboard(c);
        if (window.innerWidth <= 768) toggleSidebar();
    },

    showCourseDashboard: function (c) {
        if (c && c.includes('_pdf_')) {
            const subjectName = this.state.activePdfSubject;
            if (subjectName) {
                this.showPdfExamsList(subjectName);
                return;
            }
        }
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
        let totalQ = 0;
        if (typeof quizData !== 'undefined') {
            totalQ = quizData.filter(q => q.c === c).length;
        }
        if (typeof pdfExamsData !== 'undefined' && pdfExamsData[c]) {
            pdfExamsData[c].forEach(examQs => {
                totalQ += examQs.length;
            });
        }

        let answered = 0;
        let correctC = 0;
        let wrongC = 0;
        let timeC = 0;

        Object.keys(this.stats).forEach(key => {
            if (key === c || key.startsWith(c + '_pdf_')) {
                const stat = this.stats[key] || {};
                answered += stat.t || 0;
                correctC += stat.c || 0;
                wrongC += stat.w || 0;
                timeC += stat.time || 0;
            }
        });

        document.getElementById('db-total-questions').textContent = totalQ;
        const attemptsVal = document.getElementById('db-total-attempts');
        if (attemptsVal) attemptsVal.textContent = answered;
        document.getElementById('db-total-time').textContent = this.formatTime(timeC) + " / " + this.formatTime(this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0);
        
        const correctVal = document.getElementById('db-total-correct');
        const wrongVal = document.getElementById('db-total-wrong');
        correctVal.textContent = correctC;
        wrongVal.textContent = wrongC;

        let acc = 0;
        if (answered > 0) acc = Math.round((correctC / answered) * 100);
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

        // Find unit with most wrong answers
        let maxWrong = 0;
        let maxUnitName = "";
        let maxUnitIdx = -1;
        
        if (s.bd && s.bd['units']) {
            CONFIG[c].units.forEach((unitName, i) => {
                const unitKey = `Unit ${i + 1}`;
                const us = s.bd['units'][unitKey];
                if (us && us.w > maxWrong) {
                    maxWrong = us.w;
                    maxUnitName = unitName;
                    maxUnitIdx = i;
                }
            });
        }
        
        const warningContainer = document.getElementById('db-warning-container');
        if (warningContainer) {
            if (maxWrong > 0) {
                warningContainer.style.display = 'block';
                warningContainer.innerHTML = `
                    <div class="db-warning-box">
                        <div class="db-warning-icon">⚠️</div>
                        <div class="db-warning-content" style="display: flex; justify-content: space-between; align-items: center; width: 100%; gap: 16px; flex-wrap: wrap;">
                            <div style="flex: 1; min-width: 200px;">
                                <div class="db-warning-title">ƏN ÇOX SƏHV EDİLƏN BÖLMƏ</div>
                                <div class="db-warning-desc">Bu fəndən ən çox səhvi <span>${maxUnitName}</span> bölməsində etmisiniz (<span>${maxWrong} səhv</span>).</div>
                            </div>
                            <button class="unit-btn-start" style="background: linear-gradient(135deg, #ef4444 0%, #f97316 100%); box-shadow: 0 4px 12px rgba(239, 68, 68, 0.2);" onclick="QuizApp.startUnit('${c.replace(/'/g, "\\'")}', ${maxUnitIdx})">Bölməyə Başla</button>
                        </div>
                    </div>
                `;
            } else {
                warningContainer.style.display = 'none';
                warningContainer.innerHTML = '';
            }
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
            if (c === "Mixed") {
                this.renderMixedDashboard(listEl, layout, s);
            } else {
                listEl.innerHTML = "";
                const wrQs = this.wrongDB[c] || [];
                const hardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 2).length;
                const veryHardQsCount = wrQs.filter(q => (this.wrongCounts[q.q] || 0) >= 3).length;
                
                if (layout === 'table') {
                    listEl.classList.add('table-mode');
                    
                    // Create table element
                    const table = document.createElement('table');
                    table.className = 'stat-table unit-table';
                    
                    let multiLastTested = 0;
                    let hasMultiData = false;
                    if (s.bd && s.bd['units'] && s.bd['units']['Multi']) {
                        multiLastTested = s.bd['units']['Multi'].last || 0;
                        hasMultiData = (s.bd['units']['Multi'].t || 0) > 0;
                    }
                    if (multiLastTested === 0 && hasMultiData) {
                        multiLastTested = this.getCourseLastActiveDateFromHistory(c);
                    }
                    const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);

                    // Prepend Multi row to tbodyHTML
                    let tbodyHTML = `
                        <tr onclick="QuizApp.startMultiUnit('${c.replace(/'/g, "\\'")}')" style="background: rgba(99, 102, 241, 0.05); border-left: 3px solid var(--accent);">
                            <td style="font-weight: 800; color: var(--accent);">
                                <div class="unit-table-title"><span class="unit-table-num">⭐</span> Multi (Səhvlərin Təkrarı)</div>
                                <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                    ⏱️ Son sınaq: ${multiLastTestedStr}
                                </div>
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

                    // Prepend Mixed Only row if there are mixed-only questions
                    const mixedOnlyQs = this.getMixedOnlyQuestions(c);
                    if (mixedOnlyQs.length > 0) {
                        let mixedOnlyLastTested = 0;
                        let hasMixedOnlyData = false;
                        if (s.bd && s.bd['mixed-only'] && s.bd['mixed-only']['Yalnız Mixed-də olan suallar']) {
                            mixedOnlyLastTested = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].last || 0;
                            hasMixedOnlyData = (s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].t || 0) > 0;
                        }
                        const mixedOnlyLastTestedStr = this.formatLastTested(mixedOnlyLastTested, hasMixedOnlyData);
                        let mixedOnlyCorrect = 0, mixedOnlyWrong = 0, mixedOnlyAcc = 0;
                        if (hasMixedOnlyData) {
                            mixedOnlyCorrect = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].c || 0;
                            mixedOnlyWrong = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].w || 0;
                            const totalMixedOnly = mixedOnlyCorrect + mixedOnlyWrong;
                            if (totalMixedOnly > 0) mixedOnlyAcc = Math.round((mixedOnlyCorrect / totalMixedOnly) * 100);
                        }

                        tbodyHTML += `
                            <tr onclick="QuizApp.startMixedOnlyQs('${c.replace(/'/g, "\\'")}')" style="background: rgba(139, 92, 246, 0.05); border-left: 3px solid #8b5cf6;">
                                <td style="font-weight: 800; color: #8b5cf6;">
                                    <div class="unit-table-title"><span class="unit-table-num">💎</span> Yalnız Mixed-də olan suallar</div>
                                    <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                        ⏱️ Son sınaq: ${mixedOnlyLastTestedStr}
                                    </div>
                                </td>
                                <td style="text-align: center;">${mixedOnlyQs.length}</td>
                                <td style="text-align: center; color: var(--active); font-weight: 700;">${hasMixedOnlyData ? mixedOnlyCorrect : '-'}</td>
                                <td style="text-align: center; color: var(--wrong); font-weight: 700;">${hasMixedOnlyData ? mixedOnlyWrong : '-'}</td>
                                <td style="text-align: center; color: var(--accent); font-weight: 700;">${hasMixedOnlyData ? mixedOnlyAcc + '%' : '-'}</td>
                                <td style="text-align: right;" onclick="event.stopPropagation();">
                                    <button class="unit-btn-start" style="background: linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%); border: none;" onclick="QuizApp.startMixedOnlyQs('${c.replace(/'/g, "\\'")}')">Başla</button>
                                </td>
                            </tr>
                        `;
                    }
                    
                    CONFIG[c].units.forEach((unitName, i) => {
                        const unitIdx = i + 1;
                        let totalUnitQ = 0;
                        if (typeof quizData !== 'undefined') {
                            if (c === "Mixed" && this.mixedUnitsInfo) {
                                const muInfo = this.mixedUnitsInfo[i];
                                if (muInfo) {
                                    totalUnitQ = muInfo.endIdx - muInfo.startIdx;
                                }
                            } else {
                                totalUnitQ = quizData.filter(q => q.c === c && q.u === unitIdx).length;
                            }
                        }
                        
                        const unitKey = `Unit ${unitIdx}`;
                        let c_correct = 0;
                        let c_wrong = 0;
                        let unitLastTested = 0;
                        if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                            const us = s.bd['units'][unitKey];
                            c_correct = us.c;
                            c_wrong = us.w;
                            unitLastTested = us.last || 0;
                        }
                        
                        let unitAcc = 0;
                        const totalAnswered = c_correct + c_wrong;
                        if (totalAnswered > 0) {
                            unitAcc = Math.round((c_correct / totalAnswered) * 100);
                        }
                        
                        if (unitLastTested === 0 && totalAnswered > 0) {
                            unitLastTested = this.getCourseLastActiveDateFromHistory(c);
                        }
                        
                        const unitLastTestedStr = this.formatLastTested(unitLastTested, totalAnswered > 0);
                        
                        tbodyHTML += `
                            <tr onclick="QuizApp.startUnit('${c.replace(/'/g, "\\'")}', ${i})">
                                <td style="font-weight: 700; color: var(--text-main);">
                                    <div class="unit-table-title"><span class="unit-table-num">${unitIdx}.</span> ${unitName}</div>
                                    <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                        ⏱️ Son sınaq: ${unitLastTestedStr}
                                    </div>
                                </td>
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
                    let multiLastTested = 0;
                    let hasMultiData = false;
                    if (s.bd && s.bd['units'] && s.bd['units']['Multi']) {
                        multiLastTested = s.bd['units']['Multi'].last || 0;
                        hasMultiData = (s.bd['units']['Multi'].t || 0) > 0;
                    }
                    if (multiLastTested === 0 && hasMultiData) {
                        multiLastTested = this.getCourseLastActiveDateFromHistory(c);
                    }
                    const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);

                    const multiItem = document.createElement('div');
                    multiItem.className = 'unit-item';
                    multiItem.style.background = 'linear-gradient(135deg, rgba(99, 102, 241, 0.06) 0%, rgba(139, 92, 246, 0.06) 100%)';
                    multiItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                    multiItem.innerHTML = `
                        <div class="unit-item-header">
                            <div>
                                <div class="unit-item-title" style="color: var(--accent); font-weight: 800;">⭐ Multi (Səhvlərin Təkrarı)</div>
                                <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                    ⏱️ Son sınaq: ${multiLastTestedStr}
                                </div>
                            </div>
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

                    // Add "Yalnız Mixed-də olan suallar" card to Grid layout
                    const mixedOnlyQs = this.getMixedOnlyQuestions(c);
                    if (mixedOnlyQs.length > 0) {
                        let mixedOnlyLastTested = 0;
                        let hasMixedOnlyData = false;
                        if (s.bd && s.bd['mixed-only'] && s.bd['mixed-only']['Yalnız Mixed-də olan suallar']) {
                            mixedOnlyLastTested = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].last || 0;
                            hasMixedOnlyData = (s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].t || 0) > 0;
                        }
                        const mixedOnlyLastTestedStr = this.formatLastTested(mixedOnlyLastTested, hasMixedOnlyData);
                        let mixedOnlyCorrect = 0, mixedOnlyWrong = 0;
                        if (hasMixedOnlyData) {
                            mixedOnlyCorrect = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].c || 0;
                            mixedOnlyWrong = s.bd['mixed-only']['Yalnız Mixed-də olan suallar'].w || 0;
                        }

                        const mixedOnlyItem = document.createElement('div');
                        mixedOnlyItem.className = 'unit-item';
                        mixedOnlyItem.style.background = 'linear-gradient(135deg, rgba(139, 92, 246, 0.06) 0%, rgba(99, 102, 241, 0.06) 100%)';
                        mixedOnlyItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                        mixedOnlyItem.innerHTML = `
                            <div class="unit-item-header">
                                <div>
                                    <div class="unit-item-title" style="color: #8b5cf6; font-weight: 800;">💎 Yalnız Mixed-də olan suallar</div>
                                    <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                        ⏱️ Son sınaq: ${mixedOnlyLastTestedStr}
                                    </div>
                                </div>
                                <button class="unit-btn-start" style="background: linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%); border: none;" onclick="QuizApp.startMixedOnlyQs('${c.replace(/'/g, "\\'")}')">Başla</button>
                            </div>
                            <div class="unit-item-stats-grid">
                                <div class="unit-stat-box">
                                    <span class="us-val" style="color: var(--text-main); font-weight: 800;">${mixedOnlyQs.length}</span>
                                    <span class="us-lbl">CƏMİ SUAL</span>
                                </div>
                                <div class="unit-stat-box">
                                    <span class="us-val" style="color: var(--active); font-weight: 800;">${mixedOnlyCorrect}</span>
                                    <span class="us-lbl">DOĞRU</span>
                                </div>
                                <div class="unit-stat-box">
                                    <span class="us-val" style="color: var(--wrong); font-weight: 800;">${mixedOnlyWrong}</span>
                                    <span class="us-lbl">YANLIŞ</span>
                                </div>
                            </div>
                        `;
                        listEl.appendChild(mixedOnlyItem);
                    }
                    
                    CONFIG[c].units.forEach((unitName, i) => {
                        const unitIdx = i + 1;
                        let totalUnitQ = 0;
                        if (typeof quizData !== 'undefined') {
                            if (c === "Mixed" && this.mixedUnitsInfo) {
                                const muInfo = this.mixedUnitsInfo[i];
                                if (muInfo) {
                                    totalUnitQ = muInfo.endIdx - muInfo.startIdx;
                                }
                            } else {
                                totalUnitQ = quizData.filter(q => q.c === c && q.u === unitIdx).length;
                            }
                        }

                        const unitKey = `Unit ${unitIdx}`;
                        let c_correct = 0;
                        let c_wrong = 0;
                        let unitLastTested = 0;

                        if (s.bd && s.bd['units'] && s.bd['units'][unitKey]) {
                            const us = s.bd['units'][unitKey];
                            c_correct = us.c;
                            c_wrong = us.w;
                            unitLastTested = us.last || 0;
                        }
                        const totalAnswered = c_correct + c_wrong;
                        if (unitLastTested === 0 && totalAnswered > 0) {
                            unitLastTested = this.getCourseLastActiveDateFromHistory(c);
                        }

                        const unitLastTestedStr = this.formatLastTested(unitLastTested, totalAnswered > 0);

                        const item = document.createElement('div');
                        item.className = 'unit-item';
                        item.innerHTML = `
                            <div class="unit-item-header">
                                <div>
                                    <div class="unit-item-title">${unitName}</div>
                                    <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                        ⏱️ Son sınaq: ${unitLastTestedStr}
                                    </div>
                                </div>
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
                let accentColor = '#6366f1';
                
                if (q.c === "Mixed") {
                    const subjects = [
                        "Atatürk İlkeleri ve İnkılap Tarihi II",
                        "Grafik Tasarım II",
                        "Görsel İletişim Tasarımı",
                        "Masaüstü Yayıncılık",
                        "Tasarımda Tipografi",
                        "Türk Dili II"
                    ];
                    displayCourse = subjects[q.u - 1] || "Mixed";
                    displayUnit = this.state.currentTitle || "";
                    const style = COURSE_STYLES[displayCourse] || { accent: '#ec4899' };
                    accentColor = style.accent;
                } else {
                    displayUnit = (CONFIG[q.c] && CONFIG[q.c].units[q.u - 1]) || `Unit ${q.u}`;
                    const style = COURSE_STYLES[q.c] || { accent: '#6366f1' };
                    accentColor = style.accent;
                }
                
                qMetaEl.innerHTML = `
                    <span class="badge-meta-course" style="background: rgba(99, 102, 241, 0.08); border: 1px solid ${accentColor}30; color: ${accentColor}; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700;">${displayCourse}</span>
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

        const btnPrev = document.getElementById('btn-prev');
        if (btnPrev) btnPrev.disabled = this.state.index === 0;

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

        // Auto-advance to the next question with a 1-second delay so user can see correct/wrong state
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
        }, 1000);
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
        let globalTotalQ = typeof quizData !== 'undefined' ? quizData.length : 0;

        document.getElementById('db-total-questions').textContent = globalTotalQ;
        const attemptsVal = document.getElementById('db-total-attempts');
        if (attemptsVal) attemptsVal.textContent = globalTotalAns;
        document.getElementById('db-total-time').textContent = this.formatTime(globalTime) + " / " + this.formatTime(this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0);
        
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
                
                let multiLastTested = 0;
                let hasMultiData = false;
                Object.keys(this.stats).forEach(k => {
                    if (this.stats[k] && this.stats[k].bd && this.stats[k].bd['units'] && this.stats[k].bd['units']['Multi']) {
                        const mTs = this.stats[k].bd['units']['Multi'].last || 0;
                        if (mTs > multiLastTested) multiLastTested = mTs;
                        if ((this.stats[k].bd['units']['Multi'].t || 0) > 0) hasMultiData = true;
                    }
                });
                if (multiLastTested === 0 && hasMultiData) {
                    Object.keys(this.stats).forEach(k => {
                        const fallTs = this.getCourseLastActiveDateFromHistory(k);
                        if (fallTs > multiLastTested) multiLastTested = fallTs;
                    });
                }
                const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);

                // Prepend Multi row to tbodyHTML
                let tbodyHTML = `
                    <tr onclick="QuizApp.startMultiUnit('all')" style="background: rgba(99, 102, 241, 0.05); border-left: 3px solid var(--accent);">
                        <td style="font-weight: 800; color: var(--accent);">
                            <div class="unit-table-title"><span class="unit-table-num">⭐</span> Multi (Səhvlərin Təkrarı)</div>
                            <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                ⏱️ Son sınaq: ${multiLastTestedStr}
                            </div>
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
                    
                    const courseLastTested = this.getCourseLastTested(c);
                    const courseLastTestedStr = this.formatLastTested(courseLastTested, cs.t > 0);
                    
                    tbodyHTML += `
                        <tr onclick="QuizApp.showCourseDashboard('${c.replace(/'/g, "\\'")}')">
                            <td style="font-weight: 700; color: var(--text-main);">
                                <div class="unit-table-title">${c}</div>
                                <div class="unit-table-last-tested" style="font-size: 0.72rem; color: var(--text-muted); font-weight: 500; margin-top: 3px;">
                                    ⏱️ Son sınaq: ${courseLastTestedStr}
                                </div>
                            </td>
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
                let multiLastTested = 0;
                let hasMultiData = false;
                Object.keys(this.stats).forEach(k => {
                    if (this.stats[k] && this.stats[k].bd && this.stats[k].bd['units'] && this.stats[k].bd['units']['Multi']) {
                        const mTs = this.stats[k].bd['units']['Multi'].last || 0;
                        if (mTs > multiLastTested) multiLastTested = mTs;
                        if ((this.stats[k].bd['units']['Multi'].t || 0) > 0) hasMultiData = true;
                    }
                });
                if (multiLastTested === 0 && hasMultiData) {
                    Object.keys(this.stats).forEach(k => {
                        const fallTs = this.getCourseLastActiveDateFromHistory(k);
                        if (fallTs > multiLastTested) multiLastTested = fallTs;
                    });
                }
                const multiLastTestedStr = this.formatLastTested(multiLastTested, hasMultiData);

                const multiItem = document.createElement('div');
                multiItem.className = 'unit-item';
                multiItem.style.background = 'linear-gradient(135deg, rgba(99, 102, 241, 0.06) 0%, rgba(139, 92, 246, 0.06) 100%)';
                multiItem.style.border = '1px solid rgba(139, 92, 246, 0.3)';
                multiItem.innerHTML = `
                    <div class="unit-item-header">
                        <div>
                            <div class="unit-item-title" style="color: var(--accent); font-weight: 800;">⭐ Multi (Səhvlərin Təkrarı)</div>
                            <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                ⏱️ Son sınaq: ${multiLastTestedStr}
                            </div>
                        </div>
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
                    
                    const courseLastTested = this.getCourseLastTested(c);
                    const courseLastTestedStr = this.formatLastTested(courseLastTested, cs.t > 0);

                    const item = document.createElement('div');
                    item.className = 'unit-item';
                    item.innerHTML = `
                        <div class="unit-item-header">
                            <div>
                                <div class="unit-item-title">${c}</div>
                                <div class="unit-item-last-tested" style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px; font-weight: 500;">
                                    ⏱️ Son sınaq: ${courseLastTestedStr}
                                </div>
                            </div>
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
        document.getElementById('st-time').textContent = this.formatTime(tm) + " / " + this.formatTime(this.stats["_platform"] ? this.stats["_platform"].time || 0 : 0);
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
        const total = this.state.questions.length;
        const answeredCount = Object.keys(this.state.answers).length;
        if (answeredCount < total) {
            if (!confirm(`Sınaq yarımçıqdır (Cavablandırılıb: ${answeredCount}/${total}). Bitirməkdən əminsiniz?`)) {
                return;
            }
        }

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

    showHomeFromSidebar: function () {
        document.querySelectorAll('.course-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.menu-btn').forEach(b => b.classList.remove('active'));
        const homeBtn = document.getElementById('btn-home');
        if (homeBtn) homeBtn.classList.add('active');
        this.start();
        if (window.innerWidth <= 768) toggleSidebar();
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
        if (window.innerWidth <= 768) toggleSidebar();
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
            questionText.textContent = `${idx + 1}. ${q.q || '(Sual mətni yoxdur)'}`;
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
            "Türk Dili II": { g1: "#8b5cf6", g2: "#ec4899" },
            "Mixed": { g1: "#ec4899", g2: "#f43f5e" }
        };
        const defaultStyle = { g1: "#6366f1", g2: "#8b5cf6" };

        const coursesList = ["Mixed", "Atatürk İlkeleri ve İnkılap Tarihi II", "Türk Dili II", "Grafik Tasarım II", "Görsel İletişim Tasarımı", "Masaüstü Yayıncılık", "Tasarımda Tipografi"];
        
        if (!this.state.chartSelectedCourse) {
            this.state.chartSelectedCourse = 'all';
        }

        // Render dynamic dropdown filter
        const filtersContainer = document.getElementById('chart-courses-filters');
        if (filtersContainer) {
            filtersContainer.innerHTML = '';
            
            const selectWrap = document.createElement('div');
            selectWrap.className = 'chart-filter-select-wrap';
            
            const select = document.createElement('select');
            select.className = 'chart-filter-select';
            
            // "Hamısı" option
            const optAll = document.createElement('option');
            optAll.value = 'all';
            optAll.textContent = '🌟 Hamısı';
            if (this.state.chartSelectedCourse === 'all') optAll.selected = true;
            select.appendChild(optAll);
            
            // Course options
            coursesList.forEach(c => {
                const style = COURSE_STYLES[c] || { icon: "📚" };
                const opt = document.createElement('option');
                opt.value = c;
                opt.textContent = `${style.icon} ${c}`;
                if (this.state.chartSelectedCourse === c) opt.selected = true;
                select.appendChild(opt);
            });
            
            select.onchange = (e) => {
                this.state.chartSelectedCourse = e.target.value;
                this.drawDynamicsChart();
            };
            
            selectWrap.appendChild(select);
            filtersContainer.appendChild(selectWrap);
        }

        const chartData = last7Days.map(date => {
            const dayData = this.dailyHistory[date] || {};
            const coursesData = [];
            let totalVal = 0;
            coursesList.forEach(c => {
                let time = 0;
                let correct = 0;
                let wrong = 0;
                
                Object.keys(dayData).forEach(key => {
                    if (key === c || key.startsWith(c + '_pdf_')) {
                        const data = dayData[key] || {};
                        time += data.time || 0;
                        correct += data.correct || 0;
                        wrong += data.wrong || 0;
                    }
                });

                const val = mode === 'questions' ? (correct + wrong) : Math.round(time / 60);
                coursesData.push({ course: c, val, correct, wrong, time });
                totalVal += val;
            });
            return { date, totalVal, coursesData };
        });

        // Find the maximum value to scale the Y axis based on filtered courses
        let maxVal = 10;
        chartData.forEach(day => {
            day.coursesData.forEach(c => {
                if (this.state.chartSelectedCourse !== 'all' && this.state.chartSelectedCourse !== c.course) return;
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
        const monthsAzShort = ["Yan", "Fev", "Mar", "Apr", "May", "İyn", "İyl", "Avq", "Sen", "Okt", "Noy", "Dek"];
        chartData.forEach((day, index) => {
            const x = padding.left + index * stepWidth;
            
            // Thinning: only draw label for even indices (0, 2, 4...) to prevent overlap
            const isLast = (index === chartData.length - 1);
            if (index % 2 !== 0 && !isLast) {
                return;
            }
            if (isLast && index % 2 !== 0 && (chartData.length - 2) % 2 === 0) {
                // Skip last index if it's odd and the previous even index was drawn, to prevent overlap
                return;
            }
            
            const parts = day.date.split('-');
            const dObj = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
            const dayNum = String(dObj.getDate()).padStart(2, '0');
            const monthName = monthsAzShort[dObj.getMonth()];
            const label = `${dayNum} ${monthName}`;
            
            ctx.fillStyle = "rgba(255, 255, 255, 0.45)";
            if (index === 0) {
                ctx.textAlign = "left";
            } else if (isLast) {
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

        // Draw lines for each course using smooth Catmull-Rom splines
        coursesList.forEach(courseName => {
            if (this.state.chartSelectedCourse !== 'all' && this.state.chartSelectedCourse !== courseName) return;
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
                if (this.state.chartSelectedCourse !== 'all' && this.state.chartSelectedCourse !== courseName) return;
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
                const monthsAzLong = ["Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun", "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr"];
                const weekdaysAz = ["Bazar", "Bazar ertəsi", "Çərşənbə axşamı", "Çərşənbə", "Cümə axşamı", "Cümə", "Şənbə"];
                const parts = dayData.date.split('-');
                const dObj = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                const dayNum = String(dObj.getDate()).padStart(2, '0');
                const monthName = monthsAzLong[dObj.getMonth()];
                const weekdayName = weekdaysAz[dObj.getDay()];
                const dateStr = `${dayNum} ${monthName}, ${weekdayName}`;
                
                let detailsHTML = `<div style="font-weight:700; font-size:0.8rem; margin-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.1); padding-bottom:4px;">${dateStr}</div>`;
                let hasData = false;

                dayData.coursesData.forEach(seg => {
                    if (seg.val === 0) return;
                    if (this.state.chartSelectedCourse !== 'all' && this.state.chartSelectedCourse !== seg.course) return;
                    hasData = true;
                    const style = courseStyles[seg.course] || defaultStyle;
                    const mins = Math.floor(seg.time / 60);
                    const secs = seg.time % 60;
                    const timeStr = mins > 0 
                        ? `${mins} d ${secs > 0 ? secs + ' s' : ''}` 
                        : `${secs} s`;
                    const valStr = `<span style="color:#22c55e;font-weight:700;">${seg.correct} D</span> / <span style="color:#ef4444;font-weight:700;">${seg.wrong} S</span> <span style="color:rgba(255,255,255,0.45); font-size:0.68rem; margin-left:6px;">(${timeStr})</span>`;
                    
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
            if (key.startsWith('qa_v31_') || key === 'theme') {
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
                'stats': 'qa_v31_s',
                'wrong': 'qa_v31_w',
                'correct': 'qa_v31_c',
                'bookmarks': 'qa_v31_m',
                'daily': 'qa_v31_h',
                'dailyGoal': 'qa_v31_dg',
                'settings': 'qa_v31_conf',
                'wrongCounts': 'qa_v31_wc',
                'localUpdatedAt': 'qa_v31_localUpdatedAt'
            };

            const normalizedData = {};
            for (let [key, val] of Object.entries(data)) {
                if (firestoreKeyMap[key]) {
                    normalizedData[firestoreKeyMap[key]] = val;
                } else {
                    normalizedData[key] = val;
                }
            }

            // 2. Resolve & merge daily history if both qa_v31_h and legacy qa_v31_d exist
            let dailyHistoryToImport = null;
            
            // Extract new daily history
            if (normalizedData['qa_v31_h']) {
                try {
                    dailyHistoryToImport = typeof normalizedData['qa_v31_h'] === 'string' 
                        ? JSON.parse(normalizedData['qa_v31_h']) 
                        : normalizedData['qa_v31_h'];
                } catch(e) {}
            }
            
            // Extract legacy daily history
            if (data['qa_v31_d']) {
                try {
                    const legacyDaily = typeof data['qa_v31_d'] === 'string' 
                        ? JSON.parse(data['qa_v31_d']) 
                        : data['qa_v31_d'];
                        
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
                normalizedData['qa_v31_h'] = JSON.stringify(dailyHistoryToImport);
            }
            
            // Delete legacy qa_v31_d from data and localStorage to prevent pollution
            delete normalizedData['qa_v31_d'];
            localStorage.removeItem('qa_v31_d');

            // 3. Save all normalized keys to localStorage
            for (let [key, val] of Object.entries(normalizedData)) {
                if (key.startsWith('qa_v31_') || key === 'theme') {
                    const stringValue = typeof val === 'string' ? val : JSON.stringify(val);
                    localStorage.setItem(key, stringValue);
                    count++;
                }
            }

            if (count > 0) {
                localStorage.setItem('qa_v31_localUpdatedAt', Date.now().toString());
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
                alert("İdxal üçün uyğun açarlar (qa_v31_) tapılmadı.");
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
                'stats': 'qa_v31_s',
                'wrong': 'qa_v31_w',
                'correct': 'qa_v31_c',
                'bookmarks': 'qa_v31_m',
                'daily': 'qa_v31_h',
                'dailyGoal': 'qa_v31_dg',
                'settings': 'qa_v31_conf',
                'wrongCounts': 'qa_v31_wc',
                'localUpdatedAt': 'qa_v31_localUpdatedAt'
            };
            const normalizedData = {};
            for (let [key, val] of Object.entries(data)) {
                if (firestoreKeyMap[key]) {
                    normalizedData[firestoreKeyMap[key]] = val;
                } else {
                    normalizedData[key] = val;
                }
            }
            
            delete normalizedData['qa_v31_d'];
            localStorage.removeItem('qa_v31_d');

            for (let [key, val] of Object.entries(normalizedData)) {
                if (key.startsWith('qa_v31_') || key === 'theme') {
                    const stringValue = typeof val === 'string' ? val : JSON.stringify(val);
                    localStorage.setItem(key, stringValue);
                    count++;
                }
            }

            if (count > 0) {
                localStorage.setItem('qa_v31_localUpdatedAt', Date.now().toString());
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
        
        // Filter questions to only Atatürk and Türk Dili courses
        const surprisePool = quizData.filter(q => {
            const courseLower = (q.c || "").toLowerCase();
            return courseLower.includes("atatürk") || 
                   courseLower.includes("ataturk") || 
                   courseLower.includes("türk dil") || 
                   courseLower.includes("turk dil");
        });
        
        if (surprisePool.length === 0) {
            console.log("No Atatürk or Türk Dili questions found for surprise pool.");
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
            const colors = ['#6366f1', '#8b5cf6', '#10b981', '#ef4444', '#f59e0b', '#3b82f6'];
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
