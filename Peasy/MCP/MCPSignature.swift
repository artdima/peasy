import CryptoKit
import Foundation

/// The bridge and the app prove to each other that they hold the token without sending it,
/// so whatever takes the port while Peasy is closed never gets the token and can't answer for it.
nonisolated struct MCPSignature {
    static let timestampHeader = "Peasy-Timestamp"
    static let nonceHeader = "Peasy-Nonce"
    static let signatureHeader = "Peasy-Signature"
    /// How far a request's time may be off; the server remembers nonces for twice as long.
    static let window: TimeInterval = 60

    private let key: SymmetricKey

    init(token: String) {
        key = SymmetricKey(data: Data(token.utf8))
    }

    static func makeNonce() -> String {
        hex((0..<16).map { _ in UInt8.random(in: .min ... .max) })
    }

    func signRequest(_ body: Data, timestamp: String, nonce: String) -> String {
        sign(Self.message(["request", timestamp, nonce], body))
    }

    func isValidRequest(_ body: Data, timestamp: String, nonce: String, signature: String) -> Bool {
        isValid(signature, for: Self.message(["request", timestamp, nonce], body))
    }

    func signResponse(_ body: Data, nonce: String) -> String {
        sign(Self.message(["response", nonce], body))
    }

    func isValidResponse(_ body: Data, nonce: String, signature: String) -> Bool {
        isValid(signature, for: Self.message(["response", nonce], body))
    }

    private func sign(_ message: Data) -> String {
        Self.hex(HMAC<SHA256>.authenticationCode(for: message, using: key))
    }

    private func isValid(_ signature: String, for message: Data) -> Bool {
        guard let code = Self.bytes(hex: signature) else { return false }
        return HMAC<SHA256>.isValidAuthenticationCode(code, authenticating: message, using: key)
    }

    /// The label keeps a request's signature from passing for a reply's.
    private static func message(_ fields: [String], _ body: Data) -> Data {
        var message = Data(fields.joined(separator: "\n").utf8)
        message.append(0x0A)
        message.append(body)
        return message
    }

    static func hex(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func bytes(hex: String) -> Data? {
        let digits = Array(hex.utf8)
        guard digits.count.isMultiple(of: 2) else { return nil }
        var bytes = Data(capacity: digits.count / 2)
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(decoding: digits[index..<index + 2], as: UTF8.self), radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}
