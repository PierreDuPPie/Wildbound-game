import re

content = open('scripts/core/bootstrap.gd', 'r', encoding='utf-8').read()

# Strip out all the previously added broken lines
content = re.sub(r'\n\tPartyManager\.current_zone = current_zone', '', content)
content = re.sub(r'\n\t\t\tPartyManager\.current_zone = current_zone', '', content)
content = re.sub(r'PartyManager\.current_zone = current_zone\n', '', content)

# Carefully add them back with proper indentation
def repl(m):
    indent = m.group(1)
    return m.group(0) + indent + "PartyManager.current_zone = current_zone\n"

content = re.sub(r'^([ \t]*)(current_zone = [^\n]+)\n', repl, content, flags=re.MULTILINE)

open('scripts/core/bootstrap.gd', 'w', encoding='utf-8').write(content)
print("Fixed indentation in bootstrap.gd")
