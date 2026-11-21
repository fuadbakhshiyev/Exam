import SwiftUI

/// "Fənləri seç": a menu with a checkmark on each subject still being studied. Unticking a subject marks
/// it as passed ("Verdim"): it leaves the plan, Davam et, sınaq, səhvlər, təkrar and Ana səhifə; its data stays.
struct PassedSubjectsMenu<Label: View>: View {
    @Environment(StudyStore.self) private var store
    @ViewBuilder var label: () -> Label

    var body: some View {
        Menu {
            Section("Hazırlaşdığım fənlər") {
                ForEach(Catalog.subjects, id: \.self) { s in
                    let studying = !store.passedSubjects.contains(s)
                    Toggle(isOn: Binding(get: { studying }, set: { on in
                        withAnimation(.snappy) {
                            if on { store.passedSubjects.remove(s) } else { store.passedSubjects.insert(s) }
                        }
                    })) {
                        Text(s)
                        if !studying { Text("Verilib") }
                    }
                    // At least one subject stays.
                    .disabled(studying && store.activeSubjects.count == 1 && store.activeSubjects.first == s)
                }
            }
            if !store.passedSubjects.isEmpty {
                Button("Hamısını qaytar", systemImage: "arrow.uturn.backward") {
                    withAnimation(.snappy) { store.passedSubjects = [] }
                }
            }
        } label: { label() }
        .menuActionDismissBehavior(.disabled)
    }
}
