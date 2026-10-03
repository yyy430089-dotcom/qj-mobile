// 所有 Rust 调用在同一串行队列中执行，文本副作用保持按键顺序。
import Foundation

final class EngineClient {
    private let queue = DispatchQueue(label: "app.qjmobile.engine", qos: .userInitiated)
    private var handle: UInt64 = 0
    private var initializationAttempted = false
    private let resourceBundle: Bundle
    #if BOOTSTRAP
    private var demoEnglish = true
    private var demoRevision: UInt64 = 0
    #endif

    init(resourceBundle: Bundle = .main) { self.resourceBundle = resourceBundle }

    func perform(_ command: [String: Any], completion: @escaping (EngineFrame?) -> Void) {
        queue.async { [self] in
            #if BOOTSTRAP
            demoRevision += 1
            let action = command["action"] as? String ?? ""
            if action == "toggle_language" { demoEnglish.toggle() }
            let committed = action == "input" ? (command["text"] as? String ?? "") :
                (action == "space" ? " " : (action == "enter" ? "\n" : ""))
            let frame = EngineFrame(revision: demoRevision, input: "", preedit: "", candidates: [],
                                    committed: committed, delete_backward: action == "backspace",
                                    english: true, error: nil, warning: "基础键盘验证包：暂未接入中文引擎")
            #else
            if !initializationAttempted {
                initializationAttempted = true
                if let dict = resourceBundle.path(forResource: "dict", ofType: "qj"),
                   let gloss = resourceBundle.path(forResource: "glossary-en", ofType: "qj") {
                    handle = dict.withCString { dictPointer in
                        gloss.withCString { qjm_create(dictPointer, $0) }
                    }
                }
            }
            guard handle != 0,
                  let data = try? JSONSerialization.data(withJSONObject: command),
                  let json = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let frame: EngineFrame? = json.withCString { jsonPointer in
                guard let pointer = qjm_dispatch(handle, jsonPointer) else { return nil }
                defer { qjm_string_free(pointer) }
                let data = Data(String(cString: pointer).utf8)
                return try? JSONDecoder().decode(EngineFrame.self, from: data)
            }
            #endif
            DispatchQueue.main.async { completion(frame) }
        }
    }

    deinit {
        #if !BOOTSTRAP
        let session = handle
        queue.async { if session != 0 { qjm_destroy(session) } }
        #endif
    }
}
