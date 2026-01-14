on run {input, parameters}
	
	if input is {} then
		set input to choose file with prompt "Selecciona las imagenes a procesar:" of type {"public.image"} with multiple selections allowed
	end if
	
	-- Elegir logo (PNG)
	set wmAlias to choose file with prompt "Elige tu logo (PNG con fondo transparente):"
	set wmPath to POSIX path of wmAlias
	
	-- Parametros (con defaults guardados)
	set wmPct to my askNumber("Tamano del logo como % del ancho de la foto (12 a 25 recomendado):", my getPref("wmPct", "18"))
	set wmOpacity to my askNumber("Opacidad del logo (0 a 100):", my getPref("wmOpacity", "35"))
	set wmMargin to my askNumber("Margen en pixeles:", my getPref("wmMargin", "30"))
	set jpgQuality to my askNumber("Calidad JPG (80 a 100). Recomendado 92-98:", my getPref("jpgQuality", "98"))
	
	-- Posicion (recordar ultima)
	set lastPos to my getPref("position", "Arriba derecha")
	set posChoice to choose from list {"Arriba izquierda", "Arriba derecha", "Abajo izquierda", "Abajo derecha", "Centro"} with prompt "Elige la posicion:" default items {lastPos}
	if posChoice is false then return input
	set posChoice to item 1 of posChoice
	
	set gravity to "northeast"
	if posChoice is "Arriba izquierda" then set gravity to "northwest"
	if posChoice is "Arriba derecha" then set gravity to "northeast"
	if posChoice is "Abajo izquierda" then set gravity to "southwest"
	if posChoice is "Abajo derecha" then set gravity to "southeast"
	if posChoice is "Centro" then set gravity to "center"
	
	-- Carpeta destino
	set outFolder to choose folder with prompt "Selecciona la carpeta destino:"
	set outDir to POSIX path of outFolder
	if outDir does not end with "/" then set outDir to outDir & "/"
	
	-- Ruta ImageMagick
	set magickPath to "/opt/homebrew/bin/magick"
	try
		do shell script "/bin/test -x " & quoted form of magickPath
	on error
		set magickPath to "/usr/local/bin/magick"
		try
			do shell script "/bin/test -x " & quoted form of magickPath
		on error
			display dialog "No encontre ImageMagick (magick).

Instalalo con:
brew install imagemagick" buttons {"OK"} default button "OK"
			return input
		end try
	end try
	
	-- Log
	set logPath to (POSIX path of (path to desktop folder)) & "watermark_app_log.txt"
	do shell script "/bin/echo " & quoted form of ("---- RUN " & ((current date) as text) & " ----") & " >> " & quoted form of logPath
	
	repeat with f in input
		set inPath to POSIX path of f
		set baseName to my filenameNoExt(inPath)
		set outPath to outDir & baseName & "_wm.jpg"
		
		-- Obtener ancho de la foto
		set wStr to do shell script quoted form of magickPath & " identify -format %w " & quoted form of inPath
		set wInt to wStr as integer
		set wmW to (wInt * wmPct) div 100
		if wmW < 1 then set wmW to 1
		
		-- Comando (una sola linea)
		set cmd to quoted form of magickPath & " " & quoted form of inPath & " -auto-orient " & ¬
			"\\( " & quoted form of wmPath & " -alpha on -resize " & wmW & "x \\) " & ¬
			"-gravity " & gravity & " -geometry +" & wmMargin & "+" & wmMargin & " " & ¬
			"-compose dissolve -define compose:args=" & wmOpacity & " -composite " & ¬
			"-sampling-factor 4:4:4 -quality " & jpgQuality & " " & ¬
			quoted form of outPath
		
		try
			do shell script "/bin/zsh -lc " & quoted form of cmd
		on error errMsg
			do shell script "/bin/echo " & quoted form of ("ERROR: " & inPath & " :: " & errMsg) & " >> " & quoted form of logPath
			display dialog "Error procesando:
" & inPath & "

Detalle:
" & errMsg buttons {"OK"} default button "OK"
		end try
	end repeat
	
	-- Guardar ultimos valores para la proxima ejecucion
	my setPref("wmPct", wmPct as text)
	my setPref("wmOpacity", wmOpacity as text)
	my setPref("wmMargin", wmMargin as text)
	my setPref("jpgQuality", jpgQuality as text)
	my setPref("position", posChoice as text)
	
	display dialog "Listo.
Archivos guardados en:
" & outDir & "

Log:
" & logPath buttons {"OK"} default button "OK"
	return input
end run


-- Helpers
on askNumber(promptText, defaultValue)
	set d to display dialog promptText default answer (defaultValue as text) buttons {"Cancelar", "OK"} default button "OK"
	if button returned of d is "Cancelar" then error number -128
	set t to text returned of d
	try
		set n to t as integer
	on error
		set n to defaultValue as integer
	end try
	return n
end askNumber

on filenameNoExt(p)
	set bn to do shell script "/usr/bin/basename " & quoted form of p
	set nameOnly to do shell script "/bin/echo " & quoted form of bn & " | /usr/bin/sed 's/\\.[^.]*$//'"
	return nameOnly
end filenameNoExt

-- Preferencias persistentes (defaults)
on getPref(key, defaultValue)
	try
		return do shell script "defaults read com.watermark.app " & key
	on error
		return defaultValue
	end try
end getPref

on setPref(key, value)
	do shell script "defaults write com.watermark.app " & key & " " & quoted form of value
end setPref