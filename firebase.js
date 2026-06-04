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
    loadFromCloud: async function() {
        if (!currentUser) return;
        
        try {
            const doc = await db.collection('users').doc(currentUser.uid).get();
            
            if (doc.exists) {
                const data = doc.data();
                
                // Merge with local data (cloud wins for newer data)
                if (data.stats) localStorage.setItem(QuizApp.DB.stats, JSON.stringify(data.stats));
                if (data.wrong) localStorage.setItem(QuizApp.DB.wrong, JSON.stringify(data.wrong));
                if (data.correct) localStorage.setItem(QuizApp.DB.correct, JSON.stringify(data.correct));
                if (data.bookmarks) localStorage.setItem(QuizApp.DB.marks, JSON.stringify(data.bookmarks));
                if (data.daily) localStorage.setItem(QuizApp.DB.daily, JSON.stringify(data.daily));
                if (data.settings) localStorage.setItem(QuizApp.DB.settings, JSON.stringify(data.settings));
                
                // Reload QuizApp data
                QuizApp.loadData();
                
                console.log("Data loaded from cloud");
                this.showSyncIndicator('loaded');
            }
        } catch (error) {
            console.error("Load from cloud error:", error);
        }
    },

    // Show sync indicator
    showSyncIndicator: function(type) {
        const indicator = document.createElement('div');
        indicator.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: var(--bg-element);
            border: 1px solid var(--border);
            padding: 10px 16px;
            border-radius: 8px;
            font-size: 0.85rem;
            z-index: 9999;
            animation: fadeIn 0.3s ease;
        `;
        indicator.textContent = type === 'saved' ? '☁️ Yadda saxlanıldı' : '☁️ Yükləndi';
        document.body.appendChild(indicator);
        
        setTimeout(() => indicator.remove(), 2000);
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
    if (key.startsWith('qa_v31_')) {
        FirebaseSync.triggerAutoSave();
    }
};

// Initialize Firebase when DOM ready
document.addEventListener('DOMContentLoaded', () => {
    FirebaseSync.init();
});
