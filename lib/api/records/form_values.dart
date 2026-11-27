/// Values a blueprint form holds, keyed by field name:
///
/// - text / dropdown / radio → `String?`
/// - checkBox → `bool`
/// - fileUpload → [FileFieldValue]
/// - repeatableGroup → `List<GroupRow>`
/// - nonrepeatableGroup → [GroupRow]
typedef FormValues = Map<String, dynamic>;

/// A file the user picked (e.g. from file_picker's PlatformFile).
/// Provide [bytes] (works on web) or [path].
class PickedFile {
  const PickedFile(
      {required this.name, required this.size, this.bytes, this.path});

  final String name;
  final int size;
  final List<int>? bytes;
  final String? path;

  /// Lower case, without the dot.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Images already on the server that are still kept, plus new picks.
class FileFieldValue {
  FileFieldValue({List<String>? keptUrls, List<PickedFile>? newFiles})
      : keptUrls = keptUrls ?? [],
        newFiles = newFiles ?? [];

  final List<String> keptUrls;
  final List<PickedFile> newFiles;

  bool get isEmpty => keptUrls.isEmpty && newFiles.isEmpty;
  int get count => keptUrls.length + newFiles.length;
}

/// One row of a group. [fromServer] rows report their kept image URLs;
/// new rows leave file children out of the JSON.
class GroupRow {
  GroupRow({required this.values, this.fromServer = false});

  final FormValues values;
  final bool fromServer;
}
