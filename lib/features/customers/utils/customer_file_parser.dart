import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../mock/mock_contacts.dart';

// ponytail: bounded customer imports; split larger datasets into multiple files.
const _maxInputBytes = 16 * 1024 * 1024;
const _maxXmlBytes = 8 * 1024 * 1024;
const _maxTotalXmlBytes = 12 * 1024 * 1024;
const _maxRows = 50000;
const _maxColumns = 256;
const _maxCells = 500000;
const _maxCellCharacters = 65536;
const _limitMessage =
    'File vượt giới hạn nhập khách hàng / Customer import limit exceeded.';
const _invalidZip = 'File Excel không hợp lệ / Invalid Excel archive.';

enum ImportTargetField {
  ignore('Không nhập'),
  name('Họ và tên'),
  phone('Số điện thoại'),
  group('Nhóm khách hàng'),
  tag('Lĩnh vực / Nhãn'),
  status('Trạng thái'),
  custom('Thuộc tính tùy chỉnh');

  final String label;
  const ImportTargetField(this.label);
}

class ImportColumnMapping {
  final int sourceIndex;
  final String headerText;
  final String sampleValue;
  final ImportTargetField targetField;
  final String? customKey;

  const ImportColumnMapping({
    required this.sourceIndex,
    required this.headerText,
    required this.sampleValue,
    required this.targetField,
    this.customKey,
  });

  ImportColumnMapping copyWith({
    ImportTargetField? targetField,
    String? customKey,
    bool clearCustomKey = false,
  }) {
    return ImportColumnMapping(
      sourceIndex: sourceIndex,
      headerText: headerText,
      sampleValue: sampleValue,
      targetField: targetField ?? this.targetField,
      customKey: clearCustomKey ? null : (customKey ?? this.customKey),
    );
  }
}

class ImportedRowValidation {
  final int rowIndex;
  final Contact contact;
  final String? errorReason;
  final bool selected;

  const ImportedRowValidation({
    required this.rowIndex,
    required this.contact,
    this.errorReason,
    this.selected = true,
  });

  bool get hasError => errorReason != null;

  ImportedRowValidation copyWith({Contact? contact, bool? selected}) {
    final nextContact = contact ?? this.contact;
    return ImportedRowValidation(
      rowIndex: rowIndex,
      contact: nextContact,
      errorReason: validateImportedContact(nextContact),
      selected: selected ?? this.selected,
    );
  }
}

String? validateImportedContact(Contact contact) {
  if (contact.name.trim().isEmpty && contact.phone.trim().isEmpty) {
    return 'Thiếu cả họ tên và số điện thoại';
  }
  if (contact.phone.trim().isEmpty) {
    return 'Thiếu số điện thoại';
  }
  final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) {
    return 'Số điện thoại không hợp lệ (< 8 số)';
  }
  return null;
}

/// Parses `.csv`, `.tsv`, `.txt`, or `.xlsx` raw cell rows off the UI isolate
/// for interactive column mapping in [CustomerImportWizardDialog].
Future<List<List<String>>> parseCustomerRawRowsFile({
  String? path,
  Uint8List? bytes,
  required String fileName,
}) async {
  if (bytes != null && bytes.length > _maxInputBytes) {
    throw const FormatException(_limitMessage);
  }
  return Isolate.run(() async {
    final resolvedBytes = await _loadBoundedImportBytes(path: path, bytes: bytes);
    return parseCustomerRawRowsBytes(resolvedBytes, fileName);
  });
}

Future<Uint8List> _loadBoundedImportBytes({
  String? path,
  Uint8List? bytes,
}) async {
  if (path == null) {
    if (bytes == null) {
      throw const FormatException('Không đọc được file / Cannot read file.');
    }
    return bytes;
  }
  final file = await File(path).open();
  try {
    if (await file.length() > _maxInputBytes) {
      throw const FormatException(_limitMessage);
    }
    final content = BytesBuilder(copy: false);
    while (true) {
      final chunk = await file.read(64 * 1024);
      if (chunk.isEmpty) break;
      if (content.length + chunk.length > _maxInputBytes) {
        throw const FormatException(_limitMessage);
      }
      content.add(chunk);
    }
    return content.takeBytes();
  } finally {
    await file.close();
  }
}

