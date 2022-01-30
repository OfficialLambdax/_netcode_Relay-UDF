#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Relay.au3"


; startup _netcode_Relay
_netcode_Relay_Startup()
$__net_bTraceEnable = False

; create relay. Open at port 1226, directs all traffic to 127.0.0.1:1225
_netcode_Relay_Create("0.0.0.0", 1226, "127.0.0.1", 1225)

; loop it
While True
	_netcode_Relay_Loop()


	; commenting the sleep as the effect that your
	; cpu will be bashed, but also the affect that the latency
	; goes down by alot.
	Sleep(10)
WEnd