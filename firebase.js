// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyA_FAHBa-uX6lJXRsFlJ04GCcPe_HVLYkY",
    authDomain: "exam-6ea6d.firebaseapp.com",
    projectId: "exam-6ea6d",
    storageBucket: "exam-6ea6d.firebasestorage.app",
    messagingSenderId: "971462035893",
    appId: "1:971462035893:web:e5f0f14c147ed518ce31fc",
    measurementId: "G-WKSVB1CC1D"
};

// Firebase Auth & Firestore
let auth, db, currentUser = null;

const FirebaseSync = {
    initialized: false,

    init: async function() {
        if (this.initialized) return;
        
        try {
            // Initialize Firebase
            firebase.initializeApp(firebaseConfig);
            auth = firebase.auth();
            db = firebase.firestore();
            
            // Listen for auth state changes
            auth.onAuthStateChanged((user) => {
                currentUser = user;
                this.updateUI();
                if (user) {
                    this.loadFromCloud();
                }
            });
            
            this.initialized = true;
            console.log("Firebase initialized");
        } catch (error) {
            console.error("Firebase init error:", error);
        }
    },

    // Google Sign In
    signIn: async function() {
        try {
            const provider = new firebase.auth.GoogleAuthProvider();
            await auth.signInWithPopup(provider);
        } catch (error) {
            console.error("Sign in error:", error);
            alert("Giriş xətası: " + error.message);
        }
    },

    // Sign Out
    signOut: async function() {
        try {
            await auth.signOut();
            currentUser = null;
            this.updateUI();
        } catch (error) {
            console.error("Sign out error:", error);
        }
    },

    // Update UI based on auth state
    updateUI: function() {
        const loginBtn = document.getElementById('login-btn');
        const userInfo = document.getElementById('user-info');
        const syncStatus = document.getElementById('sync-status');
        
        if (currentUser) {
            if (loginBtn) loginBtn.style.display = 'none';
            if (userInfo) {
                userInfo.style.display = 'flex';
                userInfo.innerHTML = `
                    <div class="user-info-left">
                        <img src="${currentUser.photoURL || ''}" alt="" class="user-avatar">
                        <span class="user-name">${currentUser.displayName || currentUser.email}</span>
                    </div>
                    <button onclick="FirebaseSync.signOut()" class="logout-btn">Çıxış</button>
                `;
            }
            if (syncStatus) {
                syncStatus.className = 'sync-status-badge synced';
                syncStatus.innerHTML = '<span class="dot"></span><span>Sinxron</span>';
            }
        } else {
            if (loginBtn) loginBtn.style.display = 'flex';
            if (userInfo) userInfo.style.display = 'none';
            if (syncStatus) {
                syncStatus.className = 'sync-status-badge local';
                syncStatus.innerHTML = '<span class="dot"></span><span>Lokal</span>';
            }
        }
    },

    // Save to Cloud
    saveToCloud: async function(isSilent = false) {
        if (!currentUser) return;
        
        try {
            const data = {
                stats: JSON.parse(localStorage.getItem(QuizApp.DB.stats)) || {},
                wrong: JSON.parse(localStorage.getItem(QuizApp.DB.wrong)) || {},
                correct: JSON.parse(localStorage.getItem(QuizApp.DB.correct)) || {},
                bookmarks: JSON.parse(localStorage.getItem(QuizApp.DB.marks)) || [],
                daily: JSON.parse(localStorage.getItem(QuizApp.DB.daily)) || {},
                dailyGoal: JSON.parse(localStorage.getItem(QuizApp.DB.dailyGoal)) || { d: '', c: 0 },
                settings: JSON.parse(localStorage.getItem(QuizApp.DB.settings)) || {},
                wrongCounts: JSON.parse(localStorage.getItem(QuizApp.DB.wrongCounts)) || {},
                localUpdatedAt: parseInt(localStorage.getItem('qa_v31_localUpdatedAt') || '0'),
                updatedAt: firebase.firestore.FieldValue.serverTimestamp()
            };
            
            await db.collection('users').doc(currentUser.uid).set(data, { merge: true });
            console.log("Data saved to cloud");
            
            // Show sync indicator if not silent
            if (!isSilent) {
                this.showSyncIndicator('saved');
            }
        } catch (error) {
            console.error("Save to cloud error:", error);
        }
    },

    // Load from Cloud
    isLoadingFromCloud: false,

    mergeStats: function(local, cloud) {
        const merged = { ...local };
        Object.keys(cloud).forEach(course => {
            if (!merged[course]) {
                merged[course] = cloud[course];
            } else {
                merged[course] = {
                    t: Math.max(merged[course].t || 0, cloud[course].t || 0),
                    c: Math.max(merged[course].c || 0, cloud[course].c || 0),
                    w: Math.max(merged[course].w || 0, cloud[course].w || 0),
                    time: Math.max(merged[course].time || 0, cloud[course].time || 0),
                    bd: merged[course].bd || {}
                };
                
                if (cloud[course].bd) {
                    Object.keys(cloud[course].bd).forEach(cat => {
                        if (!merged[course].bd[cat]) {
                            merged[course].bd[cat] = cloud[course].bd[cat];
                        } else {
                            Object.keys(cloud[course].bd[cat]).forEach(sub => {
                                if (!merged[course].bd[cat][sub]) {
                                    merged[course].bd[cat][sub] = cloud[course].bd[cat][sub];
                                } else {
                                    const localSub = merged[course].bd[cat][sub];
                                    const cloudSub = cloud[course].bd[cat][sub];
                                    merged[course].bd[cat][sub] = {
                                        t: Math.max(localSub.t || 0, cloudSub.t || 0),
                                        c: Math.max(localSub.c || 0, cloudSub.c || 0),
                                        w: Math.max(localSub.w || 0, cloudSub.w || 0),
                                        last: Math.max(localSub.last || 0, cloudSub.last || 0)
                                    };
                                }
                            });
                        }
                    });
                }
            }
        });
        return merged;
    },

    mergeQuestionsDB: function(local, cloud) {
        const merged = { ...local };
        Object.keys(cloud).forEach(course => {
            if (!merged[course]) {
                merged[course] = cloud[course];
            } else {
                const localQs = merged[course] || [];
                const cloudQs = cloud[course] || [];
                const uniqueQs = [...localQs];
                cloudQs.forEach(cq => {
                    if (!uniqueQs.some(lq => lq.q === cq.q)) {
                        uniqueQs.push(cq);
                    }
                });
                merged[course] = uniqueQs;
            }
        });
        return merged;
    },

    mergeBookmarks: function(local, cloud) {
        const merged = [...(local || [])];
        (cloud || []).forEach(cq => {
            if (!merged.some(lq => lq.q === cq.q)) {
                merged.push(cq);
            }
        });
        return merged;
    },

    mergeWrongCounts: function(local, cloud) {
        const merged = { ...local };
        Object.keys(cloud || {}).forEach(qText => {
            merged[qText] = Math.max(merged[qText] || 0, cloud[qText] || 0);
        });
        return merged;
    },

    loadFromCloud: async function() {
        if (!currentUser) return;
        
        try {
            const doc = await db.collection('users').doc(currentUser.uid).get();
            
            if (doc.exists) {
                const data = doc.data();
                
                const cloudLocalUpdatedAt = data.localUpdatedAt || 0;
                const localUpdatedAt = parseInt(localStorage.getItem('qa_v31_localUpdatedAt') || '0');
                
                const hasLocalData = () => {
                    const stats = localStorage.getItem(QuizApp.DB.stats);
                    if (!stats || stats === '{}') return false;
                    try {
                        const parsed = JSON.parse(stats);
                        return Object.values(parsed).some(c => c && c.t > 0);
                    } catch (e) {
                        return false;
                    }
                };

                const isCloudEmpty = !data.stats || Object.keys(data.stats).length === 0 || !Object.values(data.stats).some(c => c && c.t > 0);
                if (isCloudEmpty && hasLocalData()) {
                    console.log("Cloud stats are empty, but local has stats. Uploading local data...");
                    this.saveToCloud(true);
                    return;
                }
                
                this.isLoadingFromCloud = true;
                
                // Retrieve local data
                const localStats = JSON.parse(localStorage.getItem(QuizApp.DB.stats)) || {};
                const localWrong = JSON.parse(localStorage.getItem(QuizApp.DB.wrong)) || {};
                const localCorrect = JSON.parse(localStorage.getItem(QuizApp.DB.correct)) || {};
                const localBookmarks = JSON.parse(localStorage.getItem(QuizApp.DB.marks)) || [];
                const localWrongCounts = JSON.parse(localStorage.getItem(QuizApp.DB.wrongCounts)) || {};
                
                // Merge data
                const mergedStats = this.mergeStats(localStats, data.stats || {});
                const mergedWrong = this.mergeQuestionsDB(localWrong, data.wrong || {});
                const mergedCorrect = this.mergeQuestionsDB(localCorrect, data.correct || {});
                const mergedBookmarks = this.mergeBookmarks(localBookmarks, data.bookmarks || []);
                const mergedWrongCounts = this.mergeWrongCounts(localWrongCounts, data.wrongCounts || {});
                
                // Merge daily history (safely with platformTime)
                const localDaily = JSON.parse(localStorage.getItem(QuizApp.DB.daily)) || {};
                const cloudDaily = data.daily || {};
                const mergedDaily = { ...localDaily };
                Object.keys(cloudDaily).forEach(date => {
                    if (!mergedDaily[date]) {
                        mergedDaily[date] = cloudDaily[date];
                    } else {
                        // Merge platformTime
                        mergedDaily[date].platformTime = Math.max(mergedDaily[date].platformTime || 0, cloudDaily[date].platformTime || 0);
                        
                        Object.keys(cloudDaily[date]).forEach(course => {
                            if (course === 'platformTime') return;
                            if (!mergedDaily[date][course]) {
                                mergedDaily[date][course] = cloudDaily[date][course];
                            } else {
                                const localVal = mergedDaily[date][course];
                                const cloudVal = cloudDaily[date][course];
                                mergedDaily[date][course] = {
                                    time: Math.max(localVal.time || 0, cloudVal.time || 0),
                                    correct: Math.max(localVal.correct || 0, cloudVal.correct || 0),
                                    wrong: Math.max(localVal.wrong || 0, cloudVal.wrong || 0)
                                };
                            }
                        });
                    }
                });
                
                // Merge daily goal
                const localDG = JSON.parse(localStorage.getItem(QuizApp.DB.dailyGoal)) || { d: '', c: 0 };
                const cloudDG = data.dailyGoal || { d: '', c: 0 };
                const todayStr = new Date().toDateString();
                let mergedDG = { d: todayStr, c: 0 };
                
                const localCount = localDG.d === todayStr ? localDG.c : 0;
                const cloudCount = cloudDG.d === todayStr ? cloudDG.c : 0;
                mergedDG.c = Math.max(localCount, cloudCount);

                // Merge settings (cloud wins if newer, otherwise keep local)
                const mergedSettings = cloudLocalUpdatedAt > localUpdatedAt ? (data.settings || {}) : (JSON.parse(localStorage.getItem(QuizApp.DB.settings)) || {});

                // Save merged data back to localStorage
                localStorage.setItem(QuizApp.DB.stats, JSON.stringify(mergedStats));
                localStorage.setItem(QuizApp.DB.wrong, JSON.stringify(mergedWrong));
                localStorage.setItem(QuizApp.DB.correct, JSON.stringify(mergedCorrect));
                localStorage.setItem(QuizApp.DB.marks, JSON.stringify(mergedBookmarks));
                localStorage.setItem(QuizApp.DB.daily, JSON.stringify(mergedDaily));
                localStorage.setItem(QuizApp.DB.dailyGoal, JSON.stringify(mergedDG));
                localStorage.setItem(QuizApp.DB.settings, JSON.stringify(mergedSettings));
                localStorage.setItem(QuizApp.DB.wrongCounts, JSON.stringify(mergedWrongCounts));
                
                const newestTimestamp = Math.max(localUpdatedAt, cloudLocalUpdatedAt, Date.now());
                localStorage.setItem('qa_v31_localUpdatedAt', newestTimestamp.toString());
                
                this.isLoadingFromCloud = false;
                
                // Reload QuizApp data
                QuizApp.loadData();
                
                // If local was newer or cloud empty, or we merged new things, sync back to cloud
                if (localUpdatedAt > cloudLocalUpdatedAt || isCloudEmpty) {
                    console.log("Syncing merged state back to cloud...");
                    this.saveToCloud(true);
                }
                
                console.log("Data merged and loaded from cloud");
                this.showSyncIndicator('loaded');
            } else {
                console.log("No cloud data found, uploading local data...");
                this.saveToCloud(true);
            }
        } catch (error) {
            this.isLoadingFromCloud = false;
            console.error("Load from cloud error:", error);
        }
    },

    // Show sync indicator
    showSyncIndicator: function(type) {
        // Disabled to prevent user distraction as requested
        console.log("Sync indicator:", type);
    },

    // Auto-save on changes (debounced)
    autoSaveTimeout: null,
    triggerAutoSave: function() {
        if (!currentUser) return;
        
        clearTimeout(this.autoSaveTimeout);
        this.autoSaveTimeout = setTimeout(() => {
            this.saveToCloud(true);
        }, 3000); // 3 saniyə sonra saxla
    }
};

// Override localStorage.setItem to trigger auto-save
const originalSetItem = localStorage.setItem.bind(localStorage);
localStorage.setItem = function(key, value) {
    originalSetItem(key, value);
    
    // Auto-save when quiz data changes
    if (key.startsWith('qa_v31_') && key !== 'qa_v31_localUpdatedAt' && (!window.FirebaseSync || !window.FirebaseSync.isLoadingFromCloud)) {
        originalSetItem('qa_v31_localUpdatedAt', Date.now().toString());
        if (window.FirebaseSync && window.FirebaseSync.triggerAutoSave) {
            window.FirebaseSync.triggerAutoSave();
        }
    }
};

// Initialize Firebase when DOM ready
document.addEventListener('DOMContentLoaded', () => {
    FirebaseSync.init();
});
