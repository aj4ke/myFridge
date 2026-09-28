import Foundation
import Testing
@testable import MyFridge

struct ReceiptLineFilterTests {
    @Test(arguments: [
        "",
        "   ",
        "------------------------",
        "3.99",
        "$12.99",
        "-0.50",
        "3.99 F",
        "SUBTOTAL 26.52",
        "SUB TOTAL 26.52",
        "TOTAL 26.52",
        "** TOTAL 26.52",
        "Order total: $45.67",
        "BALANCE DUE 26.52",
        "TAX 0.00",
        "Sales Tax 1.23",
        "VISA 26.52",
        "MASTERCARD",
        "DEBIT CARD",
        "CREDIT",
        "CASH 30.00",
        "CHANGE 3.48",
        "AUTH CODE 123456",
        "APPROVED",
        "THANK YOU FOR SHOPPING",
        "************1234",
        "(512) 555-0100",
        "512-555-0100",
        "1234 MAIN ST",
        "500 N LAMAR BLVD",
        "AUSTIN, TX 78701",
        "09/20/26 10:15 AM",
        "10:15",
        "Arriving Sep 25",
        "Delivered September 20, 2026",
        "012345678905",
        "0 12345 67890 5",
        "Order # 112-1234567-7654321",
        "三の",
        "@",
        "8",
        "9:18",
        "Q Search or ask a question",
        "Items in your order",
        "Tare Weight: 0.01 lb",
        "Checkout Bag Charge",
        "Bag Fee",
        "Collapse ^",
        "a",
        "* g",
    ])
    func dropsNonItemLines(_ line: String) {
        #expect(ReceiptLineFilter.filter([line]).isEmpty)
    }

    @Test(arguments: [
        "365 ORG BABY SPINACH 3.99 F",
        "BNLS SKNLS CHKN BRST 8.47 F",
        "FAGE TOTAL 2% YOGURT 6.49 F",
        "MAYO 12 OZ",
        "DR PEPPER 12 PK",
        "365 LG BRWN EGGS 12 CT",
        "CASHEWS ROASTED 7.99",
        "2 @ 1.29",
        "1.52 lb @ 5.57 /lb",
        "Qty: 2",
        "Organic Valley Whole Milk, 64 oz",
    ])
    func keepsItemLines(_ line: String) {
        #expect(ReceiptLineFilter.filter([line]) == [line])
    }

    @Test func joinsReceiptWeightLineOntoItemAbove() {
        let lines = ReceiptLineFilter.filter(["BNLS SKNLS CHKN BRST 8.47 F", "1.52 lb @ 5.57 /lb", "ORG KALE 2.99"])
        #expect(lines == ["BNLS SKNLS CHKN BRST 8.47 F | 1.52 lb @ 5.57 /lb", "ORG KALE 2.99"])
    }

    @Test func joinsReceiptCountLineOntoItemAbove() {
        let lines = ReceiptLineFilter.filter(["365 ORG PASTA PENNE 1.99 F", "2 @ 1.29", "ORG KALE 2.99"])
        #expect(lines == ["365 ORG PASTA PENNE 1.99 F | 2 @ 1.29", "ORG KALE 2.99"])
    }

    @Test func joinsWeightLineAcrossDroppedPriceAndTareLines() {
        let lines = ReceiptLineFilter.filter(["ORG BANANAS", "1.78 F", "TARE WEIGHT 0.01 lb", "2.30 lb @ 0.79 /lb", "ORG KALE 2.99"])
        #expect(lines == ["ORG BANANAS | 2.30 lb @ 0.79 /lb", "ORG KALE 2.99"])
    }

    @Test func trimsWhitespaceAndKeepsOrder() {
        #expect(ReceiptLineFilter.filter(["  ORG KALE 2.99 ", "TOTAL 2.99", "BANANAS 1.23"]) == ["ORG KALE 2.99", "BANANAS 1.23"])
    }

