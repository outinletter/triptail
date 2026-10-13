import SwiftUI
import PhotosUI
import MapKit
import SafariServices

struct ComposerView: View {
    let library: DraftLibrary
    @State private var selection: [PhotosPickerItem] = []
    @Binding var photos: [TravelPhoto]
    @State private var busy = false
    @State private var error: String?
    @State private var draft: TravelDraft?
    @State private var consent = false
    @State private var task: Task<Void, Never>?
    @State private var confirmReset = false
    @State private var verification: VerificationSession?
    @State private var queuedPlaces: [ConfirmedPlace]?
    @State private var photoMap: GoogleMapTarget?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("PHOTO · PLACE · HISTORY")
                        .font(.caption.weight(.bold)).tracking(3)
                        .foregroundStyle(Color(red: 0.42, green: 0.53, blue: 0.33))
                    (Text("사진을 정리하고,\n")
                     + Text("여행 글을 자동으로 ").foregroundColor(Color(red: 0.19, green: 0.36, blue: 0.29))
                     + Text("완성하세요."))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 12)
                Text("사진을 선택하면 장소·촬영 대상을 분석합니다. 지도에서 확인한 뒤 소개와 역사, 주변 정보를 담은 여행 글을 완성하세요.").foregroundStyle(.secondary)
                Button("샘플 여행 체험") {
                    draft = TravelDraft.seoulSample
                }.accessibilityIdentifier("sample")
            }
            Section("1. 사진 선택") {
                PhotosPicker(selection: $selection, maxSelectionCount: 12, matching: .images, preferredItemEncoding: .current) {
                    Label("사진 선택 (최대 12장)", systemImage: "photo.on.rectangle")
                }.disabled(busy)
                Text("선택한 사진만 읽습니다. HEIC도 지원하며 촬영일과 GPS를 기기에서 읽습니다. GPS 좌표를 Apple 지도에 보내 촬영 지역명을 조회하며 지도에서도 확인할 수 있습니다.").font(.footnote).foregroundStyle(.secondary)
                ForEach(photos) { photo in
                    HStack(alignment: .top) {
                        if let image = UIImage(data: photo.jpeg) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityLabel("선택한 여행 사진")
                        }
                        VStack(alignment: .leading) {
                            Text(photo.text.isEmpty ? "장소는 AI 글쓰기에서 자동으로 분석합니다." : photo.text).font(.footnote).lineLimit(4)
                            PhotoMetadataBubbles(photo: photo)
                            if let coordinate = photo.coordinate {
                                Button("촬영 위치를 Google 지도에서 보기") { photoMap = GoogleMapTarget(url: GoogleMapsURL.search(place: "", coordinate: coordinate)) }
                            }
                            Button("사진 제거", role: .destructive) { photos.removeAll { $0.id == photo.id } }.disabled(busy)
                        }
                    }
                }
            }
            Section("2. 여행 블로그 만들기") {
                Button { consent = true } label: { Label("AI로 사진 분석·글쓰기", systemImage: "sparkles").frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(busy || photos.isEmpty)
                Text("사진의 장소와 촬영 대상을 인식하고 지도에서 확인한 뒤 관련 자료를 조회해 소개·역사·주변 정보를 담은 블로그 글을 만듭니다. 사진의 인물이나 민감한 정보가 포함되지 않았는지 확인하세요.").font(.footnote).foregroundStyle(.secondary)
                if busy { ProgressView("사진 처리 또는 AI 응답을 기다리는 중…"); Button("취소") { task?.cancel() } }
            }
            if !photos.isEmpty { Section { Button("입력 초기화", role: .destructive) { confirmReset = true }.disabled(busy) } }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.965, green: 0.970, blue: 0.948))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
                    Text("TripTail").font(.title2.bold())
                }.fixedSize(horizontal: true, vertical: false)
                .accessibilityElement(children: .combine).accessibilityLabel("TripTail")
            }
        }
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
        .sheet(item: $photoMap) { GoogleMapBrowser(url: $0.url) }
        .sheet(item: $draft) { DraftEditor(draft: $0, library: library, previewPhotos: photos) }
        .sheet(item: $verification, onDismiss: {
            if let places = queuedPlaces { queuedPlaces = nil; writeBlog(places) }
        }) { session in
            PhotoVerificationView(session: session) { queuedPlaces = $0 }
        }
        .alert("외부 AI 전송 동의", isPresented: $consent) {
            Button("취소", role: .cancel) {}
            Button("동의하고 전송") { generate() }
        } message: {
            Text("선택한 축소 사진 \(photos.count)장을 Cloudflare를 통해 Google Vision에 전송해 장소를 인식하고, 인식된 장소명은 Wikipedia 자료 조회에 사용합니다. 지도 확인을 마치면 축소 사진·촬영일·확인한 장소와 촬영 대상·참고 자료를 DeepSeek에 전송해 블로그를 작성합니다. 지도 확인에는 장소명 또는 인식된 좌표를 Google 지도에 전송하고, 장소 검색에는 검색어와 사진 GPS를 기반으로 한 검색 범위를 Apple 지도에 전송할 수 있습니다. 분석용 사진의 GPS와 원본 메타데이터는 제거합니다. Google 지도에서 촬영 위치를 확인하면 사진에서 읽은 GPS 좌표가 Google에 전달됩니다. 인식 결과는 틀릴 수 있으므로 작성된 내용을 확인해주세요. 외부 업체의 보관·처리 정책은 안내 탭에서 확인할 수 있습니다.")
        }
        .alert("안내", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인") { error = nil } } message: { Text(error ?? "") }
        .confirmationDialog("저장하지 않은 입력과 사진을 지울까요?", isPresented: $confirmReset, titleVisibility: .visible) { Button("초기화", role: .destructive) { photos = []; selection = [] } }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--photo-retention-test"), photos.isEmpty {
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
                let image = renderer.image { context in UIColor.systemGreen.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 40)) }
                photos = [TravelPhoto(jpeg: image.jpegData(compressionQuality: 0.8)!, text: "", coordinate: PlaceCoordinate(latitude: 37.5796, longitude: 126.9770))]
            }
            if ProcessInfo.processInfo.arguments.contains("--map-preview-test") { photoMap = GoogleMapTarget(url: GoogleMapsURL.search(place: "", coordinate: PlaceCoordinate(latitude: 40.947842, longitude: -4.117433))) }
            if ProcessInfo.processInfo.arguments.contains("--verification-test") {
                let photo = TravelPhoto(jpeg: UIImage(systemName: "photo")?.jpegData(compressionQuality: 0.8) ?? Data(), text: "", captureDate: "2020-03-04")
                verification = VerificationSession(photos: [photo], recognized: [RecognizedPlace(id: "P001", candidates: [], objects: [], text: "", error: "")])
            }
        }
        #endif
    }
    private func generate() {
        task = Task {
            busy = true
            defer { busy = false }
            do {
                let result = try await AIService.identify(photos)
                try Task.checkCancellation()
                guard result.photos.count == photos.count else { throw AIService.ServiceError.message("사진 분석이 불완전합니다. 다시 시도해주세요.") }
                verification = VerificationSession(photos: photos, recognized: result.photos)
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    private func writeBlog(_ places: [ConfirmedPlace]) {
        task = Task {
            busy = true
            defer { busy = false }
            do {
                let result = try await AIService.generateVerified(photos: photos, places: places)
                try Task.checkCancellation()
                draft = result
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }

}

struct VerificationSession: Identifiable {
    let id = UUID()
    let photos: [TravelPhoto]
    let recognized: [RecognizedPlace]
}
struct VerifiedPhotoInput: Identifiable {
    let id: String
    let photo: TravelPhoto
    let recognized: RecognizedPlace
    var place: String
    var subject: String
    var coordinate: PlaceCoordinate?
    var score: Double?
    var confirmed = false
    var isReady: Bool { confirmed && PhotoVerificationRules.isKnown(place) && PhotoVerificationRules.isKnown(subject) }
}
struct PhotoVerificationView: View {
    let onConfirm: ([ConfirmedPlace]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [VerifiedPhotoInput]
    @State private var closeKeyboard = false
    init(session: VerificationSession, onConfirm: @escaping ([ConfirmedPlace]) -> Void) {
        self.onConfirm = onConfirm
        _rows = State(initialValue: zip(session.photos, session.recognized).map { photo, recognized in
            let candidate = recognized.candidates.max { $0.score < $1.score }
            return VerifiedPhotoInput(id: recognized.id, photo: photo, recognized: recognized, place: candidate?.name ?? "", subject: recognized.objects?.max { $0.score < $1.score }?.name ?? "", coordinate: photo.coordinate ?? candidate?.coordinates, score: candidate?.score)
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("사진별 장소와 촬영 대상을 확인해주세요. 장소가 다르거나 인식되지 않으면 검색해서 선택할 수 있습니다. 모든 사진을 확인하기 전에는 글을 작성하지 않습니다.") }
                ForEach($rows) { $row in PhotoVerificationRow(row: $row, closeKeyboard: closeKeyboard) }
                Section { Text("확인 완료 \(rows.filter { $0.isReady }.count) / \(rows.count)장").font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.965, green: 0.970, blue: 0.948))
            .navigationTitle("장소와 촬영 대상 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("입력 완료") { closeKeyboard.toggle() } }
                ToolbarItem(placement: .bottomBar) {
                    Button("확인 완료 · 블로그 작성") {
                        onConfirm(rows.map { ConfirmedPlace(id: $0.id, place: $0.place, detectionScore: $0.score, subject: $0.subject, sources: []) })
                        dismiss()
                    }.buttonStyle(.borderedProminent).disabled(rows.isEmpty || !rows.allSatisfy { $0.isReady })
                }
            }
        }
    }
}
struct GoogleMapTarget: Identifiable { let id = UUID(); let url: URL }
struct PhotoVerificationRow: View {
    @Binding var row: VerifiedPhotoInput
    let closeKeyboard: Bool
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var map: GoogleMapTarget?
    @State private var manualMap = false
    private enum Field: Hashable { case query, subject }
    @FocusState private var focused: Field?
    var body: some View {
        Section("사진 \(row.id)") {
            if let image = UIImage(data: row.photo.jpeg) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            PhotoMetadataBubbles(photo: row.photo, place: row.place)
            if row.photo.coordinate != nil { Text("사진에 기록된 촬영 지역을 우선 표시합니다. 촬영 위치와 사진 속 대상의 위치는 다를 수 있습니다.").font(.footnote).foregroundStyle(.secondary) }
            if row.recognized.candidates.isEmpty { Text("장소가 인식되지 않았습니다. 아래에서 실제 장소를 검색해주세요.") }
            ForEach(row.recognized.candidates, id: \.self) { candidate in
                Button("\(candidate.name) · 인식 점수 \(Int(candidate.score * 100))%") {
                    row.place = candidate.name; row.coordinate = candidate.coordinates; row.score = candidate.score; row.confirmed = false
                }
            }
            Text(row.place.isEmpty ? "선택한 장소 없음" : "선택한 장소: " + row.place).font(.headline)
            Button("Google 지도에서 위치 확인") { openMap(row.place, coordinate: row.coordinate) }.disabled(row.place.isEmpty && row.coordinate == nil)
            Button("지도에서 위치 직접 선택", systemImage: "mappin.and.ellipse") { manualMap = true }
            TextField("정확한 장소명 또는 주소 검색", text: $query).focused($focused, equals: .query).submitLabel(.search).onSubmit { focused = nil; search() }
            Button("장소 검색") { search() }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searching)
            if searching { ProgressView("장소 검색 중…") }
            if let searchError { Text(searchError).font(.footnote).foregroundStyle(.secondary) }
            ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                Button {
                    row.place = item.name ?? query
                    row.coordinate = PlaceCoordinate(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                    row.score = nil; row.confirmed = false; results = []
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.name ?? query)
                        Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Google 지도로 검색") { openMap(query, coordinate: nil) }
                Button("입력한 장소명으로 선택") { row.place = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)); row.coordinate = nil; row.score = nil; row.confirmed = false }
            }
            Text("장소 검색은 Apple 지도, 위치 확인은 Google 지도를 사용합니다.").font(.caption).foregroundStyle(.secondary)
            if let objects = row.recognized.objects, !objects.isEmpty {
                Text("인식된 대상: " + objects.prefix(5).map { $0.name }.joined(separator: " · ")).font(.footnote)
            }
            TextField("사진 속 사물·건축물·풍경의 이름", text: Binding(get: { row.subject }, set: { row.subject = String($0.prefix(200)); row.confirmed = false }))
                .autocorrectionDisabled().focused($focused, equals: .subject).submitLabel(.done).onSubmit { focused = nil }
            Text("위 날짜·시간·위치 정보와 촬영 대상을 확인한 후 아래를 켜주세요. 정보가 없는 항목은 글에서 생략합니다.").font(.footnote).foregroundStyle(.secondary)
            Toggle("이 장소와 촬영 대상이 맞습니다", isOn: $row.confirmed)
                .disabled(!PhotoVerificationRules.isKnown(row.place) || !PhotoVerificationRules.isKnown(row.subject))
        }
        .onAppear { if query.isEmpty { query = row.place } }
        .sheet(item: $map) { GoogleMapBrowser(url: $0.url) }
        .sheet(isPresented: $manualMap) {
            ManualPlaceMap(initial: row.coordinate) { name, coordinate in
                row.place = name; row.coordinate = coordinate; row.score = nil; row.confirmed = false
            }
        }
        .onChange(of: closeKeyboard) { focused = nil }
    }
    private func openMap(_ place: String, coordinate: PlaceCoordinate?) {
        map = GoogleMapTarget(url: GoogleMapsURL.search(place: place, coordinate: coordinate))
    }
    private func search() {
        Task {
            searching = true; searchError = nil
            defer { searching = false }
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = String(query.prefix(200))
                request.resultTypes = [.address, .pointOfInterest]
                if let coordinate = row.photo.coordinate { request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)) }
                let response = try await MKLocalSearch(request: request).start()
                results = Array(response.mapItems.prefix(8))
                if results.isEmpty { searchError = "검색 결과가 없습니다. Google 지도에서 찾아 장소명을 입력할 수 있습니다." }
            } catch { searchError = "검색에 실패했습니다. Google 지도에서 확인하거나 다시 검색해주세요." }
        }
    }
}
struct GoogleMapBrowser: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let point = GoogleMapsURL.coordinate(from: url) {
                    Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker("확인할 위치", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
                    }.mapStyle(.standard).accessibilityIdentifier("location-map")
                    RegionBubble(point: point)
                    Text("미리보기: Apple 지도 · Google 지도는 아래 버튼으로 열립니다.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Google 지도에서 장소 검색", systemImage: "map", description: Text("아래 버튼을 눌러 Google 지도 앱 또는 Safari에서 검색 결과를 확인하세요."))
                }
                Button { openURL(url) } label: { Label("Google 지도 열기", systemImage: "arrow.up.forward.square") }
                    .buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom)
            }.navigationTitle("위치 확인").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }
}

