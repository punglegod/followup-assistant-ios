import Foundation

struct Customer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var contact = ""
    var product = ""
    var notes = ""
    var status = "咨询中"
    var createdAt = Date()
    var nextFollowUp: Date? = nil
    var history: [Visit] = []
}

struct Visit: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var result: String
}

struct Knowledge: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind = "问答"
    var question = ""
    var aliases = ""
    var answer = ""
    var product = ""
    var tags = ""
    var source = ""
    var updatedAt = Date()

    var fingerprint: String {
        [kind, question, product].map { Search.normalize($0) }.joined(separator: "|")
    }
}

struct Archive: Codable {
    var version = 1
    var customers: [Customer] = []
    var knowledge: [Knowledge] = []

    func validate() throws {
        guard version == 1 else { throw DataError.invalid("备份版本不受支持") }
        guard Set(customers.map(\.id)).count == customers.count,
              Set(knowledge.map(\.id)).count == knowledge.count else {
            throw DataError.invalid("备份中存在重复记录编号")
        }
        guard customers.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              knowledge.allSatisfy({ !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ["问答", "话术"].contains($0.kind) }) else {
            throw DataError.invalid("备份中有缺少必填内容的记录")
        }
    }
}

enum DataError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

enum Search {
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_CN"))
            .components(separatedBy: .whitespacesAndNewlines).joined()
    }

    static func score(_ entry: Knowledge, query: String) -> Int {
        let q = normalize(query)
        if q.isEmpty { return 1 }
        let title = normalize(entry.question)
        let aliases = normalize(entry.aliases)
        let other = normalize([entry.product, entry.tags, entry.answer].joined(separator: " "))
        if title == q { return 100 }
        if title.contains(q) || aliases.contains(q) { return 80 }
        if other.contains(q) { return 60 }
        // Two-character fragments permit related Chinese wording without inventing answers.
        let chars = Array(q)
        guard chars.count >= 2 else { return 0 }
        let fragments = Set((0..<(chars.count - 1)).map { String(chars[$0...($0 + 1)]) })
        let haystack = title + aliases + other
        let matches = fragments.filter { haystack.contains($0) }.count
        return Double(matches) / Double(fragments.count) >= 0.4 ? matches : 0
    }
}

enum CSV {
    static let headers = ["类型", "问题", "相似问法", "回答", "产品", "标签", "来源"]

    static func rows(_ input: String) throws -> [[String]] {
        let text = input.hasPrefix("\u{FEFF}") ? String(input.dropFirst()) : input
        let chars = Array(text)
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false, i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == "," {
                row.append(field); field = ""; closed = false
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                row.append(field)
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []; field = ""; closed = false
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else if c == "\"" && field.isEmpty && !closed {
                quoted = true
            } else {
                guard !closed && c != "\"" else { throw DataError.invalid("CSV 引号格式错误") }
                field.append(c)
            }
            i += 1
        }
        guard !quoted else { throw DataError.invalid("CSV 中存在未闭合的引号") }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    static func parse(_ text: String) throws -> [Knowledge] {
        let table = try rows(text)
        guard let header = table.first, header == headers else {
            throw DataError.invalid("表头应为：" + headers.joined(separator: ","))
        }
        guard table.count > 1 else { throw DataError.invalid("文件只有表头，没有问答内容") }
        return try table.dropFirst().enumerated().map { offset, row in
            guard row.count == headers.count else { throw DataError.invalid("第 \(offset + 2) 条记录列数不正确") }
            let cells = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard ["问答", "话术"].contains(cells[0]), !cells[1].isEmpty, !cells[3].isEmpty else {
                throw DataError.invalid("第 \(offset + 2) 条记录需要正确的类型、问题和回答")
            }
            return Knowledge(kind: cells[0], question: cells[1], aliases: cells[2], answer: cells[3], product: cells[4], tags: cells[5], source: cells[6])
        }
    }

    static func export(_ entries: [Knowledge]) -> String {
        func cell(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return "\u{FEFF}" + ([headers] + entries.map { [$0.kind, $0.question, $0.aliases, $0.answer, $0.product, $0.tags, $0.source] })
            .map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n")
    }
}
