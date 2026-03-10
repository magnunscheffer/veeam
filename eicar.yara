rule Detect_EICAR_Comprehensive
{
    meta:
        description = "Detecta o arquivo de teste EICAR em múltiplos formatos (Padrão, Hex, Base64)"
        author = "Gemini AI"
        date = "2026-03-10"
        severity = "Informacional"

    strings:
        // 1. O padrão clássico do EICAR (Início da string)
        $eicar_standard = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"

        // 2. EICAR em formato Hexadecimal (útil se estiver embutido em scripts)
        $eicar_hex = { 58 35 4f 21 50 25 40 41 50 5b 34 5c 50 5a 58 35 34 28 50 5e 29 37 43 43 29 37 7d 24 45 49 43 41 52 2d 53 54 41 4e 44 41 52 44 2d 41 4e 54 49 56 49 52 55 53 2d 54 45 53 54 2d 46 49 4c 45 21 24 48 2b 48 2a }

        // 3. EICAR codificado em Base64 (comum em anexos de e-mail ou scripts PowerShell)
        // WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVRELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=
        $eicar_b64 = "WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVRELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo"

        // 4. Detecção parcial para evitar evasão por concatenação simples
        $part1 = "X5O!P%@AP["
        $part2 = "EICAR-STANDARD"

    condition:
        // Gatilho se qualquer uma das formas for encontrada
        $eicar_standard or 
        $eicar_hex or 
        $eicar_b64 or 
        ($part1 and $part2)
}
