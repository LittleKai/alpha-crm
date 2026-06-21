import os
import re

def process_file(filepath):
    if not filepath.endswith('.dart'): return
    if 'app_dropdown_field.dart' in filepath: return
    if 'chatbot_screen.dart' in filepath: return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    original = content
    
    # Replace AppSelectField imports
    content = content.replace("import '../../../../../shared/widgets/app_select_field.dart';", "import '../../../../../shared/widgets/app_dropdown_field.dart';")
    content = content.replace("import '../../../../shared/widgets/app_select_field.dart';", "import '../../../../shared/widgets/app_dropdown_field.dart';")
    content = content.replace("import '../../../shared/widgets/app_select_field.dart';", "import '../../../shared/widgets/app_dropdown_field.dart';")
    content = content.replace("import '../../shared/widgets/app_select_field.dart';", "import '../../shared/widgets/app_dropdown_field.dart';")
    
    # We want to replace DropdownMenuItem(...) with AppDropdownItem(...) 
    # ONLY when it's inside AppSelectField. 
    # A simpler approach: replace AppSelectField -> AppDropdownField
    # And then globally replace DropdownMenuItem(value: X, child: Text(Y)) -> AppDropdownItem(value: X, label: Y)
    # BUT only in files where AppSelectField was replaced, or just globally since we want to migrate everything?
    # Wait, if we replace DropdownButtonFormField -> AppDropdownField too, we can just replace DropdownMenuItem globally in the file.
    # The prompt was "thay thế dropdown theo quy chuẩn dropdown chung này". It implies all dropdowns.
    
    # Let's replace AppSelectField
    content = re.sub(r'AppSelectField<([^>]+)>', r'AppDropdownField<\1>', content)
    content = re.sub(r'AppSelectField\(', r'AppDropdownField(', content)
    
    # Replace DropdownMenuItem
    # Pattern: DropdownMenuItem(value: e, child: Text(e))
    # It might span multiple lines.
    # We use a regex that matches `DropdownMenuItem<...>(value: ..., child: Text(...))`
    pattern = r'DropdownMenuItem(?:<[^>]+>)?\s*\(\s*value:\s*(.+?),\s*child:\s*Text\(\s*([^,)]+?)(?:,\s*[^)]*)?\)\s*,?\s*\)'
    content = re.sub(pattern, r'AppDropdownItem(value: \1, label: \2)', content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        process_file(os.path.join(root, file))
