import Foundation

public enum CSVError: Error, Equatable {
    case empty
    case unmatchedQuote
}

public struct CSVDocument: Equatable {
    public var headers: [String]
    public var rows: [[String: String]]

    public init(headers: [String], rows: [[String: String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public enum CSVParser {
    /// RFC 4180-style parser. Quoted fields may contain commas and newlines. `""` is an escaped quote.
    public static func parse(_ text: String) throws -> CSVDocument {
        var source = text
        if source.hasPrefix("\u{feff}") {
            source.removeFirst()
        }
        source = source.replacingOccurrences(of: "\r\n", with: "\n")
        source = source.replacingOccurrences(of: "\r", with: "\n")
        if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CSVError.empty
        }

        var table: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if inQuotes {
                if character == "\"" {
                    let next = source.index(after: index)
                    if next < source.endIndex, source[next] == "\"" {
                        field.append("\"")
                        index = source.index(after: next)
                    } else {
                        inQuotes = false
                        index = next
                    }
                } else {
                    field.append(character)
                    index = source.index(after: index)
                }
                continue
            }

            if character == "\"" {
                inQuotes = true
                index = source.index(after: index)
            } else if character == "," {
                row.append(field)
                field = ""
                index = source.index(after: index)
            } else if character == "\n" {
                row.append(field)
                field = ""
                table.append(row)
                row = []
                index = source.index(after: index)
            } else {
                field.append(character)
                index = source.index(after: index)
            }
        }

        if inQuotes {
            throw CSVError.unmatchedQuote
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            table.append(row)
        }

        while let last = table.last, last.allSatisfy({ $0.isEmpty }) {
            table.removeLast()
        }
        guard let headerRow = table.first else { throw CSVError.empty }

        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard headers.contains(where: { !$0.isEmpty }) else { throw CSVError.empty }

        var records: [[String: String]] = []
        for raw in table.dropFirst() {
            if raw.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }
            var record: [String: String] = [:]
            for (offset, header) in headers.enumerated() where !header.isEmpty {
                if record[header] == nil {
                    record[header] = offset < raw.count ? raw[offset] : ""
                }
            }
            records.append(record)
        }
        return CSVDocument(headers: headers, rows: records)
    }
}
