import Foundation
import Observation

struct TravelDraft: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var updated = Date()
    var htmlBody: String?
    var evidence: [PhotoEvidence]? = nil
    static var seoulSample: TravelDraft {
        TravelDraft(title: "서울 · 경복궁과 북촌 소개 · 예시", text: "기능 체험용 서울 샘플입니다.\n\n개요\n서울은 대한민국의 수도이다. 경복궁과 북촌은 서울의 역사와 전통 건축을 살펴볼 수 있는 장소이다.\n\n역사\n경복궁은 조선 왕조의 궁궐이다. 북촌에는 전통 한옥과 골목이 남아 있다.\n\n주요 시설과 건축물\n경복궁의 주요 공간에는 광화문과 근정전 등이 있다. 북촌에서는 한옥의 건축과 골목 공간을 살펴볼 수 있다.\n\n참고 자료\n국가유산청 궁능유적본부 https://royal.khs.go.kr/\n서울한옥포털 https://hanok.seoul.go.kr/\n\n사진·촬영 시각은 이 샘플에 포함되지 않는다.", evidence: [PhotoEvidence(id: "P001", place: "경복궁 · 예시", subject: "궁궐 건축", captureDate: nil, captureTime: nil, observedText: "", note: "기능 체험용 가상 메모이며 실제 촬영이나 방문 기록이 아닙니다.", sources: [])])
    }
    var html: String {
        let records = (evidence ?? []).map { item in
            "<h3>\(BlogHTML.escape(item.id)) · \(BlogHTML.escape(item.place))</h3><p>촬영 대상: \(BlogHTML.escape(item.subject)) · 촬영일: \(BlogHTML.escape(item.captureDate ?? "기록 없음"))</p><p>직접 메모: \(BlogHTML.escape(item.note.isEmpty ? "기록 없음" : item.note))</p><p>자료 검토: \(item.reviewed ? "사용자 확인 완료" : "미검토")</p>"
        }.joined()
        let appendix = records.isEmpty ? "" : "<h2>사진별 여행 근거 기록</h2>" + records
        return BlogHTML.document(title: title, body: (htmlBody ?? text.components(separatedBy: "\n").filter { !$0.isEmpty }.map { "<p>\(BlogHTML.escape($0))</p>" }.joined()) + appendix)
    }
}

struct PhotoEvidence: Codable, Equatable, Identifiable {
    let id: String
    let place: String
    let subject: String
    let captureDate: String?
    let captureTime: String?
    let observedText: String
    let note: String
    let sources: [Source]
    var reviewed = false
    struct Source: Codable, Equatable {
        let title: String
        let url: String
        let summary: String
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
                var changed = false
                drafts = drafts.map { draft in
                    guard draft.title == "교토의 오후 · 예시", draft.text.hasPrefix("이 글은 기능 체험용 가상 예시입니다.") else { return draft }
                    var sample = TravelDraft.seoulSample; sample.id = draft.id; sample.updated = draft.updated; changed = true; return sample
                }
                if changed { _ = persist(drafts) }
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
        </style></head><body><article><header><small>TRIPTAIL · PLACE ENCYCLOPEDIA</small><h1>\(escape(title))</h1></header>\(body)<footer>TripTail · 장소와 역사를 담은 여행 기록</footer></article></body></html>
        """
    }
}

// Extract the camera's calendar day without a timezone conversion or a fabricated fallback.
enum PhotoCaptureDate {
    static func readTime(_ exif: [String: Any]) -> String? {
        guard read(exif) != nil else { return nil }
        for key in ["DateTimeOriginal", "DateTimeDigitized"] {
            guard let raw = exif[key] as? String, read([key: raw]) != nil else { continue }
            return String(raw.suffix(8))
        }
        return nil
    }

    static func read(_ exif: [String: Any]) -> String? {
        for key in ["DateTimeOriginal", "DateTimeDigitized"] {
            guard let raw = exif[key] as? String else { continue }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            formatter.isLenient = false
            guard let date = formatter.date(from: raw), formatter.string(from: date) == raw else { continue }
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        return nil
    }
}

enum PhotoVerificationRules {
    static func isKnown(_ value: String?) -> Bool {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !text.isEmpty && !["미확인", "정보 없음", "unknown", "unidentified", "unknown place"].contains(text)
    }
}

struct PlaceCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double
}
enum PhotoGPS {
    static func read(_ gps: [String: Any]) -> PlaceCoordinate? {
        guard var latitude = gps["Latitude"] as? Double, var longitude = gps["Longitude"] as? Double else { return nil }
        if let ref = gps["LatitudeRef"] as? String {
            guard ["N", "S"].contains(ref.uppercased()) else { return nil }
            latitude = abs(latitude) * (ref.uppercased() == "S" ? -1 : 1)
        }
        if let ref = gps["LongitudeRef"] as? String {
            guard ["E", "W"].contains(ref.uppercased()) else { return nil }
            longitude = abs(longitude) * (ref.uppercased() == "W" ? -1 : 1)
        }
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { return nil }
        return PlaceCoordinate(latitude: latitude, longitude: longitude)
    }
}
enum GoogleMapsURL {
    static func search(place: String, coordinate: PlaceCoordinate?) -> URL {
        var components = URLComponents(string: coordinate == nil ? "https://www.google.com/maps/search/" : "https://www.google.com/maps/@")!
        components.queryItems = [URLQueryItem(name: "api", value: "1")]
        if let coordinate {
            components.queryItems! += [URLQueryItem(name: "map_action", value: "map"), URLQueryItem(name: "center", value: "\(coordinate.latitude),\(coordinate.longitude)"), URLQueryItem(name: "zoom", value: "16"), URLQueryItem(name: "basemap", value: "roadmap")]
        } else { components.queryItems!.append(URLQueryItem(name: "query", value: place)) }
        return components.url!
    }
    static func coordinate(from url: URL) -> PlaceCoordinate? {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "center" })?.value else { return nil }
        let values = raw.split(separator: ",").compactMap { Double($0) }
        guard values.count == 2 else { return nil }
        return PhotoGPS.read(["Latitude": values[0], "Longitude": values[1]])
    }
}
