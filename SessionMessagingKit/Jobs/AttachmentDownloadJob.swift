import Foundation
import SessionUtilitiesKit
import SignalCoreKit

public final class AttachmentDownloadJob : NSObject, Job, NSCoding { // NSObject/NSCoding conformance is needed for YapDatabase compatibility
    public let attachmentID: String
    public let tsMessageID: String
    public var delegate: JobDelegate?
    public var id: String?
    public var failureCount: UInt = 0
    public var isDeferred = false

    public enum Error : LocalizedError {
        case noAttachment
        case invalidURL

        public var errorDescription: String? {
            switch self {
            case .noAttachment: return "No such attachment."
            case .invalidURL: return "Invalid file URL."
            }
        }
    }

    // MARK: Settings
    public class var collection: String { return "AttachmentDownloadJobCollection" }
    public static let maxFailureCount: UInt = 20

    // MARK: Initialization
    public init(attachmentID: String, tsMessageID: String) {
        self.attachmentID = attachmentID
        self.tsMessageID = tsMessageID
    }

    // MARK: Coding
    public init?(coder: NSCoder) {
        guard let attachmentID = coder.decodeObject(forKey: "attachmentID") as! String?,
            let tsMessageID = coder.decodeObject(forKey: "tsIncomingMessageID") as! String?,
            let id = coder.decodeObject(forKey: "id") as! String?,
            let isDeferred = coder.decodeObject(forKey: "isDeferred") as! Bool? else { return nil }
        self.attachmentID = attachmentID
        self.tsMessageID = tsMessageID
        self.id = id
        self.failureCount = coder.decodeObject(forKey: "failureCount") as! UInt? ?? 0
        self.isDeferred = isDeferred
    }

    public func encode(with coder: NSCoder) {
        coder.encode(attachmentID, forKey: "attachmentID")
        coder.encode(tsMessageID, forKey: "tsIncomingMessageID")
        coder.encode(id, forKey: "id")
        coder.encode(failureCount, forKey: "failureCount")
        coder.encode(isDeferred, forKey: "isDeferred")
    }

    // MARK: Running
    public func execute() {
        guard !isDeferred else { return }
        if TSAttachment.fetch(uniqueId: attachmentID) is TSAttachmentStream {
            // FIXME: It's not clear * how * this happens, but apparently we can get to this point
            // from time to time with an already downloaded attachment.
            return handleSuccess()
        }
        guard let pointer = TSAttachment.fetch(uniqueId: attachmentID) as? TSAttachmentPointer else {
            return handleFailure(error: Error.noAttachment)
        }
        let storage = SNMessagingKitConfiguration.shared.storage
        storage.write(with: { transaction in
            storage.setAttachmentState(to: .downloading, for: pointer, associatedWith: self.tsMessageID, using: transaction)
        }, completion: { })
        let temporaryFilePath = URL(fileURLWithPath: OWSTemporaryDirectoryAccessibleAfterFirstAuth() + UUID().uuidString)
        let handleFailure: (Swift.Error) -> Void = { error in // Intentionally capture self
            OWSFileSystem.deleteFile(temporaryFilePath.absoluteString)
            if let error = error as? Error, case .noAttachment = error {
                storage.write(with: { transaction in
                    storage.setAttachmentState(to: .failed, for: pointer, associatedWith: self.tsMessageID, using: transaction)
                }, completion: { })
                self.handlePermanentFailure(error: error)
            } else if let error = error as? DotNetAPI.Error, case .parsingFailed = error {
                // No need to retry if the response is invalid. Most likely this means we (incorrectly)
                // got a "Cannot GET ..." error from the file server.
                storage.write(with: { transaction in
                    storage.setAttachmentState(to: .failed, for: pointer, associatedWith: self.tsMessageID, using: transaction)
                }, completion: { })
                self.handlePermanentFailure(error: error)
            } else {
                self.handleFailure(error: error)
            }
        }
        if let tsMessage = TSMessage.fetch(uniqueId: tsMessageID), let v2OpenGroup = storage.getV2OpenGroup(for: tsMessage.uniqueThreadId) {
            guard let fileAsString = pointer.downloadURL.split(separator: "/").last, let file = UInt64(fileAsString) else {
                return handleFailure(Error.invalidURL)
            }
            OpenGroupAPIV2.download(file, from: v2OpenGroup.room, on: v2OpenGroup.server).done(on: DispatchQueue.global(qos: .userInitiated)) { data in
                do {
                    try data.write(to: temporaryFilePath, options: .atomic)
                } catch {
                    return handleFailure(error)
                }
                let stream = TSAttachmentStream(pointer: pointer)
                do {
                    try stream.write(data)
                } catch {
                    return handleFailure(error)
                }
                OWSFileSystem.deleteFile(temporaryFilePath.absoluteString)
                storage.write { transaction in
                    storage.persist(stream, associatedWith: self.tsMessageID, using: transaction)
                }
            }.catch(on: DispatchQueue.global()) { error in
                handleFailure(error)
            }
        } else {
            FileServerAPI.downloadAttachment(from: pointer.downloadURL).done(on: DispatchQueue.global(qos: .userInitiated)) { data in
                do {
                    try data.write(to: temporaryFilePath, options: .atomic)
                } catch {
                    return handleFailure(error)
                }
                let plaintext: Data
                if let key = pointer.encryptionKey, let digest = pointer.digest {
                    do {
                        plaintext = try Cryptography.decryptAttachment(data, withKey: key, digest: digest, unpaddedSize: pointer.byteCount)
                    } catch {
                        return handleFailure(error)
                    }
                } else {
                    plaintext = data // Open group attachments are unencrypted
                }
                let stream = TSAttachmentStream(pointer: pointer)
                do {
                    try stream.write(plaintext)
                } catch {
                    return handleFailure(error)
                }
                OWSFileSystem.deleteFile(temporaryFilePath.absoluteString)
                storage.write { transaction in
                    storage.persist(stream, associatedWith: self.tsMessageID, using: transaction)
                }
            }.catch(on: DispatchQueue.global()) { error in
                handleFailure(error)
            }
        }
    }

    private func handleSuccess() {
        delegate?.handleJobSucceeded(self)
    }
    
    private func handlePermanentFailure(error: Swift.Error) {
        delegate?.handleJobFailedPermanently(self, with: error)
    }

    private func handleFailure(error: Swift.Error) {
        delegate?.handleJobFailed(self, with: error)
    }
}

