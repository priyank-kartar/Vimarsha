# Plan 6a — Conversation Data Layer: LLM Seam, /chat, /speak, ChatRepository (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything the deep-dive conversation needs minus the UI: a backend LLM seam + `/chat`, a `/speak` endpoint, client `BackendClient.chat`/`speak`, the chat models, a `ChatThreads`/`ChatLines` schema + `ChatRepository` (save-on-demand), and the in-memory `ChatController`.

**Architecture:** Backend gains an `LlmClient` seam (`OllamaLlmClient` over httpx) behind `get_llm()`, a `POST /chat` (grounded prompt → LLM → reply), and a `POST /speak` (Chatterbox → MP3). The client gets `chat`/`speak`, freezed `ChatMessage`/`ChatContext`, persistence tables + `ChatRepository` (insert a new thread only on Save), and a `ChatController` that holds the live conversation in memory and snapshots the passage per message.

**Tech Stack:** Backend: FastAPI, httpx (already a dep), faster/chatterbox via `[tts]`, pytest. Client: Flutter, Riverpod, drift, dio, freezed. Ollama runs as a separate local process (not bundled).

**Prerequisite:** Plans 1–5b merged. Spec: `docs/superpowers/specs/2026-06-10-vimarsha-deep-dive-conversation-design.md`.

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/conversation-data
```

---

## File Structure

```
backend/
  src/vimarsha/llm.py              # NEW: LlmClient protocol + OllamaLlmClient
  src/vimarsha/models.py           # + ChatMessageIn, ChatContextModel, ChatRequest, SpeakRequest
  src/vimarsha/server.py           # + get_llm + POST /chat + POST /speak
  tests/test_server_chat.py        # NEW (fake LlmClient)
  tests/test_server_speak.py       # NEW (FakeSynth)
app/
  lib/core/models/chat_message.dart   # NEW (freezed)
  lib/core/models/chat_context.dart    # NEW (freezed)
  lib/core/backend/backend_client.dart  # + chat, speak
  lib/core/backend/dio_backend_client.dart # + chat, speak
  lib/core/db/database.dart            # + ChatThreads, ChatLines + migration 2->3
  lib/features/chat/chat_repository.dart # NEW
  lib/features/chat/chat_controller.dart # NEW
  lib/core/providers.dart              # + chatRepositoryProvider
  test/support/fake_backend_client.dart # + chat, speak
  test/core/backend/dio_backend_client_test.dart # + chat, speak tests
  test/core/db/database_test.dart       # + 2->3 migration + chat insert tests
  test/features/chat/chat_repository_test.dart  # NEW
  test/features/chat/chat_controller_test.dart  # NEW
```

---

## Task 1: Backend — LLM seam + `POST /chat`

**Files:** Create `backend/src/vimarsha/llm.py`, `backend/tests/test_server_chat.py`; Modify `backend/src/vimarsha/models.py`, `backend/src/vimarsha/server.py`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server_chat.py
from fastapi.testclient import TestClient

from vimarsha.server import app, get_llm


class _FakeLlm:
    def __init__(self):
        self.last_system = None

    def reply(self, system: str, messages: list[dict]) -> str:
        self.last_system = system
        return "the passage says the team trusted each other"


def test_chat_returns_grounded_reply():
    fake = _FakeLlm()
    app.dependency_overrides[get_llm] = lambda: fake
    client = TestClient(app)
    resp = client.post("/chat", json={
        "messages": [{"role": "user", "text": "what is this about?"}],
        "context": {
            "passage": "The team trusted each other completely.",
            "bookTitle": "The Culture Code",
            "chapterTitle": "The Christmas Truce",
        },
    })
    assert resp.status_code == 200
    assert resp.json() == {"reply": "the passage says the team trusted each other"}
    # the passage is grounded into the system prompt
    assert "The team trusted each other completely." in fake.last_system
    app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server_chat.py -v`
Expected: FAIL — `cannot import name 'get_llm'` / 404 on `/chat`.

- [ ] **Step 3: Write `backend/src/vimarsha/llm.py`**

