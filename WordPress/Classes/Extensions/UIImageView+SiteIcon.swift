import AlamofireImage
import AutomatticTracks
import Foundation
import Gridicons

/// UIImageView Helper Methods that allow us to download a SiteIcon, given a website's "Icon Path"
///
extension UIImageView {

    /// Default Settings
    ///
    struct SiteIconDefaults {
        /// Default SiteIcon's Image Size, in points.
        ///
        static let imageSize = CGSize(width: 40, height: 40)
    }

    /// Downloads the SiteIcon Image, hosted at the specified path. This method will attempt to optimize the URL, so that
    /// the download Image Size matches `imageSize`.
    ///
    /// TODO: This is a convenience method. Nuke me once we're all swifted.
    ///
    /// - Parameter path: SiteIcon's url (string encoded) to be downloaded.
    ///
    @objc
    func downloadSiteIcon(at path: String) {
        downloadSiteIcon(at: path, placeholderImage: .siteIconPlaceholder)
    }

    /// Downloads the SiteIcon Image, hosted at the specified path. This method will attempt to optimize the URL, so that
    /// the download Image Size matches `imageSize`.
    ///
    /// - Parameters:
    ///     - path: SiteIcon's url (string encoded) to be downloaded.
    ///     - imageSize: Request site icon in the specified image size.
    ///     - placeholderImage: Yes. It's the "place holder image", Sherlock.
    ///
    @objc
    func downloadSiteIcon(
        at path: String,
        imageSize: CGSize = SiteIconDefaults.imageSize,
        placeholderImage: UIImage?
    ) {
        guard let siteIconURL = optimizedURL(for: path, imageSize: imageSize) else {
            image = placeholderImage
            return
        }

        logURLOptimization(from: path, to: siteIconURL)

        let request = URLRequest(url: siteIconURL)
        downloadSiteIcon(with: request, imageSize: imageSize, placeholderImage: placeholderImage)
    }

    /// Downloads a SiteIcon image, using a specified request.
    ///
    /// - Parameters:
    ///     - request: The request for the SiteIcon.
    ///     - imageSize: Request site icon in the specified image size.
    ///     - placeholderImage: Yes. It's the "place holder image".
    ///
    private func downloadSiteIcon(
        with request: URLRequest,
        imageSize expectedSize: CGSize = SiteIconDefaults.imageSize,
        placeholderImage: UIImage?
    ) {
        af_setImage(withURLRequest: request, placeholderImage: placeholderImage, completion: { [weak self] dataResponse in
            switch dataResponse.result {
            case .success(let image):
                guard let self = self else {
                    return
                }

                // In `MediaRequesAuthenticator.authenticatedRequestForPrivateAtomicSiteThroughPhoton` we're
                // having to replace photon URLs for Atomic Private Sites, with a call to the Atomic Media Proxy
                // endpoint.  The downside of calling that endpoint is that it doesn't always return images of
                // the requested size.
                //
                // The following lines of code ensure that we resize the image to the default Site Icon size, to
                // ensure there is no UI breakage due to having larger images set here.
                //
                if image.size != expectedSize {
                    self.image = image.resizedImage(with: .scaleAspectFill, bounds: expectedSize, interpolationQuality: .default)
                } else {
                    self.image = image
                }

                self.removePlaceholderBorder()
            case .failure(let error):
                if case .requestCancelled = (error as? AFIError) {
                    // Do not log intentionally cancelled requests as errors.
                } else {
                    DDLogError(error.localizedDescription)
                }
            }
        })
    }

    /// Downloads the SiteIcon Image, associated to a given Blog. This method will attempt to optimize the URL, so that
    /// the download Image Size matches `imageSize`.
    ///
    /// - Parameters:
    ///     - blog: reference to the source blog
    ///     - placeholderImage: Yes. It's the "place holder image".
    ///
    @objc func downloadSiteIcon(
        for blog: Blog,
        imageSize: CGSize = SiteIconDefaults.imageSize,
        placeholderImage: UIImage? = .siteIconPlaceholder
    ) {
        guard let siteIconPath = blog.icon, let siteIconURL = optimizedURL(for: siteIconPath, imageSize: imageSize) else {

            if blog.isWPForTeams() && placeholderImage == .siteIconPlaceholder {
                image = UIImage.gridicon(.p2, size: imageSize)
                return
            }

            image = placeholderImage
            return
        }

        logURLOptimization(from: siteIconPath, to: siteIconURL, for: blog)

        let host = MediaHost(with: blog) { error in
            // We'll log the error, so we know it's there, but we won't halt execution.
            DDLogError(error.localizedDescription)
        }

        let mediaRequestAuthenticator = MediaRequestAuthenticator()
        mediaRequestAuthenticator.authenticatedRequest(
            for: siteIconURL,
            from: host,
            onComplete: { [weak self] request in
                self?.downloadSiteIcon(with: request, imageSize: imageSize, placeholderImage: placeholderImage)
        }) { error in
            DDLogError(error.localizedDescription)
        }
    }
}

