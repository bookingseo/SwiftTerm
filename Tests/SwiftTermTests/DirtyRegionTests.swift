//
//  DirtyRegionTests.swift
//
//  Unit tests for the iOS/visionOS dirty-region calculation used by
//  TerminalView.updateDisplay to invalidate only the rows that changed
//  instead of the whole bounds. getUpdateRange() returns visible-relative
//  rows (row 0 == top of the viewport); the scroll view keeps
//  contentOffset.y == yDisp * cellHeight, so a changed row sits at
//  content-y contentOffsetY + row * cellHeight.
//
#if os(macOS)
import Foundation
import CoreGraphics
import Testing

@testable import SwiftTerm

final class DirtyRegionTests {
    // A mid-screen change invalidates exactly the changed rows and nothing else.
    // (contentOffsetY == 0 mirrors the alt-screen / vim-in-tmux case where there is
    // no scrollback, so visible-relative rows equal content-coordinate rows.)
    @Test func midScreenChangeIsTight() {
        let cell: CGFloat = 10
        let region = TerminalView.iOSDirtyRegion (
            rowStart: 10, rowEnd: 12, totalRows: 50,
            cellHeight: cell, boundsWidth: 300, boundsHeight: 500, contentOffsetY: 0)

        #expect(region.origin.y == 10 * cell)          // top of the first changed row
        #expect(region.size.height == 3 * cell)        // rows 10,11,12 -> 3 rows tall
        #expect(region != CGRect(x: 0, y: 0, width: 300, height: 500))  // not the full bounds
    }

    // A change touching the last visible row extends to the bottom of the viewport
    // so wide/unicode glyph spill below the baseline is repainted.
    @Test func lastRowExtendsToBottom() {
        let cell: CGFloat = 10
        let region = TerminalView.iOSDirtyRegion (
            rowStart: 47, rowEnd: 49, totalRows: 50,
            cellHeight: cell, boundsWidth: 300, boundsHeight: 500, contentOffsetY: 0)

        #expect(region.origin.y == 47 * cell)
        #expect(region.maxY == 500)                    // reaches the bottom of the viewport
    }

    // A full-range update (whole screen dirty) covers the entire bounds.
    @Test func fullRangeCoversBounds() {
        let cell: CGFloat = 10
        let region = TerminalView.iOSDirtyRegion (
            rowStart: 0, rowEnd: 49, totalRows: 50,
            cellHeight: cell, boundsWidth: 300, boundsHeight: 500, contentOffsetY: 0)

        #expect(region == CGRect(x: 0, y: 0, width: 300, height: 500))
    }

    // With a non-zero content offset (scrolled into scrollback, e.g. an ordinary shell),
    // the region is anchored at contentOffsetY, NOT at 0 — otherwise the invalidated pixels
    // would land in scrollback and the visible edit would never repaint.
    @Test func scrollbackMidScreenIsAnchoredToContentOffset() {
        let cell: CGFloat = 10
        let offset: CGFloat = 1000   // yDisp == 100 rows scrolled, contentOffset.y == 100 * 10
        let region = TerminalView.iOSDirtyRegion (
            rowStart: 2, rowEnd: 4, totalRows: 25,
            cellHeight: cell, boundsWidth: 300, boundsHeight: 250, contentOffsetY: offset)

        #expect(region.origin.y == offset + 2 * cell)  // 1020, not 20
        #expect(region.size.height == 3 * cell)
    }

    // Last-row extend, with a non-zero content offset, reaches the bottom of the *visible*
    // viewport (contentOffsetY + boundsHeight), not an absolute boundsHeight.
    @Test func scrollbackLastRowExtendsToViewportBottom() {
        let cell: CGFloat = 10
        let offset: CGFloat = 1000
        let region = TerminalView.iOSDirtyRegion (
            rowStart: 23, rowEnd: 24, totalRows: 25,
            cellHeight: cell, boundsWidth: 300, boundsHeight: 250, contentOffsetY: offset)

        #expect(region.origin.y == offset + 23 * cell) // 1230
        #expect(region.maxY == offset + 250)           // 1250 == bottom of the visible viewport
    }
}
#endif
