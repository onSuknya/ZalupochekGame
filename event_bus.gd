
extends Node

signal item_collected(item_name: String, amount: int)
signal item_removed(item_name: String, amount: int)

signal inventory_changed
signal selected_item_changed(item_name: String)

signal world_generated
signal world_requested
signal return_to_menu_requested

# Игрок успешно добыл ресурс.
signal resource_collected(item_name: String, amount: int)

# Ресурс передан инвентарю для добавления в слот или руку.
signal inventory_resource_ready(item_name: String, amount: int)
