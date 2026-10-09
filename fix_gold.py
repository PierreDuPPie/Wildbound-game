inv_code = open('scripts/core/inventory_manager.gd', 'r', encoding='utf-8').read()
if 'var gold: int' not in inv_code:
    inv_code = inv_code.replace('var inventory: Dictionary = {}', 'var inventory: Dictionary = {}\nvar gold: int = 500')
    inv_code = inv_code.replace('func to_save_dict() -> Dictionary:', 'func to_save_dict() -> Dictionary:\n\treturn {\n\t\t"items": _items_to_save_dict(),\n\t\t"gold": gold\n\t}')
    inv_code = inv_code.replace('	var data: Dictionary = {}', 'func _items_to_save_dict() -> Dictionary:\n\tvar data: Dictionary = {}')
    inv_code = inv_code.replace('func load_from_save_dict(data: Dictionary) -> void:\n\tinventory.clear()', 'func load_from_save_dict(data: Dictionary) -> void:\n\tgold = int(data.get("gold", 500))\n\tinventory.clear()\n\tvar items_data = data.get("items", data) if data.has("items") else data')
    inv_code = inv_code.replace('	for key: String in data.keys():', '\tfor key: String in items_data.keys():\n\t\tif key == "gold" or key == "items": continue')
    open('scripts/core/inventory_manager.gd', 'w', encoding='utf-8').write(inv_code)

town_code = open('scripts/world/sanctuary_town.gd', 'r', encoding='utf-8').read()
town_code = town_code.replace('var player_gold: int = 500', '')
town_code = town_code.replace('player_gold', 'InventoryManager.gold')
open('scripts/world/sanctuary_town.gd', 'w', encoding='utf-8').write(town_code)
print("Updated gold persistence")
