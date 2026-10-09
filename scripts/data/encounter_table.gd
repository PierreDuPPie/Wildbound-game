class_name EncounterTable
extends Resource

@export var species: Array[CreatureSpecies] = []
@export var weights: Array[int] = []

func roll(rng: RandomNumberGenerator) -> CreatureSpecies:
    if species.is_empty():
        return null
    var total := 0
    for index in range(species.size()):
        var weight := 1
        if index < weights.size():
            weight = maxi(weights[index], 0)
        total += weight
    if total <= 0:
        return species[0]
    var pick := rng.randi_range(1, total)
    var cursor := 0
    for index in range(species.size()):
        var weight := 1
        if index < weights.size():
            weight = maxi(weights[index], 0)
        cursor += weight
        if pick <= cursor:
            return species[index]
    return species.back()
