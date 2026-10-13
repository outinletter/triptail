import SwiftUI
import UniformTypeIdentifiers

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
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var notice: String?
    @State private var discard = false
    @State private var dirty = false
    var body: some View {
        NavigationStack {
            Form {
                Section("제목") { TextField("여행 글 제목", text: $draft.title) }
                Section("본문 · 직접 확인하고 수정하세요") { TextEditor(text: $draft.text).frame(minHeight: 280).accessibilityLabel("여행 글 본문") }
                Section {
                    Button("기기에 저장") {
                        draft.updated = Date()
                        if library.save(draft) { dirty = false; notice = "보관함에 저장했습니다. 사진은 저장되지 않으며 글만 보관됩니다." }
                        else { notice = library.error }
                    }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .onChange(of: draft.text) { dirty = true }
            .onAppear { dirty = !library.drafts.contains { $0.id == draft.id } }
            .interactiveDismissDisabled(dirty)
            .confirmationDialog("저장하지 않은 글을 닫을까요?", isPresented: $discard, titleVisibility: .visible) { Button("저장하지 않고 닫기", role: .destructive) { dismiss() } }
            .alert("안내", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("확인") { notice = nil } } message: { Text(notice ?? "") }
        }
    }
}

struct LibraryView: View {
    let library: DraftLibrary
    @State private var selected: TravelDraft?
    @State private var deletion: Set<UUID> = []
    @State private var confirmDelete = false
    var body: some View {
        List {
            if let error = library.error { Text(error).foregroundStyle(.red) }
            if library.drafts.isEmpty {
                ContentUnavailableView("아직 저장한 여행이 없어요", systemImage: "books.vertical", description: Text("새 여행에서 초안을 만들고 ‘기기에 저장’을 눌러보세요."))
            }
            ForEach(library.drafts) { draft in
                Button { selected = draft } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.title).font(.headline).foregroundStyle(.primary)
                        Text(draft.text).lineLimit(2).foregroundStyle(.secondary)
                        Text(draft.updated.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.onDelete { offsets in deletion = Set(offsets.map { library.drafts[$0].id }); confirmDelete = true }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.970, blue: 0.948))
        .navigationTitle("여행 보관함")
        .toolbar { if !library.drafts.isEmpty { EditButton() } }
        .sheet(item: $selected) { DraftEditor(draft: $0, library: library) }
        .confirmationDialog("선택한 글을 삭제할까요? 되돌릴 수 없습니다.", isPresented: $confirmDelete, titleVisibility: .visible) { Button("삭제", role: .destructive) { library.delete(deletion) } }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("사용 방법") {
                Text("① 사진을 선택하거나 여행 메모를 입력합니다.\n② 기기 내 초안 또는 선택형 AI 글쓰기를 사용합니다.\n③ 내용을 확인·편집하고 저장 또는 공유합니다.")
                Text("글은 기기에 저장됩니다. 앱 삭제 시 기기 내 보관함도 삭제됩니다. 기기 백업에는 글이 포함될 수 있습니다. 개별 글은 보관함에서 삭제할 수 있습니다.")
            }
            Section("개인정보 처리방침 · 2026-10-13") {
                Text("로그인, 광고, 추적 SDK를 사용하지 않습니다. 사진은 시스템 사진 선택기로 선택한 항목만 처리하며 전체 사진 보관함이나 현재 위치 권한을 요청하지 않습니다.")
                Text("선택한 사진은 메모리에서 축소·재인코딩하고 글자 인식은 Apple Vision으로 기기에서 수행합니다. GPS와 EXIF는 저장·전송하지 않습니다. 사진은 보관함에 저장되지 않습니다.")
                Text("외부 AI 전송은 매번 동의해야 실행됩니다. 축소 사진, 여행지, 날짜, 메모는 Cloudflare의 TripTail 서버를 거쳐 DeepSeek에 전달됩니다. 전송된 데이터는 각 업체의 정책을 따릅니다. 앱은 서버에 여행 글을 저장하는 기능이 없지만 업체의 요청·운영 로그 및 보관 기간은 별도 확인이 필요합니다.")
                Text("동의를 거부하려면 전송 안내에서 취소하세요. 다음 요청에서도 다시 동의합니다. 이미 전송된 자료의 삭제 문의는 아래 지원 채널로 요청하세요. 공유한 자료는 선택한 공유 앱의 정책이 적용됩니다.")
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