```python
from __future__ import annotations

from typing import Protocol


class LlmClient(Protocol):
    def reply(self, system: str, messages: list[dict]) -> str:
        """Return the assistant reply for a system prompt + chat messages
        (each {'role': 'user'|'assistant', 'content': str})."""
        ...


class OllamaLlmClient:
    """Talks to a local Ollama server. Run `ollama serve` and
    `ollama pull llama3.2:3b` first."""

    def __init__(
        self,
        model: str = "llama3.2:3b",
        base_url: str = "http://localhost:11434",
    ):
        self._model = model
        self._base = base_url

    def reply(self, system: str, messages: list[dict]) -> str:
        import httpx

        payload = {
            "model": self._model,
            "messages": [{"role": "system", "content": system}] + messages,
            "stream": False,
        }
        resp = httpx.post(f"{self._base}/api/chat", json=payload, timeout=120.0)
        resp.raise_for_status()
        return resp.json()["message"]["content"].strip()
```

- [ ] **Step 4: Add chat models to `backend/src/vimarsha/models.py`**

Append:

```python
class ChatMessageIn(BaseModel):
    role: str
    text: str


class ChatContextModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    passage: str
    figure_caption: Optional[str] = Field(default=None, alias="figureCaption")
    book_title: str = Field(alias="bookTitle")
    chapter_title: str = Field(alias="chapterTitle")


class ChatRequest(BaseModel):
    messages: list[ChatMessageIn]
    context: ChatContextModel


class SpeakRequest(BaseModel):
    text: str
```

- [ ] **Step 5: Add `get_llm` + `/chat` to `backend/src/vimarsha/server.py`**

Add imports (merge):

```python
from vimarsha.llm import LlmClient, OllamaLlmClient
from vimarsha.models import ChatRequest, ChatContextModel, SpeakRequest
```

Add the cached factory, a prompt builder, and the route:

```python
_llm: LlmClient | None = None


def get_llm() -> LlmClient:
    """Cached Ollama client; overridden in tests."""
    global _llm
    if _llm is None:
        _llm = OllamaLlmClient()
    return _llm


def _chat_system(ctx: ChatContextModel) -> str:
    fig = f"\nA figure on screen is captioned: {ctx.figure_caption}" if ctx.figure_caption else ""
    return (
        f"You are a thoughtful reading companion discussing "
        f"\"{ctx.book_title}\" — chapter \"{ctx.chapter_title}\".\n"
        f"The reader is currently on this passage:\n\"\"\"\n{ctx.passage}\n\"\"\"{fig}\n"
        f"Answer their questions about it clearly and concisely. Ground your "
        f"answer in this passage; if it isn't covered, say so briefly."
    )


@app.post("/chat")
async def chat(req: ChatRequest, llm: LlmClient = Depends(get_llm)):
    system = _chat_system(req.context)
    messages = [{"role": m.role, "content": m.text} for m in req.messages]
    reply = await run_in_threadpool(llm.reply, system, messages)
    return {"reply": reply}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server_chat.py -v`
Expected: PASS.

- [ ] **Step 7: Full backend suite**

Run: `cd backend && uv run pytest`
Expected: all pass (prior 51 + 1 = 52).

- [ ] **Step 8: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/src/vimarsha/llm.py backend/src/vimarsha/models.py backend/src/vimarsha/server.py backend/tests/test_server_chat.py
git commit -m "feat: LLM seam (Ollama) + POST /chat grounded on the passage (Plan 6a Task 1)"
```

---

## Task 2: Backend — `POST /speak`

**Files:** Create `backend/tests/test_server_speak.py`; Modify `backend/src/vimarsha/server.py`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server_speak.py
import subprocess

from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.fakes import FakeSynth


def test_speak_returns_mp3(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    client = TestClient(app)
    resp = client.post("/speak", json={"text": "Hello there, reader."})
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "audio/mpeg"
    out = tmp_path / "reply.mp3"
    out.write_bytes(resp.content)
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(out)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    assert float(dur) > 0
    app.dependency_overrides.clear()


def test_speak_rejects_empty_text():
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    client = TestClient(app)
    assert client.post("/speak", json={"text": "   "}).status_code == 400
    app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server_speak.py -v`
