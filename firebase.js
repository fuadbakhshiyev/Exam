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

    loadFromCloud: async function() {
        if (!currentUser) return;
        
        try {
            const doc = await db.collection('users').doc(currentUser.uid).get();
            
            if (doc.exists) {
                const data = doc.data();
                
                const cloudLocalUpdatedAt = data.localUpdatedAt || 0;
                const localUpdatedAt = parseInt(localStorage.getItem('qa_v31_localUpdatedAt') || '0');
                
                // Helper to check if local has actual statistics data
                const hasLocalData = () => {
                    const stats = localStorage.getItem(QuizApp.DB.stats);
                    if (!stats || stats === '{}') return false;
                    try {
                        const parsed = JSON.parse(stats);
                        // If there is any course with total answers > 0
                        return Object.values(parsed).some(c => c && c.t > 0);
                    } catch (e) {
                        return false;
                    }
                };

                // Safety check: if cloud stats are empty/missing, but local has stats, upload local instead of overwriting
                const isCloudEmpty = !data.stats || Object.keys(data.stats).length === 0 || !Object.values(data.stats).some(c => c && c.t > 0);
                if (isCloudEmpty && hasLocalData()) {
                    console.log("Cloud stats are empty, but local has stats. Uploading local data to protect user progress...");
                    this.saveToCloud(true);
                    return;
                }

                // If local data is newer than cloud data, or both are 0 but local has data, upload local data.
                if (localUpdatedAt > cloudLocalUpdatedAt || (localUpdatedAt === 0 && cloudLocalUpdatedAt === 0 && hasLocalData())) {
                    console.log("Local data is newer or has initial data, uploading local data...");
                    this.saveToCloud(true);
                    return;
                }
                
                this.isLoadingFromCloud = true;
                
                // Merge with local data (cloud wins for newer data)
                if (data.stats) localStorage.setItem(QuizApp.DB.stats, JSON.stringify(data.stats));
                if (data.wrong) localStorage.setItem(QuizApp.DB.wrong, JSON.stringify(data.wrong));
                if (data.correct) localStorage.setItem(QuizApp.DB.correct, JSON.stringify(data.correct));
                if (data.bookmarks) localStorage.setItem(QuizApp.DB.marks, JSON.stringify(data.bookmarks));
                
                // Safely merge daily history instead of raw overwrite to prevent key mismatches/missing days
                const localDaily = JSON.parse(localStorage.getItem(QuizApp.DB.daily)) || {};
                const cloudDaily = data.daily || {};
                const mergedDaily = { ...localDaily };
                Object.keys(cloudDaily).forEach(date => {
                    if (!mergedDaily[date]) {
                        mergedDaily[date] = cloudDaily[date];
                    } else {
                        Object.keys(cloudDaily[date]).forEach(course => {
                            if (!mergedDaily[date][course]) {
                                mergedDaily[date][course] = cloudDaily[date][course];
                            } else {
                                const localAttempts = (mergedDaily[date][course].correct || 0) + (mergedDaily[date][course].wrong || 0);
                                const cloudAttempts = (cloudDaily[date][course].correct || 0) + (cloudDaily[date][course].wrong || 0);
                                if (cloudAttempts > localAttempts) {
                                    mergedDaily[date][course] = cloudDaily[date][course];
                                }
                            }
                        });
                    }
                });
                localStorage.setItem(QuizApp.DB.daily, JSON.stringify(mergedDaily));

                if (data.settings) localStorage.setItem(QuizApp.DB.settings, JSON.stringify(data.settings));
                if (data.wrongCounts) localStorage.setItem(QuizApp.DB.wrongCounts, JSON.stringify(data.wrongCounts));
                if (data.localUpdatedAt) localStorage.setItem('qa_v31_localUpdatedAt', data.localUpdatedAt.toString());
                
                this.isLoadingFromCloud = false;
                
                // Reload QuizApp data
                QuizApp.loadData();
                
                console.log("Data loaded from cloud");
                this.showSyncIndicator('loaded');
            } else {
                // If doc doesn't exist in cloud, upload our current local data
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
