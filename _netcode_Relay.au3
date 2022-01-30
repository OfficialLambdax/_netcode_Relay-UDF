#include-once
#include "_netcode_AddonCore.au3"


#cs

	Requires the _netcode_AddonCore.au3 UDF and _netcode_Core.au3 UDF.

	TCP-IPv4, for the time being, only.

	All Sockets are non blocking.

	The proxy will only recv and send data if the send to socket is send ready.
	It pretty much checks the sockets that have something send to the proxy first
	and then filters them for the corresponding linked sockets that can be send to.

	So the proxy does not buffer data. Memory usage should therefore be low.

#ce

Global $__net_Relay_sAddonVersion = "0.2.2"


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Relay_Startup
; Description ...: Needs to be called in order to use the UDF.
; Syntax ........: _netcode_Relay_Startup()
; Return values .: True				= Success
;				 : False			= UDF already started
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Relay_Startup()
	_netcode_Startup() ; it doesnt matter that it might was already called, because it just returns if it already was

	Local $arParents = __netcode_Addon_GetSocketList('RelayParents')
	If IsArray($arParents) Then Return False

	__netcode_Addon_CreateSocketList('RelayParents')

	__netcode_Addon_Log(0, 1)
	Return True
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Relay_Shutdown
; Description ...: ~ todo
; Syntax ........: _netcode_Relay_Shutdown()
; Parameters ....: None
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Relay_Shutdown()
	; closes each and every client and parent and wipes everything clean

;~ 	__netcode_Addon_Log(0, 2)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Relay_Loop
; Description ...: Will accept new clients and receive and send data. Needs to be called frequently in order to relay the data.
; Syntax ........: _netcode_Relay_Loop([$hSocket = False])
; Parameters ....: $hSocket             - [optional] When set to a Socket, will only loop the given relay socket. Otherwise all.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Relay_Create
; Description ...: Starts a relay parent (aka listener) and returns the socket.
; Syntax ........: _netcode_Relay_Create($sOpenOnIP, $nOpenOnPort, $sRelayToIP, $nRelayToPort)
; Parameters ....: $sOpenOnIP           - Relay is open to this IP (set 0.0.0.0 for everyone)
;                  $nOpenOnPort         - Port to listen
;                  $sRelayToIP          - Relay to this IP
;                  $nRelayToPort        - Relay to this Port
; Return values .: Socket				= If success
;				 : False				= If not
; Errors ........: 1					- Listener could not be started
;				 : 2					- UDF not started yet
; Extendeds .....: See msdn https://docs.microsoft.com/de-de/windows/win32/winsock/windows-sockets-error-codes-2
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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

	; create socket lists
	__netcode_Addon_CreateSocketLists_InOutRel($hSocket)

	; save relay information
	Local $arRelayDestination[2] = [$sRelayToIP,$nRelayToPort]
	__netcode_Addon_SetVar($hSocket, 'RelayDestination', $arRelayDestination)

	__netcode_Addon_Log(0, 2, $hSocket)

	Return $hSocket

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Relay_Close
; Description ...: ~ todo
; Syntax ........: _netcode_Relay_Close(Const $hSocket)
; Parameters ....: $hSocket             - [const] a handle value.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
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







Func __netcode_Relay_Loop(Const $hSocket)

	; check for new incoming connections. a single per loop
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	if $hIncomingSocket <> -1 Then __netcode_Addon_NewIncoming($hSocket, $hIncomingSocket, 0)

	; check pending incoming for disconnects
;~ 	__netcode_Addon_CheckIncoming($hSocket, 0)

	; check pending outgoing for timeouts or successfull connects
	__netcode_Addon_CheckOutgoing($hSocket, 0)

	; recv and send data
	__netcode_Addon_RecvAndSend($hSocket, 0)

EndFunc
