//
//  ThumbnailImageManager.swift
//  Scanley
//
//  Created by Claude on 2025-09-19.
//

import Foundation
import Photos
import UIKit

@MainActor
class ThumbnailImageManager: ObservableObject {
    static let shared = ThumbnailImageManager()

    private let imageManager = PHImageManager.default()
    private let cache = NSCache<NSString, UIImage>()
    private var assetCache: [String: PHAsset] = [:]
    private var activeRequests: [String: PHImageRequestID] = [:]

    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Cache up to 100 thumbnails
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit

        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    // MARK: - Public Methods

    func getCachedThumbnail(documentID: String) -> UIImage? {
        return cache.object(forKey: NSString(string: documentID))
    }

    func loadThumbnail(documentID: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = getCachedThumbnail(documentID: documentID) {
            return cachedImage
        }

        // Get PHAsset
        guard let asset = await getAsset(documentID: documentID) else {
            return nil
        }

        // Load image
        return await requestThumbnail(asset: asset, documentID: documentID)
    }

    func batchLoadThumbnails(documentIDs: [String]) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]

        // Separate cached and uncached items
        var uncachedIDs: [String] = []
        for documentID in documentIDs {
            if let cachedImage = getCachedThumbnail(documentID: documentID) {
                results[documentID] = cachedImage
            } else {
                uncachedIDs.append(documentID)
            }
        }

        // Batch fetch assets for uncached items
        if !uncachedIDs.isEmpty {
            let assets = await batchFetchAssets(documentIDs: uncachedIDs)

            // Load images for uncached items
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for documentID in uncachedIDs {
                    if let asset = assets[documentID] {
                        group.addTask {
                            let image = await self.requestThumbnail(asset: asset, documentID: documentID)
                            return (documentID, image)
                        }
                    }
                }

                for await (documentID, image) in group {
                    if let image = image {
                        results[documentID] = image
                    }
                }
            }
        }

        return results
    }

    func cancelRequest(documentID: String) {
        if let requestID = activeRequests.removeValue(forKey: documentID) {
            imageManager.cancelImageRequest(requestID)
        }
    }

    func cancelAllRequests() {
        for requestID in activeRequests.values {
            imageManager.cancelImageRequest(requestID)
        }
        activeRequests.removeAll()
    }

    // MARK: - Private Methods

    private func getAsset(documentID: String) async -> PHAsset? {
        // Check asset cache first
        if let cachedAsset = assetCache[documentID] {
            return cachedAsset
        }

        // Fetch from Photos library
        return await withCheckedContinuation { continuation in
            var hasResumed = false

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", documentID)

            DispatchQueue.global(qos: .userInitiated).async {
                let assets = PHAsset.fetchAssets(with: fetchOptions)
                let asset = assets.firstObject

                DispatchQueue.main.async {
                    guard !hasResumed else { return }
                    hasResumed = true

                    if let asset = asset {
                        self.assetCache[documentID] = asset
                    }
                    continuation.resume(returning: asset)
                }
            }
        }
    }

    private func batchFetchAssets(documentIDs: [String]) async -> [String: PHAsset] {
        return await withCheckedContinuation { continuation in
            var hasResumed = false

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "localIdentifier IN %@", documentIDs)

            DispatchQueue.global(qos: .userInitiated).async {
                let assets = PHAsset.fetchAssets(with: fetchOptions)
                var assetMap: [String: PHAsset] = [:]

                assets.enumerateObjects { asset, _, _ in
                    assetMap[asset.localIdentifier] = asset
                }

                DispatchQueue.main.async {
                    guard !hasResumed else { return }
                    hasResumed = true

                    // Update asset cache
                    for (documentID, asset) in assetMap {
                        self.assetCache[documentID] = asset
                    }

                    continuation.resume(returning: assetMap)
                }
            }
        }
    }

    private func requestThumbnail(asset: PHAsset, documentID: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            var hasResumed = false

            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .opportunistic
            requestOptions.isNetworkAccessAllowed = false
            requestOptions.resizeMode = .exact

            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: requestOptions
            ) { [weak self] image, info in
                DispatchQueue.main.async {
                    // Only resume continuation once
                    guard !hasResumed else { return }

                    // Check if this is the final result
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    let requestCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                    let requestError = info?[PHImageErrorKey] as? Error

                    // Resume for final result, error, or cancellation
                    let shouldResume = !isDegraded || requestCancelled || requestError != nil || isInCloud

                    if shouldResume {
                        hasResumed = true

                        // Remove from active requests
                        self?.activeRequests.removeValue(forKey: documentID)

                        // Cache the image if successful
                        if let image = image, requestError == nil, !requestCancelled {
                            let cost = Int(image.size.width * image.size.height * 4) // Rough memory cost
                            self?.cache.setObject(image, forKey: NSString(string: documentID), cost: cost)
                        }

                        continuation.resume(returning: image)
                    }
                }
            }

            // Track active request
            activeRequests[documentID] = requestID
        }
    }

    private func handleMemoryWarning() {
        // Clear all caches to free memory
        cache.removeAllObjects()

        // Clear asset cache for older items
        if assetCache.count > 50 {
            let keysToRemove = Array(assetCache.keys.dropFirst(25))
            for key in keysToRemove {
                assetCache.removeValue(forKey: key)
            }
        }

        print("🧹 ThumbnailImageManager: Cleared caches due to memory warning")
    }
}