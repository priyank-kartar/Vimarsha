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

@DriftDatabase(tables: [Books, Chapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
