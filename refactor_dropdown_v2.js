const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function processAppSelectField(match, typeParam, innerStr) {
    // replace DropdownMenuItem inside AppSelectField
    // pattern: DropdownMenuItem(value: V, child: Text(L))
    let newInner = innerStr.replace(/DropdownMenuItem\s*(<[^>]+>)?\s*\(\s*value:\s*(.*?),\s*child:\s*Text\(\s*([\s\S]+?)\s*\)\s*,?\s*\)/g, (m, t, v, textContent) => {
        // extract label from textContent (might have style: ...)
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

    // 1. AppSelectField replacement
    // We use a regex that handles nested parens roughly. 
    // Since javascript doesn't have recursive matching, we'll just match AppSelectField<...>( up to the next AppSelectField or end of widget.
    // A simpler way is to split by AppSelectField and process.
    let parts = content.split(/AppSelectField(<[^>]+>)?\s*\(/);
    // parts[0] is before first AppSelectField
    // parts[1] is type param (or undefined)
    // parts[2] is the rest...
    
    if (parts.length > 1) {
        let newContent = parts[0];
        for (let i = 1; i < parts.length; i += 2) {
            let typeParam = parts[i];
            let rest = parts[i + 1];
            
            // find the closing parenthesis for AppSelectField
            let depth = 1;
            let j = 0;
            for (; j < rest.length; j++) {
                if (rest[j] === '(') depth++;
                if (rest[j] === ')') depth--;
                if (depth === 0) break;
            }
            
            let innerStr = rest.substring(0, j);
            let afterStr = rest.substring(j + 1); // skip closing )
            
            newContent += processAppSelectField('', typeParam, innerStr) + ')' + afterStr;
        }
        content = newContent;
    }

    if (content !== original) {
        // Replace imports
        content = content.replace(/app_select_field\.dart/g, 'app_dropdown_field.dart');
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Updated:', filePath);
    }
}

walkDir('lib', refactorFile);
