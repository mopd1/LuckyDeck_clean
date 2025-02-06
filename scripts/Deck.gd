# Deck.gd
extends RefCounted

var cards = []
const SUITS = ["hearts", "diamonds", "clubs", "spades"]
const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

var rng: CryptoRNG

func _init():
	rng = CryptoRNG.new()
	reset()

func reset():
	cards.clear()
	for suit in SUITS:
		for rank in RANKS:
			cards.append({"suit": suit, "rank": rank})
	shuffle()

func shuffle():
	cards = rng.shuffle_array(cards)

func deal_card():
	if cards.is_empty():
		print("Error: No cards left in the deck!")
		return null
	return cards.pop_back()

func deal_hand(num_cards):
	var hand = []
	for i in range(num_cards):
		var card = deal_card()
		if card:
			hand.append(card)
	return hand
