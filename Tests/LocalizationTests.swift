import Foundation
import Testing

private final class LocalizationBundleMarker {}

@Suite struct LocalizationTests {
    @Test func chineseCatalogAndEnglishFallback() throws {
        let bundle = Bundle(for: LocalizationBundleMarker.self)
        let chinesePath = try #require(bundle.path(forResource: "zh-Hans", ofType: "lproj"))
        let chinese = try #require(Bundle(path: chinesePath))
        #expect(chinese.localizedString(forKey: "Charge limit", value: nil, table: nil) == "充电上限")
        let format = chinese.localizedString(forKey: "charging to %lld%%", value: nil, table: nil)
        #expect(String(format: format, Int64(80)) == "正在充电至 80%")
        #expect(
            chinese.localizedString(forKey: "Missing English text", value: nil, table: nil) == "Missing English text")
    }
}
