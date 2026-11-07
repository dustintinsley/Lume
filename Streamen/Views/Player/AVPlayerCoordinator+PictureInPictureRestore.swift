//
//  AVPlayerCoordinator+PictureInPictureRestore.swift
//  Streamen
//
//  PiP's restore button on iOS: a player page that stepped aside for PiP
//  (`PlayerPipParking`) comes back before the PiP window flies home.
//

#if os(iOS)
    import AVKit

    extension AVPlayerCoordinator {
        @objc(pictureInPictureController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)
        func pictureInPictureController(
            _: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            PlayerPipParking.shared.restoreParkedPage(completion: completionHandler)
        }
    }
#endif
