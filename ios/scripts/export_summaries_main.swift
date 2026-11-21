// Dumps SubjectSummaries (ios/Imtahan/Store/SubjectSummaries*.swift) as JSON for the website.
// Run via ios/scripts/export_summaries.sh.
import Foundation

func block(_ b: SubjectSummary.Block) -> [String: Any] {
    var d: [String: Any] = ["points": b.points]
    if let h = b.heading { d["heading"] = h }
    return d
}

var out: [String: Any] = [:]
for (subject, s) in SubjectSummaries.all {
    var d: [String: Any] = ["quick": s.quick]
    if let i = s.intro { d["intro"] = block(i) }
    d["units"] = s.units.map { u in
        ["number": u.number, "title": u.title, "blocks": u.blocks.map(block), "traps": u.traps] as [String: Any]
    }
    out[subject] = d
}
let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
