import XCTest
@testable import BlueskyReader

final class HTMLMetaParserTests: XCTestCase {

    func testExtractsOGTitle() {
        let html = """
        <html><head>
        <meta property="og:title" content="My Great Article">
        <title>Fallback Title</title>
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "My Great Article")
    }

    func testFallsBackToTitleTagWhenNoOGTitle() {
        let html = """
        <html><head>
        <title>Plain Title Tag</title>
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Plain Title Tag")
    }

    func testExtractsOGSiteName() {
        let html = """
        <html><head>
        <meta property="og:site_name" content="Example News">
        <meta property="og:title" content="A Title">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.siteName, "Example News")
    }

    func testDecodesHTMLEntitiesInTitle() {
        let html = """
        <html><head>
        <meta property="og:title" content="Tom &amp; Jerry &mdash; A Story">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Tom & Jerry — A Story")
    }

    func testDecodesNumericEntities() {
        let html = """
        <html><head>
        <meta property="og:title" content="Caf&#233; &#x2019;Round&#x2019; the Corner">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Café \u{2019}Round\u{2019} the Corner")
    }

    func testAttributeOrderContentBeforeProperty() {
        let html = """
        <html><head>
        <meta content="Content First Title" property="og:title">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Content First Title")
    }

    func testSingleQuotedAttributes() {
        let html = """
        <html><head>
        <meta property='og:title' content='Single Quoted Title'>
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Single Quoted Title")
    }

    func testNameAttributeAlsoMatchesKey() {
        let html = """
        <html><head>
        <meta name="og:title" content="Name Attr Title">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertEqual(meta.title, "Name Attr Title")
    }

    func testNoMetaOrTitleReturnsNil() {
        let html = "<html><head></head><body>No meta here</body></html>"
        let meta = HTMLMetaParser.parse(html: html)
        XCTAssertNil(meta.title)
        XCTAssertNil(meta.siteName)
    }
}
