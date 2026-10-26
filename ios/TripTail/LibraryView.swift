import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct HTMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }
    var html: String
    init(html: String) { self.html = html }
    init(configuration: ReadConfiguration) throws { html = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(html.utf8)) }
}

struct DraftEditor: View {
    @State var draft: TravelDraft
    let library: DraftLibrary
    var previewPhotos: [TravelPhoto] = []
    @State private var showPreview = false
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var notice: String?
    @State private var discard = false
    @State private var dirty = false
    @State private var initialized = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    JourneySteps(active: 3)
                    Label("여행 글이 준비되었습니다", systemImage: "checkmark.seal").font(.headline)
                    Text("내용과 출처를 확인하고 보관함에 저장하거나 공유하세요.").font(.footnote).foregroundStyle(.secondary)
                    if !previewPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(previewPhotos) { photo in
                                    if let image = UIImage(data: photo.jpeg) {
                                        Image(uiImage: image).resizable().scaledToFill().frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel("선택한 여행 사진")
                                    }
                                }
                            }
                        }
                    }
                    Button("기기에 저장") {
                        draft.updated = Date()
                        if library.save(draft) { dirty = false; notice = "글과 사진별 근거 기록을 보관함에 저장했습니다. 원본 사진과 GPS는 저장하지 않습니다." }
                        else { notice = library.error }
                    }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).buttonStyle(.borderedProminent).tint(Color(red: 0.76, green: 0.88, blue: 0.80)).foregroundStyle(Color(red: 0.08, green: 0.29, blue: 0.23)).buttonBorderShape(.capsule).controlSize(.large)
                }
                Section("제목") { TextField("여행 글 제목", text: $draft.title) }
                if let evidence = draft.evidence, !evidence.isEmpty {
                    Section("사진별 여행 근거 기록") {
                        Text("촬영일·직접 메모·확인한 장소와 참고 자료를 글과 함께 기기에 보관합니다. 원본 사진과 GPS는 저장하지 않습니다. 자료 검토 표시는 사용자의 확인이며 사실성 보증이 아닙니다.").font(.footnote).foregroundStyle(.secondary)
                        ForEach(Array(evidence.enumerated()), id: \.element.id) { index, item in
                            DisclosureGroup("\(item.id) · \(item.place)") {
                                LabeledContent("촬영일", value: item.captureDate ?? "기록 없음")
                                if let time = item.captureTime { LabeledContent("촬영 시각", value: time) }
                                if let zone = item.captureTimeZoneID { LabeledContent("위치 시간대", value: zone) }
                                LabeledContent("촬영 대상", value: item.subject)
                                Text("직접 메모: " + (item.note.isEmpty ? "기록 없음" : item.note)).accessibilityIdentifier("evidenceNote-\(item.id)")
                                if !item.observedText.isEmpty { Text("사진에서 읽힌 글자: " + item.observedText).font(.footnote) }
                                if item.sources.isEmpty { Text("연결된 배경 자료 없음 — 본문의 역사·수치가 근거 없이 추가되지 않았는지 확인하세요.").font(.footnote) }
                                ForEach(Array(item.sources.enumerated()), id: \.offset) { _, source in
                                    Text(source.title).font(.headline)
                                    Text(source.summary).font(.footnote).textSelection(.enabled)
                                    if let url = URL(string: source.url), url.scheme == "https", ["en.wikipedia.org", "ko.wikipedia.org"].contains(url.host ?? "") { Link("원문과 대조하기", destination: url) }
                                }
                                Toggle("이 사진의 장소·메모·자료를 검토했습니다", isOn: Binding(get: { draft.evidence?[index].reviewed ?? false }, set: { draft.evidence?[index].reviewed = $0; dirty = true }))
                            }
                        }
                    }
                }
                Section("본문 · 직접 확인하고 수정하세요") { TextEditor(text: $draft.text).frame(minHeight: 280).accessibilityLabel("여행 글 본문") }
                Section {
                    Button("꾸며진 블로그 미리보기") { showPreview = true }
                    ShareLink(item: draft.title + "\n\n" + draft.text) { Label("글 공유", systemImage: "square.and.arrow.up") }
                    Button("블로그 HTML 파일 내보내기") { exporting = true }
                    Text("공유 전 장소, 읽힌 글자, AI 설명을 확인하세요. HTML에는 사진 자리 설명과 글이 들어갑니다. 실제 사진은 블로그에서 추가하세요.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.965, green: 0.970, blue: 0.948))
            .navigationTitle("여행 글 편집")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { if dirty { discard = true } else { dismiss() } } } }
            .fileExporter(isPresented: $exporting, document: HTMLDocument(html: draft.html), contentType: .html, defaultFilename: "triptail-blog") { result in
                if case .failure = result { notice = "파일을 내보내지 못했습니다. 다시 시도하거나 글 공유를 사용하세요." }
            }
            .onChange(of: draft.title) { dirty = true }
            .onChange(of: draft.text) { dirty = true; draft.htmlBody = nil }
            .onAppear { guard !initialized else { return }; initialized = true; dirty = !library.drafts.contains { $0.id == draft.id }; showPreview = draft.htmlBody != nil }
            .sheet(isPresented: $showPreview, onDismiss: { if let saved = library.drafts.first(where: { $0.id == draft.id }), saved.title == draft.title && saved.text == draft.text && saved.htmlBody == draft.htmlBody && saved.evidence == draft.evidence { dirty = false } }) { BlogPreview(draft: draft, photos: previewPhotos, library: library) }
            .interactiveDismissDisabled(dirty)
            .confirmationDialog("저장하지 않은 글을 닫을까요?", isPresented: $discard, titleVisibility: .visible) { Button("저장하지 않고 닫기", role: .destructive) { dismiss() } }
            .alert("안내", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("확인") { notice = nil } } message: { Text(notice ?? "") }
        }
    }
}

