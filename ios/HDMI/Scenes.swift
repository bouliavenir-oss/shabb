import SwiftUI
import AVFoundation

@main @MainActor class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = session.role == .windowExternalDisplayNonInteractive
            ? ExternalSceneDelegate.self : MainSceneDelegate.self
        return config
    }
}

@MainActor class MainSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: RootView(model: .shared))
        window.overrideUserInterfaceStyle = .dark
        self.window = window; window.makeKeyAndVisible()
    }
    func sceneDidEnterBackground(_ scene: UIScene) { AppModel.shared.engine.background() }
    func sceneDidBecomeActive(_ scene: UIScene) { AppModel.shared.engine.foreground() }
}

@MainActor class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(rootView: OutputView(engine: AppModel.shared.engine))
        self.window = window; window.isHidden = false
        AppModel.shared.externalConnected = true
        AppModel.shared.log.add("display", "Écran externe connecté")
    }
    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil; AppModel.shared.externalConnected = false
        AppModel.shared.log.add("display", "Écran externe déconnecté ; lecture locale maintenue")
    }
}

final class PlayerSurface: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerSurface {
        let view = PlayerSurface(); view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect; return view
    }
    func updateUIView(_ view: PlayerSurface, context: Context) { view.playerLayer.player = player }
    static func dismantleUIView(_ view: PlayerSurface, coordinator: ()) { view.playerLayer.player = nil }
}
struct OutputView: View {
    @ObservedObject var engine: PlaybackEngine
    var body: some View {
        ZStack {
            Color.black
            if !engine.isBlack { PlayerLayerView(player: engine.player) }
        }.ignoresSafeArea().statusBarHidden(true)
    }
}
