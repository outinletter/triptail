import SwiftUI
import PhotosUI

struct ComposerView: View {
    let library: DraftLibrary
    @State private var selection: [PhotosPickerItem] = []
    @State private var photos: [TravelPhoto] = []
    @State private var busy = false
    @State private var error: String?
    @State private var draft: TravelDraft?
    @State private var consent = false
    @State private var task: Task<Void, Never>?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("TRAVEL STORY MAKER")
                        .font(.caption.weight(.bold)).tracking(3)
                        .foregroundStyle(Color(red: 0.42, green: 0.53, blue: 0.33))
                    (Text("사진을 정리하고,\n")
                     + Text("여행 글을 자동으로 ").foregroundColor(Color(red: 0.19, green: 0.36, blue: 0.29))
                     + Text("완성하세요."))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 12)
                Text("사진을 선택하면 장소와 촬영일을 분석해 소개·역사·주변 정보가 담긴 여행 블로그를 만듭니다.").foregroundStyle(.secondary)
                Button("샘플 여행 체험") {
                    draft = TravelDraft(title: "교토의 오후 · 예시", text: "이 글은 기능 체험용 가상 예시입니다.\n\n언덕길을 걸어 올라가 목조 건축과 도시 풍경을 바라보았다.\n\n나만의 사진과 기억을 넣어 여행 기록을 완성해보세요.")
                }.accessibilityIdentifier("sample")
            }
            Section("1. 사진 선택") {
                PhotosPicker(selection: $selection, maxSelectionCount: 12, matching: .images, preferredItemEncoding: .current) {
                    Label("사진 선택 (최대 12장)", systemImage: "photo.on.rectangle")
                }.disabled(busy)
                Text("선택한 사진만 읽습니다. HEIC도 지원하며 촬영일만 읽습니다. GPS와 원본 메타데이터는 전송하지 않습니다.").font(.footnote).foregroundStyle(.secondary)
                ForEach(photos) { photo in
                    HStack(alignment: .top) {
                        if let image = UIImage(data: photo.jpeg) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityLabel("선택한 여행 사진")
                        }
                        VStack(alignment: .leading) {
                            Text(photo.text.isEmpty ? "장소는 AI 글쓰기에서 자동으로 분석합니다." : photo.text).font(.footnote).lineLimit(4)
                            Text(photo.captureDate.map { "촬영일: " + $0 } ?? "촬영일 정보 없음").font(.caption).foregroundStyle(.secondary)
                            Button("사진 제거", role: .destructive) { photos.removeAll { $0.id == photo.id } }.disabled(busy)
                        }
                    }
                }
            }
            Section("2. 여행 블로그 만들기") {
                Button { makeLocalDraft() } label: { Label("기기 내 초안 만들기", systemImage: "pencil.line") }.disabled(busy || photos.isEmpty)
                Button { consent = true } label: { Label("AI로 사진 분석·글쓰기", systemImage: "sparkles") }.disabled(busy || photos.isEmpty)
                Text("사진의 장소를 자동으로 인식하고 관련 자료를 조회해 소개·역사·주변 정보를 담은 블로그 글을 만듭니다. AI는 선택 기능입니다. 사진의 인물이나 민감한 정보가 포함되지 않았는지 확인하세요.").font(.footnote).foregroundStyle(.secondary)
                if busy { ProgressView("사진 처리 또는 AI 응답을 기다리는 중…"); Button("취소") { task?.cancel() } }
            }
            if !photos.isEmpty { Section { Button("입력 초기화", role: .destructive) { confirmReset = true }.disabled(busy) } }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.970, blue: 0.948))
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
        .sheet(item: $draft) { DraftEditor(draft: $0, library: library, previewPhotos: photos) }
        .alert("외부 AI 전송 동의", isPresented: $consent) {
            Button("취소", role: .cancel) {}
            Button("동의하고 전송") { generate() }
        } message: {
            Text("선택한 축소 사진 \(photos.count)장을 Cloudflare를 통해 Google Vision에 전송해 장소를 인식하고, 인식된 장소명은 Wikipedia 자료 조회에 사용합니다. 축소 사진·사진에서 읽힌 촬영일·장소 및 참고 자료는 DeepSeek에 전송해 블로그를 작성합니다. GPS와 원본 메타데이터는 제거합니다. 인식 결과는 틀릴 수 있으므로 작성된 내용을 확인해주세요. 외부 업체의 보관·처리 정책은 안내 탭에서 확인할 수 있습니다.")
        }
        .alert("안내", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
        .confirmationDialog("저장하지 않은 입력과 사진을 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) { Button("초기화", role: .destructive) { photos = []; selection = [] } }
        .onDisappear { task?.cancel() }
    }
    private func makeLocalDraft() {
        let observations = photos.enumerated().map { index, photo in
            "[사진 \(index + 1)]\n촬영일: \(photo.captureDate ?? "정보 없음")\n" + (photo.text.isEmpty ? "사진의 장소와 기억을 편집 화면에서 적어주세요." : "사진에서 읽힌 글자 (확인 필요):\n\(photo.text)")
        }.joined(separator: "\n\n")
        draft = TravelDraft(title: "사진으로 남기는 여행", text: observations)
    }
    private func generate() {
        task = Task {
            busy = true
            defer { busy = false }
            do {
                let generated = try await AIService.generateAutomatically(photos: photos)
                try Task.checkCancellation()
                draft = generated
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
