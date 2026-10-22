param([switch]$Probar)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$dir  = Join-Path (Get-Location).Path '..\entregables'
$orig = Get-ChildItem $dir -Filter 'Plantilla - Informe*.docx' | Select-Object -First 1
$dest = Join-Path $dir 'Informe Metodologico FARMASIS - Corregido.docx'
Copy-Item $orig.FullName $dest -Force

$zip = [System.IO.Compression.ZipFile]::Open($dest, 'Update')
$entry = $zip.GetEntry('word/document.xml')
$sr = New-Object System.IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8)
$xml = $sr.ReadToEnd(); $sr.Close()

# pares: buscar => reemplazar
$cambios = @(
 @('una base de datos híbrida (MySQL y MongoDB) para garantizar consistencia y seguridad transaccional',
   'una base de datos documental unificada en MongoDB (usuarios, clientes, productos, facturas y configuración) para garantizar consistencia y seguridad transaccional'),
 @('incluyendo el modelo Entidad-Relación híbrido (MySQL/MongoDB)',
   'incluyendo el modelo de datos documental unificado en MongoDB (con una única colección de usuarios diferenciada por roles)'),
 @('los repositorios interactúan con bases de datos MySQL (seguridad) y MongoDB (catálogo). Todo el acceso es perimetrado por Spring Security y contraseñas cifradas en ',
   'los repositorios interactúan con una única base de datos MongoDB (usuarios, catálogo, facturas y configuración). Todo el acceso es perimetrado por Spring Security, con verificación en dos pasos (2FA) opcional que cada usuario decide activar desde Configuración, y contraseñas cifradas en '),
 @(' REST y Seguridad.',
   ' REST, seguridad y migración total de datos a MongoDB.'),
 @('- Sistema de Login con seguridad ',
   '- Sistema de Login con 2FA opcional y seguridad '),
 @('Modelado E-R físico y Esquema Estrella.',
   'Modelado documental en MongoDB y Esquema Estrella.'),
 @('El sistema garantiza la persistencia segura de los datos bajo arquitectura híbrida y cifra las identidades correctamente con Spring Security.',
   'El sistema garantiza la persistencia segura de los datos sobre MongoDB como única base de datos (se migraron los usuarios existentes sin pérdida de acceso y se unificaron clientes y usuarios en una sola colección con roles: administrador, empleado y cliente), cifra las identidades con Spring Security y ofrece verificación en dos pasos opcional. Se depuró el alcance eliminando los módulos de auditoría, novedades y asistencia, que no aportaban valor al negocio, y se rediseñó el dashboard del propietario con indicadores reales (ventas, tickets, top de productos y alertas de stock) consultados de forma optimizada.')
)
$ok = @(); $no = @()
foreach($c in $cambios){
  $b = $c[0].Replace('&','&amp;'); $r = $c[1].Replace('&','&amp;')
  $p = $c[0].Substring(0,[Math]::Min(40,$c[0].Length))
  if($xml.Contains($b)){ $xml = $xml.Replace($b,$r); $ok += $p } else { $no += $p }
}
"OK: " + $ok.Count; $ok | % { "  + $_" }
"NO ENCONTRADOS: " + $no.Count; $no | % { "  - $_" }

if($Probar){ $zip.Dispose(); Remove-Item $dest; return }
$entry.Delete()
$new = $zip.CreateEntry('word/document.xml')
$sw = New-Object System.IO.StreamWriter($new.Open(), (New-Object Text.UTF8Encoding($false)))
$sw.Write($xml); $sw.Close()
$zip.Dispose()
"Generado: $dest"
