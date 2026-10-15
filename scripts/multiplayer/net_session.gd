class_name NetSession
extends Node
## The one RPC surface shared by client and headless server (MULTIPLAYER.md §14). Both builds put
## this node at the same path (/root/Match/Session) with identical @rpc declarations; it only checks
## who sent a call and forwards it to whichever role is attached.
##
## Client -> server calls are "any_peer", so the server re-checks the sender on every call and the
## registry decides what that sender may touch. Server -> client calls are "authority" (peer 1) and
## the client checks the sender again before trusting them.

signal join_requested(peer_id: int, version: Variant, player_name: Variant)
signal inputs_received(peer_id: int, epoch: Variant, payload: Variant)
signal join_accepted_received(entity_id: Variant, epoch: Variant, server_tick: Variant)
signal join_rejected_received(reason: Variant)
signal roster_received(entries: Variant)
signal snapshot_received(server_tick: Variant, ack_sequence: Variant, entities: Variant)
signal events_received(events: Variant)


# --- Client -> server ----------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func request_join(version: Variant, player_name: Variant) -> void:
	if multiplayer.is_server():
		join_requested.emit(multiplayer.get_remote_sender_id(), version, player_name)


@rpc("any_peer", "call_remote", "unreliable", NetProtocol.CH_INPUT)
func submit_inputs(epoch: Variant, payload: Variant) -> void:
	if multiplayer.is_server():
		inputs_received.emit(multiplayer.get_remote_sender_id(), epoch, payload)


# --- Server -> client ----------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func join_accepted(entity_id: Variant, epoch: Variant, server_tick: Variant) -> void:
	if _from_server():
		join_accepted_received.emit(entity_id, epoch, server_tick)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func join_rejected(reason: Variant) -> void:
	if _from_server():
		join_rejected_received.emit(reason)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_CONTROL)
func receive_roster(entries: Variant) -> void:
	if _from_server():
		roster_received.emit(entries)


@rpc("authority", "call_remote", "unreliable_ordered", NetProtocol.CH_SNAPSHOT)
func receive_snapshot(server_tick: Variant, ack_sequence: Variant, entities: Variant) -> void:
	if _from_server():
		snapshot_received.emit(server_tick, ack_sequence, entities)


@rpc("authority", "call_remote", "reliable", NetProtocol.CH_EVENTS)
func receive_events(events: Variant) -> void:
	if _from_server():
		events_received.emit(events)


func _from_server() -> bool:
	return not multiplayer.is_server() and multiplayer.get_remote_sender_id() == NetProtocol.SERVER_PEER
