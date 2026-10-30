extends Node

## Sistema global de eventos de sonido / ruido para percepción de IA enemiga.
## Permite al jugador u otros emisores propagar perturbaciones acústicas en el mundo.

signal ruido_emitido(posicion: Vector3, radio: float)

func emitir_ruido(posicion: Vector3, radio: float) -> void:
	ruido_emitido.emit(posicion, radio)
