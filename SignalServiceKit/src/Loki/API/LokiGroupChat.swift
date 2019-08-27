
@objc(LKGroupChat)
public final class LokiGroupChat : NSObject {
    public let kind: Kind
    @objc public let server: String
    @objc public let displayName: String
    @objc public let isDeletable: Bool
    
    @objc public var id: String {
        switch kind {
        case .publicChat(let id): return "\(server).\(id)"
        case .rss(let customID): return "rss://\(customID)"
        }
    }
    
    @objc public var isRSS: Bool {
        switch kind {
        case .publicChat(let id): return false
        case .rss(let customID): return true
        }
    }
    
    @objc public var isPublicChat: Bool {
        switch kind {
        case .publicChat(let id): return true
        case .rss(let customID): return false
        }
    }
    
    public enum Kind { case publicChat(id: UInt), rss(customID: String) }
    
    // MARK: Initialization
    public init(kind: Kind, server: String, displayName: String, isDeletable: Bool) {
        self.kind = kind
        self.server = server
        self.displayName = displayName
        self.isDeletable = isDeletable
    }
    
    @objc public convenience init(kindAsString: String, id: String, server: String, displayName: String, isDeletable: Bool) {
        let kind: Kind
        switch kindAsString {
        case "publicChat": kind = .publicChat(id: UInt(id)!)
        case "rss": kind = .rss(customID: id)
        default: preconditionFailure()
        }
        self.init(kind: kind, server: server, displayName: displayName, isDeletable: isDeletable)
    }
    
    // MARK: Description
    override public var description: String { return "\(id) (\(displayName))" }
}
