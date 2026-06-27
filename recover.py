import json
import os
import sys

transcript_path = r'C:\Users\kiabo\.gemini\antigravity\brain\d2fd5741-f700-448e-80b9-08fd027898e7\.system_generated\logs\transcript_full.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    data = json.loads(line)
    if data.get('source') == 'SYSTEM' and data.get('type') == 'TOOL_RESPONSE':
        content = data.get('content', '')
        if '@@ -132,612 +132,6 @@' in content:
            diff_lines = content.split('\n')
            recovered = []
            in_block = False
            for dl in diff_lines:
                if '@@ -132,612 +132,6 @@' in dl:
                    in_block = True
                    continue
                if in_block:
                    if dl == '[diff_block_end]':
                        break
                    if dl.startswith('-'):
                        recovered.append(dl[1:]) # remove the minus
                    elif dl.startswith(' '):
                        recovered.append(dl[1:]) # remove the space
            
            with open('recovered.gd', 'w', encoding='utf-8') as out:
                out.write('\n'.join(recovered))
            print('Recovered ' + str(len(recovered)) + ' lines!')
            break
