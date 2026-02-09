extends ProgressBar

func setup(max_hp: int):
	self.max_value = max_hp
	self.value = max_hp

func update_health(new_hp: int):
	self.value = new_hp
