//
//  SportsFieldMarkings.swift
//  Streamen
//
//  The line markings of a playing surface — a football pitch, a basketball
//  court, a hockey rink, a gridiron, a baseball diamond, a tennis court —
//  drawn in code for the Sports Hub's backdrop, so there is no artwork to
//  bundle or license. Each is laid out portrait, ends at top and bottom, and
//  keeps the curves that make it recognisable at a glance (centre circles,
//  penalty arcs, three-point lines, creases) rather than bare rectangles.
//

import SwiftUI

/// A sport's playing-surface lines in a portrait rect about 0.62 wide.
struct SportsFieldMarkings: Shape {
    private enum Surface {
        case pitch, court, rink, gridiron, diamond, tennis
    }

    private let surface: Surface

    init?(sport: String?) {
        switch sport {
        case "soccer": surface = .pitch
        case "basketball": surface = .court
        case "hockey": surface = .rink
        case "football", "rugby", "rugby-league", "australian-football": surface = .gridiron
        case "baseball": surface = .diamond
        case "tennis": surface = .tennis
        default: return nil
        }
    }

    func path(in rect: CGRect) -> Path {
        var pen = MarkingPen(rect: rect)
        switch surface {
        case .pitch: drawPitch(&pen)
        case .court: drawCourt(&pen)
        case .rink: drawRink(&pen)
        case .gridiron: drawGridiron(&pen)
        case .diamond: drawDiamond(&pen)
        case .tennis: drawTennis(&pen)
        }
        return pen.path
    }

    // MARK: - Surfaces

    private func drawPitch(_ pen: inout MarkingPen) {
        let radius = pen.width * 0.15
        pen.path.addRect(pen.rect)
        pen.line(pen.point(0, 0.5), pen.point(1, 0.5))
        pen.circle(pen.point(0.5, 0.5), radius: radius)
        pen.dot(pen.point(0.5, 0.5))
        for end in [0.0, 1.0] {
            let inward = end == 0 ? 1.0 : -1.0
            pen.path.addRect(pen.box(0.2, end == 0 ? 0 : 0.84, width: 0.6, height: 0.16))
            pen.path.addRect(pen.box(0.36, end == 0 ? 0 : 0.94, width: 0.28, height: 0.06))
            pen.path.addRect(pen.box(0.43, end == 0 ? -0.015 : 1, width: 0.14, height: 0.015))
            let spot = pen.point(0.5, end + inward * 0.11)
            pen.dot(spot)
            // The penalty arc, the part of the spot's circle outside the box.
            pen.arc(center: spot, radius: radius, from: end == 0 ? 32.5 : 212.5, to: end == 0 ? 147.5 : 327.5)
        }
        let corner = pen.width * 0.04
        pen.arc(center: pen.point(0, 0), radius: corner, from: 0, to: 90)
        pen.arc(center: pen.point(1, 0), radius: corner, from: 90, to: 180)
        pen.arc(center: pen.point(1, 1), radius: corner, from: 180, to: 270)
        pen.arc(center: pen.point(0, 1), radius: corner, from: 270, to: 360)
    }

    private func drawCourt(_ pen: inout MarkingPen) {
        pen.path.addRect(pen.rect)
        pen.line(pen.point(0, 0.5), pen.point(1, 0.5))
        pen.circle(pen.point(0.5, 0.5), radius: pen.width * 0.12)
        for end in [0.0, 1.0] {
            let inward = end == 0 ? 1.0 : -1.0
            pen.path.addRect(pen.box(0.34, end == 0 ? 0 : 0.79, width: 0.32, height: 0.21))
            pen.circle(pen.point(0.5, end + inward * 0.21), radius: pen.width * 0.12)
            // Backboard and hoop.
            pen.line(pen.point(0.42, end + inward * 0.025), pen.point(0.58, end + inward * 0.025))
            let basket = pen.point(0.5, end + inward * 0.05)
            pen.circle(basket, radius: pen.width * 0.025)
            // The three-point line: short straights off the baseline, then the arc.
            pen.path.move(to: pen.point(0.07, end))
            pen.path.addLine(to: pen.point(0.07, end + inward * 0.1))
            pen.path.addArc(
                center: basket, radius: pen.width * 0.43,
                startAngle: .degrees(end == 0 ? 167 : 193), endAngle: .degrees(end == 0 ? 13 : 347),
                clockwise: end == 0
            )
            pen.path.addLine(to: pen.point(0.93, end))
        }
    }