    @Test func mergesNameSplitAcrossParagraphsAndAttachesQty() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Items in your order"],
            ["Nashoba Brook Bakery Sourdough Half"],
            ["Deli Loaf, 21 oz"],
            ["Qty: 1 @ $6.99 each"],
            ["$6.99"],
            ["365 by Whole Foods Market, Organic", "Whole Milk, 64 oz"],
            ["Qty: 1@$4.39 each"],
            ["$4.39"],
        ])
        #expect(items == [
            "Nashoba Brook Bakery Sourdough Half Deli Loaf, 21 oz | Qty: 1 @ $6.99 each",
            "365 by Whole Foods Market, Organic Whole Milk, 64 oz | Qty: 1@$4.39 each",
        ])
    }

    @Test func skipsPriceBetweenNameLinesWhenPageHasQty() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["365 by Whole Foods Market Salted"],
            ["$3.99"],
            ["Butter, 16 OZ"],
            ["Qty: 1 @ $3.99 each"],
        ])
        #expect(items == ["365 by Whole Foods Market Salted Butter, 16 OZ | Qty: 1 @ $3.99 each"])
    }

    @Test func dropsStoreHeaderAboveItems() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Purchased at Whole Foods Market -"],
            ["WHOLE"],
            ["Cambridge"],
            ["Purchased on Monday, September 28, 2026"],
            ["Items in your order"],
            ["Bag Fee"],
            ["Qty: 2 @$0.00 each"],
            ["$0.00"],
            ["Genji Sushi, Spicy Shrimp Tempura", "Crunch Roll, 8.96 Ounce"],
            ["Qty: 1 @ $12.99 each"],
        ])
        #expect(items == ["Genji Sushi, Spicy Shrimp Tempura Crunch Roll, 8.96 Ounce | Qty: 1 @ $12.99 each"])
    }

    @Test func itemsWithoutQtyEndAtTheirPrice() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["365 by Whole Foods Market, Organic", "Chicken Noodle Soup, 18.6 Ounce"],
            ["$3.99"],
            ["Organic Strawberries, 1 lb"],
            ["$4.99"],
            ["8"],
        ])
        #expect(items == ["365 by Whole Foods Market, Organic Chicken Noodle Soup, 18.6 Ounce", "Organic Strawberries, 1 lb"])
    }

    @Test func dropsItemsWhoseNameIsJunk() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Checkout Bag Charge"],
            ["Qty: 2@$0.10 each"],
            ["$0.20"],
            ["Organic Red Onion"],
            ["Qty: 0.88 lb @$2.99/lb"],
            ["Tare Weight: 0.01 lb"],
            ["$2.63"],
        ])
        #expect(items == ["Organic Red Onion | Qty: 0.88 lb @$2.99/lb"])
    }

    @Test func dropsQtyCutOffFromItemAboveTheScreenshot() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Qty: 1 @ $3.99 each"],
            ["$3.99"],
            ["Organic Whole Milk, 64 oz"],
            ["Qty: 1 @ $4.39 each"],
        ])
        #expect(items == ["Organic Whole Milk, 64 oz | Qty: 1 @ $4.39 each"])
    }

    @Test func keepsItemCutOffBeforeItsQty() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Pineapple Chunks Small"],
            ["Qty: 0.69 lb @$5.49/lb"],
            ["$3.79"],
            ["Organic Strawberries, 1 lb"],
        ])
        #expect(items == ["Pineapple Chunks Small | Qty: 0.69 lb @$5.49/lb", "Organic Strawberries, 1 lb"])
    }

    @Test func emptyInputGivesNothing() {
        #expect(ReceiptLineFilter.filter([]).isEmpty)
        #expect(ReceiptLineFilter.screenshotItems(from: []).isEmpty)
    }

    @Test func pagesWithoutQtyOrPricesKeepOneEntryPerParagraph() {
        let items = ReceiptLineFilter.screenshotItems(from: [
            ["Delivered September 20"],
            ["Organic Strawberries,", "1 lb"],
            ["Buy it again"],
        ])
        #expect(items == ["Organic Strawberries, 1 lb", "Buy it again"])
    }
}
