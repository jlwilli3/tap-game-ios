//
//  ContentView.swift
//  TapGame
//
//  Native SwiftUI endless jumper — neon arcade.
//

import SwiftUI
import UIKit

private enum Arcade {
    static let void = Color(red: 0.02, green: 0.02, blue: 0.06)
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.72)
    static let cyan = Color(red: 0.12, green: 0.96, blue: 0.98)
    static let violet = Color(red: 0.55, green: 0.28, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.28)

    /// Replace this string with your live Stripe Payment Link.
    static let stripePaymentLinkText = "https://buy.stripe.com/test_TapGameUnlockSkins"
    static var stripePaymentURL: URL {
        URL(string: stripePaymentLinkText) ?? URL(string: "https://buy.stripe.com")!
    }

    static let highScoreKey = "tapgame.highScore"
}

enum Screen {
    case menu
    case playing
    case gameOver
}

struct Obstacle: Identifiable {
    let id: UUID
    var x: CGFloat
    var width: CGFloat
    var height: CGFloat
    var scored: Bool
}

@Observable
@MainActor
final class GameEngine {
    var screen: Screen = .menu
    var playerY: CGFloat = 0
    var velocity: CGFloat = 0
    var obstacles: [Obstacle] = []
    var score: Int = 0
    var highScore: Int
    var flash: CGFloat = 0
    var pulse: CGFloat = 0

    private var lastDate: Date?
    private var spawnAccumulator: TimeInterval = 0
    private var nextSpawn: TimeInterval = 1.35
    private let gravity: CGFloat = 2_450
    private let jumpSpeed: CGFloat = 820
    private let playerSize: CGFloat = 38
    private let groundInset: CGFloat = 86
    private let playerX: CGFloat = 92

    init() {
        highScore = UserDefaults.standard.integer(forKey: Arcade.highScoreKey)
    }

    func startGame() {
        playerY = 0
        velocity = 0
        obstacles = []
        score = 0
        flash = 0
        lastDate = nil
        spawnAccumulator = 0
        nextSpawn = 1.25
        screen = .playing
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func returnToMenu() {
        screen = .menu
        lastDate = nil
    }

    func jump() {
        guard screen == .playing else { return }
        guard playerY <= 1 else { return }
        velocity = jumpSpeed
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func tick(now: Date, size: CGSize) {
        pulse = CGFloat(now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4)

        guard screen == .playing, size.width > 0, size.height > 0 else {
            lastDate = now
            return
        }

        let dt = min(now.timeIntervalSince(lastDate ?? now), 1.0 / 30.0)
        lastDate = now
        guard dt > 0 else { return }

        flash = max(0, flash - CGFloat(dt) * 3.2)

        // playerY is height above the ground (positive = up on screen).
        velocity -= gravity * CGFloat(dt)
        playerY += velocity * CGFloat(dt)
        if playerY < 0 {
            playerY = 0
            velocity = 0
        }

        let speed = 260 + min(CGFloat(score) * 9.5, 280)
        spawnAccumulator += dt
        if spawnAccumulator >= nextSpawn {
            spawnAccumulator = 0
            nextSpawn = max(0.72, 1.38 - Double(score) * 0.028)
            let height = CGFloat.random(in: 34...78)
            obstacles.append(
                Obstacle(
                    id: UUID(),
                    x: size.width + 40,
                    width: CGFloat.random(in: 28...44),
                    height: height,
                    scored: false
                )
            )
        }

        let groundY = size.height - groundInset
        let playerRect = CGRect(
            x: playerX,
            y: groundY - playerSize - playerY,
            width: playerSize,
            height: playerSize
        )

        var next: [Obstacle] = []
        next.reserveCapacity(obstacles.count)
        for var obstacle in obstacles {
            obstacle.x -= speed * CGFloat(dt)
            let rect = CGRect(
                x: obstacle.x,
                y: groundY - obstacle.height,
                width: obstacle.width,
                height: obstacle.height
            )
            if playerRect.insetBy(dx: 6, dy: 6).intersects(rect) {
                gameOver()
                return
            }
            if !obstacle.scored, obstacle.x + obstacle.width < playerX {
                obstacle.scored = true
                score += 1
            }
            if obstacle.x + obstacle.width > -40 {
                next.append(obstacle)
            }
        }
        obstacles = next
    }

    func draw(in context: GraphicsContext, size: CGSize) {
        let groundY = size.height - groundInset

        drawBackdrop(context, size: size, groundY: groundY)
        drawGround(context, size: size, groundY: groundY)
        drawObstacles(context, groundY: groundY)
        drawPlayer(context, groundY: groundY)

        if flash > 0 {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Arcade.pink.opacity(Double(flash) * 0.35))
            )
        }
    }

