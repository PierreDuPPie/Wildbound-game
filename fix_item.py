inv_code = open('scripts/core/inventory_manager.gd', 'r', encoding='utf-8').read()

old_sig = 'func use_item_on_creature(item_id: StringName, creature: CreatureInstance) -> Dictionary:'
new_sig = 'func use_item_on_creature(item_id: StringName, creature: CreatureInstance, in_battle: bool = false) -> Dictionary:'

if old_sig in inv_code:
    inv_code = inv_code.replace(old_sig, new_sig)
    
    # Add context check
    context_check = '''	if in_battle and not item.can_use_in_battle():
		result["message"] = "Cannot use this item in battle."
		return result
	if not in_battle and not item.can_use_in_overworld():
		result["message"] = "Cannot use this item outside of battle."
		return result
'''
    inv_code = inv_code.replace('	if not has_item(item_id):\n\t\tresult["message"] = "No items remaining."\n\t\treturn result', 
                                '	if not has_item(item_id):\n\t\tresult["message"] = "No items remaining."\n\t\treturn result\n\n' + context_check)
                                
    # Add status and buff handling
    heal_logic = '	if item.heal_amount > 0:'
    buff_logic = '''
	if item.clears_status:
		creature.status_id = &"none"
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s was cured!" % creature.display_name()
		return result

	if item.buff_stat != &"none" and item.buff_stat != &"":
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s feels its %s rise! (Not fully implemented)" % [creature.display_name(), item.buff_stat]
		return result
'''
    inv_code = inv_code.replace(heal_logic, buff_logic + '\n' + heal_logic)
    
    open('scripts/core/inventory_manager.gd', 'w', encoding='utf-8').write(inv_code)
    print("Updated inventory_manager.gd")
else:
    print("Signature not found")
