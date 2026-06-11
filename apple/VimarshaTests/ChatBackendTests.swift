import Foundation
import Testing
@testable import Vimarsha

/// V32 — the `/chat` + `/speak` wire contract: the JSON request the client builds must
/// match the backend's `ChatRequest`/`SpeakRequest` pydantic models exactly (camelCase
/// aliases `figureCaption`/`bookTitle`/`chapterTitle`; no key remapping).
struct ChatBackendTests {
    private let base = URL(string: "http://localhost:8000")!

    @Test func chatRequestMatchesBackendContract() throws {
        let request = try URLSessionBackendClient.jsonRequest(
            url: base.appending(path: "chat"),
            body: ChatRequestBody(
                messages: [.user("What is entropy?"), .assistant("A measure."), .user("Why?")],
                context: ChatContextDTO(
                    passage: "The passage.", figureCaption: "Figure 2",
                    bookTitle: "Book", chapterTitle: "Chapter"
                )
            )
        )
        #expect(request.url?.path() == "/chat")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = json["messages"] as! [[String: Any]]
        #expect(messages.count == 3)
        #expect(messages[0]["role"] as? String == "user")
        #expect(messages[0]["text"] as? String == "What is entropy?")
        #expect(messages[1]["role"] as? String == "assistant")
        let context = json["context"] as! [String: Any]
        #expect(context["passage"] as? String == "The passage.")
        #expect(context["figureCaption"] as? String == "Figure 2")
        #expect(context["bookTitle"] as? String == "Book")
        #expect(context["chapterTitle"] as? String == "Chapter")
    }

    @Test func chatContextOmitsAbsentFigureCaption() throws {
        let request = try URLSessionBackendClient.jsonRequest(
            url: base.appending(path: "chat"),
            body: ChatRequestBody(
                messages: [.user("Q")],
                context: ChatContextDTO(passage: "P", bookTitle: "B", chapterTitle: "C")
            )
        )
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let context = json["context"] as! [String: Any]
        #expect(context["figureCaption"] == nil)
    }

    @Test func chatReplyDecodes() throws {
        let data = Data(#"{"reply": "Grounded answer."}"#.utf8)
        let decoded = try JSONDecoder().decode(ChatReplyResponse.self, from: data)
        #expect(decoded.reply == "Grounded answer.")
    }

    @Test func speakRequestMatchesBackendContract() throws {
        let request = try URLSessionBackendClient.jsonRequest(
            url: base.appending(path: "speak"), body: SpeakRequestBody(text: "Read me.")
        )
        #expect(request.url?.path() == "/speak")
        #expect(request.httpMethod == "POST")
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(json["text"] as? String == "Read me.")
        #expect(json.count == 1)
    }
}
