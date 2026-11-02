// Google sign-in and cloud sync (Firebase Auth + Firestore)
//
// Kept deliberately cheap so the free quota is never close:
//  - writes happen only when something changed, at most every few minutes and when the app is hidden
//  - answer lists are stored as short question keys instead of full question objects
//  - this semester lives in its own place, the old semester's data is never touched
// Devices are merged, never overwritten: per course the side with more answers is kept.

const firebaseConfig = {
    apiKey: "AIzaSyA_FAHBa-uX6lJXRsFlJ04GCcPe_HVLYkY",
    authDomain: "exam-6ea6d.firebaseapp.com",
    projectId: "exam-6ea6d",
    storageBucket: "exam-6ea6d.firebasestorage.app",
    messagingSenderId: "971462035893",
    appId: "1:971462035893:web:e5f0f14c147ed518ce31fc"
};

(function () {
    const SEMESTER = 'v32';
    const PREFIX = 'qa_v32_';
    const TS_KEY = 'qa_v32_localUpdatedAt';
    const SYNCED_KEY = 'qa_v32_syncedUid';
    const SAVE_EVERY = 3 * 60 * 1000;   // at most one write per 3 minutes while studying
    const PULL_EVERY = 60 * 1000;       // re-check the cloud when the app comes back, at most once a minute

    const rawSet = Storage.prototype.setItem;
    const rawRemove = Storage.prototype.removeItem;
    const ls = window.localStorage;
    const read = (k, d) => { try { const v = ls.getItem(k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } };
    const localTs = () => parseInt(ls.getItem(TS_KEY) || '0', 10) || 0;

    // ---- short keys for questions (FNV-1a hash of the question text)
    const hash = (str) => {
        let h = 0x811c9dc5;
        for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193); }
        return (h >>> 0).toString(36);
    };
    let pools = null, textByHash = null;
    const poolFor = (key) => {
        if (!pools) {
            pools = {};
            textByHash = {};
            const add = (k, q) => {
                if (!q || !q.q) return;
                (pools[k] = pools[k] || {})[hash(q.q)] = q;
                textByHash[hash(q.q)] = q.q;
            };
            if (typeof quizData !== 'undefined') quizData.forEach(q => add(q.c, q));
            if (typeof pdfExamsData !== 'undefined') {
                Object.keys(pdfExamsData).forEach(s => (pdfExamsData[s] || []).forEach((exam, i) => exam.forEach(q => add(`${s}_pdf_${i}`, q))));
            }
        }
        return pools[key] || {};
    };

    // { course: [question objects] }  ->  { course: ["#hash" or full object] }
    const packDB = (db) => {
        const out = {};
        Object.keys(db || {}).forEach(k => {
            const pool = poolFor(k);
            out[k] = (db[k] || []).map(q => (q && q.q && pool[hash(q.q)]) ? '#' + hash(q.q) : q);
        });
        return out;
    };
    const unpackDB = (db) => {
        const out = {};
        Object.keys(db || {}).forEach(k => {
            const pool = poolFor(k);
            const m = k.match(/_pdf_(\d+)$/);
            out[k] = (db[k] || []).map(x => {
                if (typeof x !== 'string') return x;
                const q = pool[x.slice(1)];
                return q ? (m ? { ...q, c: k, u: +m[1] + 1 } : { ...q }) : null;
            }).filter(Boolean);
            if (!out[k].length) delete out[k];
        });
        return out;
    };
    const packCounts = (wc) => {
        poolFor('');
        const out = {};
        Object.keys(wc || {}).forEach(t => { const h = hash(t); out[textByHash[h] === t ? '#' + h : t] = wc[t]; });
        return out;
    };
    const unpackCounts = (wc) => {
        poolFor('');
        const out = {};
        Object.keys(wc || {}).forEach(k => { const t = k[0] === '#' ? textByHash[k.slice(1)] : k; if (t) out[t] = wc[k]; });
        return out;
    };

    const hasLocalData = () => {
        const s = read(PREFIX + 's', {});
        return Object.values(s || {}).some(c => c && c.t > 0);
    };

    const snapshot = () => ({
        stats: read(PREFIX + 's', {}),
        wrong: packDB(read(PREFIX + 'w', {})),
        correct: packDB(read(PREFIX + 'c', {})),
        marks: read(PREFIX + 'm', []),
        history: read(PREFIX + 'h', {}),
        dailyGoal: read(PREFIX + 'dg', null),
        settings: read(PREFIX + 'conf', null),
        wrongCounts: packCounts(read(PREFIX + 'wc', {})),
        ts: localTs()
    });

    // ---- merging two snapshots (both in the packed cloud form)
    const num = (x) => (typeof x === 'number' && isFinite(x)) ? x : 0;
    const weight = (o) => o && typeof o === 'object' ? num(o.t) * 1e7 + num(o.time) : 0;
    const dayWeight = (o) => o && typeof o === 'object' ? (num(o.correct) + num(o.wrong)) * 1e7 + num(o.time) : num(o);
    const pick = (a, b, w) => (a === undefined ? b : b === undefined ? a : (w(b) > w(a) ? b : a));
    const keysOf = (...objs) => [...new Set(objs.flatMap(o => Object.keys(o || {})))];
    const qKey = (x) => typeof x === 'string' ? x : (x && x.q) || JSON.stringify(x);

    const merge = (a, b) => {
        // stats: per course, keep the side that answered more (then: studied longer)
        const stats = {};
        keysOf(a.stats, b.stats).forEach(k => {
            const x = (a.stats || {})[k], y = (b.stats || {})[k];
            stats[k] = pick(x, y, weight);
        });
        // which side "owns" each course, so its answer lists stay consistent with its stats
        const winner = (k) => {
            const x = (a.stats || {})[k], y = (b.stats || {})[k];
            if (x === undefined && y === undefined) return null;
            return stats[k] === x ? a : b;
        };
        const lists = (field) => {
            const out = {};
            keysOf(a[field], b[field]).forEach(k => {
                const w = winner(k);
                const la = (a[field] || {})[k], lb = (b[field] || {})[k];
                if (w) { const v = (w[field] || {})[k]; if (v && v.length) out[k] = v; return; }
                const seen = new Set(), u = [];
                [...(la || []), ...(lb || [])].forEach(x => { const q = qKey(x); if (!seen.has(q)) { seen.add(q); u.push(x); } });
                if (u.length) out[k] = u;
            });
            return out;
        };
        // daily history: per day and per course the bigger entry, platform time = the longer one
        const history = {};
        keysOf(a.history, b.history).forEach(day => {
            const x = (a.history || {})[day] || {}, y = (b.history || {})[day] || {};
            const d = {};
            keysOf(x, y).forEach(c => { d[c] = pick(x[c], y[c], dayWeight); });
            history[day] = d;
        });
        const wrongCounts = {};
        keysOf(a.wrongCounts, b.wrongCounts).forEach(k => {
            wrongCounts[k] = Math.max(num((a.wrongCounts || {})[k]), num((b.wrongCounts || {})[k]));
        });
        const newer = a.ts >= b.ts ? a : b, older = newer === a ? b : a;
        // bookmarks: everything bookmarked on either side
        const marks = [], seenM = new Set();
        [...(newer.marks || []), ...(older.marks || [])].forEach(x => { const q = qKey(x); if (!seenM.has(q)) { seenM.add(q); marks.push(x); } });
        let dailyGoal = newer.dailyGoal || older.dailyGoal || null;
        if (a.dailyGoal && b.dailyGoal && a.dailyGoal.d === b.dailyGoal.d) dailyGoal = { ...newer.dailyGoal, c: Math.max(num(a.dailyGoal.c), num(b.dailyGoal.c)) };
        else if (a.dailyGoal && b.dailyGoal) dailyGoal = (a.dailyGoal.d || '') > (b.dailyGoal.d || '') ? a.dailyGoal : b.dailyGoal;
        return {
            stats, wrong: lists('wrong'), correct: lists('correct'), marks, history,
            dailyGoal, settings: newer.settings || older.settings || null, wrongCounts,
            ts: Math.max(num(a.ts), num(b.ts))
        };
    };
    const sameData = (a, b) => canon(a) === canon(b);
    const canon = (o) => {
        const sortDeep = (v) => Array.isArray(v) ? v.map(sortDeep) : (v && typeof v === 'object') ? Object.keys(v).sort().reduce((r, k) => { if (k !== 'ts' && v[k] !== undefined) r[k] = sortDeep(v[k]); return r; }, {}) : v;
        return JSON.stringify(sortDeep(o || {}));
    };

    let auth = null, db = null, user = null;
    let applying = false, dirty = false, saving = false, lastPull = 0, mode = null;
    let quickTimer = null, unlisten = null, status = { ok: null, at: 0, err: '' };
    const QUICK_DELAY = 8 * 1000;   // an answer goes out ~8 seconds later
    // answering touches these; the open-app clock only touches stats/history, which ride the slower interval
    const QUICK_KEYS = ['w', 'c', 'm', 'wc', 'dg', 'conf'].map(k => PREFIX + k);

    const FirebaseSync = {
        initialized: false,
        get user() { return user; },

        init: function () {
            if (this.initialized) return;
            this.initialized = true;
            this.updateUI();
            if (typeof firebase === 'undefined') { console.warn('Firebase SDK yüklənmədi'); return; }
            try {
                firebase.initializeApp(firebaseConfig);
                auth = firebase.auth();
                db = firebase.firestore();
                auth.getRedirectResult().catch(e => console.error('Redirect sign-in error:', e));
                auth.onAuthStateChanged(u => {
                    user = u;
                    this.updateUI();
                    if (unlisten) { unlisten(); unlisten = null; }
                    if (u) this.sync().then(() => this.listen());
                });
            } catch (e) {
                console.error('Firebase init error:', e);
            }

            setInterval(() => this.save(), SAVE_EVERY);
            document.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'hidden') this.save();
                else if (Date.now() - lastPull > PULL_EVERY) this.sync();
            });
            window.addEventListener('pagehide', () => this.save());
        },

        signIn: async function () {
            if (!auth) return alert('Giriş hazırda mümkün deyil. İnternet bağlantısını yoxlayın.');
            const provider = new firebase.auth.GoogleAuthProvider();
            provider.setCustomParameters({ prompt: 'select_account' });
            try {
                await auth.signInWithPopup(provider);
            } catch (e) {
                if (['auth/popup-blocked', 'auth/operation-not-supported-in-this-environment', 'auth/cancelled-popup-request'].includes(e.code)) {
                    return auth.signInWithRedirect(provider);
                }
                if (e.code === 'auth/popup-closed-by-user') return;
                if (e.code === 'auth/unauthorized-domain') return alert('Bu ünvan Firebase-də icazəli deyil. Firebase Console → Authentication → Settings → Authorized domains bölməsinə "' + location.hostname + '" əlavə edin.');
                console.error('Sign in error:', e);
                alert('Giriş alınmadı: ' + e.message);
            }
        },

        signOut: async function () {
            if (!auth) return;
            await this.save();
            if (unlisten) { unlisten(); unlisten = null; }
            await auth.signOut();
        },

        updateUI: function () {
            const el = document.getElementById('sbx-acc');
            if (!el) return;
            if (user) {
                const name = (user.displayName || user.email || '').replace(/</g, '&lt;');
                el.innerHTML = `
                    ${user.photoURL ? `<img class="sbx-acc-av" src="${user.photoURL}" alt="" referrerpolicy="no-referrer">` : `<span class="sbx-acc-av">${name.charAt(0)}</span>`}
                    <span class="sbx-acc-txt">
                        <span class="sbx-acc-name" title="${(user.email || '').replace(/"/g, '')}">${name}</span>
                        <button class="sbx-acc-st" id="sbx-acc-st" onclick="FirebaseSync.save(true)" title="İndi sinxronlaşdır">Sinxronlaşır…</button>
                    </span>
                    <button class="sbx-acc-out" onclick="FirebaseSync.signOut()">Çıxış</button>`;
                this.updateStatus();
            } else {
                el.innerHTML = `
                    <button class="sbx-acc-in" onclick="FirebaseSync.signIn()">
                        <svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>
                        <span>Google ilə daxil ol</span>
                    </button>`;
            }
        },

        // Where this semester is stored: its own document, or (if the rules only allow users/{uid}) one field of it
        ref: function () { return mode === 'field' ? db.collection('users').doc(user.uid) : db.collection('users').doc(user.uid).collection('sync').doc(SEMESTER); },

        readCloud: async function () {
            if (!mode) mode = ls.getItem('fb_sync_mode') || 'doc';
            try {
                const d = await this.ref().get();
                if (!d.exists) return null;
                return mode === 'field' ? (d.data()[SEMESTER] || null) : d.data();
            } catch (e) {
                if (e.code === 'permission-denied' && mode === 'doc') {
                    mode = 'field';
                    rawSet.call(ls, 'fb_sync_mode', 'field');
                    return this.readCloud();
                }
                throw e;
            }
        },

        writeCloud: async function (data) {
            if (mode === 'field') await this.ref().set({ [SEMESTER]: data }, { merge: true });
            else await this.ref().set(data);
        },

        // Bring this device and the cloud together. Nothing is ever replaced wholesale:
        // both sides are merged (per course the side with more answers wins), so a device
        // that was only left open can never wipe the progress made on another one.
        pull: function () { return this.sync(); },

        sync: async function () {
            if (!user || !db) return;
            if (saving) { dirty = true; return; }
            saving = true;
            lastPull = Date.now();
            dirty = false;
            try {
                const cloud = await this.readCloud();
                const local = snapshot();
                const merged = cloud ? merge(local, cloud) : local;
                rawSet.call(ls, SYNCED_KEY, user.uid);
                if (!sameData(merged, local)) this.apply(merged);
                if (!cloud || !sameData(merged, cloud)) {
                    if (cloud || hasLocalData()) await this.writeCloud(merged);
                }
                status = { ok: true, at: Date.now(), err: '' };
            } catch (e) {
                dirty = true;
                status = { ok: false, at: Date.now(), err: (e && (e.code || e.message)) || 'xəta' };
                console.error('Cloud sync error:', e);
            } finally {
                saving = false;
                this.updateStatus();
                if (dirty) this.scheduleQuick();
            }
        },

        scheduleQuick: function () {
            if (!user || quickTimer) return;
            quickTimer = setTimeout(() => { quickTimer = null; this.save(); }, QUICK_DELAY);
        },

        // Live updates: when another device writes, merge it in right away
        listen: function () {
            if (!user || !db || unlisten || !mode) return;
            try {
                unlisten = this.ref().onSnapshot(d => {
                    if (d.metadata.hasPendingWrites || applying || saving) return;
                    const cloud = !d.exists ? null : (mode === 'field' ? (d.data()[SEMESTER] || null) : d.data());
                    if (!cloud) return;
                    const local = snapshot();
                    const merged = merge(local, cloud);
                    if (!sameData(merged, local)) this.apply(merged);
                    if (!sameData(merged, cloud)) { dirty = true; this.scheduleQuick(); }
                    status = { ok: true, at: Date.now(), err: '' };
                    this.updateStatus();
                }, e => {
                    console.error('Cloud listen error:', e);
                    status = { ok: false, at: Date.now(), err: e.code || e.message };
                    this.updateStatus();
                    unlisten = null;
                });
            } catch (e) { console.error('Cloud listen error:', e); }
        },

        updateStatus: function () {
            const el = document.getElementById('sbx-acc-st');
            if (!el) return;
            if (status.ok === null) { el.textContent = 'Sinxronlaşır…'; el.className = 'sbx-acc-st'; return; }
            const t = new Date(status.at), hm = String(t.getHours()).padStart(2, '0') + ':' + String(t.getMinutes()).padStart(2, '0');
            el.textContent = status.ok ? 'Sinxron ✓ ' + hm : 'Xəta: ' + status.err + ' (' + hm + ')';
            el.className = 'sbx-acc-st' + (status.ok ? '' : ' err');
        },

        apply: function (cloud) {
            applying = true;
            try {
                const put = (k, v) => { if (v === null || v === undefined) rawRemove.call(ls, k); else rawSet.call(ls, k, JSON.stringify(v)); };
                put(PREFIX + 's', cloud.stats || {});
                put(PREFIX + 'w', unpackDB(cloud.wrong));
                put(PREFIX + 'c', unpackDB(cloud.correct));
                put(PREFIX + 'm', cloud.marks || []);
                put(PREFIX + 'h', cloud.history || {});
                if (cloud.dailyGoal) put(PREFIX + 'dg', cloud.dailyGoal);
                if (cloud.settings) put(PREFIX + 'conf', cloud.settings);
                put(PREFIX + 'wc', unpackCounts(cloud.wrongCounts));
                rawSet.call(ls, TS_KEY, String(cloud.ts || Date.now()));
            } finally {
                applying = false;
            }
            this.refreshApp();
        },

        // Redraw what is on screen with the new data (never interrupts a running quiz)
        refreshApp: function () {
            if (typeof QuizApp === 'undefined') return;
            QuizApp.loadData();
            if (typeof LifeOS !== 'undefined' && LifeOS.updateNavProgress) LifeOS.updateNavProgress();
            const st = QuizApp.state || {};
            if (st.view === 'home') QuizApp.start();
            else if (st.view === 'dashboard' && st.course) QuizApp.showCourseDashboard(st.course);
            else if (st.view === 'stats') QuizApp.showStats();
            else if (st.view === 'wrong') QuizApp.showWrong();
            else if (st.view === 'pdf-exams-dashboard') QuizApp.showPdfExamsDashboard();
            else if (st.view === 'pdf-exams-list') QuizApp.showPdfExamsList(st.pdfExamSubject);
        },

        save: function (force) {
            if (!user || !db || (!dirty && !force)) return Promise.resolve();
            return this.sync();
        },

        // Old callers: a change was made, it will go out with the next scheduled write
        triggerAutoSave: function () { dirty = true; this.scheduleQuick(); },
        saveToCloud: function () { dirty = true; return this.save(true); },
        loadFromCloud: function () { return this.sync(); },

        // "Sıfırla": remove only this semester from the cloud
        deleteCloud: async function () {
            if (!user || !db) return;
            if (!mode) await this.readCloud().catch(() => {});
            if (mode === 'field') await this.ref().update({ [SEMESTER]: firebase.firestore.FieldValue.delete() });
            else await this.ref().delete();
            dirty = false;
        }
    };

    // Every change to this semester's data marks it for the next write
    Storage.prototype.setItem = function (key, value) {
        rawSet.call(this, key, value);
        if (this === ls && !applying && typeof key === 'string' && key.startsWith(PREFIX) && key !== TS_KEY && key !== SYNCED_KEY) {
            rawSet.call(this, TS_KEY, Date.now().toString());
            dirty = true;
            if (QUICK_KEYS.includes(key)) FirebaseSync.scheduleQuick();
        }
    };

    FirebaseSync._codec = { packDB, unpackDB, packCounts, unpackCounts, snapshot, merge, sameData };
    window.FirebaseSync = FirebaseSync;
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => FirebaseSync.init());
    else FirebaseSync.init();
})();
