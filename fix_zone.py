content = open('scripts/core/bootstrap.gd', 'r', encoding='utf-8').read()
import re
content = re.sub(r'(current_zone = (.*))\n', r'\1\n\tPartyManager.current_zone = current_zone\n', content)
open('scripts/core/bootstrap.gd', 'w', encoding='utf-8').write(content)
print("Added PartyManager.current_zone sync")
