const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else {
            results.push(file);
        }
    });
    return results;
}

function fixInitialValue(filePath) {
    if (!filePath.endsWith('.dart')) return;
    
    let content = fs.readFileSync(filePath, 'utf8');
    
    if (content.includes('DropdownButtonFormField') || content.includes('EntityPicker')) {
        // Replace initialValue: with value: in DropdownButtonFormField context
        // We use a regex that looks for DropdownButtonFormField followed by some content and then initialValue:
        // We match until a closing parenthesis ); or another widget definition.
        
        // This regex is slightly different in JS. We use the 's' flag for dotAll if available, or [^]
        content = content.replace(/DropdownButtonFormField[^]*?initialValue:/g, (match) => {
            // Ensure we didn't cross into another widget like TextFormField
            if (match.includes('TextFormField')) {
                return match; // Don't replace if there's a TextFormField in between
            }
            return match.replace('initialValue:', 'value:');
        });

        if (filePath.endsWith('entity_picker.dart')) {
            content = content.replace('initialValue: widget.value', 'value: widget.value');
        }
    }
    
    fs.writeFileSync(filePath, content);
}

const files = walk('lib');
files.forEach(fixInitialValue);
