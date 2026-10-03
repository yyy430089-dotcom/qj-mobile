// 核心返回的候选及文本操作；候选和译词分两次显示。
import Foundation

struct EngineFrame: Decodable {
    struct Candidate: Decodable {
        let text: String
        let annotation: String?
    }
    let revision: UInt64
    let input: String
    let preedit: String
    let candidates: [Candidate]
    let committed: String
    let delete_backward: Bool
    let english: Bool
    let error: String?
    let warning: String?
}
