class_name MinesweeperTypes
extends RefCounted

enum CellVisibility {
	COVERED,
	REVEALED,
	FLAGGED,
}

enum GameStatus {
	READY,
	PLAYING,
	WON,
	LOST,
}

class CellData extends RefCounted:
	var has_mine: bool = false
	var adjacent_mines: int = 0
	var visibility: int = CellVisibility.COVERED

	func reset() -> void:
		has_mine = false
		adjacent_mines = 0
		visibility = CellVisibility.COVERED
