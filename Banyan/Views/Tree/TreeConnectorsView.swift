// TreeConnectorsView.swift
// Draws the lines linking the three generations. Node views publish their centre
// anchors through NodeAnchorKey; this view resolves them and strokes a single path.

import SwiftUI

/// Collects the centre anchor of every rendered tree node, keyed by person id.
struct NodeAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGPoint>] { [:] }

    static func reduce(
        value: inout [UUID: Anchor<CGPoint>],
        nextValue: () -> [UUID: Anchor<CGPoint>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct TreeConnectorsView: View {
    let anchors: [UUID: Anchor<CGPoint>]
    let parentIds: [UUID]
    let focalId: UUID
    let partnerId: UUID?
    let childIds: [UUID]

    private var halfWidth: CGFloat { NodeMetrics.width / 2 }
    private var halfHeight: CGFloat { NodeMetrics.height / 2 }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, _ in
                var path = Path()
                addParentConnectors(to: &path, proxy: proxy)
                addPartnerConnector(to: &path, proxy: proxy)
                addChildConnectors(to: &path, proxy: proxy)
                context.stroke(
                    path,
                    with: .color(BanyanTheme.Color.connector),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Line building

    /// Partner line between two parents, plus the drop line down to the focal node.
    /// With a single parent the drop starts at that parent's bottom edge instead.
    private func addParentConnectors(to path: inout Path, proxy: GeometryProxy) {
        guard let focal = center(of: focalId, in: proxy) else { return }
        let parentCenters = parentIds.compactMap { center(of: $0, in: proxy) }
            .sorted { $0.x < $1.x }
        guard let first = parentCenters.first else { return }

        // The drop leaves the parent row at its bottom edge so the elbow's horizontal
        // segment stays in the gap between rows instead of crossing a parent card.
        let dropStart: CGPoint
        if parentCenters.count >= 2, let last = parentCenters.last {
            let midpoint = CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
            path.move(to: CGPoint(x: first.x + halfWidth, y: first.y))
            path.addLine(to: CGPoint(x: last.x - halfWidth, y: last.y))
            path.move(to: midpoint)
            path.addLine(to: CGPoint(x: midpoint.x, y: midpoint.y + halfHeight))
            dropStart = CGPoint(x: midpoint.x, y: midpoint.y + halfHeight)
        } else {
            dropStart = CGPoint(x: first.x, y: first.y + halfHeight)
        }
        addElbow(from: dropStart, to: CGPoint(x: focal.x, y: focal.y - halfHeight), in: &path)
    }

    /// Horizontal line between the focal node and their (first) partner.
    private func addPartnerConnector(to path: inout Path, proxy: GeometryProxy) {
        guard let partnerId,
              let focal = center(of: focalId, in: proxy),
              let partner = center(of: partnerId, in: proxy) else { return }

        if partner.x >= focal.x {
            path.move(to: CGPoint(x: focal.x + halfWidth, y: focal.y))
            path.addLine(to: CGPoint(x: partner.x - halfWidth, y: partner.y))
        } else {
            path.move(to: CGPoint(x: partner.x + halfWidth, y: partner.y))
            path.addLine(to: CGPoint(x: focal.x - halfWidth, y: focal.y))
        }
    }

    /// Drop from the focal node to a horizontal bar, then a short drop to each child.
    private func addChildConnectors(to path: inout Path, proxy: GeometryProxy) {
        guard let focal = center(of: focalId, in: proxy) else { return }
        let childCenters = childIds.compactMap { center(of: $0, in: proxy) }
        guard let firstChild = childCenters.first else { return }

        let focalBottom = focal.y + halfHeight
        let childTop = firstChild.y - halfHeight
        let barY = (focalBottom + childTop) / 2

        path.move(to: CGPoint(x: focal.x, y: focalBottom))
        path.addLine(to: CGPoint(x: focal.x, y: barY))

        let xs = childCenters.map(\.x) + [focal.x]
        if let minX = xs.min(), let maxX = xs.max(), minX != maxX {
            path.move(to: CGPoint(x: minX, y: barY))
            path.addLine(to: CGPoint(x: maxX, y: barY))
        }

        for child in childCenters {
            path.move(to: CGPoint(x: child.x, y: barY))
            path.addLine(to: CGPoint(x: child.x, y: child.y - halfHeight))
        }
    }

    // MARK: - Helpers

    /// A vertical-horizontal-vertical elbow so off-centre nodes connect with right angles.
    private func addElbow(from start: CGPoint, to end: CGPoint, in path: inout Path) {
        let midY = (start.y + end.y) / 2
        path.move(to: start)
        path.addLine(to: CGPoint(x: start.x, y: midY))
        path.addLine(to: CGPoint(x: end.x, y: midY))
        path.addLine(to: end)
    }

    private func center(of id: UUID, in proxy: GeometryProxy) -> CGPoint? {
        guard let anchor = anchors[id] else { return nil }
        return proxy[anchor]
    }
}