/// Keeps file IO, decompression and parsing off the Flutter UI isolate.
Future<List<Contact>> parseCustomerImportFile({
  String? path,
  Uint8List? bytes,
  required String fileName,
}) async {
  if (bytes != null && bytes.length > _maxInputBytes) {
    throw const FormatException(_limitMessage);
  }
  return Isolate.run(() async {
    final resolvedBytes = await _loadBoundedImportBytes(path: path, bytes: bytes);
    return parseCustomerImportBytes(resolvedBytes, fileName);
  });
}

/// Parses raw rows from CSV/TSV/XLSX bytes without mapping into [Contact].
List<List<String>> parseCustomerRawRowsBytes(Uint8List bytes, String fileName) {
  if (bytes.length > _maxInputBytes) throw const FormatException(_limitMessage);
  final ext = fileName.toLowerCase().split('.').last;
  return ext == 'xlsx'
      ? _parseXlsxRows(bytes)
      : _parseDelimitedRows(_decodeText(bytes));
}

/// Parses `.csv`, `.tsv`, `.txt`, or `.xlsx` bytes into [Contact] records.
List<Contact> parseCustomerImportBytes(Uint8List bytes, String fileName) {
  final rows = parseCustomerRawRowsBytes(bytes, fileName);
  return _rowsToContacts(rows);
}

/// Auto-detects the most likely header row index among the first 10 rows,
/// or returns -1 when data begins immediately without headers.
int detectHeaderRowIndex(List<List<String>> rows) {
  if (rows.isEmpty) return -1;
  final limit = rows.length < 10 ? rows.length : 10;
  for (var r = 0; r < limit; r++) {
    final row = rows[r];
    for (final cell in row) {
      final norm = _normalizeHeader(cell);
      if (_nameHeaders.contains(norm) || _phoneHeaders.contains(norm)) {
        return r;
      }
    }
  }
  return -1;
}

/// Builds suggested column mappings for a chosen [headerRowIndex] (`-1` means
/// headerless table starting at row 0).
List<ImportColumnMapping> suggestImportMappings(
  List<List<String>> rows, {
  required int headerRowIndex,
}) {
  if (rows.isEmpty) return const [];
  final sampleRowIdx = headerRowIndex >= 0 ? headerRowIndex : 0;
  final maxCols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  if (maxCols == 0) return const [];

  final assigned = <ImportTargetField>{};
  final result = <ImportColumnMapping>[];

  // Find first non-empty cell below header as preview sample per column
  String findSample(int col) {
    final start = headerRowIndex >= 0 ? headerRowIndex + 1 : 0;
    for (var r = start; r < rows.length && r < start + 15; r++) {
      if (col < rows[r].length && rows[r][col].trim().isNotEmpty) {
        return rows[r][col].trim();
      }
    }
    return '';
  }

  for (var col = 0; col < maxCols; col++) {
    final headerText = headerRowIndex >= 0 &&
            headerRowIndex < rows.length &&
            col < rows[headerRowIndex].length
        ? rows[headerRowIndex][col].trim()
        : 'Cột ${col + 1}';
    final sample = findSample(col);
    final norm = _normalizeHeader(headerText);

    ImportTargetField target = ImportTargetField.ignore;
    String? customKey;

    if (headerRowIndex >= 0) {
      if (!assigned.contains(ImportTargetField.name) &&
          _nameHeaders.contains(norm)) {
        target = ImportTargetField.name;
        assigned.add(target);
      } else if (!assigned.contains(ImportTargetField.phone) &&
          _phoneHeaders.contains(norm)) {
        target = ImportTargetField.phone;
        assigned.add(target);
      } else if (!assigned.contains(ImportTargetField.group) &&
          _groupHeaders.contains(norm)) {
        target = ImportTargetField.group;
        assigned.add(target);
      } else if (!assigned.contains(ImportTargetField.tag) &&
          _tagHeaders.contains(norm)) {
        target = ImportTargetField.tag;
        assigned.add(target);
      } else if (!assigned.contains(ImportTargetField.status) &&
          _statusHeaders.contains(norm)) {
        target = ImportTargetField.status;
        assigned.add(target);
      } else if (norm.isNotEmpty) {
        target = ImportTargetField.custom;
        customKey = norm;
      }
    } else if (sampleRowIdx < rows.length) {
      final firstRow = rows[sampleRowIdx];
      if (maxCols == 1 && col == 0) {
        target = ImportTargetField.phone;
      } else {
        final firstLooksLikePhone =
            firstRow.isNotEmpty && _looksLikePhone(firstRow[0]);
        if (col == 0) {
          target = firstLooksLikePhone
              ? ImportTargetField.phone
              : ImportTargetField.name;
        } else if (col == 1) {
          target = firstLooksLikePhone
              ? ImportTargetField.name
              : ImportTargetField.phone;
        } else if (col == 2) {
          target = ImportTargetField.group;
        } else if (col == 3) {
          target = ImportTargetField.tag;
        }
      }
    }

    result.add(
      ImportColumnMapping(
        sourceIndex: col,
        headerText: headerText.isEmpty ? 'Cột ${col + 1}' : headerText,
        sampleValue: sample,
        targetField: target,
        customKey: customKey,
      ),
    );
  }
  return result;
}

