import Foundation
import Testing
import UIKit
@testable import MyFridge

/**
 * <name>_raw.txt is raw OCR, <name>.png the image, <name>.expected.txt the wanted output.
 * Names containing "screenshot" use the screenshot rules.
 */
struct FixtureTests {
    @Test(arguments: textFixtureNames())
    func rawTextMatchesExpected(_ name: String) throws {
        let raw = try fixtureLines("\(name)_raw")
        let actual = name.contains("screenshot")
            ? ReceiptLineFilter.screenshotItems(from: paragraphs(from: raw))
            : ReceiptLineFilter.filter(raw)
        #expect(actual == (try expectedLines(name)))
    }

    /** Lines only need to be 90% alike since simulator OCR differs slightly from the phone. */
    @Test(arguments: imageFixtureNames())
    func imageMatchesExpected(_ name: String) async throws {
        let url = try #require(imageURL(name))
        let image = try #require(UIImage(contentsOfFile: url.path))
        let actual: [String]
        if name.contains("screenshot") {
            actual = ReceiptLineFilter.screenshotItems(from: try await OCRService.recognizeParagraphs(in: [image]))
        } else {
            actual = ReceiptLineFilter.filter(try await OCRService.recognizeLines(in: [image]))
        }
        let expected = try expectedLines(name)

        try #require(
            actual.count == expected.count,
            "Got \(actual.count) entries, expected \(expected.count). Actual output:\n\(actual.joined(separator: "\n"))"
        )
        for (line, expectedLine) in zip(actual, expected) {
            #expect(similarity(line, expectedLine) >= 0.9, "Got:\n\(line)\nExpected:\n\(expectedLine)")
        }
    }

    @Test func fixturesAreBundled() {
        #expect(!textFixtureNames().isEmpty)
    }
}

/** Only exists so Bundle(for:) can find the test bundle. */
private nonisolated final class FixtureBundleToken {}

private nonisolated let fixtureBundle = Bundle(for: FixtureBundleToken.self)
private nonisolated let imageExtensions = ["png", "jpg", "jpeg", "heic"]

private nonisolated func hasExpected(_ name: String) -> Bool {
    fixtureBundle.url(forResource: "\(name).expected", withExtension: "txt") != nil
}

private nonisolated func textFixtureNames() -> [String] {
    (fixtureBundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? [])
        .map { $0.deletingPathExtension().lastPathComponent }
        .filter { $0.hasSuffix("_raw") }
        .map { String($0.dropLast("_raw".count)) }
        .filter(hasExpected)
        .sorted()
}

/** Matches extensions ignoring case since iPhone screenshots end in .PNG. */
private nonisolated func imageURLs() -> [String: URL] {
    let urls = (fixtureBundle.urls(forResourcesWithExtension: nil, subdirectory: nil) ?? [])
        .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
    return Dictionary(urls.map { ($0.deletingPathExtension().lastPathComponent, $0) }) { first, _ in first }
}

private nonisolated func imageFixtureNames() -> [String] {
    imageURLs().keys.filter(hasExpected).sorted()
}

private func imageURL(_ name: String) -> URL? {
    imageURLs()[name]
}

private func fixtureLines(_ resource: String) throws -> [String] {
    let url = try #require(fixtureBundle.url(forResource: resource, withExtension: "txt"))
    return try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
}

private func expectedLines(_ name: String) throws -> [String] {
    try fixtureLines("\(name).expected").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
}

private func paragraphs(from lines: [String]) -> [[String]] {
    lines.split { $0.trimmingCharacters(in: .whitespaces).isEmpty }.map(Array.init)
}

private func similarity(_ a: String, _ b: String) -> Double {
    let a = Array(a.lowercased()), b = Array(b.lowercased())
    guard !a.isEmpty, !b.isEmpty else { return a.count == b.count ? 1 : 0 }
    var previous = Array(0...b.count)
    for (i, charA) in a.enumerated() {
        var current = [i + 1]
        for (j, charB) in b.enumerated() {
            current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (charA == charB ? 0 : 1)))
        }
        previous = current
    }
    return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
}