    private func gameOver() {
        screen = .gameOver
        flash = 1
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: Arcade.highScoreKey)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func drawBackdrop(_ context: GraphicsContext, size: CGSize, groundY: CGFloat) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Arcade.void))

        var sky = context
        sky.addFilter(.blur(radius: 40))
        sky.fill(
            Path(ellipseIn: CGRect(x: -80, y: -60, width: size.width * 0.7, height: 280)),
            with: .color(Arcade.violet.opacity(0.22))
        )
        sky.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.35, y: 40, width: size.width * 0.8, height: 240)),
            with: .color(Arcade.pink.opacity(0.12))
        )

        var grid = Path()
        let spacing: CGFloat = 36
        for x in stride(from: 0, through: size.width, by: spacing) {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: groundY))
        }
        for y in stride(from: 0, through: groundY, by: spacing) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(Arcade.cyan.opacity(0.06)), lineWidth: 1)

        var horizon = context
        horizon.addFilter(.blur(radius: 8))
        horizon.fill(
            Path(CGRect(x: 0, y: groundY - 10, width: size.width, height: 20)),
            with: .color(Arcade.cyan.opacity(0.35))
        )
    }

    private func drawGround(_ context: GraphicsContext, size: CGSize, groundY: CGFloat) {
        let floor = CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)
        context.fill(Path(floor), with: .color(Color(red: 0.04, green: 0.04, blue: 0.09)))

        var stripe = Path()
        stripe.move(to: CGPoint(x: 0, y: groundY))
        stripe.addLine(to: CGPoint(x: size.width, y: groundY))
        context.stroke(stripe, with: .color(Arcade.cyan), lineWidth: 3)

        var ticks = Path()
        for x in stride(from: 0, through: size.width, by: 22) {
            ticks.move(to: CGPoint(x: x, y: groundY))
            ticks.addLine(to: CGPoint(x: x, y: groundY + 10))
        }
        context.stroke(ticks, with: .color(Arcade.pink.opacity(0.45)), lineWidth: 1.5)
    }

    private func drawObstacles(_ context: GraphicsContext, groundY: CGFloat) {
        for obstacle in obstacles {
            let rect = CGRect(
                x: obstacle.x,
                y: groundY - obstacle.height,
                width: obstacle.width,
                height: obstacle.height
            )
            var glow = context
            glow.addFilter(.blur(radius: 12))
            glow.fill(Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 6), with: .color(Arcade.pink.opacity(0.55)))
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Arcade.pink))
            context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(.white.opacity(0.55)), lineWidth: 1.2)
        }
    }

    private func drawPlayer(_ context: GraphicsContext, groundY: CGFloat) {
        let rect = CGRect(
            x: playerX,
            y: groundY - playerSize - playerY,
            width: playerSize,
            height: playerSize
        )
        var glow = context
        glow.addFilter(.blur(radius: 16))
        glow.fill(Path(roundedRect: rect.insetBy(dx: -8, dy: -8), cornerRadius: 10), with: .color(Arcade.cyan.opacity(0.7)))
        context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Arcade.cyan))
        context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(.white.opacity(0.8)), lineWidth: 1.4)

        let visor = CGRect(x: rect.minX + 8, y: rect.minY + 10, width: 22, height: 8)
        context.fill(Path(roundedRect: visor, cornerRadius: 2), with: .color(Arcade.void.opacity(0.55)))
    }
}

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var showShop = false
    @State private var titlePulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let canvasSize = geo.size
                    let _ = engine.tick(now: timeline.date, size: canvasSize)
                    Canvas { context, size in
                        engine.draw(in: context, size: size)
                    }
                }

                VStack {
                    hud
                    Spacer()
                }
                .padding(.top, 18)

                switch engine.screen {
                case .menu:
                    menuOverlay
                case .playing:
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { engine.jump() }
                case .gameOver:
                    gameOverOverlay
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .sheet(isPresented: $showShop) {
            shopSheet
        }
        .onAppear { titlePulse = true }
    }

    private var hud: some View {
        HStack {
            scoreChip(title: "SCORE", value: engine.score, tint: Arcade.cyan)
            Spacer()
            scoreChip(title: "BEST", value: engine.highScore, tint: Arcade.gold)
        }
        .padding(.horizontal, 22)
        .opacity(engine.screen == .menu ? 0.55 : 1)
    }

    private func scoreChip(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(tint.opacity(0.7))
            Text("\(value)")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.8), radius: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var menuOverlay: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 10) {
                Text("TAPGAME")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Arcade.cyan, Arcade.pink, Arcade.violet],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Arcade.pink.opacity(0.7), radius: titlePulse ? 22 : 8)
                    .scaleEffect(titlePulse ? 1.03 : 1.0)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: titlePulse)

                Text("ENDLESS NEON RUN")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Arcade.cyan.opacity(0.75))

                Text("TAP ANYWHERE TO JUMP")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 4)
            }

            VStack(spacing: 14) {
                arcadeButton(title: "START GAME", tint: Arcade.cyan) {
                    engine.startGame()
                }
                arcadeButton(title: "UNLOCK SKINS", tint: Arcade.pink) {
                    showShop = true
                }
            }
            .padding(.horizontal, 36)

            Spacer()
            Text("BEST  \(engine.highScore)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Arcade.gold.opacity(0.9))
                .padding(.bottom, 36)
        }
        .background(
            LinearGradient(
                colors: [Arcade.void.opacity(0.15), Arcade.void.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("GAME OVER")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(Arcade.pink)
                .shadow(color: Arcade.pink, radius: 16)

            VStack(spacing: 6) {
                Text("SCORE  \(engine.score)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Arcade.cyan)
                Text("BEST  \(engine.highScore)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Arcade.gold)
            }

            VStack(spacing: 12) {
                arcadeButton(title: "PLAY AGAIN", tint: Arcade.cyan) {
                    engine.startGame()
                }
                arcadeButton(title: "MAIN MENU", tint: Arcade.violet) {
                    engine.returnToMenu()
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .background(Arcade.void.opacity(0.55).ignoresSafeArea())
    }

    private var shopSheet: some View {
        NavigationStack {
            ZStack {
                Arcade.void.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("PREMIUM SKINS")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Arcade.pink)

                    HStack(spacing: 16) {
                        skinSwatch(Arcade.cyan, name: "ION")
                        skinSwatch(Arcade.pink, name: "PULSE")
                        skinSwatch(Arcade.gold, name: "ARC")
                    }

                    Text("Unlock neon player skins with a one-tap checkout.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Link(destination: Arcade.stripePaymentURL) {
                        Text("UNLOCK SKINS")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(Arcade.void)
                            .background(Arcade.pink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Arcade.pink.opacity(0.65), radius: 16)
                    }
                    .padding(.horizontal, 8)

                    Text(Arcade.stripePaymentLinkText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Arcade.cyan.opacity(0.8))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
                .padding(28)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showShop = false }
                        .foregroundStyle(Arcade.cyan)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func skinSwatch(_ color: Color, name: String) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 64, height: 64)
                .shadow(color: color.opacity(0.8), radius: 12)
            Text(name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func arcadeButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .tracking(2.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint, lineWidth: 1.6)
                )
                .shadow(color: tint.opacity(0.55), radius: 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
