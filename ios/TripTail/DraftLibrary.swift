import Foundation
import Observation

struct TravelDraft: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var updated = Date()
    var html: String {
        let escape: (String) -> String = { $0.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;") }
        return "<!doctype html><html lang=\"ko\"><meta charset=\"utf-8\"><title>\(escape(title))</title><body><h2>\(escape(title))</h2>" + text.components(separatedBy: "\n").filter { !$0.isEmpty }.map { "<p>\(escape($0))</p>" }.joined() + "</body></html>"
    }
}

@MainActor @Observable
final class DraftLibrary {
    var drafts: [TravelDraft] = []
    var error: String?
    private let file: URL
    init() {
        file = URL.documentsDirectory.appendingPathComponent("travel-drafts.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                drafts = try JSONDecoder().decode([TravelDraft].self, from: Data(contentsOf: file))
            }
        } catch { self.error = "보관함을 읽지 못했습니다. 원본 파일은 유지됩니다." }
    }
    @discardableResult func save(_ draft: TravelDraft) -> Bool {
        var next = drafts
        if let index = next.firstIndex(where: { $0.id == draft.id }) { next[index] = draft }
        else { next.insert(draft, at: 0) }
        return persist(next)
    }
    func delete(_ ids: Set<UUID>) { _ = persist(drafts.filter { !ids.contains($0.id) }) }
    private func persist(_ next: [TravelDraft]) -> Bool {
        do {
            try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtection])
            drafts = next
            return true
        } catch { self.error = "저장 공간을 확인해주세요. 글을 공유해 따로 보관할 수 있습니다."; return false }
    }
}
