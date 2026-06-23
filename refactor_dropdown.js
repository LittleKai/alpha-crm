const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function refactorFile(filePath) {
    if (!filePath.endsWith('.dart')) return;
    
    let original = fs.readFileSync(filePath, 'utf8');
    let content = original;

    // 1. Replace imports
    content = content.replace(/app_select_field\.dart/g, 'app_dropdown_field.dart');

    // 2. Replace Widgets
    content = content.replace(/AppSelectField</g, 'AppDropdownField<');
    content = content.replace(/AppSelectField\(/g, 'AppDropdownField(');
    content = content.replace(/DropdownButtonFormField</g, 'AppDropdownField<');
    content = content.replace(/DropdownButtonFormField\(/g, 'AppDropdownField(');

    // 3. Replace DropdownMenuItem
    // This is the tricky part. We need to match DropdownMenuItem(value: X, child: Text(Y...))
    // We'll use a regex that handles newlines and optional params.
    // child:\s*Text\(([^,)]+)[^)]*\)
    
    let regex = /DropdownMenuItem\s*(<[^>]+>)?\s*\(\s*value:\s*([^,]+),\s*child:\s*Text\(\s*([^,)]+)(?:,\s*[^)]*)?\)\s*,?\s*\)/g;
    content = content.replace(regex, 'AppDropdownItem$1(value: $2, label: $3)');

    // For cases where child is not Text, or spans multiple lines, we can do a fallback generic replacement:
    let regex2 = /DropdownMenuItem\s*(<[^>]+>)?\s*\(\s*value:\s*(.+?),\s*child:\s*Text\(([\s\S]+?)\)\s*,?\s*\)/g;
    content = content.replace(regex2, (match, type, val, textContent) => {
        // textContent could be `'Text'` or `variable`
        // if textContent has a comma, we just take the first part
        let label = textContent.split(',')[0].trim();
        return `AppDropdownItem${type || ''}(value: ${val}, label: ${label})`;
    });

    if (content !== original) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Updated:', filePath);
    }
}

walkDir('lib', refactorFile);