struct PhotoMetadataBubbles: View {
    let photo: TravelPhoto
    var place: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            bubble(photo.captureDate ?? "촬영 날짜 없음", icon: "calendar")
            bubble(photo.captureTime.map { $0 + " · 카메라 기록 시간" } ?? "촬영 시간 없음", icon: "clock")
            if !place.isEmpty { bubble(place, icon: "mappin") }
            if let point = photo.coordinate {
                RegionBubble(point: point)
            } else { bubble("촬영 지역 정보 없음 · 지도에서 선택 가능", icon: "location.slash") }
        }
    }
    private func bubble(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(Color(red: 0.19, green: 0.36, blue: 0.29))
            .background(Color(red: 0.92, green: 0.95, blue: 0.89), in: RoundedRectangle(cornerRadius: 16))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ManualPlaceMap: View {
    let initial: PlaceCoordinate?
    let onSelect: (String, PlaceCoordinate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var point: PlaceCoordinate?
    @State private var name = ""
    @State private var position: MapCameraPosition
    init(initial: PlaceCoordinate?, onSelect: @escaping (String, PlaceCoordinate) -> Void) {
        self.initial = initial; self.onSelect = onSelect
        _point = State(initialValue: initial)
        _position = State(initialValue: initial.map { .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))) } ?? .automatic)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("지도를 이동하거나 확대하고 원하는 위치를 탭하세요.").font(.footnote).padding()
                MapReader { proxy in
                    Map(position: $position) {
                        if let point { Marker("선택한 위치", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) }
                    }.mapStyle(.standard).onTapGesture { location in
                        if let coordinate = proxy.convert(location, from: .local) {
                            point = PlaceCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    if let point { Text(String(format: "선택 좌표 %.5f, %.5f", point.latitude, point.longitude)).font(.caption) }
                    TextField("선택한 위치의 정확한 장소명", text: $name).textFieldStyle(.roundedBorder)
                    Button("이 위치와 장소명 사용") {
                        if let point { onSelect(name.trimmingCharacters(in: .whitespacesAndNewlines), point); dismiss() }
                    }.buttonStyle(.borderedProminent).disabled(point == nil || !PhotoVerificationRules.isKnown(name))
                }.padding()
            }.navigationTitle("지도에서 위치 선택").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }
}

struct RegionBubble: View {
    let point: PlaceCoordinate
    @State private var name = "촬영 지역 확인 중…"
    var body: some View {
        Label(name, systemImage: "mappin.and.ellipse").font(.caption)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(Color(red: 0.19, green: 0.36, blue: 0.29))
            .background(Color(red: 0.92, green: 0.95, blue: 0.89), in: RoundedRectangle(cornerRadius: 16))
            .task(id: point) {
                do {
                    let places = try await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: point.latitude, longitude: point.longitude), preferredLocale: Locale(identifier: "ko_KR"))
                    guard !Task.isCancelled else { return }
                    let place = places.first
                    var parts: [String] = []
                    for value in [place?.country, place?.administrativeArea, place?.locality, place?.subLocality] {
                        if let value, !parts.contains(value) { parts.append(value) }
                    }
                    name = parts.isEmpty ? "지역명 확인 불가 · 지도에서 확인" : parts.joined(separator: " · ")
                } catch { if !Task.isCancelled { name = "지역명 조회 실패 · 지도에서 확인" } }
            }
    }
}
