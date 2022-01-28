#include-once
#include "_netcode_AddonCore.au3"


#cs

	Requires the _netcode_AddonCore.au3 UDF and _netcode_Core.au3 UDF.

	TCP-IPv4, for the time being, only.

#ce

Global $__net_Relay_sAddonVersion = "0.2"


Func _netcode_Relay_Startup()
	_netcode_Startup() ; it doesnt matter that it might was already called, because it just returns if it already was

	Local $arParents = __netcode_Addon_GetSocketList('RelayParents')
	If IsArray($arParents) Then Return False

	__netcode_Addon_CreateSocketList('RelayParents')

	__netcode_Addon_Log(0, 1)
	Return True
EndFunc

Func _netcode_Relay_Shutdown()
	; closes each and every client and parent and wipes everything clean

;~ 	__netcode_Addon_Log(0, 2)
EndFunc


; if no socket is given then all parent sockets are looped
Func _netcode_Relay_Loop(Const $hSocket = False)

	if $hSocket Then
		__netcode_Relay_Loop($hSocket)
	Else
		Local $arParents = __netcode_Addon_GetSocketList('RelayParents')

		For $i = 0 To UBound($arParents) - 1
			__netcode_Relay_Loop($arParents[$i])
		Next
	EndIf

EndFunc


Func _netcode_Relay_Create($sOpenOnIP, $nOpenOnPort, $sRelayToIP, $nRelayToPort)

	; start listener
	Local $hSocket = __netcode_TCPListen($sOpenOnIP, $nOpenOnPort, Default)
	Local $nError = @error
	If $nError Then
		__netcode_Addon_Log(0, 3, $hSocket)
		Return SetError(1, $nError, False)
	EndIf

	; add to parent socket list
	If Not __netcode_Addon_AddToSocketList('RelayParents', $hSocket) Then
		__netcode_TCPCloseSocket($hSocket)
		__netcode_Addon_Log(0, 3, $hSocket)
		Return SetError(2, 0, False)
	EndIf

	; create socket list for the incoming pending clients
	__netcode_Addon_CreateSocketList($hSocket & '_IncomingPending')

	; create socket list for the outgoing pending clients (aka connect clients)
	__netcode_Addon_CreateSocketList($hSocket & '_OutgoingPending')

	; create socket list for all clients
	__netcode_Addon_CreateSocketList($hSocket)

	; save relay information
	Local $arRelayDestination[2] = [$sRelayToIP,$nRelayToPort]
	__netcode_Addon_SetVar($hSocket, 'RelayDestination', $arRelayDestination)

	__netcode_Addon_Log(0, 2, $hSocket)

	Return $hSocket

EndFunc

Func _netcode_Relay_Close(Const $hSocket)

	Local $arClients = __netcode_Addon_GetSocketList($hSocket)
	If Not IsArray($arClients) Then
		__netcode_Addon_Log(0, 5, $hSocket)
		Return SetError(1, 0, False) ; unknown relay
	EndIf

	; close and wipe incoming pending list
	__netcode_Addon_WipeSocketList($hSocket & '_IncomingPending')

	; close and wipe outgoing pending list
	__netcode_Addon_WipeSocketList($hSocket & '_OutgoingPending')

	; close all clients and wipe the vars
	__netcode_Addon_WipeSocketList($hSocket)

	; close the relay listener
	__netcode_TCPCloseSocket($hSocket)

	; remove it from the parent list
	__netcode_Addon_RemoveFromSocketList('RelayParents', $hSocket)

	__netcode_Addon_Log(0, 4, $hSocket)

	Return True
EndFunc






; accepts new clients
; connects non blocking to the destination
; and then adds both together
Func __netcode_Relay_Loop(Const $hSocket)

	; check for new incoming connections. a single per loop
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	if $hIncomingSocket <> -1 Then __netcode_Relay_NewIncoming($hSocket, $hIncomingSocket)

	; check pending incoming for disconnects
;~ 	__netcode_Relay_CheckIncoming($hSocket)

	; check pending outgoing for timeouts or successfully connects
	__netcode_Relay_CheckOutgoing($hSocket)

	; recv and send data
	__netcode_Relay_RecvAndSend($hSocket)

EndFunc

Func __netcode_Relay_NewIncoming(Const $hSocket, $hIncomingSocket)

	__netcode_Addon_Log(0, 10, $hIncomingSocket)

	; add to pending list
	__netcode_Addon_AddToSocketList($hSocket & '_IncomingPending', $hIncomingSocket)

	; get relay destination
	Local $arRelayDestination = __netcode_Addon_GetVar($hSocket, 'RelayDestination')

	; connect non blocking
	Local $hOutgoingSocket = __netcode_TCPConnect($arRelayDestination[0], $arRelayDestination[1], 2, True)

	; add to pending list
	__netcode_Addon_AddToSocketList($hSocket & '_OutgoingPending', $hOutgoingSocket)

	; init timer for timeout
	__netcode_Addon_SetVar($hOutgoingSocket, 'ConnectTimer', TimerInit())

	; link them already together
	__netcode_Addon_SetVar($hIncomingSocket, 'Link', $hOutgoingSocket)
	__netcode_Addon_SetVar($hOutgoingSocket, 'Link', $hIncomingSocket)

	__netcode_Addon_Log(0, 11, $arRelayDestination[0] & ':' & $arRelayDestination[1])