struct LibraryView: View {
    let library: DraftLibrary
    @State private var selected: TravelDraft?
    var body: some View {
        List {
            if let error = library.error { Text(error).foregroundStyle(.red) }
            if library.drafts.isEmpty {
                ContentUnavailableView("아직 저장한 여행이 없어요", systemImage: "books.vertical", description: Text("새 여행에서 사진을 확인하고 글을 완성한 뒤 저장하세요."))
            }
            ForEach(library.drafts) { draft in
                Button { selected = draft } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(Color(red: 0.03, green: 0.32, blue: 0.26))
                            .frame(width: 54, height: 70).background(Color(red: 0.92, green: 0.95, blue: 0.89), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(draft.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                            Text(draft.text).font(.subheadline).lineLimit(2).foregroundStyle(.secondary)
                            Label(draft.updated.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                            if let evidence = draft.evidence, !evidence.isEmpty {
                                Label("사진 근거 \(evidence.count)장 · 자료 검토 \(evidence.filter { $0.reviewed }.count)/\(evidence.count)", systemImage: "checklist").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { library.delete([draft.id]) } label: { Label("삭제", systemImage: "trash") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.970, blue: 0.948))
        .navigationTitle("여행 보관함")
        .sheet(item: $selected) { DraftEditor(draft: $0, library: library) }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("사용 방법") {
                Text("① 여행 사진을 선택하고 사진별 직접 관찰·메모를 남깁니다.\n② 전송에 동의하면 장소·촬영 대상을 자동 분석하고 바로 글을 작성합니다. 필요하면 분석 전에 사진 카드의 지도에서 위치를 지정하세요.\n③ 편집 화면의 ‘사진별 여행 근거 기록’에서 촬영일·메모·참고 자료를 대조하고 검토 상태를 저장합니다.\n④ 글과 근거 기록을 기기에 저장하거나 HTML로 내보냅니다.")
                Text("글과 사진별 근거 기록(확인 장소·촬영일·촬영 시각·위치 시간대·읽힌 글자·직접 메모·참고 자료·검토 상태)은 기기에 저장됩니다. 원본 사진과 GPS는 보관하지 않습니다. 앱 삭제 시 기기 내 보관함도 삭제됩니다. 기기 백업에는 글과 근거 기록이 포함될 수 있습니다. 개별 글과 연결된 근거 기록은 보관함에서 함께 삭제할 수 있습니다.")
            }
            Section("개인정보 처리방침 · 2026-10-26") {
                Text("로그인, 광고, 추적 SDK를 사용하지 않습니다. Google Vision에 선택한 축소 사진을 전송해 장소와 글자를 인식할 수 있습니다. 인식하거나 사용자가 지도에서 지정한 장소명을 Wikipedia로 전송해 역사·시설·주요 사물 자료를 조회합니다. 지도에서 위치를 직접 선택하거나 장소 검색 시 검색어를 Apple 지도에 전달하고 Google 지도 확인에는 선택 장소명 또는 인식 좌표를 전달합니다. 사진 GPS는 지역명 조회와 선택한 현지 시간대 순서 제안을 위해 Apple에 전달될 수 있습니다. Google 지도 촬영 위치 표시 및 Apple 지도 검색 범위에 사용할 수 있습니다. 현재 위치 권한은 사용하지 않습니다. 사진은 시스템 사진 선택기로 선택한 항목만 처리하며 전체 사진 보관함이나 현재 위치 권한을 요청하지 않습니다.")
                Text("선택한 사진은 메모리에서 축소·재인코딩하고 글자 인식은 Apple Vision으로 기기에서 수행합니다. 분석용 축소 사진에서 GPS와 원본 EXIF는 제거합니다. 지도에서 촬영 위치를 확인할 때 GPS 좌표를 Google에 전달하며, 장소 검색 범위를 설정하거나 위치 시간대를 확인할 때 Apple에 전달할 수 있습니다. 원본 사진과 GPS는 보관함에 저장하지 않습니다. EXIF 촬영 날짜·시간을 별도로 읽어 확인 화면에 표시합니다. 촬영일은 AI 요청과 작성된 글에 사용할 수 있습니다. 촬영일이 없으면 날짜를 임의로 추가하지 않습니다. 사진은 보관함에 저장되지 않습니다.")
                Text("외부 AI 전송은 매번 동의해야 실행됩니다. 축소 사진, 촬영 지역, 촬영일, 사진별 직접 메모, 촬영 대상과 참고 자료는 Cloudflare의 TripTail 서버를 거쳐 DeepSeek에 전달됩니다. 촬영 시각과 기기 내 자료 검토 표시는 별도 AI 요청에 포함하지 않습니다. 선택 기능인 현지 시간대 순서 제안은 사진 GPS 또는 사용자가 지도에서 선택한 위치 좌표를 Apple 지도 서비스에 보내 위치 시간대를 확인합니다. 카메라 시계 설정과 실제 현지 시간이 다르면 제안 순서가 정확하지 않을 수 있습니다. 전송된 데이터는 각 업체의 정책을 따릅니다. 앱은 서버에 여행 글을 저장하는 기능이 없지만 업체의 요청·운영 로그 및 보관 기간은 별도 확인이 필요합니다.")
                Text("동의를 거부하려면 전송 안내에서 취소하세요. 다음 요청에서도 다시 동의합니다. 이미 전송된 자료의 삭제 문의는 아래 지원 채널로 요청하세요. 공유한 자료는 선택한 공유 앱의 정책이 적용됩니다.")
                Link("Google 지도 개인정보 정책", destination: URL(string: "https://policies.google.com/privacy")!)
                Link("Google Cloud 개인정보 정책", destination: URL(string: "https://cloud.google.com/terms/cloud-privacy-notice")!)
                Link("Wikimedia 개인정보 정책", destination: URL(string: "https://foundation.wikimedia.org/wiki/Policy:Privacy_policy")!)
                Link("Cloudflare 개인정보 정책", destination: URL(string: "https://www.cloudflare.com/privacypolicy/")!)
                Link("DeepSeek 개인정보 정책", destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
            }
            Section("지원 및 의견") {
                Link("TripTail 지원 · 오류 및 삭제 문의", destination: URL(string: "https://github.com/outinletter/triptail/issues")!)
                Link("이메일 지원 · 개인정보 삭제 요청", destination: URL(string: "mailto:outintube@gmail.com")!)
                Text("공개 문의에는 사진, API 키, 개인정보를 올리지 마세요.").font(.footnote)
            }
        }.scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.970, blue: 0.948))
        .navigationTitle("안내 및 개인정보")
    }
}

struct BlogPreview: View {
    let draft: TravelDraft
    let photos: [TravelPhoto]
    var library: DraftLibrary? = nil
    @State private var notice: String?
    @State private var exporting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            BlogWebView(html: previewHTML)
                .navigationTitle("여행 블로그")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("글 편집") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        HStack {
                            if let library {
                                Button { notice = library.save(draft) ? "보관함에 저장했습니다." : library.error } label: { Label("저장", systemImage: "bookmark") }
                                    .buttonStyle(.borderedProminent).tint(Color(red: 0.76, green: 0.88, blue: 0.80)).foregroundStyle(Color(red: 0.08, green: 0.29, blue: 0.23))
                            }
                            ShareLink(item: draft.title + "\n\n" + draft.text) { Label("공유", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                            Button { exporting = true } label: { Label("HTML", systemImage: "doc.richtext") }.buttonStyle(.bordered)
                        }.controlSize(.large)
                        Text("사진은 보관되지 않습니다. HTML에는 사진 자리와 글이 포함됩니다.").font(.caption).foregroundStyle(.secondary)
                    }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
                .fileExporter(isPresented: $exporting, document: HTMLDocument(html: draft.html), contentType: .html, defaultFilename: "triptail-guide") { result in
                    if case .failure = result { notice = "파일을 내보내지 못했습니다. 다시 시도해주세요." }
                }
                .alert("안내", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("확인") { notice = nil } } message: { Text(notice ?? "") }
        }
    }
    private var previewHTML: String {
        var body = draft.htmlBody ?? draft.text.components(separatedBy: "\n").map { "<p>\(BlogHTML.escape($0))</p>" }.joined()
        for (index, photo) in photos.enumerated() {
            let id = String(format: "P%03d", index + 1)
            let pattern = "\\[사진 " + id + "[^\\]]*\\]"
            let image = "<figure><img alt='여행 사진 \(index + 1)' src='data:image/jpeg;base64,\(photo.jpeg.base64EncodedString())'><figcaption>여행 사진 \(index + 1)</figcaption></figure>"
            if let range = body.range(of: pattern, options: .regularExpression) { body.replaceSubrange(range, with: image) }
        }
        return BlogHTML.document(title: draft.title, body: body)
    }
}
struct BlogWebView: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        return view
    }
    final class Coordinator { var loadedHTML: String? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        view.loadHTMLString(html, baseURL: nil)
    }
}
