import SwiftUI
import PhotosUI

struct ComposerView: View {
    let library: DraftLibrary
    @State private var selection: [PhotosPickerItem] = []
    @State private var photos: [TravelPhoto] = []
    @State private var place = ""
    @State private var memo = ""
    @State private var date = Date()
    @State private var busy = false
    @State private var error: String?
    @State private var draft: TravelDraft?
    @State private var consent = false
    @State private var task: Task<Void, Never>?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Label("사진에서 시작하는 여행 이야기", systemImage: "leaf.fill").font(.title2.bold())
                Text("사진 속 글자를 기기에서 읽고, 여행 메모로 초안을 만드세요. 인터넷 없이도 저장·편집·공유할 수 있습니다.").foregroundStyle(.secondary)
                Button("샘플 여행 체험") {
                    draft = TravelDraft(title: "교토의 오후 · 예시", text: "이 글은 기능 체험용 가상 예시입니다.\n\n언덕길을 걸어 올라가 목조 건축과 도시 풍경을 바라보았다.\n\n나만의 사진과 기억을 넣어 여행 기록을 완성해보세요.")
                }.accessibilityIdentifier("sample")
            }
            Section("1. 사진 선택") {
                PhotosPicker(selection: $selection, maxSelectionCount: 12, matching: .images) {
                    Label("사진 선택 (최대 12장)", systemImage: "photo.on.rectangle")
                }.disabled(busy)
                Text("선택한 사진만 읽습니다. HEIC도 지원하며 GPS와 원본 메타데이터는 복사하지 않습니다.").font(.footnote).foregroundStyle(.secondary)
                ForEach(photos) { photo in
                    HStack(alignment: .top) {
                        if let image = UIImage(data: photo.jpeg) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityLabel("선택한 여행 사진")
                        }
                        VStack(alignment: .leading) {
                            Text(photo.text.isEmpty ? "읽힌 글자 없음 · 장소를 직접 입력해주세요" : photo.text).font(.footnote).lineLimit(4)
                            Button("사진 제거", role: .destructive) { photos.removeAll { $0.id == photo.id } }.disabled(busy)
                        }
                    }
                }
            }
            Section("2. 나의 여행") {
                TextField("여행지 (모르면 비워두세요)", text: $place).onChange(of: place) { _, v in place = String(v.prefix(200)) }
                DatePicker("방문 날짜", selection: $date, displayedComponents: .date)
                TextField("느낀 점, 사진 설명, 기억하고 싶은 순간", text: $memo, axis: .vertical).lineLimit(4...8).onChange(of: memo) { _, v in memo = String(v.prefix(4000)) }
                Text("사진 속 글자는 틀릴 수 있습니다. 장소와 역사 정보는 게시 전에 확인하세요.").font(.footnote).foregroundStyle(.secondary)
            }.disabled(busy)
            Section("3. 초안 만들기") {
                Button { makeLocalDraft() } label: { Label("기기 내 초안 만들기", systemImage: "pencil.line") }.disabled(busy || (photos.isEmpty && memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                Button { consent = true } label: { Label("AI로 사진 분석·글쓰기", systemImage: "sparkles") }.disabled(busy || photos.isEmpty)
                Text("AI는 선택 기능입니다. 전송 전에 대상과 내용을 안내합니다. 사진의 인물이나 민감한 정보가 포함되지 않았는지 확인하세요.").font(.footnote).foregroundStyle(.secondary)
                if busy { ProgressView("사진 처리 또는 AI 응답을 기다리는 중…"); Button("취소") { task?.cancel() } }
            }
            if !photos.isEmpty || !memo.isEmpty { Section { Button("입력 초기화", role: .destructive) { confirmReset = true }.disabled(busy) } }
        }
        .navigationTitle("TripTail")
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            task = Task {
                busy = true
                defer { busy = false; selection = [] }
                var loaded: [TravelPhoto] = []
                do {
                    for item in items {
                        try Task.checkCancellation()
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoService.PhotoError.unreadable }
                        guard data.count <= 20 * 1024 * 1024 else { throw AIService.ServiceError.message("장당 20MB 이하 사진을 선택해주세요.") }
                        loaded.append(try await PhotoService.prepare(data))
                    }
                    try Task.checkCancellation()
                    if !items.isEmpty { photos = loaded }
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $draft) { DraftEditor(draft: $0, library: library) }
        .alert("외부 AI 전송 동의", isPresented: $consent) {
            Button("취소", role: .cancel) {}
            Button("동의하고 전송") { generate() }
        } message: {
            Text("선택한 사진 \(photos.count)장(축소 JPEG), 여행지, 방문 날짜, 메모가 Cloudflare의 TripTail 서버를 통해 DeepSeek에 전달되어 분석됩니다. GPS 메타데이터는 제거됩니다. 외부 업체의 보관·처리 정책이 적용되며 이미 전송한 데이터는 앱에서 회수할 수 없습니다. 안내 탭의 개인정보 처리방침을 확인하세요. 동의하지 않아도 기기 내 초안을 사용할 수 있습니다.")
        }
        .alert("안내", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
        .confirmationDialog("저장하지 않은 입력과 사진을 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) { Button("초기화", role: .destructive) { photos = []; selection = []; place = ""; memo = "" } }
        .onDisappear { task?.cancel() }
    }
    private func makeLocalDraft() {
        let title = place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "나의 여행" : place
        let observations = photos.enumerated().map { index, photo in
            "[사진 \(index + 1)]\n" + (photo.text.isEmpty ? "사진의 장소와 기억을 직접 적어주세요." : "사진에서 읽힌 글자 (확인 필요):\n\(photo.text)")
        }.joined(separator: "\n\n")
        draft = TravelDraft(title: title, text: date.formatted(date: .abbreviated, time: .omitted) + "\n\n" + memo + "\n\n" + observations)
    }
    private func generate() {
        task = Task {
            busy = true
            defer { busy = false }
            do {
                let text = try await AIService.generate(photos: photos, place: place, memo: memo, date: date.formatted(date: .numeric, time: .omitted))
                try Task.checkCancellation()
                draft = TravelDraft(title: place.isEmpty ? "여행 이야기" : place, text: text)
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
