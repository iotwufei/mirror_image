import QuartzCore
import CoreGraphics

extension CALayer {

    func setImage(_ image: CGImage, aspectFitIn bounds: CGRect) {
        contents = image
        contentsGravity = .resizeAspect
        masksToBounds = true
        frame = bounds
    }

    func setImageContentRect(for targetFrame: CGRect, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            frame = targetFrame
            return
        }

        let imageAspect = imageSize.width / imageSize.height
        let frameAspect = targetFrame.width / targetFrame.height

        var contentRect = CGRect(x: 0, y: 0, width: 1, height: 1)

        if imageAspect > frameAspect {
            let visibleWidth = frameAspect / imageAspect
            contentRect = CGRect(
                x: (1 - visibleWidth) / 2,
                y: 0,
                width: visibleWidth,
                height: 1
            )
        } else {
            let visibleHeight = imageAspect / frameAspect
            contentRect = CGRect(
                x: 0,
                y: (1 - visibleHeight) / 2,
                width: 1,
                height: visibleHeight
            )
        }

        contentsRect = contentRect
        contentsGravity = .resizeAspect
        frame = targetFrame
        masksToBounds = true
    }

    func createSublayerForImage(_ image: CGImage, frame targetFrame: CGRect) -> CALayer {
        let layer = CALayer()
        layer.contents = image
        layer.contentsGravity = .resizeAspect
        layer.masksToBounds = true
        layer.frame = targetFrame
        return layer
    }
}
