import Foundation
final class MockProtocol: URLProtocol {
 static var paths: [String] = []
 override class func canInit(with request: URLRequest) -> Bool { true }
 override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
 override func startLoading() {
  let path = request.url!.lastPathComponent
  Self.paths.append(path)
  let data: [String: Any]
  switch path {
  case "landmarks": data = ["photos": [["id":"P001", "candidates":[["name":"Correct Place", "score":0.8]], "text":"", "error":""], ["id":"P002", "candidates":[["name":"Wrong Place", "score":0.1]], "text":"", "error":""]]]
  case "research": data = ["results": [["place":"Correct Place", "sources":[["title":"Unrelated", "url":"https://en.wikipedia.org/wiki/Unrelated", "summary":"UNRELATED_SENTINEL"], ["title":"Correct Place", "url":"https://en.wikipedia.org/wiki/Correct_Place", "summary":"Documented history."]], "error":""]]]
  default:
   var bytes = request.httpBody
   if bytes == nil, let stream = request.httpBodyStream {
    stream.open(); defer { stream.close() }; var body = Data(); var buffer = [UInt8](repeating:0,count:4096)
    while stream.hasBytesAvailable { let count=stream.read(&buffer,maxLength:buffer.count); if count<=0 {break}; body.append(buffer,count:count) }; bytes=body
   }
   let payload = try! JSONSerialization.jsonObject(with: bytes!) as! [String:Any]
   let prompt = payload["prompt"] as! String
   assert(prompt.contains("2020-03-04")); assert(prompt.contains("P002")); assert(!prompt.contains("UNRELATED_SENTINEL")); assert(!prompt.contains("Wrong Place"))
   assert(prompt.contains("Documented history.")); assert(prompt.contains("0.8"))
   data = ["titles":["Test blog"], "html":"<h2>Introduction</h2><p>Documented history.</p>"]
  }
  client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed)
  client?.urlProtocol(self,didLoad:try! JSONSerialization.data(withJSONObject:data)); client?.urlProtocolDidFinishLoading(self)
 }
 override func stopLoading() {}
}
@main struct Checks {
 static func main() async throws {
  assert(PhotoCaptureDate.read(["DateTimeOriginal":"2020:03:04 23:59:58"]) == "2020-03-04")
  assert(PhotoCaptureDate.read(["DateTimeDigitized":"2024:02:29 00:00:00"]) == "2024-02-29")
  assert(PhotoCaptureDate.read(["DateTimeOriginal":"2023:02:29 00:00:00"]) == nil)
  assert(PhotoCaptureDate.read([:]) == nil)
  assert(PhotoCaptureDate.read(["DateTimeOriginal":"not a date", "DateTimeDigitized":"2022:01:02 12:00:00"]) == "2022-01-02")
  assert(PhotoGPS.read(["Latitude":37.5665,"Longitude":126.978])?.latitude == 37.5665)
  assert(PhotoGPS.read(["Latitude":33.0,"LatitudeRef":"S","Longitude":70.0,"LongitudeRef":"W"])?.longitude == -70)
  assert(PhotoGPS.read(["Latitude":91.0,"Longitude":0.0]) == nil)
  assert(PhotoGPS.read([:]) == nil)
  let mapURL = GoogleMapsURL.search(place:"",coordinate:PlaceCoordinate(latitude:37.5,longitude:127.0))
  assert(URLComponents(url:mapURL,resolvingAgainstBaseURL:false)?.queryItems?.first { $0.name == "query" }?.value == "37.5,127.0")
  URLProtocol.registerClass(MockProtocol.self)
  let photos = [TravelPhoto(jpeg:Data([1]),text:"",captureDate:"2020-03-04"),TravelPhoto(jpeg:Data([2]),text:"")]
  do { _ = try await AIService.generateVerified(photos: photos, places: []); assertionFailure("Missing confirmation must block writing") } catch {}
  do { _ = try await AIService.generateVerified(photos: photos, places: [ConfirmedPlace(id:"P001",place:"Correct Place",subject:"미확인",sources:[]), ConfirmedPlace(id:"P002",place:"Another Place",subject:"Building",sources:[])]); assertionFailure("Unknown subject must block writing") } catch {}
  assert(MockProtocol.paths.isEmpty)
  _ = try await AIService.identify(photos)
  let result = try await AIService.generateVerified(photos: photos, places: [ConfirmedPlace(id:"P001",place:"Correct Place",detectionScore:0.8,subject:"Aqueduct",sources:[]),ConfirmedPlace(id:"P002",place:"Another Place",subject:"Building",sources:[])])
  assert(MockProtocol.paths == ["landmarks","research","deepseek"])
  assert(result.html.contains("<h2>Introduction</h2>"))
  print("Verified place and subject gate, sourced HTML pipeline, EXIF dates and missing dates passed")
 }
}