// MARK: - Private Methods
//
extension UIImageView {
    /// Returns the Size Optimized URL for a given Path.
    ///
    func optimizedURL(for path: String, imageSize: CGSize = SiteIconDefaults.imageSize) -> URL? {
        if isPhotonURL(path) || isDotcomURL(path) {
            return optimizedDotcomURL(from: path, imageSize: imageSize)
        }

        if isBlavatarURL(path) {
            return optimizedBlavatarURL(from: path, imageSize: imageSize)
        }

        return optimizedPhotonURL(from: path, imageSize: imageSize)
    }

    // MARK: - Private Helpers

    /// Returns the download URL for a square icon with a size of `imageSize` in pixels.
    ///
    /// - Parameter path: SiteIcon URL (string encoded).
    ///
    private func optimizedDotcomURL(from path: String, imageSize: CGSize = SiteIconDefaults.imageSize) -> URL? {
        let size = imageSize.toPixels()
        let query = String(format: "w=%d&h=%d", Int(size.width), Int(size.height))

        return parseURL(path: path, query: query)
    }

    /// Returns the icon URL corresponding to the provided path
    ///
    /// - Parameter path: Blavatar URL (string encoded).
    ///
    private func optimizedBlavatarURL(from path: String, imageSize: CGSize = SiteIconDefaults.imageSize) -> URL? {
        let size = imageSize.toPixels()
        let query = String(format: "d=404&s=%d", Int(max(size.width, size.height)))

        return parseURL(path: path, query: query)
    }

    /// Returs the photon URL for the provided path
    ///
    /// - Parameter siteIconPath: SiteIcon URL (string encoded).
    ///
    private func optimizedPhotonURL(from path: String, imageSize: CGSize = SiteIconDefaults.imageSize) -> URL? {
        guard let url = URL(string: path) else {
            return nil
        }

        return PhotonImageURLHelper.photonURL(with: imageSize, forImageURL: url)
    }

    /// Indicates if the received URL is hosted at WordPress.com
    ///
    private func isDotcomURL(_ path: String) -> Bool {
        return path.contains(".files.wordpress.com")
    }

    /// Indicates if the received URL is hosted at Gravatar.com
    ///
    private func isBlavatarURL(_ path: String) -> Bool {
        return path.contains("gravatar.com/blavatar")
    }

    /// Indicates if the received URL is a Photon Endpoint
    /// Possible matches are "i0.wp.com", "i1.wp.com" & "i2.wp.com" -> https://developer.wordpress.com/docs/photon/
    ///
    private func isPhotonURL(_ path: String) -> Bool {
        return path.contains(".wp.com")
    }

    /// Attempts to parse the URL contained within a Path, with a given query. Returns nil on failure.
    ///
    private func parseURL(path: String, query: String) -> URL? {
        guard var components = URLComponents(string: path) else {
            return nil
        }

        components.query = query

        return components.url
    }
}

// MARK: - Border handling

@objc
extension UIImageView {

    func removePlaceholderBorder() {
        layer.borderColor = UIColor.clear.cgColor
    }
}

// MARK: - Logging Support

/// This is just a temporary extension to try and narrow down the caused behind this issue: https://sentry.io/share/issue/3da4662c65224346bb3a731c131df13d/
///
private extension UIImageView {

    private func logURLOptimization(from original: String, to optimized: URL) {
        DDLogInfo("URL optimized from \(original) to \(optimized.absoluteString)")
    }

    private func logURLOptimization(from original: String, to optimized: URL, for blog: Blog) {
        let blogInfo: String
        if blog.isAccessibleThroughWPCom() {
            blogInfo = "dot-com-accessible: \(blog.url ?? "unknown"), id: \(blog.dotComID ?? 0)"
        } else {
            blogInfo = "self-hosted with url: \(blog.url ?? "unknown")"
        }

        DDLogInfo("URL optimized from \(original) to \(optimized.absoluteString) for blog \(blogInfo)")
    }
}

// MARK: - CGFloat Extension

private extension CGSize {

    func toPixels() -> CGSize {
        return CGSize(width: width.toPixels(), height: height.toPixels())
    }
}

private extension CGFloat {

    func toPixels() -> CGFloat {
        return self * UIScreen.main.scale
    }
}
