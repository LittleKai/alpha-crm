const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function processAppSelectField(typeParam, innerStr) {
    let newInner = innerStr.replace(/DropdownMenuItem\s*(<[^>]+>)?\s*\(\s*value:\s*(.*?),\s*child:\s*Text\(\s*([\s\S]+?)\s*\)\s*,?\s*\)/g, (m, t, v, textContent) => {
        let parts = textContent.split(',');
        let label = parts[0].trim();
        return `AppDropdownItem${t || ''}(value: ${v}, label: ${label})`;
    });
    
    return `AppDropdownField${typeParam || ''}(${newInner})`;
}

function refactorFile(filePath) {
    if (!filePath.endsWith('.dart')) return;
    
    let original = fs.readFileSync(filePath, 'utf8');
    let content = original;

    let parts = content.split(/AppSelectField(<[^>]+>)?\s*\(/);
    
    if (parts.length > 1) {
        let newContent = parts[0];
        for (let i = 1; i < parts.length; i += 2) {
            let typeParam = parts[i];
            let rest = parts[i + 1];
            
            let depth = 1;
            let j = 0;
            for (; j < rest.length; j++) {
                if (rest[j] === '(') depth++;
                if (rest[j] === ')') depth--;
                if (depth === 0) break;
            }
            
            let innerStr = rest.substring(0, j);
            let afterStr = rest.substring(j + 1);
            
            newContent += processAppSelectField(typeParam, innerStr) + afterStr;
        }
        content = newContent;
    }

    if (content !== original) {
        content = content.replace(/app_select_field\.dart/g, 'app_dropdown_field.dart');
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Updated:', filePath);
    }
}

walkDir('lib', refactorFile);
