import Foundation

/// Loads the *user-owned*, natively decrypted Windows elements.fsc script.
/// Templates are the source of the real game's default object metadata,
/// rather than made-up categories based on CML field names. This reader
/// deliberately bundles no original FAKT_SCRIPT text or model bytes.
public enum CMOriginalElementsTemplateCatalog {
    public struct Template: Sendable {
        public let name: String
        public let defaultBits: Int?
        public let defaultFloat: Double?
        public let defaultSnapLength: Double?
        public let modelReferences: [String]
        public let attachedObjects: [String]
        public let originalProperties: [String: [String]]
    }

    public enum ParseError: Error {
        case malformedBraces, missingTemplates, missingScriptHeader
    }

    private final class Node {
        let name: String
        var properties: [String] = []
        var children: [Node] = []
        init(_ name: String) { self.name = name }
    }

    /// Field identifiers and values in original scripts are ASCII; optional
    /// CP1251 human-language comments are intentionally not interpreted here.
    public static func parse(decodedBytes data: Data) throws -> [String: Template] {
        guard data.starts(with: Data("//#FAKT_SCRIPT#".utf8)) else {
            throw ParseError.missingScriptHeader
        }
        let content = String(decoding: data, as: UTF8.self)
        let root = Node("__root__")
        var stack: [Node] = [root]
        var pending: String?

        for line in content.split(omittingEmptySubsequences: false,
                                  whereSeparator: \.isNewline) {
            let stripped = line.split(separator: "//", maxSplits: 1,
                                      omittingEmptySubsequences: false)[0]
            let text = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            if text == "{" {
                guard let title = pending else { throw ParseError.malformedBraces }
                let next = Node(title)
                stack[stack.count - 1].children.append(next)
                stack.append(next)
                pending = nil
            } else if text == "}" {
                guard stack.count > 1 else { throw ParseError.malformedBraces }
                if let pending {
                    stack[stack.count - 1].properties.append(pending)
                }
                pending = nil
                stack.removeLast()
            } else if text.hasSuffix("{") {
                if let pending {
                    stack[stack.count - 1].properties.append(pending)
                }
                let title = String(text.dropLast()).trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { throw ParseError.malformedBraces }
                let next = Node(title)
                stack[stack.count - 1].children.append(next)
                stack.append(next)
                pending = nil
            } else {
                if let pending {
                    stack[stack.count - 1].properties.append(pending)
                }
                pending = text
            }
        }
        guard stack.count == 1 else { throw ParseError.malformedBraces }
        guard let templatesRoot = root.children.first(where: { $0.name == "TEMPLATES" })
        else { throw ParseError.missingTemplates }

        var result: [String: Template] = [:]
        func walk(_ node: Node) {
            if node.name.hasPrefix("tmo_") && result[node.name] == nil {
                var props: [String: [String]] = [:]
                var models: [String] = []
                for line in node.properties {
                    let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                    guard let cmd = parts.first else { continue }
                    let key = String(cmd).uppercased()
                    let value = parts.count == 2
                        ? String(parts[1]).trimmingCharacters(in: .whitespaces)
                        : ""
                    props[key, default: []].append(value)
                    if key == "3DO", !value.isEmpty { models.append(value) }
                }
                for child in node.children where child.name.hasPrefix("3DO ") {
                    models.append(String(child.name.dropFirst(4)))
                }
                let bits = props["BITS"]?.first.flatMap { Int($0, radix: 2) }
                let float = props["VALF"]?.first.flatMap(Double.init)
                let snap = props["SV_LEN"]?.first.flatMap(Double.init)
                result[node.name] = Template(
                    name: node.name,
                    defaultBits: bits,
                    defaultFloat: float,
                    defaultSnapLength: snap,
                    modelReferences: Array(Set(models)).sorted(),
                    attachedObjects: node.children.filter { $0.name.hasPrefix("tmo_") }
                        .map(\.name),
                    originalProperties: props
                )
            }
            for child in node.children { walk(child) }
        }
        walk(templatesRoot)
        return result
    }
}