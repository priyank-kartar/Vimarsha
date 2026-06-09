import 'package:drift/drift.dart';

part 'database.g.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get epubPath => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterId => text()();
  TextColumn get title => text()();
  TextColumn get downloadStatus => text().withDefault(const Constant('none'))();
  TextColumn get bundlePath => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bookId, chapterIndex};
}

class Memos extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get blockId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  TextColumn get audioPath => text()();
  TextColumn get transcript => text().nullable()();
  TextColumn get transcriptStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Books, Chapters, Memos])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(memos);
        },
      );
}
