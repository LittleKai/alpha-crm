import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../mock/mock_contacts.dart';

/// Parses `.csv`, `.tsv`, `.txt`, or `.xlsx` bytes into [Contact] records.
List<Contact> parseCustomerImportBytes(Uint8List bytes, String fileName) {
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
  final firstLine = normalized.split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  final delimiter = firstLine.contains('\t')
      ? '\t'
      : (';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
            ? ';'
            : ',');

  final rows = <List<String>>[];
  var currentRow = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

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
      currentRow.add(cell.toString().trim());
      cell.clear();
    } else if (ch == '\n') {
      currentRow.add(cell.toString().trim());
      cell.clear();
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
      currentRow = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(cell.toString().trim());
    if (currentRow.any((c) => c.isNotEmpty)) {
      rows.add(currentRow);
    }
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
    if (data.getUint32(i, Endian.little) == 0x06054b50) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset < 0) return const {};

  final totalEntries = data.getUint16(eocdOffset + 10, Endian.little);
  var cdOffset = data.getUint32(eocdOffset + 16, Endian.little);
  final result = <String, Uint8List>{};
  final rawZlib = ZLibCodec(raw: true);

  for (var idx = 0; idx < totalEntries && cdOffset + 46 <= bytes.length; idx++) {
    if (data.getUint32(cdOffset, Endian.little) != 0x02014b50) break;
    final method = data.getUint16(cdOffset + 10, Endian.little);
    final compSize = data.getUint32(cdOffset + 20, Endian.little);
    final nameLen = data.getUint16(cdOffset + 28, Endian.little);
    final extraLen = data.getUint16(cdOffset + 30, Endian.little);
    final commentLen = data.getUint16(cdOffset + 32, Endian.little);
    final localOffset = data.getUint32(cdOffset + 42, Endian.little);

    final name = utf8.decode(
      Uint8List.sublistView(bytes, cdOffset + 46, cdOffset + 46 + nameLen),
      allowMalformed: true,
    );
    cdOffset += 46 + nameLen + extraLen + commentLen;

    if (localOffset + 30 > bytes.length) continue;
    if (data.getUint32(localOffset, Endian.little) != 0x04034b50) continue;
    final localNameLen = data.getUint16(localOffset + 26, Endian.little);
    final localExtraLen = data.getUint16(localOffset + 28, Endian.little);
    final dataStart = localOffset + 30 + localNameLen + localExtraLen;
    if (dataStart + compSize > bytes.length) continue;

    final slice = Uint8List.sublistView(bytes, dataStart, dataStart + compSize);
    if (method == 0) {
      result[name] = slice;
    } else if (method == 8) {
      result[name] = Uint8List.fromList(rawZlib.decode(slice));
    }
  }
  return result;
}

List<String> _parseSharedStrings(String xml) {
  final siRegex = RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true);
  final tRegex = RegExp(r'<t(?:\s[^>]*)?>(.*?)</t>', dotAll: true);
  return [
    for (final si in siRegex.allMatches(xml))
      tRegex
          .allMatches(si.group(1)!)
          .map((m) => _unescapeXml(m.group(1)!))
          .join(),
  ];
}

List<List<String>> _parseWorksheetXml(String xml, List<String> sharedStrings) {
  final rowRegex = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
  final cellRegex = RegExp(
    r'<c\b([^>]*?)(?:/>|>(.*?)</c>)',
    dotAll: true,
  );
  final refAttr = RegExp(r'\br="([A-Z]+)\d+"');
  final typeAttr = RegExp(r'\bt="([^"]+)"');
  final vTag = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true);
  final tTag = RegExp(r'<t(?:\s[^>]*)?>(.*?)</t>', dotAll: true);

  final rows = <List<String>>[];
  for (final rowMatch in rowRegex.allMatches(xml)) {
    final rowCells = <int, String>{};
    var maxCol = -1;
    var nextCol = 0;

    for (final cellMatch in cellRegex.allMatches(rowMatch.group(1)!)) {
      final attrs = cellMatch.group(1) ?? '';
      final inner = cellMatch.group(2) ?? '';
      final refMatch = refAttr.firstMatch(attrs);
      final colIndex = refMatch != null
          ? _columnLettersToIndex(refMatch.group(1)!)
          : nextCol;
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
      rowCells[colIndex] = value.trim();
    }

    if (maxCol >= 0) {
      final row = List<String>.generate(
        maxCol + 1,
        (i) => rowCells[i] ?? '',
      );
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
