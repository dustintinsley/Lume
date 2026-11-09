//
//  SwipeBackGesture.swift
//  Streamen
//
//  Keeps the edge swipe that goes back working on pages that hide the system
//  back button. The movie and series detail pages replace it with a glass
//  chevron over the hero, and `navigationBarBackButtonHidden(true)` also turns
//  off UIKit's interactive pop gesture, so on those pages only the button went
//  back. `swipeBackEnabled()` answers the gesture's delegate for the stack the
//  page is in, allowing it whenever there is a page to go back to.
//

import SwiftUI

extension View {
    /// Re-enables the edge swipe back on a page that hides its back button.
    func swipeBackEnabled() -> some View {
        #if os(iOS)
            background(SwipeBackEnabler().frame(width: 0, height: 0))
        #else
            self
        #endif
    }
}

#if os(iOS)
    import UIKit

    private struct SwipeBackEnabler: UIViewControllerRepresentable {
        func makeUIViewController(context _: Context) -> Controller {
            Controller()
        }

        func updateUIViewController(_: Controller, context _: Context) {}

        final class Controller: UIViewController {
            override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated)
                guard let navigationController, let gesture = navigationController.interactivePopGestureRecognizer
                else { return }
                gesture.delegate = PopGestureDelegate.shared
                gesture.isEnabled = true
            }
        }
    }

    /// Allows the pop gesture only with something to go back to: one on the
    /// root page leaves the stack unresponsive.
    private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
        static let shared = PopGestureDelegate()

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController = Self.navigationController(of: gestureRecognizer.view) else { return false }
            return navigationController.viewControllers.count > 1
        }

        private static func navigationController(of view: UIView?) -> UINavigationController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let navigationController = current as? UINavigationController { return navigationController }
                responder = current.next
            }
            return nil
        }
    }
#endif