/// Converts raw rows into validated preview items according to user [mappings].
List<ImportedRowValidation> buildValidatedImportRows(
  List<List<String>> rows, {
  required int headerRowIndex,
  required List<ImportColumnMapping> mappings,
}) {
  if (rows.isEmpty) return const [];
  final startRow = headerRowIndex >= 0 ? headerRowIndex + 1 : 0;
  final now = DateTime.now();

  int? findIdx(ImportTargetField f) {
    for (final m in mappings) {
      if (m.targetField == f) return m.sourceIndex;
    }
    return null;
  }

  final nameIdx = findIdx(ImportTargetField.name);
  final phoneIdx = findIdx(ImportTargetField.phone);
  final groupIdx = findIdx(ImportTargetField.group);
  final tagIdx = findIdx(ImportTargetField.tag);
  final statusIdx = findIdx(ImportTargetField.status);
  final customMappings = mappings
      .where(
        (m) =>
            m.targetField == ImportTargetField.custom &&
            (m.customKey?.trim().isNotEmpty ?? false),
      )
      .toList();

  final results = <ImportedRowValidation>[];
  for (var r = startRow; r < rows.length; r++) {
    final row = rows[r];
    String cellAt(int? idx) =>
        (idx != null && idx >= 0 && idx < row.length) ? row[idx].trim() : '';

    final phone = cellAt(phoneIdx);
    var name = cellAt(nameIdx);
    if (phone.isEmpty && name.isEmpty) continue;
    if (name.isEmpty) name = phone;

    final group = cellAt(groupIdx);
    final tag = cellAt(tagIdx);
    final status = cellAt(statusIdx);
    final customAttrs = <String, String>{};
    for (final m in customMappings) {
      final val = cellAt(m.sourceIndex);
      if (val.isNotEmpty) customAttrs[m.customKey!] = val;
    }

    final contact = Contact(
      id: '',
      name: name,
      phone: phone,
      group: group.isEmpty ? 'Mặc định' : group,
      tag: tag.isEmpty ? 'Mặc định' : tag,
      source: 'Import File',
      status: status.isEmpty ? 'Chưa gửi' : status,
      createdAt: now,
      customAttributes: customAttrs,
    );
    final err = validateImportedContact(contact);
    results.add(
      ImportedRowValidation(
        rowIndex: r,
        contact: contact,
        errorReason: err,
        selected: err == null,
      ),
    );
  }
  return results;
}

