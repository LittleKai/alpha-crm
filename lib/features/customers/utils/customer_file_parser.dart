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
    if (path == null) {
      if (bytes == null) {
        throw const FormatException('Không đọc được file / Cannot read file.');
      }
      return parseCustomerImportBytes(bytes, fileName);
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
      return parseCustomerImportBytes(content.takeBytes(), fileName);
    } finally {
      await file.close();
    }
  });
}

/// Parses `.csv`, `.tsv`, `.txt`, or `.xlsx` bytes into [Contact] records.
List<Contact> parseCustomerImportBytes(Uint8List bytes, String fileName) {
  if (bytes.length > _maxInputBytes) throw const FormatException(_limitMessage);
  final ext = fileName.toLowerCase().split('.').last;
  final rows = ext == 'xlsx'
      ? _parseXlsxRows(bytes)
      : _parseDelimitedRows(_decodeText(bytes));
  return _rowsToContacts(rows);
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