Expected: FAIL — 404 on `/speak`.

- [ ] **Step 3: Add `/speak` to `backend/src/vimarsha/server.py`**

Add imports (merge):

```python
import os

import numpy as np
from starlette.background import BackgroundTask

from vimarsha.audio_io import write_mp3
from vimarsha.stitch import assemble
from vimarsha.tts import chunk_text
```

Add the route:

```python
@app.post("/speak")
async def speak(req: SpeakRequest, synth: Synthesizer = Depends(get_synth)):
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="empty text")

    def _render() -> str:
        wav = np.concatenate([synth.synthesize(c) for c in chunk_text(req.text)])
        full, _timings = assemble([("reply", wav)], synth.sample_rate, 0)
        out = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        out.close()
        write_mp3(full, synth.sample_rate, out.name)
        return out.name

    path = await run_in_threadpool(_render)
    return FileResponse(
        path, media_type="audio/mpeg", background=BackgroundTask(os.remove, path)
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server_speak.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Full backend suite**

Run: `cd backend && uv run pytest`
Expected: all pass (54 total).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/src/vimarsha/server.py backend/tests/test_server_speak.py
git commit -m "feat: POST /speak (Chatterbox TTS of arbitrary text) (Plan 6a Task 2)"
```

---

## Task 3: Client — chat models + `BackendClient.chat`/`speak`

**Files:** Create `chat_message.dart`, `chat_context.dart`; Modify
`backend_client.dart`, `dio_backend_client.dart`,
`test/support/fake_backend_client.dart`, `dio_backend_client_test.dart`.

- [ ] **Step 1: Write `app/lib/core/models/chat_message.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String role, // 'user' | 'assistant'
    required String text,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
```

- [ ] **Step 2: Write `app/lib/core/models/chat_context.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_context.freezed.dart';
part 'chat_context.g.dart';

@freezed
abstract class ChatContext with _$ChatContext {
  const factory ChatContext({
    required String passage,
    String? figureCaption,
    required String bookTitle,
    required String chapterTitle,
  }) = _ChatContext;

  factory ChatContext.fromJson(Map<String, dynamic> json) =>
      _$ChatContextFromJson(json);
}
```

- [ ] **Step 3: Add to the interface `app/lib/core/backend/backend_client.dart`**

Add the import + methods:

```dart
import '../models/chat_message.dart';
import '../models/chat_context.dart';
```

```dart
  /// Ask the LLM, grounded in [context], given the running conversation.
  Future<String> chat(List<ChatMessage> messages, ChatContext context);

  /// Synthesize [text] to speech; returns MP3 bytes.
  Future<List<int>> speak(String text);
```

- [ ] **Step 4: Implement in `app/lib/core/backend/dio_backend_client.dart`**

```dart
  @override
  Future<String> chat(List<ChatMessage> messages, ChatContext context) async {
    final resp = await _dio.post('/chat', data: {
      'messages': messages.map((m) => m.toJson()).toList(),
      'context': context.toJson(),
    });
    return (resp.data as Map<String, dynamic>)['reply'] as String;
  }

  @override
  Future<List<int>> speak(String text) async {
    final resp = await _dio.post<List<int>>(
      '/speak',
      data: {'text': text},
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }
```

(Add `import '../models/chat_message.dart';` and `import '../models/chat_context.dart';` to the Dio impl.)

- [ ] **Step 5: Add to `app/test/support/fake_backend_client.dart`**

```dart
  String reply = 'a thoughtful answer';
  List<int> speech = const [137, 80, 78, 71];
  Object? throwOnChat;
  Object? throwOnSpeak;
  final List<List<ChatMessage>> chatCalls = [];

  @override
  Future<String> chat(List<ChatMessage> messages, ChatContext context) async {
    chatCalls.add(messages);
    if (throwOnChat != null) throw throwOnChat!;
    return reply;
  }

  @override
  Future<List<int>> speak(String text) async {
    if (throwOnSpeak != null) throw throwOnSpeak!;
    return speech;
  }
```