String _decodeText(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    bytes = Uint8List.sublistView(bytes, 3);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

List<List<String>> _parseDelimitedRows(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final firstLine = LineSplitter.split(normalized)
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final delimiter = firstLine.contains('\t')
      ? '\t'
      : (';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
            ? ';'
            : ',');

  final rows = <List<String>>[];
  var currentRow = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var cellCount = 0;
  var rowCount = 0;

  void finishCell() {
    if (currentRow.length >= _maxColumns || ++cellCount > _maxCells) {
      throw const FormatException(_limitMessage);
    }
    currentRow.add(cell.toString().trim());
    cell.clear();
  }

  void finishRow() {
    if (++rowCount > _maxRows) throw const FormatException(_limitMessage);
    if (currentRow.any((c) => c.isNotEmpty)) rows.add(currentRow);
    currentRow = <String>[];
  }

  for (var i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < normalized.length && normalized[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == delimiter) {
      finishCell();
    } else if (ch == '\n') {
      finishCell();
      finishRow();
    } else {
      cell.write(ch);
    }
    if (cell.length > _maxCellCharacters) {
      throw const FormatException(_limitMessage);
    }
  }
  if (cell.isNotEmpty || currentRow.isNotEmpty) {
    finishCell();
    finishRow();
  }
  return rows;
}

List<List<String>> _parseXlsxRows(Uint8List bytes) {
  final files = _readZipEntries(bytes);
  final sharedXml = files['xl/sharedStrings.xml'];
  final sharedStrings = sharedXml != null
      ? _parseSharedStrings(utf8.decode(sharedXml, allowMalformed: true))
      : const <String>[];

  final sheetKey = files.keys.firstWhere(
    (k) => k == 'xl/worksheets/sheet1.xml',
    orElse: () => files.keys.firstWhere(
      (k) => k.startsWith('xl/worksheets/sheet') && k.endsWith('.xml'),
      orElse: () => '',
    ),
  );
  if (sheetKey.isEmpty) return const [];
  final sheetXml = utf8.decode(files[sheetKey]!, allowMalformed: true);
  return _parseWorksheetXml(sheetXml, sharedStrings);
}

Map<String, Uint8List> _readZipEntries(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var eocdOffset = -1;
  final minEocd = bytes.length - 65557 < 0 ? 0 : bytes.length - 65557;
  for (var i = bytes.length - 22; i >= minEocd; i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50 &&
        i + 22 + data.getUint16(i + 20, Endian.little) == bytes.length) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset < 0) throw const FormatException(_invalidZip);

  final totalEntries = data.getUint16(eocdOffset + 10, Endian.little);
  var cdOffset = data.getUint32(eocdOffset + 16, Endian.little);
  final cdEnd = cdOffset + data.getUint32(eocdOffset + 12, Endian.little);
  if (totalEntries > 4096 ||
      data.getUint16(eocdOffset + 4, Endian.little) != 0 ||
      data.getUint16(eocdOffset + 6, Endian.little) != 0 ||
      data.getUint16(eocdOffset + 8, Endian.little) != totalEntries ||
      cdOffset > eocdOffset ||
      cdEnd > eocdOffset) {
    throw const FormatException(_invalidZip);
  }
  final entries =
      <
        String,
        ({int method, int flags, int compressedSize, int size, int offset})
      >{};
  for (var idx = 0; idx < totalEntries; idx++) {
    if (cdOffset + 46 > cdEnd ||
        data.getUint32(cdOffset, Endian.little) != 0x02014b50) {
      throw const FormatException(_invalidZip);
    }
    final nameLen = data.getUint16(cdOffset + 28, Endian.little);
    final nextOffset =
        cdOffset +
        46 +
        nameLen +
        data.getUint16(cdOffset + 30, Endian.little) +
        data.getUint16(cdOffset + 32, Endian.little);
    if (nextOffset > cdEnd) throw const FormatException(_invalidZip);
    final name = utf8.decode(
      Uint8List.sublistView(bytes, cdOffset + 46, cdOffset + 46 + nameLen),
      allowMalformed: true,
    );
    if (entries.containsKey(name)) throw const FormatException(_invalidZip);
    entries[name] = (
      method: data.getUint16(cdOffset + 10, Endian.little),
      flags: data.getUint16(cdOffset + 8, Endian.little),
      compressedSize: data.getUint32(cdOffset + 20, Endian.little),
      size: data.getUint32(cdOffset + 24, Endian.little),
      offset: data.getUint32(cdOffset + 42, Endian.little),
    );
    if (data.getUint16(cdOffset + 34, Endian.little) != 0) {
      throw const FormatException(_invalidZip);
    }
    cdOffset = nextOffset;
  }
  if (cdOffset != cdEnd) throw const FormatException(_invalidZip);
  final sheet = entries.containsKey('xl/worksheets/sheet1.xml')
      ? 'xl/worksheets/sheet1.xml'
      : entries.keys.firstWhere(
          (name) =>
              name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml'),
          orElse: () => '',
        );
  final result = <String, Uint8List>{};
  var totalBytes = 0;
  for (final name in ['xl/sharedStrings.xml', if (sheet.isNotEmpty) sheet]) {
    final entry = entries[name];
    if (entry == null) continue;
    final localOffset = entry.offset;
    if (localOffset + 30 > data.getUint32(eocdOffset + 16, Endian.little) ||
        data.getUint32(localOffset, Endian.little) != 0x04034b50 ||
        entry.flags & 0x41 != 0 ||
        data.getUint16(localOffset + 6, Endian.little) != entry.flags ||
        data.getUint16(localOffset + 8, Endian.little) != entry.method ||
        (entry.method != 0 && entry.method != 8)) {
      throw const FormatException(_invalidZip);
    }
    if (entry.size > _maxXmlBytes ||
        totalBytes + entry.size > _maxTotalXmlBytes) {
      throw const FormatException(_limitMessage);
    }
    final localNameLen = data.getUint16(localOffset + 26, Endian.little);
    final localExtraLen = data.getUint16(localOffset + 28, Endian.little);
    final dataStart = localOffset + 30 + localNameLen + localExtraLen;
    if (dataStart + entry.compressedSize >
            data.getUint32(eocdOffset + 16, Endian.little) ||
        utf8.decode(
              Uint8List.sublistView(
                bytes,
                localOffset + 30,
                localOffset + 30 + localNameLen,
              ),
              allowMalformed: true,
            ) !=
            name) {
      throw const FormatException(_invalidZip);
    }
    final slice = Uint8List.sublistView(
      bytes,
      dataStart,
      dataStart + entry.compressedSize,
    );
    final output = _BoundedXmlSink(_maxTotalXmlBytes - totalBytes);
    if (entry.method == 0) {
      output.add(slice);
    } else {
      final decoder = ZLibCodec(
        raw: true,
      ).decoder.startChunkedConversion(output);
      for (var offset = 0; offset < slice.length; offset += 1024) {
        decoder.add(
          Uint8List.sublistView(
            slice,
            offset,
            offset + 1024 < slice.length ? offset + 1024 : slice.length,
          ),
        );
      }
      decoder.close();
    }
    final xml = output.bytes.takeBytes();
    if (xml.length != entry.size) throw const FormatException(_invalidZip);
    totalBytes += xml.length;
    result[name] = xml;
  }
  return result;
}