EndFunc

#cs
Func __netcode_Relay_CheckIncoming(Const $hSocket)

	; get incoming socket list
	Local $arClients = __netcode_Addon_GetSocketList($hSocket & '_IncomingPending')
	if UBound($arClients) = 0 Then Return

	; select
	$arClients = __netcode_SocketSelect($arClients, True)
	Local $nArSize = UBound($arClients)

	If $nArSize = 0 Then Return

	Local $hOutgoingSocket = 0

	; for each select socket
	For $i = 0 To $nArSize - 1

		; check connection
		__netcode_Addon_TCPRecv($arClients[$i], 1)

		; if disconnected then
		Switch @error

			Case 1, 10050 To 10054

				; get linked outgoing socket
				$hOutgoingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

				; close both
				__netcode_TCPCloseSocket($arClients[$i])
				__netcode_TCPCloseSocket($hOutgoingSocket)

				; remove the incoming and outgoing socket
				__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $arClients[$i])
				__netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $hOutgoingSocket)

				; tidy both socket vars
				_storageS_TidyGroupVars($arClients[$i])
				_storageS_TidyGroupVars($hOutgoingSocket)

		EndSwitch

	Next

EndFunc
#ce

Func __netcode_Relay_CheckOutgoing(Const $hSocket)

	; get outgoing socket list
	Local $arClients = __netcode_Addon_GetSocketList($hSocket & '_OutgoingPending')
	If UBound($arClients) = 0 Then Return

	; select
	$arClients = __netcode_SocketSelect($arClients, False)
	Local $nArSize = UBound($arClients)
	Local $hIncomingSocket = 0

	; if sockets have successfully connected
	If $nArSize > 0 Then


		For $i = 0 To $nArSize - 1

			__netcode_Addon_Log(0, 12, $arClients[$i])

			; get incoming socket
			$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

			; add both to the clients list
			__netcode_Addon_AddToSocketList($hSocket, $arClients[$i])
			__netcode_Addon_AddToSocketList($hSocket, $hIncomingSocket)

			; remove both from the pending lists
			__netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $arClients[$i])
			__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $hIncomingSocket)

			__netcode_Addon_Log(0, 13, $hIncomingSocket, $arClients[$i])

		Next

	EndIf

	; reread the outgoing socket list
	$arClients = __netcode_Addon_GetSocketList($hSocket & '_OutgoingPending')
	$nArSize = UBound($arClients)

	if $nArSize = 0 Then Return

	; check timeouts
	Local $hTimer = 0

	For $i = 0 To $nArSize - 1

		; get timer
		$hTimer = __netcode_Addon_GetVar($arClients[$i], 'ConnectTimer')

		; check timeout
		if TimerDiff($hTimer) > 2000 Then

			__netcode_Addon_Log(0, 14, $arClients[$i])

			; get incoming socket
			$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

			; close both
			__netcode_TCPCloseSocket($arClients[$i])
			__netcode_TCPCloseSocket($hIncomingSocket)

			; remove both
			__netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $arClients[$i])
			__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $hIncomingSocket)

			; tidy both
			_storageS_TidyGroupVars($arClients[$i])
			_storageS_TidyGroupVars($hIncomingSocket)

			__netcode_Addon_Log(0, 15, $hIncomingSocket)

		EndIf

	Next

EndFunc

Func __netcode_Relay_RecvAndSend(Const $hSocket)

	; get sockets
	Local $arClients = __netcode_Addon_GetSocketList($hSocket)
	if UBound($arClients) = 0 Then Return

	; select these that have something received or that are disconnected
	$arClients = __netcode_SocketSelect($arClients, True)
	Local $nArSize = UBound($arClients)
	if $nArSize = 0 Then Return

	; get the linked sockets
	Local $arSockets[$nArSize]
	For $i = 0 To $nArSize - 1
		$arSockets[$i] = __netcode_Addon_GetVar($arClients[$i], 'Link')
	Next

	; filter the linked sockets, for those that are send ready
	$arClients = __netcode_SocketSelect($arSockets, False)
	Local $nArSize = UBound($arClients)

	if $nArSize = 0 Then Return

	Local $sData = ""
	Local $hLinkSocket = 0

	; recv and send
	For $i = 0 To $nArSize - 1

		; get the socket that had something to be received
		$hLinkSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

		; get the recv buffer
		$sData = __netcode_Addon_RecvPackages($hLinkSocket)

		; check if we disconnected
		if @error Then

			__netcode_TCPCloseSocket($arClients[$i])
			__netcode_TCPCloseSocket($hLinkSocket)

			__netcode_Addon_RemoveFromSocketList($hSocket, $arClients[$i])
			__netcode_Addon_RemoveFromSocketList($hSocket, $hLinkSocket)

			_storageS_TidyGroupVars($arClients[$i])
			_storageS_TidyGroupVars($hLinkSocket)

			__netcode_Addon_Log(0, 15, $arClients[$i])
			__netcode_Addon_Log(0, 15, $hLinkSocket)

			ContinueLoop

		EndIf

		__netcode_Addon_Log(0, 16, $hLinkSocket, $arClients[$i], @extended)

		; send the data non blocking
		__netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

	Next

EndFunc