(Add `import 'package:vimarsha/core/models/chat_message.dart';` and
`import 'package:vimarsha/core/models/chat_context.dart';` to the fake.)

- [ ] **Step 6: Write the failing test**

Append to `app/test/core/backend/dio_backend_client_test.dart` (inside `main`;
add the two model imports at the top):

```dart
  test('chat posts /chat and returns the reply', () async {
    adapter.onPost(
      '/chat',
      (server) => server.reply(200, {'reply': 'because they trusted each other'}),
      data: Matchers.any,
    );
    final text = await client.chat(
      const [ChatMessage(role: 'user', text: 'why?')],
      const ChatContext(
          passage: 'p', bookTitle: 'B', chapterTitle: 'C'),
    );
    expect(text, 'because they trusted each other');
  });

  test('speak posts /speak and returns bytes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = [137, 80, 78, 71, 13];
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..add(payload);
      req.response.close();
    });
    final realDio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    final bytes = await DioBackendClient(realDio).speak('hi');
    expect(bytes, payload);
  });
```

- [ ] **Step 7: Generate code + run tests**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2`
Then: `cd app && flutter test test/core/backend/dio_backend_client_test.dart 2>&1 | tail -3`
Expected: build succeeds; tests pass. `flutter analyze` clean.

- [ ] **Step 8: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/models/chat_message.dart app/lib/core/models/chat_context.dart app/lib/core/backend app/test/support/fake_backend_client.dart app/test/core/backend/dio_backend_client_test.dart
git commit -m "feat: ChatMessage/ChatContext + BackendClient.chat/speak (Plan 6a Task 3)"
```

---

## Task 4: Client — chat tables + migration + `ChatRepository`

**Files:** Modify `app/lib/core/db/database.dart`,
`app/test/core/db/database_test.dart`; Create
`app/lib/features/chat/chat_repository.dart`,
`app/test/features/chat/chat_repository_test.dart`; Modify `app/lib/core/providers.dart`.

- [ ] **Step 1: Write the failing DB test**

Append to `app/test/core/db/database_test.dart` (inside `main`):

```dart
  test('insert a chat thread + line', () async {
    await db.into(db.chatThreads).insert(ChatThreadsCompanion.insert(
        id: 't1', bookId: 'b1', chapterIndex: 0, title: const Value('Why trust?')));
    await db.into(db.chatLines).insert(ChatLinesCompanion.insert(
        id: 'l1', threadId: 't1', role: 'user', body: 'why?'));
    expect((await db.select(db.chatThreads).get()).single.title, 'Why trust?');
    expect((await db.select(db.chatLines).get()).single.body, 'why?');
  });
```

Add a migration test (append, alongside the existing v1->v2 one):

```dart
  test('upgrading a v2 database adds chat tables and preserves data', () async {
    final dir = Directory.systemTemp.createTempSync('mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v2.sqlite';
    final raw = sqlite3.open(path);
    raw.execute('CREATE TABLE books (id TEXT NOT NULL PRIMARY KEY, '
        "title TEXT NOT NULL, author TEXT NOT NULL DEFAULT '', "
        'epub_path TEXT NOT NULL, created_at INTEGER NOT NULL);');
    raw.execute('CREATE TABLE chapters (book_id TEXT NOT NULL, '
        'chapter_index INTEGER NOT NULL, chapter_id TEXT NOT NULL, '
        "title TEXT NOT NULL, download_status TEXT NOT NULL DEFAULT 'none', "
        'bundle_path TEXT, audio_path TEXT, duration_ms INTEGER, '
        'position_ms INTEGER NOT NULL DEFAULT 0, '
        'PRIMARY KEY (book_id, chapter_index));');
    raw.execute('CREATE TABLE memos (id TEXT NOT NULL PRIMARY KEY, '
        'book_id TEXT NOT NULL, chapter_index INTEGER NOT NULL, block_id TEXT, '
        'position_ms INTEGER NOT NULL DEFAULT 0, audio_path TEXT NOT NULL, '
        "transcript TEXT, transcript_status TEXT NOT NULL DEFAULT 'pending', "
        'created_at INTEGER NOT NULL);');
    raw.execute("INSERT INTO books (id, title, author, epub_path, created_at) "
        "VALUES ('b1', 'Old Book', 'Ada', '/x', 1700000000);");
    raw.execute('PRAGMA user_version = 2;');
    raw.close();

    final migrated = AppDatabase(NativeDatabase(File(path)));
    addTearDown(migrated.close);
    await migrated.into(migrated.chatThreads).insert(
        ChatThreadsCompanion.insert(id: 't1', bookId: 'b1', chapterIndex: 0));
    expect((await migrated.select(migrated.chatThreads).get()).single.id, 't1');
    expect((await migrated.select(migrated.books).get()).single.title, 'Old Book');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -4`
