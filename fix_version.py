# Update project.godot
p = open('project.godot', 'r', encoding='utf-8').read()
p = p.replace('config/name="WILDBOUND 0.1"', 'config/name="WILDBOUND 0.3"')
open('project.godot', 'w', encoding='utf-8').write(p)

# Update README.md
import os
if os.path.exists('README.md'):
    r = open('README.md', 'r', encoding='utf-8').read()
    r = r.replace('WILDBOUND 0.1', 'WILDBOUND 0.3')
    open('README.md', 'w', encoding='utf-8').write(r)

print("Updated versions to 0.3")
