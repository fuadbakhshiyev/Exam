// Firebase Sync Simulator (Firebase is completely disabled)
console.log("Firebase sync is completely disabled. Everything is saved to localStorage / GitHub.");

window.FirebaseSync = {
    initialized: false,
    init: async function() {
        console.log("FirebaseSync.init: Disabled");
    },
    signIn: async function() {
        console.log("FirebaseSync.signIn: Disabled");
    },
    signOut: async function() {
        console.log("FirebaseSync.signOut: Disabled");
    },
    updateUI: function() {
        console.log("FirebaseSync.updateUI: Disabled");
    },
    saveToCloud: async function(isSilent = false) {
        console.log("FirebaseSync.saveToCloud: Disabled");
        return Promise.resolve();
    },
    loadFromCloud: async function() {
        console.log("FirebaseSync.loadFromCloud: Disabled");
        return Promise.resolve();
    },
    triggerAutoSave: function() {
        // No-op, do not sync
    }
};
