//
//  SwipeBackGesture.swift
//  Streamen
//
//  Keeps the edge swipe that goes back working on pages that hide the system
//  back button. The movie and series detail pages replace it with a glass
//  chevron over the hero, and `navigationBarBackButtonHidden(true)` also turns
//  off UIKit's interactive pop gesture, so on those pages only the button went
//  back. Answering the gesture's delegate here re-enables it on any pushed page.
//

#if os(iOS)
    import UIKit

    extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
        override open func viewDidLoad() {
            super.viewDidLoad()
            interactivePopGestureRecognizer?.delegate = self
        }

        /// Only with something to go back to: a pop gesture on the root page
        /// leaves the stack unresponsive.
        public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer === interactivePopGestureRecognizer ? viewControllers.count > 1 : true
        }
    }
#endif