    private func drawRink(_ pen: inout MarkingPen) {
        let corner = pen.width * 0.28
        pen.path.addRoundedRect(in: pen.rect, cornerSize: CGSize(width: corner, height: corner))
        for down in [0.35, 0.5, 0.65] {
            pen.line(pen.point(0, down), pen.point(1, down))
        }
        pen.circle(pen.point(0.5, 0.5), radius: pen.width * 0.12)
        pen.dot(pen.point(0.5, 0.5))
        for end in [0.0, 1.0] {
            let inward = end == 0 ? 1.0 : -1.0
            let goalLine = end + inward * 0.07
            pen.line(pen.point(0.05, goalLine), pen.point(0.95, goalLine))
            // The crease, a half circle in front of the goal.
            pen.arc(center: pen.point(0.5, goalLine), radius: pen.width * 0.08, from: end == 0 ? 0 : 180, to: end == 0 ? 180 : 360)
            for across in [0.27, 0.73] {
                let faceoff = pen.point(across, end + inward * 0.18)
                pen.circle(faceoff, radius: pen.width * 0.11)
                pen.dot(faceoff)
            }
        }
    }

    private func drawGridiron(_ pen: inout MarkingPen) {
        pen.path.addRect(pen.rect)
        for step in 0 ... 10 {
            let down = 0.08 + Double(step) * 0.084
            pen.line(pen.point(0, down), pen.point(1, down))
            // Hash marks between the yard lines.
            guard step < 10 else { continue }
            for tick in 1 ... 4 {
                let tickDown = down + Double(tick) * 0.0168
                pen.line(pen.point(0.36, tickDown), pen.point(0.4, tickDown))
                pen.line(pen.point(0.6, tickDown), pen.point(0.64, tickDown))
            }
        }
    }

    /// The whole park, unframed: home plate low, foul lines out to the fence
    /// and its warning track, the diamond enlarged so it reads at a glance,
    /// the mound, the infield arc and the batter's circle.
    private func drawDiamond(_ pen: inout MarkingPen) {
        let home = pen.point(0.5, 0.62)
        let fence = pen.width * 0.7
        let foul = fence / 2.squareRoot()
        pen.line(home, CGPoint(x: home.x + foul, y: home.y - foul))
        pen.line(home, CGPoint(x: home.x - foul, y: home.y - foul))
        pen.arc(center: home, radius: fence, from: -135, to: -45)
        pen.arc(center: home, radius: fence * 0.93, from: -135, to: -45)
        let half = pen.width * 0.2
        let bases = [
            CGPoint(x: home.x + half, y: home.y - half),
            CGPoint(x: home.x, y: home.y - half * 2),
            CGPoint(x: home.x - half, y: home.y - half)
        ]
        pen.path.addLines([home] + bases + [home])
        for base in bases {
            pen.path.addRect(CGRect(x: base.x - 5, y: base.y - 5, width: 10, height: 10))
        }
        let mound = CGPoint(x: home.x, y: home.y - half * 0.95)
        pen.circle(mound, radius: pen.width * 0.035)
        pen.arc(center: mound, radius: half * 1.45, from: -155, to: -25)
        pen.circle(home, radius: pen.width * 0.05)
    }

    private func drawTennis(_ pen: inout MarkingPen) {
        pen.path.addRect(pen.rect)
        pen.line(pen.point(0.125, 0), pen.point(0.125, 1))
        pen.line(pen.point(0.875, 0), pen.point(0.875, 1))
        pen.line(pen.point(-0.04, 0.5), pen.point(1.04, 0.5))
        pen.line(pen.point(0.125, 0.27), pen.point(0.875, 0.27))
        pen.line(pen.point(0.125, 0.73), pen.point(0.875, 0.73))
        pen.line(pen.point(0.5, 0.27), pen.point(0.5, 0.73))
        pen.line(pen.point(0.5, 0), pen.point(0.5, 0.02))
        pen.line(pen.point(0.5, 0.98), pen.point(0.5, 1))
    }
}

/// Draws in fractions of a rect: `point(0.5, 0.5)` is its centre.
private struct MarkingPen {
    let rect: CGRect
    var path = Path()

    var width: CGFloat {
        rect.width
    }

    func point(_ across: Double, _ down: Double) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * across, y: rect.minY + rect.height * down)
    }

    func box(_ across: Double, _ down: Double, width boxWidth: Double, height boxHeight: Double) -> CGRect {
        CGRect(origin: point(across, down), size: CGSize(width: rect.width * boxWidth, height: rect.height * boxHeight))
    }

    mutating func line(_ start: CGPoint, _ end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)
    }

    mutating func circle(_ center: CGPoint, radius: CGFloat) {
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    mutating func dot(_ center: CGPoint) {
        circle(center, radius: 1.5)
    }

    /// An arc on its own, from `start` to `end` degrees (0° right, 90° down).
    mutating func arc(center: CGPoint, radius: CGFloat, from start: Double, to end: Double) {
        let radians = start * .pi / 180
        path.move(to: CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians)))
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
    }
}
