-- ============================================================
-- OrganizarCorreo.applescript
-- ------------------------------------------------------------
-- Qué hace:
--   Recorre TODAS las cuentas de Apple Mail. Para cada cuenta,
--   revisa la bandeja de ENTRADA y la de ENVIADOS.
--   Toma solo los correos marcados como LEÍDOS.
--   Para cada correo leído:
--     - Si es de entrada -> usa el dominio del REMITENTE
--     - Si es de salida  -> usa el dominio del PRIMER DESTINATARIO
--   Crea (si no existe) una carpeta con el nombre del dominio,
--   dentro una subcarpeta "Entrada" o "Enviado" según corresponda,
--   y dentro de esa, una subcarpeta con la dirección de correo,
--   y MUEVE el mensaje ahí.
--
--   Estructura resultante, ej:
--     gmail.com/Entrada/cliente1@gmail.com
--     gmail.com/Enviado/cliente1@gmail.com
--   Lleva un registro (procesados.txt) con el Message-ID de cada
--   correo ya movido, para no volver a tocarlo en la próxima corrida.
-- ============================================================

property logFolder : (POSIX path of (path to home folder)) & "Library/Application Support/OrganizarCorreo/"
property logFile : logFolder & "procesados.txt"
property processedIDs : {}
property nuevosIDs : {}

on run
	-- Preparar carpeta y archivo de registro si no existen
	do shell script "mkdir -p " & quoted form of logFolder
	do shell script "touch " & quoted form of logFile

	set contenido to (do shell script "cat " & quoted form of logFile)
	if contenido is "" then
		set processedIDs to {}
	else
		set processedIDs to paragraphs of contenido
	end if
	set nuevosIDs to {}

	tell application "Mail"
		set listaCuentas to every account
	end tell

	repeat with cuenta in listaCuentas
		set nombreCuenta to (name of cuenta) as text
		log "Procesando cuenta: " & nombreCuenta

		-- Bandeja de entrada
		try
			tell application "Mail" to set elInbox to mailbox "INBOX" of cuenta
			my procesarBuzon(elInbox, "entrada")
		on error errMsg
			log "  Sin INBOX accesible en " & nombreCuenta & ": " & errMsg
		end try

		-- Enviados: el nombre varía según proveedor (Gmail, iCloud, Exchange, etc.)
		repeat with nombreEnviados in {"Sent Messages", "Sent", "Enviados", "Correo enviado"}
			try
				tell application "Mail" to set laCarpetaEnviados to mailbox (nombreEnviados as text) of cuenta
				my procesarBuzon(laCarpetaEnviados, "salida")
				exit repeat
			on error
				-- probar el siguiente nombre posible
			end try
		end repeat
	end repeat

	-- Guardar los IDs nuevos procesados en esta corrida
	if (count of nuevosIDs) > 0 then
		set AppleScript's text item delimiters to linefeed
		set textoNuevo to nuevosIDs as text
		set AppleScript's text item delimiters to ""
		do shell script "echo " & quoted form of textoNuevo & " >> " & quoted form of logFile
	end if

	log "Listo. Correos movidos en esta corrida: " & (count of nuevosIDs)
end run

-- ------------------------------------------------------------
-- Procesa un buzón: filtra los leídos y mueve los que falten
-- ------------------------------------------------------------
on procesarBuzon(elBuzon, tipo)
	tell application "Mail"
		set mensajesLeidos to (every message of elBuzon whose read status is true)
	end tell

	repeat with unMensaje in mensajesLeidos
		try
			tell application "Mail"
				set idUnico to (message id of unMensaje)
			end tell
			if idUnico is missing value or idUnico is "" then
				tell application "Mail" to set numId to (id of unMensaje)
				set idUnico to "sinid-" & (numId as text)
			end if

			if (processedIDs does not contain idUnico) and (nuevosIDs does not contain idUnico) then

				set direccionClave to ""

				if tipo is "entrada" then
					tell application "Mail" to set textoRemitente to (sender of unMensaje)
					set direccionClave to my extraerCorreo(textoRemitente)
				else
					tell application "Mail" to set listaDestinatarios to (to recipients of unMensaje)
					if (count of listaDestinatarios) > 0 then
						tell application "Mail" to set direccionClave to (address of item 1 of listaDestinatarios)
					end if
				end if

				if direccionClave is not "" then
					set dominio to my extraerDominio(direccionClave)

					if dominio is not "" then
						if tipo is "entrada" then
							set nombreSubcarpeta to "Entrada"
						else
							set nombreSubcarpeta to "Enviado"
						end if

						set rutaNivel1 to dominio
						set rutaNivel2 to dominio & "/" & nombreSubcarpeta
						set rutaNivel3 to dominio & "/" & nombreSubcarpeta & "/" & direccionClave

						my asegurarCarpeta(rutaNivel1)
						my asegurarCarpeta(rutaNivel2)
						my asegurarCarpeta(rutaNivel3)

						tell application "Mail"
							set carpetaDestino to mailbox rutaNivel3
							move unMensaje to carpetaDestino
						end tell

						set end of nuevosIDs to idUnico
					end if
				end if
			end if
		on error errMsg
			log "  Error con un mensaje: " & errMsg
		end try
	end repeat
end procesarBuzon

-- Extrae "correo@dominio.com" de un texto tipo "Nombre <correo@dominio.com>"
on extraerCorreo(remitenteTexto)
	set textoOriginal to remitenteTexto as text
	if textoOriginal contains "<" then
		set AppleScript's text item delimiters to "<"
		set parte2 to text item 2 of textoOriginal
		set AppleScript's text item delimiters to ">"
		set correo to text item 1 of parte2
		set AppleScript's text item delimiters to ""
		return correo
	else
		return textoOriginal
	end if
end extraerCorreo

-- Extrae el dominio de "correo@dominio.com" -> "dominio.com"
on extraerDominio(correoCompleto)
	if correoCompleto contains "@" then
		set AppleScript's text item delimiters to "@"
		set dominio to text item 2 of correoCompleto
		set AppleScript's text item delimiters to ""
		return dominio
	else
		return ""
	end if
end extraerDominio

-- Crea una carpeta (mailbox) en Mail si todavía no existe
on asegurarCarpeta(rutaCarpeta)
	tell application "Mail"
		try
			mailbox rutaCarpeta
		on error
			make new mailbox with properties {name:rutaCarpeta}
		end try
	end tell
end asegurarCarpeta
