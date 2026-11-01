import Foundation
import StreamenRecorderKit
import Testing

@Suite("normalizedBaseURL")
struct BaseURLTests {
    @Test(arguments: [
        ("nas.local", "http://nas.local:8090"),
        ("  nas.local  ", "http://nas.local:8090"),
        ("192.168.1.20", "http://192.168.1.20:8090"),
        ("192.168.1.20:9000", "http://192.168.1.20:9000"),
        ("http://192.168.1.20:9000/", "http://192.168.1.20:9000"),
        ("http://nas.local", "http://nas.local:8090"),
        ("HTTP://NAS.local:8090/api/v1/info?x=1#frag", "http://NAS.local:8090"),
        ("https://dvr.example.com", "https://dvr.example.com"),
        ("https://dvr.example.com:8443/some/path/", "https://dvr.example.com:8443"),
        ("http://user:pass@nas.local:8090", "http://nas.local:8090"),
        ("[::1]:8090", "http://[::1]:8090"),
        ("http://[fe80::1]", "http://[fe80::1]:8090"),
    ])
    func accepts(input: String, expected: String) {
        #expect(StreamenRecorderClient.normalizedBaseURL(from: input)?.absoluteString == expected)
    }

    @Test(arguments: [
        "",
        "   ",
        "ftp://nas.local",
        "nas local",
        "http://",
        "http://nas.local:0",
        "http://nas.local:99999",
        "://nas.local",
    ])
    func rejects(input: String) {
        #expect(StreamenRecorderClient.normalizedBaseURL(from: input) == nil)
    }

    @Test func constants() {
        #expect(StreamenRecorderClient.bonjourServiceType == "_streamen-recorder._tcp")
        #expect(StreamenRecorderClient.defaultPort == 8090)
        #expect(StreamenRecorderClient.supportedAPIVersion == 1)
    }
}
