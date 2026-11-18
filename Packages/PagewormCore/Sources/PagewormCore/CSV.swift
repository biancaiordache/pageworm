import Foundation

public struct CSVTable: Equatable, Sendable {
    public var headers: [String]
    public var rows: [[String: String]]

    public init(headers: [String], rows: [[String: String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public enum CSVDecoder {
    /// RFC 4180-ish parser. Handles quoted commas, escaped quotes, and newlines inside quotes.
    /// Delimiter is comma unless the header row clearly uses semicolons.
    public static func parse(_ text: String) -> CSVTable {
        let stripped = text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text
        let delimiter = detectDelimiter(stripped)
        let records = parseRecords(stripped, delimiter: delimiter)
        guard let headerRecord = records.first else {
            return CSVTable(headers: [], rows: [])
        }
        let headers = headerRecord.map(normalizeHeader)
        var rows: [[String: String]] = []
        rows.reserveCapacity(max(0, records.count - 1))
        for record in records.dropFirst() {
            if record.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() where !header.isEmpty {
                if index < record.count {
                    row[header] = record[index]
                }
            }
            rows.append(row)
        }
        return CSVTable(headers: headers, rows: rows)
    }

    public static func normalizeHeader(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{feff}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func detectDelimiter(_ text: String) -> Character {
        var inQuotes = false
        var commas = 0
        var semicolons = 0
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if inQuotes, next < text.endIndex, text[next] == "\"" {
                    index = text.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if !inQuotes, character == "\n" || character == "\r" {
                break
            } else if !inQuotes, character == "," {
                commas += 1
            } else if !inQuotes, character == ";" {
                semicolons += 1
            }
            index = text.index(after: index)
        }
        return semicolons > commas ? ";" : ","
    }

    static func parseRecords(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func finishField() {
            record.append(field)
            field = ""
        }

        func finishRecord() {
            finishField()
            if !(record.count == 1 && record[0].isEmpty) {
                records.append(record)
            }
            record = []
        }

        while index < text.endIndex {
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                    index = text.index(after: index)
                    continue
                }
                field.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "\"" && field.trimmingCharacters(in: .whitespaces).isEmpty {
                field = ""
                inQuotes = true
                index = text.index(after: index)
                continue
            }

            if character == delimiter {
                finishField()
                index = text.index(after: index)
                continue
            }

            if character == "\n" {
                finishRecord()
                index = text.index(after: index)
                continue
            }

            if character == "\r" {
                finishRecord()
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    index = text.index(after: next)
                } else {
                    index = next
                }
                continue
            }

            field.append(character)
            index = text.index(after: index)
        }

        if inQuotes || !field.isEmpty || !record.isEmpty {
            finishRecord()
        }
        return records
    }
}