class _BoundedXmlSink implements Sink<List<int>> {
  _BoundedXmlSink(this.totalRemaining);
  final int totalRemaining;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > _maxXmlBytes ||
        bytes.length + chunk.length > totalRemaining) {
      throw const FormatException(_limitMessage);
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

List<String> _parseSharedStrings(String xml) {
  final siRegex = RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true);
  final tRegex = RegExp(r'<t(?:\s[^>]*)?>(.*?)</t>', dotAll: true);
  final strings = <String>[];
  for (final si in siRegex.allMatches(xml)) {
    if (strings.length >= _maxCells) throw const FormatException(_limitMessage);
    final value = tRegex
        .allMatches(si.group(1)!)
        .map((m) => _unescapeXml(m.group(1)!))
        .join();
    if (value.length > _maxCellCharacters) {
      throw const FormatException(_limitMessage);
    }
    strings.add(value);
  }
  return strings;
}

List<List<String>> _parseWorksheetXml(String xml, List<String> sharedStrings) {
  final rowRegex = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
  final cellRegex = RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true);
  final refAttr = RegExp(r'\br="([A-Z]+)\d+"');
  final typeAttr = RegExp(r'\bt="([^"]+)"');
  final vTag = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true);
  final tTag = RegExp(r'<t(?:\s[^>]*)?>(.*?)</t>', dotAll: true);

  final rows = <List<String>>[];
  var rowCount = 0;
  var cellCount = 0;
  var allocatedCells = 0;
  for (final rowMatch in rowRegex.allMatches(xml)) {
    if (++rowCount > _maxRows) throw const FormatException(_limitMessage);
    final rowCells = <int, String>{};
    var maxCol = -1;
    var nextCol = 0;

    for (final cellMatch in cellRegex.allMatches(rowMatch.group(1)!)) {
      if (++cellCount > _maxCells) throw const FormatException(_limitMessage);
      final attrs = cellMatch.group(1) ?? '';
      final inner = cellMatch.group(2) ?? '';
      final refMatch = refAttr.firstMatch(attrs);
      final colIndex = refMatch != null
          ? _columnLettersToIndex(refMatch.group(1)!)
          : nextCol;
      if (colIndex >= _maxColumns) throw const FormatException(_limitMessage);
      nextCol = colIndex + 1;
      if (colIndex > maxCol) maxCol = colIndex;

      final type = typeAttr.firstMatch(attrs)?.group(1) ?? '';
      String value = '';
      if (type == 'inlineStr') {
        value = tTag
            .allMatches(inner)
            .map((m) => _unescapeXml(m.group(1)!))
            .join();
      } else {
        final rawV = vTag.firstMatch(inner)?.group(1) ?? '';
        if (type == 's') {
          final idx = int.tryParse(rawV.trim());
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            value = sharedStrings[idx];
          }
        } else {
          value = _unescapeXml(rawV);
        }
      }
      if (value.length > _maxCellCharacters) {
        throw const FormatException(_limitMessage);
      }
      rowCells[colIndex] = value.trim();
    }

    if (maxCol >= 0) {
      allocatedCells += maxCol + 1;
      if (allocatedCells > _maxCells) {
        throw const FormatException(_limitMessage);
      }
      final row = List<String>.generate(maxCol + 1, (i) => rowCells[i] ?? '');
      if (row.any((c) => c.isNotEmpty)) {
        rows.add(row);
      }
    }
  }
  return rows;
}

