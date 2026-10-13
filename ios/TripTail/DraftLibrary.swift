import Foundation
import Observation

struct TravelDraft: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var updated = Date()
    var htmlBody: String?
    var html: String {
        BlogHTML.document(title: title, body: htmlBody ?? text.components(separatedBy: "\n").filter { !$0.isEmpty }.map { "<p>\(BlogHTML.escape($0))</p>" }.joined())
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

enum BlogHTML {
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }
    static func sanitize(_ raw: String) -> String {
        let allowed: Set<String> = ["h2", "h3", "p", "ul", "ol", "li", "strong", "em", "blockquote", "br"]
        guard let regex = try? NSRegularExpression(pattern: "<[^>]*>") else { return escape(raw) }
        let ns = raw as NSString
        var output = "", cursor = 0
        for match in regex.matches(in: raw, range: NSRange(location: 0, length: ns.length)) {
            output += escape(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let tag = ns.substring(with: match.range)
            let name = tag.trimmingCharacters(in: CharacterSet(charactersIn: "</> ")).components(separatedBy: .whitespacesAndNewlines).first?.lowercased() ?? ""
            if allowed.contains(name) { output += "<" + (tag.hasPrefix("</") ? "/" : "") + name + ">" }
            cursor = NSMaxRange(match.range)
        }
        return output + escape(ns.substring(from: cursor))
    }
    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "</p>|</h[23]>|</li>|<br>|</blockquote>", with: "\n\n", options: .regularExpression).replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression).replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&amp;", with: "&")
    }
    static func document(title: String, body: String) -> String {
        """
        <!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:"><title>\(escape(title))</title><style>
        body{margin:0;background:#f6f7f1;color:#232a25;font:17px/1.9 -apple-system,sans-serif}article{max-width:760px;margin:auto;padding:32px 24px 64px;background:#fff}header{padding:28px 0;border-bottom:1px solid #dde4d8;margin-bottom:32px}small{color:#6b8754;letter-spacing:3px;font-weight:700}h1{font-size:32px;line-height:1.4;color:#315c49}h2{font-size:25px;margin-top:44px}h3{font-size:21px;margin-top:32px;color:#315c49}p{margin:18px 0}blockquote{margin:24px 0;padding:18px 22px;border-left:4px solid #98b777;background:#f5f7ed;border-radius:8px}li{margin:8px 0}img{width:100%;border-radius:18px}figure{margin:28px 0}figcaption{font-size:13px;color:#6b746b}footer{margin-top:40px;font-size:13px;color:#6b746b}
        </style></head><body><article><header><small>TRIPTAIL · TRAVEL JOURNAL</small><h1>\(escape(title))</h1></header>\(body)<footer>TripTail로 정리한 여행 이야기 · 정보는 방문 전에 다시 확인하세요.</footer></article></body></html>
        """
    }
}