Expected: FAIL — `chatThreads`/`chatLines` undefined.

- [ ] **Step 3: Update `app/lib/core/db/database.dart`**

Add the tables (after `Memos`):

```dart
class ChatThreads extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get anchorBlockId => text().nullable()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatLines extends Table {
  TextColumn get id => text()();
  TextColumn get threadId => text()();
  TextColumn get role => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Update the annotation, version, and migration:

```dart
@DriftDatabase(tables: [Books, Chapters, Memos, ChatThreads, ChatLines])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(memos);
          if (from < 3) {
            await m.createTable(chatThreads);
            await m.createTable(chatLines);
          }
        },
      );
}
```

- [ ] **Step 4: Generate code + run DB tests**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2`
Then: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -3`
Expected: build succeeds; DB tests pass.

- [ ] **Step 5: Write the failing `ChatRepository` test**

```dart
// app/test/features/chat/chat_repository_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chat_message.dart';
import 'package:vimarsha/features/chat/chat_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ChatRepository repo() => ChatRepository(db: db, idGen: () => 'thread1');

  test('saveThread persists a thread and its messages', () async {
    final id = await repo().saveThread(
      bookId: 'b1', chapterIndex: 2, anchorBlockId: 'p3', title: 'Why?',
      messages: const [
        ChatMessage(role: 'user', text: 'why did they trust?'),
        ChatMessage(role: 'assistant', text: 'because of safety'),
      ],
    );
    expect(id, 'thread1');
    final t = (await db.select(db.chatThreads).get()).single;
    expect(t.bookId, 'b1');
    expect(t.chapterIndex, 2);
    expect(t.title, 'Why?');
    final lines = await (db.select(db.chatLines)
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
        .get();
    expect(lines.map((l) => l.role).toList(), ['user', 'assistant']);
    expect(lines.first.body, 'why did they trust?');
  });

  test('each saveThread creates a new thread (multiple per chapter)', () async {
    var n = 0;
    final r = ChatRepository(db: db, idGen: () => 'th${n++}');
    await r.saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'a')]);
    await r.saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'b')]);
    expect((await db.select(db.chatThreads).get()).length, 2);
  });

  test('watchMessages returns a thread\'s lines; deleteThread clears both', () async {
    await repo().saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'hi')]);
    final lines = await repo().watchMessages('thread1').first;
    expect(lines, hasLength(1));
    await repo().deleteThread('thread1');
    expect(await db.select(db.chatThreads).get(), isEmpty);
    expect(await db.select(db.chatLines).get(), isEmpty);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd app && flutter test test/features/chat/chat_repository_test.dart 2>&1 | tail -4`
Expected: FAIL — `chat_repository.dart` does not exist.

- [ ] **Step 7: Write `app/lib/features/chat/chat_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/models/chat_message.dart';

/// Persistence for saved conversations. Threads + lines are written ONLY when
/// the user taps Save; each save creates a new thread.
class ChatRepository {
  ChatRepository({required AppDatabase db, String Function()? idGen})
      : _db = db,
        _idGen = idGen ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final String Function() _idGen;
  static const _uuid = Uuid();

