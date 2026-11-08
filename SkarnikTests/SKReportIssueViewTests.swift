//
//  SKReportIssueViewTests.swift
//  SkarnikTests
//

import Foundation
import Testing
@testable import Skarnik

struct SKReportIssueViewTests {

    @Test func mailtoEncodingEscapesQuerySeparators() {
        let encoded = SKReportIssueView.mailtoEncoded("a & b = c + d? #e")
        #expect(!encoded.contains("&"))
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("?"))
        #expect(!encoded.contains("#"))
        #expect(encoded.removingPercentEncoding == "a & b = c + d? #e")
    }

    @Test func mailtoBodyWithAmpersandSurvivesAsOneQueryValue() throws {
        let body = "Падрабязнасці: памылка & націск"
        let url = try #require(URL(string: "mailto:x@example.com?subject=s&body=\(SKReportIssueView.mailtoEncoded(body))"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.map(\.name) == ["subject", "body"])
        #expect(items.last?.value == body)
    }
}