int _columnLettersToIndex(String letters) {
  var result = 0;
  for (var i = 0; i < letters.length; i++) {
    result = result * 26 + (letters.codeUnitAt(i) - 64);
    if (result > _maxColumns) throw const FormatException(_limitMessage);
  }
  return result - 1;
}

String _unescapeXml(String input) {
  return input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

List<Contact> _rowsToContacts(List<List<String>> rows) {
  if (rows.isEmpty) return const [];

  final firstRow = rows.first;
  int? nameIdx;
  int? phoneIdx;
  int? groupIdx;
  int? tagIdx;
  final customHeaders = <int, String>{};

  for (var i = 0; i < firstRow.length; i++) {
    final norm = _normalizeHeader(firstRow[i]);
    if (nameIdx == null && _nameHeaders.contains(norm)) {
      nameIdx = i;
    } else if (phoneIdx == null && _phoneHeaders.contains(norm)) {
      phoneIdx = i;
    } else if (groupIdx == null && _groupHeaders.contains(norm)) {
      groupIdx = i;
    } else if (tagIdx == null && _tagHeaders.contains(norm)) {
      tagIdx = i;
    } else if (norm.isNotEmpty) {
      customHeaders[i] = norm;
    }
  }

  final hasHeader = nameIdx != null || phoneIdx != null;
  final startRow = hasHeader ? 1 : 0;

  if (!hasHeader) {
    customHeaders.clear();
    if (firstRow.length == 1) {
      phoneIdx = 0;
      nameIdx = 0;
    } else {
      final firstLooksLikePhone = _looksLikePhone(firstRow[0]);
      phoneIdx = firstLooksLikePhone ? 0 : 1;
      nameIdx = firstLooksLikePhone ? 1 : 0;
      if (firstRow.length > 2) groupIdx = 2;
      if (firstRow.length > 3) tagIdx = 3;
    }
  }

  final now = DateTime.now();
  final contacts = <Contact>[];
  for (var r = startRow; r < rows.length; r++) {
    final row = rows[r];
    String cellAt(int? idx) =>
        (idx != null && idx >= 0 && idx < row.length) ? row[idx].trim() : '';

    var phone = cellAt(phoneIdx);
    var name = cellAt(nameIdx);
    if (phone.isEmpty && name.isEmpty) continue;
    if (name.isEmpty) name = phone;

    final group = cellAt(groupIdx);
    final tag = cellAt(tagIdx);
    final customAttrs = <String, String>{};
    for (final entry in customHeaders.entries) {
      final val = cellAt(entry.key);
      if (val.isNotEmpty) customAttrs[entry.value] = val;
    }

    contacts.add(
      Contact(
        id: '',
        name: name,
        phone: phone,
        group: group.isEmpty ? 'Mặc định' : group,
        tag: tag.isEmpty ? 'Mặc định' : tag,
        source: 'Import File',
        status: 'Chưa gửi',
        createdAt: now,
        customAttributes: customAttrs,
      ),
    );
  }
  return contacts;
}

bool _looksLikePhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 8 && digits.length <= 15;
}

String _normalizeHeader(String raw) {
  var s = raw.trim().toLowerCase();
  const vietMap = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
  };
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    buf.write(vietMap[ch] ?? ch);
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

const _nameHeaders = {
  'name',
  'full_name',
  'fullname',
  'customer',
  'customer_name',
  'ten',
  'ten_khach',
  'ho_ten',
  'ho_va_ten',
  'ten_khach_hang',
  'khach_hang',
};

const _phoneHeaders = {
  'phone',
  'phone_number',
  'mobile',
  'tel',
  'zalo',
  'sdt',
  'so_dien_thoai',
  'dien_thoai',
};

const _groupHeaders = {
  'group',
  'customer_group',
  'company',
  'nhom',
  'nhom_khach_hang',
  'cong_ty',
};

const _tagHeaders = {
  'tag',
  'tags',
  'label',
  'nhan',
  'linh_vuc',
  'phan_loai',
};

const _statusHeaders = {
  'status',
  'trang_thai',
  'state',
};
