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

    @Test func supportMailFooterListsAppAndDevice() {
        let footer = SKSupportMail.footer(appVersion: "3.8.0", build: "77", systemName: "iOS",
                                          systemVersion: "26.1", deviceModel: "iPhone17,1")
        #expect(footer == "—\nСкарнік 3.8.0 (77)\niOS 26.1 · iPhone17,1")
    }

    @Test func supportMailGoesOnlyToSkarnikappWithTheFooterInTheBody() throws {
        let body = "\n\n—\nСкарнік 3.8.0 (77)\niOS 26.1 · iPhone17,1"
        let url = try #require(SKSupportMail.url(subject: nil, body: body))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == "skarnikapp@gmail.com")
        #expect(components.queryItems?.map(\.name) == ["body"])
        #expect(components.queryItems?.first?.value == body)
    }

    @Test func modelIdentifierIsNotEmpty() {
        #expect(!SKSupportMail.modelIdentifier().isEmpty)
    }
}
