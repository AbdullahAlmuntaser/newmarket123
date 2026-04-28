import os
import re

def fix_initial_value(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Replace initialValue with value when it's inside a DropdownButtonFormField or entity_picker.dart
    # We look for DropdownButtonFormField followed by some content and then initialValue:
    # This is a bit tricky with regex, so we'll do it more carefully.
    
    # Pattern to find DropdownButtonFormField and the next initialValue
    # This regex attempts to find DropdownButtonFormField and then the first occurrence of initialValue:
    # until it hits a closing parenthesis or next widget.
    
    # A simpler approach: if a file contains DropdownButtonFormField, 
    # and we find 'initialValue:' we can check the context.
    
    if 'DropdownButtonFormField' in content or 'EntityPicker' in content:
        # Regex to find initialValue: and check if it's likely a DropdownButtonFormField
        # We'll use a simple replacement for now and verify.
        # Actually, let's use a more surgical approach.
        
        lines = content.split('\n')
        new_lines = []
        is_inside_dropdown = False
        for line in lines:
            if 'DropdownButtonFormField' in line:
                is_inside_dropdown = True
            
            if is_inside_dropdown and 'initialValue:' in line:
                line = line.replace('initialValue:', 'value:')
            
            if is_inside_dropdown and ');' in line: # End of widget call (approximate)
                # This is weak but might work for most cases.
                pass 
                
            new_lines.append(line)
        
        # Reset is_inside_dropdown is hard. 
        # Let's just replace all 'initialValue:' with 'value:' if it's NOT a 'TextFormField'.
        # Wait, that's also risky.
        
        # How about: find all occurrences of DropdownButtonFormField and replace the next initialValue
        content = re.sub(r'(DropdownButtonFormField<[^>]*>\s*\(\s*)initialValue:', r'\1value:', content)
        content = re.sub(r'(DropdownButtonFormField\s*\(\s*)initialValue:', r'\1value:', content)
        
        # Also for cases where it's not immediately after (more common)
        # We'll match DropdownButtonFormField and then some content until initialValue:
        # We need to be careful not to skip over other widgets.
        
        # Let's use a more robust regex:
        # Match DropdownButtonFormField, then any characters except 'TextFormField' or 'TextEditingController' 
        # until initialValue:
        def replace_dropdown(match):
            return match.group(0).replace('initialValue:', 'value:')

        content = re.sub(r'DropdownButtonFormField[^{};]*?initialValue:', replace_dropdown, content, flags=re.DOTALL)
        
        # Special case for entity_picker.dart
        if 'entity_picker.dart' in file_path:
             content = content.replace('initialValue: widget.value', 'value: widget.value')

    with open(file_path, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_initial_value(os.path.join(root, file))
