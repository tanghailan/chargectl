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
        #expect(LogPresentation.display("Calibrate", bundle: chinese) == "校准")
        #expect(LogPresentation.display("Below 80%", bundle: chinese) == "低于 80%")
        #expect(LogPresentation.display("macOS charge limit is off", bundle: chinese) == "macOS 充电上限已关闭")
        #expect(LogPresentation.display("calibrating, draining to 15%", bundle: chinese) == "正在校准，放电至 15%")
        #expect(
            LogPresentation.display("calibration started: draining to 15%", bundle: chinese) == "已开始校准：放电至 15%")
    }
}
