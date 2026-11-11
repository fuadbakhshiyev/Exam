import Foundation

// Quiz timer (startTimer / stopTimer / pauseTimer / resumeTimer), platform timer
// (startPlatformTimer / pausePlatformTimer), 180 s idle detection and the visibilitychange handler.

extension StudyStore {
    static let idleLimitMs: Int64 = 180_000

    /// Time is stored only for CONFIG courses, the mock key, "_pdf_" exam keys and "_final_" booklet keys.
    static func isStatTracked(_ c: String) -> Bool {
        Catalog.configKeys.contains(c) || c == Catalog.mockKey || c.contains("_pdf_") || QuestionBank.isFinalKey(c)
    }

    /// "mm:ss" of the running quiz timer.
    var quizTimerText: String {
        let s = quizElapsedSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    var isQuizTimerRunning: Bool { quizTickTask != nil }

    // MARK: Quiz timer

    func startQuizTimer(course c: String) {
        stopQuizTimer()
        activeCourse = c
        quizSecondsAccumulated = 0
        quizElapsedSeconds = 0
        resumeQuizTimer()
    }

    func stopQuizTimer() {
        pauseQuizTimer()
        activeCourse = nil
        quizSecondsAccumulated = 0
    }

    func pauseQuizTimer() {
        guard let task = quizTickTask else { return }
        task.cancel()
        quizTickTask = nil
        guard let c = activeCourse else { return }
        let total = Int((Self.nowMs() - quizSessionStart) / 1000)
        var delta = total - quizSecondsInSession
        if delta > 0 {
            if delta > 5 { delta = 1 }
            if Self.isStatTracked(c) { recordCourseTime(c, delta: delta) }
            quizSecondsInSession += delta
        }
        quizSecondsAccumulated += quizSecondsInSession
        quizSecondsInSession = 0
        quizElapsedSeconds = quizSecondsAccumulated
    }

    func resumeQuizTimer() {
        guard let c = activeCourse, quizTickTask == nil else { return }
        quizSessionStart = Self.nowMs()
        quizSecondsInSession = 0
        let tracked = Self.isStatTracked(c)
        if tracked && data.stats[c] == nil { data.stats[c] = CourseStat() }
        quizTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.quizTick(course: c, tracked: tracked)
            }
        }
    }

    private func quizTick(course c: String, tracked: Bool) {
        guard activeCourse != nil else { return }
        let now = Self.nowMs()
        if now - lastActivityTime > Self.idleLimitMs {
            isIdle = true
            pauseQuizTimer()
            pausePlatformTimer()
            return
        }
        let total = Int((now - quizSessionStart) / 1000)
        var delta = total - quizSecondsInSession
        if delta > 0 {
            if delta > 5 {
                delta = 1
                quizSessionStart = now - Int64(quizSecondsInSession + 1) * 1000
            }
            if tracked { recordCourseTime(c, delta: delta) }
            quizSecondsInSession += delta
        }
        quizElapsedSeconds = quizSecondsAccumulated + quizSecondsInSession
    }

    // MARK: Platform timer

    var isPlatformTimerRunning: Bool { platformTickTask != nil }

    func startPlatformTimer() {
        guard platformTickTask == nil else { return }
        platformSessionStart = Self.nowMs()
        platformSecondsInSession = 0
        platformTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.platformTick()
            }
        }
    }

    func pausePlatformTimer() {
        guard let task = platformTickTask else { return }
        task.cancel()
        platformTickTask = nil
        let total = Int((Self.nowMs() - platformSessionStart) / 1000)
        var delta = total - platformSecondsInSession
        if delta > 0 {
            if delta > 5 { delta = 1 }
            recordPlatformTime(delta)
        }
    }

    private func platformTick() {
        let now = Self.nowMs()
        if now - lastActivityTime > Self.idleLimitMs {
            isIdle = true
            pauseQuizTimer()
            pausePlatformTimer()
            return
        }
        let total = Int((now - platformSessionStart) / 1000)
        var delta = total - platformSecondsInSession
        if delta > 0 {
            if delta > 5 {
                delta = 1
                platformSessionStart = now - Int64(platformSecondsInSession + 1) * 1000
            }
            recordPlatformTime(delta)
            platformSecondsInSession += delta
        }
    }

    // MARK: Activity / lifecycle

    /// Call on every tap / key press (window click/keydown/touchstart in the web app).
    func noteActivity() {
        lastActivityTime = Self.nowMs()
        if isIdle {
            isIdle = false
            startPlatformTimer()
            if activeCourse != nil && quizTickTask == nil && !isSurpriseActive { resumeQuizTimer() }
        }
    }

    /// scenePhase handler (document visibilitychange): pauses the quiz timer, the platform timer and the
    /// surprise countdown in the background and resumes them when the app is active again.
    func handleScenePhase(active: Bool) {
        if active {
            // Coming back to the app counts as activity (the web waits for the next click).
            lastActivityTime = Self.nowMs()
            isIdle = false
            startPlatformTimer()
            if activeCourse != nil && quizTickTask == nil && !isSurpriseActive { resumeQuizTimer() }
            surpriseEngine?.sceneDidBecomeActive()
        } else {
            if quizTickTask != nil && activeCourse != nil { pauseQuizTimer() }
            pausePlatformTimer()
            surpriseEngine?.sceneWillResignActive()
            flush()
        }
    }
}