  Future<String> saveThread({
    required String bookId,
    required int chapterIndex,
    String? anchorBlockId,
    String? title,
    required List<ChatMessage> messages,
  }) async {
    final threadId = _idGen();
    await _db.transaction(() async {
      await _db.into(_db.chatThreads).insert(ChatThreadsCompanion.insert(
            id: threadId,
            bookId: bookId,
            chapterIndex: chapterIndex,
            anchorBlockId: Value(anchorBlockId),
            title: Value(title),
          ));
      for (final m in messages) {
        await _db.into(_db.chatLines).insert(ChatLinesCompanion.insert(
              id: _uuid.v4(),
              threadId: threadId,
              role: m.role,
              body: m.text,
            ));
      }
    });
    return threadId;
  }

  Stream<List<ChatThread>> watchThreads() => (_db.select(_db.chatThreads)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<ChatLine>> watchMessages(String threadId) => (_db.select(_db.chatLines)
        ..where((l) => l.threadId.equals(threadId))
        ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
      .watch();

  Future<List<ChatLine>> getThreadMessages(String threadId) =>
      (_db.select(_db.chatLines)
            ..where((l) => l.threadId.equals(threadId))
            ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
          .get();

  Future<void> deleteThread(String threadId) async {
    await (_db.delete(_db.chatLines)..where((l) => l.threadId.equals(threadId))).go();
    await (_db.delete(_db.chatThreads)..where((t) => t.id.equals(threadId))).go();
  }
}
```

- [ ] **Step 8: Add `chatRepositoryProvider` to `app/lib/core/providers.dart`**

Add the import + provider:

```dart
import '../features/chat/chat_repository.dart';
```

```dart
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(db: ref.watch(databaseProvider)),
);
```

- [ ] **Step 9: Run tests**

Run: `cd app && flutter test test/features/chat/chat_repository_test.dart 2>&1 | tail -3`
Expected: PASS (3 tests).

- [ ] **Step 10: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/db/database.dart app/lib/features/chat/chat_repository.dart app/lib/core/providers.dart app/test/core/db/database_test.dart app/test/features/chat/chat_repository_test.dart
git commit -m "feat: ChatThreads/ChatLines + migration + ChatRepository (Plan 6a Task 4)"
```

---

## Task 5: Client — `ChatController` (live conversation)

**Files:** Create `app/lib/features/chat/chat_controller.dart`,
`app/test/features/chat/chat_controller_test.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/chat/chat_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/chat_context.dart';
import 'package:vimarsha/features/chat/chat_controller.dart';

import '../../support/fake_backend_client.dart';

ChatContext _ctx() => const ChatContext(
    passage: 'the team trusted each other', bookTitle: 'B', chapterTitle: 'C');

void main() {
  test('sendMessage appends the user turn then the assistant reply', () async {
    final backend = FakeBackendClient()..reply = 'because of psychological safety';
    final c = ChatController(backend: backend, contextSnapshot: _ctx);
    await c.sendMessage('why did they trust?');
    expect(c.messages.map((m) => m.role).toList(), ['user', 'assistant']);
    expect(c.messages.last.text, 'because of psychological safety');
    expect(c.sending, isFalse);
    expect(c.error, isFalse);
    // the backend received the user turn
    expect(backend.chatCalls.single.single.text, 'why did they trust?');
  });

  test('a backend failure flags error and keeps the user turn (retryable)', () async {
    final backend = FakeBackendClient()..throwOnChat = Exception('ollama down');
    final c = ChatController(backend: backend, contextSnapshot: _ctx);
    await c.sendMessage('why?');
    expect(c.messages, hasLength(1)); // just the user turn
    expect(c.error, isTrue);

    backend.throwOnChat = null;
    backend.reply = 'recovered answer';
    await c.retry();
    expect(c.error, isFalse);
    expect(c.messages.last.text, 'recovered answer');
  });

  test('context is snapshotted at send time', () async {
    var passage = 'first passage';
    final backend = FakeBackendClient();
    final c = ChatController(
        backend: backend,
        contextSnapshot: () => ChatContext(
            passage: passage, bookTitle: 'B', chapterTitle: 'C'));
    await c.sendMessage('q1');
    passage = 'later passage';
    await c.sendMessage('q2');
    // (the fake records messages, not context, but this proves the callback is
    // invoked per send without throwing as the live passage changes)
    expect(backend.chatCalls, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/chat/chat_controller_test.dart 2>&1 | tail -4`
Expected: FAIL — `chat_controller.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/chat/chat_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../core/backend/backend_client.dart';
import '../../core/models/chat_context.dart';
import '../../core/models/chat_message.dart';

/// Holds one live, in-memory conversation. Snapshots the passage context at each
/// send so grounding follows playback. Nothing is persisted here — saving is the
/// repository's job, on explicit user action.
class ChatController extends ChangeNotifier {
  ChatController({
    required BackendClient backend,
    required ChatContext Function() contextSnapshot,
  })  : _backend = backend,
        _contextSnapshot = contextSnapshot;

  final BackendClient _backend;
  final ChatContext Function() _contextSnapshot;

  final List<ChatMessage> messages = [];
  bool sending = false;
  bool error = false;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;
    messages.add(ChatMessage(role: 'user', text: trimmed));
    await _send();
  }

  /// Re-send after a failure (the last turn is the unanswered user message).
  Future<void> retry() async {
    if (sending) return;
    await _send();
  }

  Future<void> _send() async {
    sending = true;
    error = false;
    notifyListeners();
    try {
      final reply = await _backend.chat(List.of(messages), _contextSnapshot());
      messages.add(ChatMessage(role: 'assistant', text: reply));
    } catch (_) {
      error = true;
    } finally {
      sending = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/chat/chat_controller_test.dart 2>&1 | tail -3`
Expected: PASS (3 tests).

- [ ] **Step 5: Full app suite + analyze + backend**

Run: `cd app && flutter analyze 2>&1 | tail -2 && flutter test 2>&1 | tail -3`
Expected: `No issues found!`; all app tests pass.
Run: `cd backend && uv run pytest 2>&1 | tail -1` → 54 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/chat/chat_controller.dart app/test/features/chat/chat_controller_test.dart
git commit -m "feat: ChatController (in-memory live conversation, per-send context) (Plan 6a Task 5)"
```

---

## Self-Review

**Spec coverage (§2 backend, §3 client data/logic):**
- §2 LLM seam + `/chat` (grounded prompt) → Task 1. ✅
- §2 `/speak` (Chatterbox) → Task 2. ✅
- §3 `BackendClient.chat`/`speak` + `ChatMessage`/`ChatContext` → Task 3. ✅
- §3 `ChatThreads`/`ChatLines` + 2→3 migration + `ChatRepository` (save = new thread, watch, delete) → Task 4. ✅
- §3 `ChatController` (in-memory, per-send context snapshot, retry) → Task 5. ✅
- Discuss panel, record double-tap, Conversations screen → Plan 6b (out of scope). Noted.

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** `LlmClient.reply(system, messages)` matches the fake + `/chat`. Backend `ChatContextModel` aliases (`figureCaption`/`bookTitle`/`chapterTitle`) match the Dart `ChatContext` freezed fields + JSON. `BackendClient.chat(List<ChatMessage>, ChatContext) -> Future<String>` and `speak(String) -> Future<List<int>>` consistent across interface, Dio impl, fake, and `ChatController`. Drift tables named `ChatThreads`/`ChatLines` (rows `ChatThread`/`ChatLine`) to avoid colliding with the freezed `ChatMessage`. `ChatRepository.saveThread/watchThreads/watchMessages/getThreadMessages/deleteThread` consistent between source + tests; `idGen` injection for the thread id, `Uuid().v4()` for line ids. `ChatController` (`messages`, `sending`, `error`, `sendMessage`, `retry`) consistent between source + tests. Migration adds `chatThreads`/`chatLines` at `from < 3`, preserving the `from < 2` memos step.
